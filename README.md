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

As opções principais estão no bloco `CONFIG` no começo de `EmotesV2.lua`:

- `CatalogUrl`: fonte JSON do catálogo.
- `PageSize`: quantidade de emotes por página.
- `Theme`: cores da interface.
- `EmoteKey`: tecla usada para abrir o painel.

O catálogo aceita uma lista de itens ou um objeto com a chave `data`. Cada item precisa ter `id` e pode ter `name`.

## Compatibilidade

O script tenta usar `Humanoid:PlayEmoteAndGetAnimTrackById` primeiro e usa `Animator:LoadAnimation` como fallback. O resultado depende do jogo, do tipo de rig e das permissões do ambiente de execução.

## Créditos e referência

Esta versão foi reestruturada a partir da ideia do script de referência indicado pelo autor do repositório. O código foi reescrito em uma arquitetura menor, sem copiar o arquivo monolítico original.

## Owner control

O script agora inclui um botão com a textura 125710311764143 acima do botão de engrenagem. A janela só abre para o dono da experiência ou para um UserId listado em OWNER_USER_IDS; outros usuários recebem a mensagem em português e inglês.

As ações de ban, kick, jumpscare, mensagens, próximo player, TP, Goto e sentar usam um bridge HTTP opcional. Configure EMOTES_DARK_OWNER_API no ambiente do executor para a URL base do bridge. O script usa:

- POST /clients/register para registrar usuários que estão executando o script.
- POST /commands para enviar comandos do owner.
- GET /commands/poll?userId=&gameId=&placeId=&jobId=&cursor= para entregar comandos ao cliente alvo.

O bridge precisa autenticar o dono no servidor e retornar o polling como { commands = { ... }, cursor = "..." }. Cada comando usa action, targetUserId ou targetUsername e payload. Para ban permanente, envie durationMinutes = 0; para kick, payload.reason é obrigatório.

Um LocalScript não consegue, sozinho, expulsar, banir ou mover outro cliente. Por isso, sem um bridge autenticado, a janela continua visível para o owner, mas mostra que a API ainda não foi configurada.

A implementação do painel foi separada em OwnerControl.lua e é carregada com proteção por pcall, para que uma incompatibilidade do Delta não impeça o script principal de iniciar.
\n## Owner bridge incluído\n\nO painel Owner precisa de uma API para registrar os clientes e entregar os comandos. O bridge está em `owner-bridge.js` e usa apenas o Node.js, sem dependências externas.\n\n### Publicar\n\n1. Publique este repositório em um serviço Node ou execute localmente com Node 18+.\n2. Configure as variáveis de ambiente:\n\n   - `PORT`: porta HTTP (o serviço normalmente define automaticamente).\n   - `OWNER_USER_IDS`: UserIds dos owners separados por vírgula. O padrão é `10956940752`.\n   - `OWNER_CONTROL_TOKEN`: token recomendado para autenticar os comandos do owner.\n\n3. Inicie com `npm start` e use a URL pública como base da API.\n\nNo executor do owner, antes de rodar o script, configure:\n\n```lua\ngetgenv().EMOTES_DARK_OWNER_API = "https://seu-bridge.exemplo"\ngetgenv().EMOTES_DARK_OWNER_TOKEN = "o-mesmo-token-do-servidor"\n```\n\nO token não deve ser colocado no GitHub nem compartilhado com usuários comuns. Os clientes enviam `POST /clients/register` a cada ciclo e fazem polling em `GET /commands/poll`; os comandos são enviados por `POST /commands`. O bridge mantém a fila em memória, então reiniciar o processo limpa clientes e comandos pendentes.\n\nO alvo precisa estar online e executando o script. Kick, ban e teleporte são aplicados pelo cliente-alvo; portanto, o bridge não substitui regras ou scripts server-side do jogo.\n