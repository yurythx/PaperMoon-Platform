"""
Script de teste de carga (Locust) contra a stack PaperMoon-Platform.

⚠️ LEIA ANTES DE RODAR — o KEYCLOAK_URL padrão é o servidor REAL da
Prefeitura (sso.rondonopolis.mt.gov.br), usado em produção por funcionários
de verdade via AD/LDAP. Isto NÃO é um ambiente de teste isolado.

Regras que valem para qualquer execução contra esse Keycloak:
  1. Combine JANELA e CONCORRÊNCIA (--users/--spawn-rate) com quem administra
     o AD/Keycloak ANTES de rodar — nunca "só testar rapidinho" sem avisar.
  2. Use uma conta de TESTE dedicada (LOCUST_TEST_USERNAME/PASSWORD), nunca a
     conta real de um funcionário — políticas de lockout por tentativas
     erradas no AD podem bloquear a conta de alguém de verdade.
  3. Comece com poucos usuários simulados (ex: --users 5 --spawn-rate 1) e
     suba aos poucos, observando o Grafana/Prometheus da stack principal —
     não o dashboard do próprio Locust, que não vê o lado do servidor.
  4. Todo segredo (client_secret, usuário/senha de teste) vem de variável de
     ambiente — nunca hardcode um valor real aqui, mesmo "só pra testar uma
     vez". O .env desta stack é gerado pelo Ansible a partir de
     host_vars/test-stack.yml (vault), mesmo padrão do resto da plataforma.

Task 1 (autenticação) roda uma vez por usuário simulado, em on_start() — não
a cada iteração — para não transformar o teste de carga da API em um ataque
de força bruta contra o endpoint de login do Keycloak. Uma segunda task,
com peso bem menor, simula reautenticação periódica (renovação de sessão),
que é o padrão real de uso — não reautenticação a cada request.
"""

from __future__ import annotations

import os

from locust import HttpUser, between, task

# ── Configuração — tudo por variável de ambiente, sem default sensível ──────
#
# Troque REALM_NAME/CLIENT_ID pelo realm/client reais do seu ambiente antes
# de rodar. Ver docs/backend/sso-keycloak-integration.md (PaperMoon) para o
# racional completo da integração OIDC que esta stack está testando.

KEYCLOAK_URL = os.environ.get("KEYCLOAK_URL", "https://sso.rondonopolis.mt.gov.br")
REALM_NAME = os.environ.get("REALM_NAME", "Prefeitura")  # troque pro seu realm
CLIENT_ID = os.environ.get("CLIENT_ID", "papermoon")  # troque pro seu client_id

# client_secret só existe se o client for confidencial (tipo o "papermoon" do
# SSO de staff). Para um client PÚBLICO (sem secret), deixe
# CLIENT_SECRET="" no .env — o payload do token omite o campo nesse caso.
CLIENT_SECRET = os.environ.get("CLIENT_SECRET", "")

# Credenciais de um usuário de TESTE dedicado — nunca uma conta real (ver
# aviso no topo do arquivo). Sem default: o teste falha alto e explícito
# (KeyError-like via .environ direto) se alguém esquecer de configurar,
# em vez de silenciosamente tentar autenticar com string vazia.
LOCUST_TEST_USERNAME = os.environ["LOCUST_TEST_USERNAME"]
LOCUST_TEST_PASSWORD = os.environ["LOCUST_TEST_PASSWORD"]

# Alvos internos da stack PaperMoon — LAN, não o domínio público (evita
# gerar carga desnecessária no Cloudflare Tunnel/edge; o teste de carga
# quer medir o backend/frontend em si, não a CDN na frente deles).
DJANGO_API_URL = os.environ.get("DJANGO_API_URL", "http://192.168.1.102:8000")
NEXTJS_URL = os.environ.get("NEXTJS_URL", "http://192.168.1.102:3000")

TOKEN_ENDPOINT = f"{KEYCLOAK_URL}/realms/{REALM_NAME}/protocol/openid-connect/token"


