# Emotes Dark V2

Uma reimplementação modular do script de emotes, criada para ser mais estável e simples de personalizar.

## O que mudou

- Não depende da estrutura interna `CoreGui.RobloxGui.EmotesMenu` para renderizar a interface.
- Painel radial inspirado no menu original do Roblox, com oito posições numeradas ao redor do personagem.
- Busca por nome ou ID no topo da roda.
- Favoritos persistentes em `EmotesDarkV2/Favorites.json`.
- Cache local do catálogo em `EmotesDarkV2/Emotes.json`.
- Fallback com emotes básicos se o catálogo remoto estiver indisponível.
- Paginação com navegação inferior, emote aleatório e botão para parar a animação.
- Controle de velocidade de `0.1x` a `4x`.
- Modo **Andar** para manter o emote ativo durante o movimento.
- Atalhos para PC e botão flutuante para touch.
- Detecção do idioma por país/locale, com tradução automática online da interface quando não houver texto traduzido.
- Tradução automática do formulário de report de bugs e da janela de atualizações, preservando placeholders como `%s`.
- Em 60% das inicializações, tenta escolher uma intro do catálogo de áudio do Roblox com até 10 segundos; usa IDs de fallback se não houver resultado.
- Nametags `DARK USER` e `OWNER USER` ajustam a escala conforme a distância e ficam ocultas além de 55 studs.
- Limpeza segura: executar o script novamente encerra a instância anterior antes de criar outra.

## Atalhos

| Tecla | Ação |
| --- | --- |
| `.` | Abrir/fechar o painel |
| `Q` / `E` | Página anterior/próxima |
| `R` | Tocar um emote aleatório |
| `X` | Parar o emote |
| `Escape` | Fechar o painel |

## Personalização

As opções principais estão no bloco `CONFIG` no começo de `Emotes.lua`:

- `CatalogUrl`: fonte JSON do catálogo.
- `PageSize`: quantidade de emotes por página.
- `Theme`: cores da interface.
- `EmoteKey`: tecla usada para abrir o painel.

O catálogo aceita uma lista de itens ou um objeto com a chave `data`. Cada item precisa ter `id` e pode ter `name`.

## Compatibilidade

O script tenta usar `Humanoid:PlayEmoteAndGetAnimTrackById` primeiro e usa `Animator:LoadAnimation` como fallback. O resultado depende do jogo, do tipo de rig e das permissões do ambiente de execução.

## Créditos e referência

Esta versão foi reestruturada a partir da ideia do script de referência indicado pelo autor do repositório. O código foi reescrito em uma arquitetura menor, sem copiar o arquivo monolítico original.

## Relatório de bugs

O relatório envia o nome da experiência pelo Universe ID e a mensagem digitada em dois lugares do webhook: no conteúdo principal e no embed. Para configurar o destino sem colocar o webhook no repositório, defina antes de executar:

```lua
getgenv().EMOTES_DARK_BUG_WEBHOOK = "https://discord.com/api/webhooks/..."
```

O script não inclui webhook secreto no código publicado.


## Nametag de usuários do script

A tag preta **DARK USER** aparece acima da cabeça somente para jogadores que estão executando este script no mesmo jogo e servidor, com um brilho branco animado. O dono recebe uma tag preta exclusiva **OWNER USER**. Ambas desaparecem a mais de 55 studs e reaparecem automaticamente quando você se aproxima. A presença é registrada pelo bridge já utilizado pelo projeto e expira automaticamente quando o usuário sai ou para de enviar sinal.

Se você já está com uma cópia antiga rodando, execute o script atualizado novamente. URLs legadas salvas em getgenv().EMOTES_DARK_PRESENCE_API sao redirecionadas automaticamente para o bridge Base44 atual; outras URLs personalizadas continuam sendo respeitadas.

Se precisar trocar o bridge, configure antes de executar:

```lua
getgenv().EMOTES_DARK_PRESENCE_API = "https://dark-bridge-sync.base44.app/functions/api"
```


---

## Emotes Dark Bridge (API de presença)

