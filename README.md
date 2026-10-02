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

## Relatórios de bugs e sugestões

Configure destinos independentes para reports de bugs e sugestões antes de executar o script:

```lua
getgenv().EMOTES_DARK_BUG_WEBHOOK = "https://discord.com/api/webhooks/..."
getgenv().EMOTES_DARK_SUGGESTION_WEBHOOK = "https://discord.com/api/webhooks/..."
```

As sugestões têm cooldown independente de 5 horas, salvo localmente em 7yd7/EmotesSuggestionCooldown.json. Reports de bugs mantêm o cooldown atual de 15 horas e o serviço global opcional.

Também é possível preencher SUGGESTION_WEBHOOK_URL em uma cópia local privada. Não publique URLs reais de webhook em um repositório público.


## Nametag de usuários do script

A tag preta **DARK USER** aparece acima da cabeça somente para jogadores que estão executando este script no mesmo jogo e servidor, com um brilho branco animado. O dono recebe uma tag preta exclusiva **OWNER USER**. Ambas desaparecem a mais de 55 studs e reaparecem automaticamente quando você se aproxima. A presença é registrada pelo bridge já utilizado pelo projeto e expira automaticamente quando o usuário sai ou para de enviar sinal.

Se você já está com uma cópia antiga rodando, execute o script atualizado novamente. A API de presença e comandos do projeto é `https://emotes-bridge-sync.lovable.app/api`. O script aceita uma URL personalizada em `getgenv().EMOTES_DARK_PRESENCE_API`.

Para configurar manualmente antes de executar:

```lua
getgenv().EMOTES_DARK_PRESENCE_API = "https://emotes-bridge-sync.lovable.app/api"
```

A bridge precisa aceitar `POST /clients/register` e `GET /clients/active`. Configure a URL base sem incluir tokens ou chaves.


## Comandos /kick e /puxar

- Use `/kick <username> [motivo]` para solicitar que o cliente correspondente saia do servidor.
- Use `/puxar <username>` para solicitar que esse cliente se mova para perto do owner.
- Os comandos são restritos ao owner e só podem alcançar usuários no mesmo servidor que estejam executando uma versão compatível do script. Eles não removem nem movem jogadores que não executam o script e não substituem autoridade do servidor Roblox.
- Para o envio remoto, a bridge precisa aceitar o campo `command` no registro e devolvê-lo na lista `clients`. O endpoint público confirma presença e rotas básicas; o encaminhamento dos comandos ainda precisa ser validado com dois clientes reais.
