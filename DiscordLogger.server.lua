-- ServerScriptService/DiscordLogger.server.lua

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Cole aqui um webhook NOVO, somente no servidor.
-- Não publique a URL real no GitHub.
local WEBHOOK_URL = "COLOQUE_O_WEBHOOK_AQUI"

local EXECUTION_COOLDOWN = 10
local lastExecution = {}

local executionEvent = ReplicatedStorage:FindFirstChild("OwnedScriptStarted")

if not executionEvent then
    executionEvent = Instance.new("RemoteEvent")
    executionEvent.Name = "OwnedScriptStarted"
    executionEvent.Parent = ReplicatedStorage
end

local function sanitize(value)
    value = tostring(value or "")
    value = value:gsub("@everyone", "@ everyone")
    value = value:gsub("@here", "@ here")
    return value
end

local function sendLog(player, action, details)
    if WEBHOOK_URL == "" or WEBHOOK_URL == "COLOQUE_O_WEBHOOK_AQUI" then
        warn("[DiscordLogger] Configure WEBHOOK_URL no servidor.")
        return
    end

    local payload = {
        username = "Roblox Audit",
        embeds = {{
            title = "📋 Ação registrada",
            color = 5793266,
            timestamp = DateTime.now():ToIsoDate(),
            fields = {
                {
                    name = "🎮 Jogador",
                    value = string.format(
                        "[%s](https://www.roblox.com/users/%d/profile)\nID: %d",
                        sanitize(player.DisplayName),
                        player.UserId,
                        player.UserId
                    ),
                    inline = false,
                },
                {
                    name = "📌 Ação",
                    value = sanitize(action),
                    inline = false,
                },
                {
                    name = "📋 Detalhes",
                    value = sanitize(details),
                    inline = false,
                },
                {
                    name = "🗺️ Jogo",
                    value = string.format(
                        "%s\nPlaceId: %d",
                        sanitize(game.Name),
                        game.PlaceId
                    ),
                    inline = false,
                },
            },
            footer = {
                text = "Sistema de Auditoria",
            },
        }},
    }

    local success, err = pcall(function()
        HttpService:PostAsync(
            WEBHOOK_URL,
            HttpService:JSONEncode(payload),
            Enum.HttpContentType.ApplicationJson
        )
    end)

    if not success then
        warn("[DiscordLogger] Falha ao enviar log: " .. tostring(err))
    end
end

-- Registra quando o sistema autorizado é iniciado.
executionEvent.OnServerEvent:Connect(function(player, version)
    local now = os.clock()

    if lastExecution[player.UserId]
        and now - lastExecution[player.UserId] < EXECUTION_COOLDOWN then
        return
    end

    lastExecution[player.UserId] = now

    sendLog(
        player,
        "Executou o sistema autorizado",
        "Versão: " .. sanitize(version or "desconhecida")
    )
end)

Players.PlayerAdded:Connect(function(player)
    sendLog(player, "Entrou no servidor", "")
end)

Players.PlayerRemoving:Connect(function(player)
    sendLog(player, "Saiu do servidor", "")
    lastExecution[player.UserId] = nil
end)

print("[DiscordLogger] Carregado. Configure WEBHOOK_URL antes de publicar o jogo.")
