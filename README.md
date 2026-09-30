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

- Next.js (App Router) — página de status e rotas `/api/*`, que a Netlify publica como Netlify Functions.
- Netlify Blobs — armazenamento da presença (store `emotes-dark-presence`, consistência forte).
- Nenhum dado fica na memória da função; cada requisição lê e grava no Blobs.

### Rotas

| Método | Rota | Descrição |
| --- | --- | --- |
| `GET` | `/api` | Estado de saúde. `200` com `status: "online"` ou `503` com `status: "degraded"` se o Blobs não estiver acessível. |
| `POST` | `/api/clients/register` | Corpo JSON com `userId`, `username`, `displayName`, `gameId`, `placeId`, `jobId`, `sessionId`. |
| `GET` | `/api/clients/active?gameId=…&placeId=…&jobId=…` | Devolve `{ "clients": [...] }` apenas daquele servidor. |

Cada cliente devolvido tem `userId`, `username`, `displayName`, `sessionId` e `lastSeen` (ms).

### Regras

- Chave de armazenamento: `presence/{gameId}/{placeId}/{jobId}/{userId}` — servidores nunca se misturam.
- Inativo após **15 segundos** sem novo `register`. Registros expirados são apagados a cada consulta
  de `/active` e por uma função agendada (`netlify/functions/presence-cleanup.mts`, a cada 5 minutos)
  que limpa servidores abandonados.
- **Comandos no `sessionId` são descartados.** Tudo a partir de `|DK|` (e do formato compacto `_EDK_`)
  é removido antes de gravar; comandos de kick/puxar nunca são guardados nem retransmitidos.
- Validação: ids numéricos, `jobId` alfanumérico com hífen (até 64), `username` no formato Roblox,
  `displayName` sem caracteres de controle (até 32). Dados inválidos retornam `400`.
- Limites: corpo até **2 KB** (`413`), URL até 1024 caracteres (`414`), até 200 clientes por servidor.
- Sem segredos no código. Na Netlify o Blobs é autenticado automaticamente.

### Conectar ao v0

1. Abra o chat do v0 deste projeto (ou crie um novo em v0.app e importe o repositório).
2. No canto superior direito, abra **Settings → Git** e conecte o repositório
   `mateyspess-afk/emotes-dark`. Tudo que for alterado no v0 é enviado para a branch mostrada ali.
3. Faça as edições pelo v0 normalmente e abra/mescle o Pull Request para a branch principal.

> O preview do v0 não tem acesso ao Netlify Blobs, então a página mostrará
> "Armazenamento indisponível" ali. Isso é esperado.

### Publicar na Netlify

1. Em app.netlify.com: **Add new project → Import an existing project → GitHub** e escolha
   `mateyspess-afk/emotes-dark`.
2. As configurações vêm do `netlify.toml` (`pnpm build`, Node 22). Clique em **Deploy**.
3. Ao terminar, a Netlify mostra o domínio gerado, por exemplo `nome-aleatorio-123.netlify.app`.
   Abra-o: a página deve mostrar **API online**.
4. A cada merge na branch principal (inclusive os feitos pelo v0) a Netlify publica de novo.

### Configurar o script

O endereço padrão do script **não foi alterado**. Depois de publicar, defina o endereço real no
executor antes de carregar o Emotes Dark, trocando `SEU-SITE` pelo domínio gerado pela Netlify:

```lua
getgenv().EMOTES_DARK_PRESENCE_API = "https://SEU-SITE.netlify.app/api"
```

Exemplo: se o domínio for `nome-aleatorio-123.netlify.app`, use
`"https://nome-aleatorio-123.netlify.app/api"`. O endereço precisa terminar em `/api`.
Quando aberta no domínio publicado, a página inicial já mostra a linha pronta para copiar.

### Opcional: publicar fora da Netlify

Se publicar em outro lugar (por exemplo pelo botão Publish do v0), defina as variáveis
`NETLIFY_BLOBS_SITE_ID` (ID do site na Netlify) e `NETLIFY_BLOBS_TOKEN` (token pessoal da Netlify)
nas variáveis de ambiente do projeto. Nunca coloque esses valores no código. Nesse caso use o
domínio desse deploy no lugar de `SEU-SITE.netlify.app`.

### Desenvolvimento

```bash
pnpm install
pnpm test     # testes das rotas, da validação e da expiração (Vitest)
pnpm dev
```

Os testes trocam o Netlify Blobs por um armazenamento falso apenas no ambiente de teste.
