-- ServerScriptService/DiscordLogger.server.lua

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Cole aqui um webhook NOVO somente neste Script do servidor.
-- Nunca publique a URL real no GitHub.
local WEBHOOK_URL = "https://discord.com/api/webhooks/1553781884646072331/S7Xh-v41IIWjvrH276HI6y9j-roatP6Zk_dDx3dWEUUaRDNsc-lA-8RDlALxR4Z0XYdS"

local REQUEST_TIMEOUT = 3
local MAX_FIELD_LENGTH = 1024
local MAX_BIO_LENGTH = 150
local EXECUTION_COOLDOWN = 10
local lastExecutionLog = {}

local executionEvent = ReplicatedStorage:FindFirstChild("OwnedScriptStarted")
if not executionEvent then
    executionEvent = Instance.new("RemoteEvent")
    executionEvent.Name = "OwnedScriptStarted"
    executionEvent.Parent = ReplicatedStorage
end

local function truncateText(value, maxLength)
    value = tostring(value or "")
    if #value <= maxLength then return value end
    if maxLength <= 3 then return value:sub(1, maxLength) end
    return value:sub(1, maxLength - 3) .. "..."
end

local function sanitizeMentions(value)
    value = tostring(value or "")
    value = value:gsub("@everyone", "@ everyone")
    value = value:gsub("@here", "@ here")
    return value
end

local function getServerInfo()
    return {
        PlaceId = game.PlaceId,
        JobId = game.JobId ~= "" and game.JobId or "N/A (Studio)",
        GameName = game.Name,
        PlayerCount = #Players:GetPlayers(),
        MaxPlayers = Players.MaxPlayers,
    }
end

local function generateTeleportCode(placeId, jobId)
    if jobId == "N/A (Studio)" or jobId == "" then
        return "Execute em um servidor online para gerar o código de teleporte"
    end

    return string.format(
        "game:GetService('TeleportService'):TeleportToPlaceInstance(%d, '%s', game.Players.LocalPlayer)",
        placeId,
        jobId
    )
end

local function getPlayerAvatarUrl(userId)
    local url = string.format(
        "https://thumbnails.roblox.com/v1/users/avatar-headshot?userIds=%d&size=420x420&format=Png&isCircular=false",
        userId
    )

    local success, body = pcall(function()
        return HttpService:GetAsync(url)
    end)

    if not success or not body then return nil end

    local decodeSuccess, decoded = pcall(function()
        return HttpService:JSONDecode(body)
    end)

    if decodeSuccess and decoded and decoded.data
        and decoded.data[1] and decoded.data[1].imageUrl then
        return decoded.data[1].imageUrl
    end

    return nil
end

local function getPlayerAccountInfo(userId)
    local url = string.format("https://users.roblox.com/v1/users/%d", userId)

    local success, body = pcall(function()
        return HttpService:GetAsync(url)
    end)

    if not success or not body then return nil end

    local decodeSuccess, decoded = pcall(function()
        return HttpService:JSONDecode(body)
    end)

    if not decodeSuccess or not decoded then return nil end

    return {
        displayName = decoded.displayName or "N/A",
        username = decoded.name or "N/A",
        description = decoded.description or "",
        created = decoded.created,
        hasVerifiedBadge = decoded.hasVerifiedBadge or false,
    }
end

local function parseAccountAge(isoDate)
    if not isoDate then return "Desconhecida", 0, 0, 0 end

    local year, month, day = isoDate:match("(%d+)-(%d+)-(%d+)")
    if not year then return "Desconhecida", 0, 0, 0 end

    year, month, day = tonumber(year), tonumber(month), tonumber(day)

    local accountTime = os.time({
        year = year,
        month = month,
        day = day,
        hour = 12,
        min = 0,
        sec = 0,
    })

    local ageDays = math.max(0, math.floor((os.time() - accountTime) / 86400))
    local ageYears = math.floor(ageDays / 365)
    local remainingDays = ageDays - ageYears * 365
    local formattedDate = string.format("%02d/%02d/%04d", day, month, year)

    return formattedDate, ageDays, ageYears, remainingDays
end

local function getAccountAgeText(ageDays, ageYears, remainingDays)
    if ageDays <= 0 then return "Conta nova" end

    if ageYears > 0 then
        return string.format(
            "%d ano%s e %d dia%s",
            ageYears,
            ageYears ~= 1 and "s" or "",
            remainingDays,
            remainingDays ~= 1 and "s" or ""
        )
    end

    return string.format("%d dia%s", ageDays, ageDays ~= 1 and "s" or "")
end

local function collectPlayerData(player)
    local avatarUrl = nil
    local accountInfo = nil
    local avatarFinished = false
    local accountFinished = false

    task.spawn(function()
        avatarUrl = getPlayerAvatarUrl(player.UserId)
        avatarFinished = true
    end)

    task.spawn(function()
        accountInfo = getPlayerAccountInfo(player.UserId)
        accountFinished = true
    end)

    local elapsed = 0
    while not (avatarFinished and accountFinished)
        and elapsed < REQUEST_TIMEOUT do
        task.wait(0.1)
        elapsed = elapsed + 0.1
    end

    return avatarUrl, accountInfo
