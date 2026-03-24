# Instagram OAuth Flow (PsyManager)

## Fluxo planejado

1. O app iOS chama o backend em `/auth/instagram/start`.
2. O backend inicia OAuth com Meta/Instagram.
3. Meta redireciona para o callback do backend.
4. O backend troca `code` por token com seguranca.
5. O backend redireciona o app para `psymanager://oauth/instagram?...`.
6. O app interpreta o deep link e marca a conexao como ativa.
7. O app usa o backend para sincronizar insights via `/instagram/insights`.

## Motivo para usar backend

- proteger `app secret`
- controlar refresh token
- aplicar cache/rate limit
- centralizar logs e tratamento de falhas

## Deep link esperado pelo app

- `psymanager://oauth/instagram?status=success&handle=<artistHandle>`