class PaperMoonLoadTest(HttpUser):
    """
    Um "usuário simulado" completo: autentica uma vez no Keycloak, depois
    alterna entre chamadas autenticadas na API Django e navegação no
    frontend Next.js — simulando o uso real de alguém logado.

    `host` não é fixado aqui de propósito: cada task usa a URL completa
    (self.client.get/post com URL absoluta) porque as três tasks batem em
    três hosts diferentes (Keycloak, Django, Next.js). Rodar com
    `--host` vazio e checar os logs se o Locust reclamar.
    """

    wait_time = between(2, 8)  # ritmo humano, não rajada — ajuste com cautela

    def on_start(self) -> None:
        """Autentica uma vez quando o usuário simulado "nasce" — não a cada task."""
        self.access_token: str | None = None
        self.authenticate()

    def authenticate(self) -> None:
        """
        Grant `password` (Resource Owner Password Credentials) — usado aqui
        porque é o único jeito de simular "N usuários fazendo login" sem um
        navegador real por trás. Fora de teste de carga, ROPC é desencorajado
        pelo próprio OAuth 2.0 Security BCP (expõe a senha do usuário
        diretamente ao client) — não é o grant usado pelo login real da
        aplicação (que é Authorization Code + PKCE, ver ADR 0002 do
        PaperMoon). Não reaproveite este padrão fora deste script de teste.
        """
        payload = {
            "grant_type": "password",
            "client_id": CLIENT_ID,
            "username": LOCUST_TEST_USERNAME,
            "password": LOCUST_TEST_PASSWORD,
        }
        if CLIENT_SECRET:
            payload["client_secret"] = CLIENT_SECRET

        with self.client.post(
            TOKEN_ENDPOINT,
            data=payload,
            name="/realms/.../protocol/openid-connect/token",  # agrupa no relatório, evita 1 linha por realm
            catch_response=True,
        ) as response:
            if response.status_code != 200:
                response.failure(
                    f"Falha ao autenticar no Keycloak: {response.status_code} {response.text[:200]}"
                )
                return
            data = response.json()
            self.access_token = data.get("access_token")
            if not self.access_token:
                response.failure("Resposta 200 do Keycloak sem access_token no corpo")

    @property
    def auth_headers(self) -> dict[str, str]:
        return {"Authorization": f"Bearer {self.access_token}"} if self.access_token else {}

    # ── Task 1 — reautenticação periódica (peso baixo, não é o grosso da carga) ──
    @task(1)
    def reauthenticate(self) -> None:
        """
        Simula renovação de sessão (ex: token expirou, usuário volta depois de
        um tempo parado) — não uma tentativa de login nova a cada iteração.
        Peso 1 contra peso 5-6 das outras tasks: a maior parte do tempo o
        usuário simulado já está autenticado e só consome a API/frontend.
        """
        self.authenticate()

    # ── Task 2 — API Django autenticada ─────────────────────────────────────
    @task(6)
    def hit_django_api(self) -> None:
        if not self.access_token:
            return  # on_start falhou em autenticar — não gera carga sem token

        # Endpoints de exemplo, leves e read-only — troque pelos endpoints
        # reais que você quer medir (ver docs/backend/api.md do PaperMoon).
        # Evite endpoints de escrita (POST/PATCH) num teste de carga, a menos
        # que o objetivo explícito seja testar concorrência de escrita —
        # nesse caso, use dados de teste, nunca IDs de clientes reais.
        self.client.get(
            f"{DJANGO_API_URL}/api/v1/auth/me/",
            headers=self.auth_headers,
            name="/api/v1/auth/me/",
        )
        self.client.get(
            f"{DJANGO_API_URL}/health/",
            name="/health/",  # público, sem auth — bom baseline de latência do backend puro
        )

    # ── Task 3 — Frontend Next.js ────────────────────────────────────────────
    @task(5)
    def hit_nextjs_frontend(self) -> None:
        # GETs simples de página — medem SSR/tempo de resposta, não interação
        # de UI (Locust não executa JavaScript, é só requisição HTTP crua).
        self.client.get(f"{NEXTJS_URL}/", name="/ (home)")
        self.client.get(f"{NEXTJS_URL}/servicos", name="/servicos")
        self.client.get(f"{NEXTJS_URL}/login", name="/login")