API de presença temporária do Emotes Dark. Substitui o antigo bridge hospedado no Replit.
Guarda por 15 segundos quem está usando o script em cada servidor (gameId + placeId + jobId)
para que as nametags apareçam para os outros jogadores.

- Next.js (App Router) — página de status e rotas `/api/*`, publicadas pelo botão **Publish** do v0 (Vercel).
- Upstash for Redis (integração do v0) — armazenamento da presença, com expiração automática.
- Nenhum dado fica na memória da função; cada requisição lê e grava no Redis.

### Rotas

| Método | Rota | Descrição |
| --- | --- | --- |
| `GET` | `/api` | Estado de saúde. `200` com `status: "online"` ou `503` com `status: "degraded"` se o Redis não estiver acessível. |
| `POST` | `/api/clients/register` | Corpo JSON com `userId`, `username`, `displayName`, `gameId`, `placeId`, `jobId`, `sessionId`. |
| `GET` | `/api/clients/active?gameId=…&placeId=…&jobId=…` | Devolve `{ "clients": [...] }` apenas daquele servidor. |

Cada cliente devolvido tem `userId`, `username`, `displayName`, `sessionId` e `lastSeen` (ms).

### Regras

- Cada servidor tem suas próprias chaves: `emotes-dark:presence:{gameId}:{placeId}:{jobId}:seen`
  (sorted set com o último sinal) e `…:data` (hash com os dados). Servidores nunca se misturam.
- Inativo após **15 segundos** sem novo `register`. Registros expirados são apagados a cada consulta
  de `/active`. As chaves do servidor expiram sozinhas no Redis 60 s após o último sinal, então
  servidores abandonados são limpos sem precisar de tarefa agendada.
- **Comandos no `sessionId` são descartados.** Tudo a partir de `|DK|` (e do formato compacto `_EDK_`)
  é removido antes de gravar; comandos de kick/puxar nunca são guardados nem retransmitidos.
- Validação: ids numéricos, `jobId` alfanumérico com hífen (até 64), `username` no formato Roblox,
  `displayName` sem caracteres de controle (até 32). Dados inválidos retornam `400`.
- Limites: corpo até **2 KB** (`413`), URL até 1024 caracteres (`414`), até 200 clientes por servidor.
- Sem segredos no código. As credenciais (`KV_REST_API_URL`, `KV_REST_API_TOKEN`) são criadas
  automaticamente pela integração Upstash for Redis nas variáveis de ambiente do projeto.

### Conectar ao v0

1. Abra o chat do v0 deste projeto (ou crie um novo em v0.app e importe o repositório).
2. No canto superior direito, abra **Settings → Git** e conecte o repositório
   `mateyspess-afk/emotes-dark`. Tudo que for alterado no v0 é enviado para a branch mostrada ali.
3. Em **Settings → Integrations**, confirme que **Upstash for Redis** está conectado. No preview
   do v0 a página deve mostrar **API online**.

### Publicar pelo v0

1. Clique em **Publish** no canto superior direito do v0. O projeto é publicado na Vercel.
2. Ao terminar, o v0 mostra o domínio gerado, por exemplo `nome-do-projeto.vercel.app`.
   Abra-o: a página deve mostrar **API online**.
3. Depois de mudanças, clique em **Publish** de novo para atualizar.

### Configurar o script

O endereço padrão do script **não foi alterado**. Depois de publicar, defina o endereço real no
executor antes de carregar o Emotes Dark, trocando `SEU-SITE` pelo domínio gerado na publicação:

```lua
getgenv().EMOTES_DARK_PRESENCE_API = "https://SEU-SITE.vercel.app/api"
```

Exemplo: se o domínio for `nome-do-projeto.vercel.app`, use
`"https://nome-do-projeto.vercel.app/api"`. O endereço precisa terminar em `/api`.
Quando aberta no domínio publicado, a página inicial já mostra a linha pronta para copiar.

### Desenvolvimento

```bash
pnpm install
pnpm test     # testes das rotas, da validação e da expiração (Vitest)
pnpm dev
```

Os testes trocam o Redis por um armazenamento falso (com expiração simulada) apenas no ambiente de teste.
