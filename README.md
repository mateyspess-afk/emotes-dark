# Emotes Dark Bridge

Bridge de presença temporária do Emotes Dark, preparado para publicação pelo v0. A API usa Next.js Route Handlers e Vercel Blob; não usa memória da função como banco de dados.

## Rotas

- `GET /api` — saúde da API (`{"status":"ok"}`).
- `POST /api/clients/register` — recebe `userId`, `username`, `displayName`, `gameId`, `placeId`, `jobId` e `sessionId`.
- `GET /api/clients/active?gameId=...&placeId=...&jobId=...` — lista somente presenças do servidor solicitado.

Cada registro expira após 15 segundos sem atualização. A leitura remove registros expirados e inválidos. O `sessionId` é sanitizado no servidor: tudo depois de `|DK|` é descartado, portanto comandos codificados de kick/puxar nunca são retransmitidos.

## Publicar no v0

1. Conecte o repositório `mateyspess-afk/emotes-dark` ao v0 usando **Settings → GitHub**.
2. Importe o repositório e confirme que o projeto usa a integração **Blob**. O v0 injeta `BLOB_READ_WRITE_TOKEN`; nenhum segredo deve ser commitado.
3. Publique pelo botão **Publish** no canto superior direito.
4. Copie o domínio real gerado. Não invente ou substitua por um domínio fixo: configure o script depois da publicação com:

```lua
getgenv().EMOTES_DARK_PRESENCE_API = "https://SEU-SITE.v0l.app/api"
```

Troque apenas `SEU-SITE` pelo subdomínio criado para o projeto. O valor deve terminar em `/api`.

## Testes básicos

Com as dependências instaladas, execute `pnpm test`. Os testes cobrem a remoção de comandos do `sessionId`, a validação de campos e a janela de expiração de 15 segundos. O teste de integração das rotas pode ser feito após publicar:

```bash
curl https://SEU-SITE.v0l.app/api
curl -X POST https://SEU-SITE.v0l.app/api/clients/register \
  -H 'content-type: application/json' \
  -d '{"userId":"1","username":"player","displayName":"Player","gameId":"game","placeId":"place","jobId":"job","sessionId":"session|DK|kick:1"}'
curl 'https://SEU-SITE.v0l.app/api/clients/active?gameId=game&placeId=place&jobId=job'
```