end

local function sendLog(player, action, details)
    if WEBHOOK_URL == "" or WEBHOOK_URL == "" then
        warn("[DiscordLogger] Configure WEBHOOK_URL no servidor.")
        return
    end

    if not player then return end

    local serverInfo = getServerInfo()
    local teleportCode = generateTeleportCode(serverInfo.PlaceId, serverInfo.JobId)
    local avatarUrl, accountInfo = collectPlayerData(player)

    local createdFormatted = "Desconhecida"
    local ageDays = 0
    local ageYears = 0
    local remainingDays = 0
    local isVerified = false
    local accountDescription = ""

    if accountInfo then
        createdFormatted, ageDays, ageYears, remainingDays = parseAccountAge(accountInfo.created)
        isVerified = accountInfo.hasVerifiedBadge
        accountDescription = accountInfo.description or ""
    end

    accountDescription = truncateText(sanitizeMentions(accountDescription), MAX_BIO_LENGTH)
    local ageText = getAccountAgeText(ageDays, ageYears, remainingDays)
    local verifiedIcon = isVerified and " ✅" or ""
    local profileUrl = string.format("https://www.roblox.com/users/%d/profile", player.UserId)

    local fields = {
        {
            name = "🎮 Jogador",
            value = truncateText(string.format(
                "[%s (@%s)](%s)%s\nID: %d",
                sanitizeMentions(player.DisplayName),
                sanitizeMentions(player.Name),
                profileUrl,
                verifiedIcon,
                player.UserId
            ), MAX_FIELD_LENGTH),
            inline = true,
        },
        {
            name = "📅 Conta criada em",
            value = string.format("%s\n*(%s)*", createdFormatted, ageText),
            inline = true,
        },
        {
            name = "📌 Ação",
            value = truncateText(sanitizeMentions(action), MAX_FIELD_LENGTH),
            inline = false,
        },
        {
            name = "🗺️ Jogo",
            value = string.format("**%s**\nPlaceId: %d", sanitizeMentions(serverInfo.GameName), serverInfo.PlaceId),
            inline = false,
        },
        {
            name = "🌐 Servidor (JobId)",
            value = sanitizeMentions(serverInfo.JobId),
            inline = false,
        },
        {
            name = "👥 Jogadores no Servidor",
            value = string.format("%d / %d", serverInfo.PlayerCount, serverInfo.MaxPlayers),
            inline = true,
        },
        {
            name = "🚀 Teleporte",
            value = truncateText(teleportCode, MAX_FIELD_LENGTH),
            inline = false,
        },
    }

    if accountDescription ~= "" then
        table.insert(fields, {
            name = "📝 Bio do Perfil",
            value = accountDescription,
            inline = false,
        })
    end

    if details and tostring(details) ~= "" then
        table.insert(fields, {
            name = "📋 Detalhes",
            value = truncateText(sanitizeMentions(details), MAX_FIELD_LENGTH),
            inline = false,
        })
    end

    local embed = {
        title = "📋 Ação Registrada no Servidor",
        color = 5793266,
        timestamp = DateTime.now():ToIsoDate(),
        footer = {
            text = "Sistema de Auditoria • " .. truncateText(serverInfo.GameName, 150),
        },
        fields = fields,
    }

    if avatarUrl then
        embed.thumbnail = { url = avatarUrl }
    end

    local payload = {
        username = "Roblox Audit",
        avatar_url = "https://i.imgur.com/gK5g7gK.png",
        embeds = { embed },
    }

    local success, errorMessage = pcall(function()
        HttpService:PostAsync(
            WEBHOOK_URL,
            HttpService:JSONEncode(payload),
            Enum.HttpContentType.ApplicationJson
        )
    end)

    if success then
        print(string.format("[DiscordLogger] Log enviado: %s | %s", player.Name, tostring(action)))
    else
        warn("[DiscordLogger] Falha ao enviar log: " .. tostring(errorMessage))
    end
end

-- ============================================================
-- LOG DE INICIALIZAÇÃO DO EMOTES.LUA
-- ============================================================

executionEvent.OnServerEvent:Connect(function(player, version)
    local now = os.clock()
    local lastTime = lastExecutionLog[player.UserId]

    if lastTime and now - lastTime < EXECUTION_COOLDOWN then
        return
    end

    lastExecutionLog[player.UserId] = now

    sendLog(
        player,
        "Executou o sistema autorizado",
        "Versão: " .. sanitizeMentions(version or "desconhecida")
    )
end)

Players.PlayerAdded:Connect(function(player)
    sendLog(player, "Entrou no servidor")
end)

Players.PlayerRemoving:Connect(function(player)
    sendLog(player, "Saiu do servidor")
    lastExecutionLog[player.UserId] = nil
end)

print(string.format(
    "[DiscordLogger] Carregado. PlaceId: %d | JobId: %s",
    game.PlaceId,
    game.JobId ~= "" and game.JobId or "N/A (Studio)"
))
