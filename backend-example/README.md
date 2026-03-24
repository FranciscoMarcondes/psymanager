# PsyManager Backend Example

Backend Node/Express de exemplo para:

- iniciar fluxo OAuth de Instagram (mock)
- redirecionar de volta para o app iOS por deep link
- expor endpoint de insights semanais/mensais

## Uso

1. `cp .env.example .env`
2. `npm install`
3. `npm run dev`

## Endpoints

- `GET /health`
- `GET /auth/instagram/start?artist=<handle>&redirect_uri=<custom_scheme>`
- `GET /auth/instagram/callback`
- `GET /instagram/insights?artist=<handle>`

## Importante

Este backend e um exemplo funcional de contrato. Para producao, substitua o mock pelo fluxo real com Meta Graph API, armazenamento seguro de tokens e renovacao de credenciais.
