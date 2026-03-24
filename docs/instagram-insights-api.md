# Instagram Insights API Contract (PsyManager)

## Objetivo

Fornecer snapshots de insights semanais/mensais para o app analisar crescimento, alcance e sugerir ações.

## Endpoint sugerido

- `GET /instagram/insights?artist=<handle>`

Exemplo:

- `https://seu-backend.com/instagram/insights?artist=astralnomad`

## Resposta JSON esperada

```json
[
  {
    "periodLabel": "Semana atual",
    "periodStartISO": "2026-03-10T00:00:00Z",
    "periodEndISO": "2026-03-17T23:59:59Z",
    "followersStart": 1200,
    "followersEnd": 1255,
    "reach": 7400,
    "impressions": 11300,
    "profileVisits": 560,
    "reelViews": 4700,
    "postsPublished": 4
  }
]
```

## Observações de implementação

- O app não armazena token da Meta em código.
- OAuth e troca de tokens devem ocorrer no backend.
- O backend deve tratar rate limit e renovação de token.
- Recomenda-se cache diário para evitar requisições excessivas.

## Boas práticas

- Validar e normalizar timezone no backend.
- Registrar fonte e timestamp da coleta.
- Sempre retornar períodos ordenados por data.
