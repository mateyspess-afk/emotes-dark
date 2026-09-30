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
