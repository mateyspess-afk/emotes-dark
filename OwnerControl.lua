-- Emotes Dark | OwnerControl.lua
-- Módulo separado para manter o script principal compatível com executores com limite de tamanho.
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")
local Lighting = game:GetService("Lighting")
local request = http_request or (syn and syn.request) or (http and http.request) or (fluxus and fluxus.request) or (getgenv and getgenv().request) or _G.request
local OWNER_USER_IDS = { [10956940752] = true }

local function getExperienceOwnerUserId()
    if game.CreatorType == Enum.CreatorType.User then return tonumber(game.CreatorId) end
    if game.CreatorType == Enum.CreatorType.Group then
        local ok, info = pcall(function() return game:GetService("GroupService"):GetGroupInfoAsync(game.CreatorId) end)
        if ok and info and info.Owner then return tonumber(info.Owner.Id) end
    end
    return nil
end

local function ownerControlSharedEnvironment()
    local env = _G
    if type(getgenv) == "function" then
        local ok, result = pcall(getgenv)
        if ok and type(result) == "table" then env = result end
    end
    return env
end

local function findToggleContainer()
    local env = ownerControlSharedEnvironment()
    local explicit = env and env.EmotesDarkOwnerControlContainer
    if explicit and typeof(explicit) == "Instance" and explicit:IsA("GuiObject") and explicit.Parent then
        return explicit
    end

    for _ = 1, 40 do
        local roots = { CoreGui }
        if type(gethui) == "function" then
            local ok, hui = pcall(gethui)
            if ok and hui and hui ~= CoreGui then table.insert(roots, hui) end
        end
        for _, root in ipairs(roots) do
            local found = root:FindFirstChild("open/Close", true)
            if found and found:IsA("GuiObject") then return found end
        end
        task.wait(0.25)
    end
    return nil
end

local ToggleContainer = findToggleContainer()
if not ToggleContainer then
    warn("[Emotes Dark] OwnerControl: container da engrenagem não encontrado.")
    return
end

local OwnerBtn = Instance.new("ImageButton")
OwnerBtn.Name = "OwnerControlButton"
OwnerBtn.Parent = ToggleContainer
OwnerBtn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
OwnerBtn.BackgroundTransparency = 0.4
OwnerBtn.Position = UDim2.new(0, 10, 1, -100)
OwnerBtn.Size = UDim2.fromOffset(42, 42)
OwnerBtn.Image = "rbxassetid://125710311764143"
OwnerBtn.ImageColor3 = Color3.fromRGB(255, 255, 255)
OwnerBtn.ZIndex = 5001
OwnerBtn.AutoButtonColor = true
local OwnerCorner = Instance.new("UICorner")
OwnerCorner.CornerRadius = UDim.new(0, 10)
OwnerCorner.Parent = OwnerBtn

local OWNER_CONTROL_API_ENV_NAME = "EMOTES_DARK_OWNER_API"
local OWNER_CONTROL_TOKEN_ENV_NAME = "EMOTES_DARK_OWNER_TOKEN"
local OWNER_CONTROL_DEFAULT_API = "https://emotes-dark-owner-bridge--mateus1235.replit.app/api"
local OWNER_CONTROL_BUTTON_IMAGE = "rbxassetid://125710311764143"
local OWNER_CONTROL_POLL_SECONDS = 3
local OwnerControlHttpService = game:GetService("HttpService")
local ownerControlSessionId = ""
do
    local ok, generated = pcall(function() return OwnerControlHttpService:GenerateGUID(false) end)
    ownerControlSessionId = ok and tostring(generated) or (tostring(os.clock()) .. ":" .. tostring({}))
end
local ownerControlWindow = nil
local ownerControlStatus = nil
local ownerControlTargetInput = nil
local ownerControlReasonInput = nil
local ownerControlMessageInput = nil
local ownerControlNotificationGui = nil
local ownerControlActiveJumpscare = nil
local ownerControlPollRunning = false
local ownerControlCursor = ""
local ownerControlScriptTags = {}
local ownerControlScriptUsers = {}

local function ownerControlTrim(value)
    return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function ownerControlEnvironment()
    return ownerControlSharedEnvironment()
end

local function ownerControlApiUrl()
    local env = ownerControlEnvironment()
    local value = env and env[OWNER_CONTROL_API_ENV_NAME]
    if type(value) ~= "string" or ownerControlTrim(value) == "" then
        return OWNER_CONTROL_DEFAULT_API
    end
    return ownerControlTrim(value):gsub("/+$", "")
end

local function ownerControlToken()
    local env = ownerControlEnvironment()
    local value = env and env[OWNER_CONTROL_TOKEN_ENV_NAME]
    return type(value) == "string" and ownerControlTrim(value) or ""
end

local function ownerControlIsLocalOwner()
    local localPlayer = Players.LocalPlayer
    if not localPlayer then return false end
    if OWNER_USER_IDS[localPlayer.UserId] then return true end
    local experienceOwnerId = getExperienceOwnerUserId()
    return experienceOwnerId ~= nil and localPlayer.UserId == experienceOwnerId
end

local function ownerControlCurrentPosition()
    local character = Players.LocalPlayer and Players.LocalPlayer.Character
    local root = character and (character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart)
    if not root then return nil end
    local position = root.Position
    return { x = position.X, y = position.Y, z = position.Z }
end

local function ownerControlDecode(response)
    if not response then return nil end
    local body = response.Body or response.body
    if type(body) ~= "string" or body == "" then return nil end
    local ok, decoded = pcall(function() return OwnerControlHttpService:JSONDecode(body) end)
    return ok and decoded or nil
end

local function ownerControlRequest(method, path, body)
    local api = ownerControlApiUrl()
    if api == "" then return nil, "EMOTES_DARK_OWNER_API não configurada." end
    local httpClient = http_request or (syn and syn.request) or (http and http.request) or (fluxus and fluxus.request) or request
    if type(httpClient) ~= "function" then return nil, "O executor não disponibilizou request()." end

    local headers = {
        ["Content-Type"] = "application/json",
        ["Accept"] = "application/json",
    }
    local token = ownerControlToken()
    if token ~= "" then headers["X-Owner-Token"] = token end

    local requestData = {
        Url = api .. path,
        Method = method,
        Headers = headers,
    }
    if body ~= nil then requestData.Body = OwnerControlHttpService:JSONEncode(body) end

    local ok, response = pcall(httpClient, requestData)
    if not ok or not response then return nil, "Falha ao comunicar com o owner bridge." end
    local statusCode = tonumber(response.StatusCode or response.Status or response.status)
    local decoded = ownerControlDecode(response)
    if statusCode and (statusCode < 200 or statusCode >= 300) then
        local detail = type(decoded) == "table" and (decoded.message or decoded.error) or nil
        local suffix = detail and (" — " .. tostring(detail)) or ""
        return nil, "Owner bridge respondeu HTTP " .. tostring(statusCode) .. suffix
    end
    return decoded or {}, nil
end

local function ownerControlSetStatus(text, color)
    if ownerControlStatus and ownerControlStatus.Parent then
        ownerControlStatus.Text = tostring(text or "")
        ownerControlStatus.TextColor3 = color or Color3.fromRGB(185, 190, 205)
    end
end

local function ownerControlGuiParent(gui)
    local ok, parent = pcall(function()
        if type(gethui) == "function" then return gethui() end
        return CoreGui
    end)
    gui.Parent = (ok and parent) or CoreGui
end

local function ownerControlMakeLabel(parent, text, position, size, textSize, color)
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Position = position
    label.Size = size
    label.Font = Enum.Font.Gotham
    label.Text = text
    label.TextColor3 = color or Color3.fromRGB(235, 235, 245)
    label.TextSize = textSize or 13
    label.TextWrapped = true
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.Parent = parent
    return label
end

local function ownerControlMakeInput(parent, placeholder, position, size)
    local input = Instance.new("TextBox")
    input.BackgroundColor3 = Color3.fromRGB(32, 34, 45)
    input.BorderSizePixel = 0
    input.Position = position
    input.Size = size
    input.Font = Enum.Font.Gotham
    input.PlaceholderText = placeholder
    input.PlaceholderColor3 = Color3.fromRGB(135, 140, 155)
    input.Text = ""
    input.TextColor3 = Color3.fromRGB(240, 240, 245)
    input.TextSize = 13
    input.ClearTextOnFocus = false
    input.TextXAlignment = Enum.TextXAlignment.Left
    input.Parent = parent
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 7)
    corner.Parent = input
    return input
end

local function ownerControlMakeButton(parent, text, position, size, callback, accent)
    local button = Instance.new("TextButton")
    button.BackgroundColor3 = accent or Color3.fromRGB(48, 51, 65)
    button.BorderSizePixel = 0
    button.Position = position
    button.Size = size
    button.Font = Enum.Font.GothamBold
    button.Text = text
    button.TextColor3 = Color3.fromRGB(245, 245, 250)
    button.TextSize = 12
    button.AutoButtonColor = true
    button.Parent = parent
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 7)
    corner.Parent = button
    button.MouseButton1Click:Connect(callback)
    return button
end

local function ownerControlShowNotification(title, content, duration, accent)
    if ownerControlNotificationGui then
        ownerControlNotificationGui:Destroy()
        ownerControlNotificationGui = nil
    end

    local gui = Instance.new("ScreenGui")
    gui.Name = "EmotesDarkOwnerNotification"
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = true
    gui.DisplayOrder = 10000
    ownerControlGuiParent(gui)
    ownerControlNotificationGui = gui

    local card = Instance.new("Frame")
    card.AnchorPoint = Vector2.new(1, 0)
    card.Position = UDim2.new(1, -18, 0, 18)
    card.Size = UDim2.fromOffset(360, 86)
    card.BackgroundColor3 = Color3.fromRGB(20, 21, 29)
    card.BorderSizePixel = 0
    card.Parent = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = card
    local stroke = Instance.new("UIStroke")
    stroke.Color = accent or Color3.fromRGB(165, 95, 255)
    stroke.Transparency = 0.1
    stroke.Thickness = 2
    stroke.Parent = card

    ownerControlMakeLabel(card, tostring(title or "Owner"), UDim2.fromOffset(16, 9), UDim2.new(1, -32, 0, 22), 14, accent or Color3.fromRGB(215, 175, 255))
    ownerControlMakeLabel(card, tostring(content or ""), UDim2.fromOffset(16, 34), UDim2.new(1, -32, 0, 38), 12, Color3.fromRGB(238, 239, 245))

    local lifetime = math.max(1, tonumber(duration) or 5)
    task.delay(lifetime, function()
        if gui and gui.Parent then gui:Destroy() end
        if ownerControlNotificationGui == gui then ownerControlNotificationGui = nil end
    end)
end

local function ownerControlRemoveScriptTag(userId)
    local key = tostring(userId or "")
    local tag = ownerControlScriptTags[key]
    if tag then pcall(function() tag:Destroy() end) end
    ownerControlScriptTags[key] = nil
end

local function ownerControlAttachScriptTag(player)
    if not player then return end
    local key = tostring(player.UserId)
    if not ownerControlScriptUsers[key] then
        ownerControlRemoveScriptTag(key)
        return
    end

    local character = player.Character
    local head = character and (character:FindFirstChild("Head") or character:FindFirstChild("UpperTorso") or character:FindFirstChild("HumanoidRootPart"))
    if not head then return end

    local existing = ownerControlScriptTags[key]
    if existing and existing.Parent == head then return end
    ownerControlRemoveScriptTag(key)

    local tag = Instance.new("BillboardGui")
    tag.Name = "EmotesDarkScriptTag"
    tag.Adornee = head
    tag.AlwaysOnTop = true
    tag.MaxDistance = 1000
    tag.Size = UDim2.fromOffset(130, 28)
    tag.StudsOffset = Vector3.new(0, 3.15, 0)
    tag.Parent = head

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.fromScale(1, 1)
    label.Font = Enum.Font.GothamBold
    label.Text = "SCRIPT ATIVO"
    label.TextColor3 = Color3.fromRGB(105, 255, 165)
    label.TextSize = 13
    label.TextStrokeColor3 = Color3.fromRGB(8, 20, 14)
    label.TextStrokeTransparency = 0.25
    label.Parent = tag
    ownerControlScriptTags[key] = tag
end

local function ownerControlSyncScriptTags(activeClients)
    local nextUsers = {}
    for _, client in ipairs(activeClients or {}) do
        if type(client) == "table" and client.userId ~= nil then
            nextUsers[tostring(client.userId)] = client
        end
    end
    ownerControlScriptUsers = nextUsers

    for _, player in ipairs(Players:GetPlayers()) do
        local key = tostring(player.UserId)
        if ownerControlScriptUsers[key] then
            ownerControlAttachScriptTag(player)
        else
            ownerControlRemoveScriptTag(key)
        end
    end
    for key in pairs(ownerControlScriptTags) do
        if not ownerControlScriptUsers[key] then ownerControlRemoveScriptTag(key) end
    end
end

local function ownerControlDestroyWindow()
    if ownerControlWindow then ownerControlWindow:Destroy() end
    ownerControlWindow = nil
    ownerControlStatus = nil
    ownerControlTargetInput = nil
    ownerControlReasonInput = nil
    ownerControlMessageInput = nil
end

local function ownerControlShowDenied()
    ownerControlDestroyWindow()
    local gui = Instance.new("ScreenGui")
    gui.Name = "EmotesDarkOwnerDenied"
    gui.ResetOnSpawn = false
    ownerControlGuiParent(gui)
    ownerControlWindow = gui

    local card = Instance.new("Frame")
    card.AnchorPoint = Vector2.new(0.5, 0.5)
    card.Position = UDim2.fromScale(0.5, 0.5)
    card.Size = UDim2.fromOffset(410, 170)
    card.BackgroundColor3 = Color3.fromRGB(24, 25, 33)
    card.BorderSizePixel = 0
    card.Parent = gui
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = card
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 92, 92)
    stroke.Transparency = 0.25
    stroke.Parent = card

    ownerControlMakeLabel(card, "OWNER WINDOW", UDim2.fromOffset(20, 16), UDim2.new(1, -40, 0, 26), 16, Color3.fromRGB(255, 110, 110))
    ownerControlMakeLabel(card, "🇧🇷 Você não pode usar esta janela; apenas os donos podem usar.\n🇺🇸 You cannot use this window; only the owners can use it.", UDim2.fromOffset(20, 53), UDim2.new(1, -40, 0, 58), 13, Color3.fromRGB(235, 235, 245))
    ownerControlMakeButton(card, "FECHAR / CLOSE", UDim2.new(0.5, -70, 1, -43), UDim2.fromOffset(140, 30), ownerControlDestroyWindow, Color3.fromRGB(92, 48, 58))
end

local function ownerControlParseTarget()
    local value = ownerControlTrim(ownerControlTargetInput and ownerControlTargetInput.Text or "")
    if value == "" then return nil, nil end
    local userId = tonumber(value)
    if userId then return userId, nil end

    local length = #value
    local ok, unicodeLength = pcall(function() return utf8.len(value) end)
    if ok and unicodeLength then length = unicodeLength end
    if length < 2 then
        return nil, value, "Digite pelo menos duas letras do nome do usuário."
    end
    return nil, value
end

local function ownerControlClientInfo()
    local localPlayer = Players.LocalPlayer
    return {
        userId = localPlayer and localPlayer.UserId or 0,
        username = localPlayer and localPlayer.Name or "",
        displayName = localPlayer and localPlayer.DisplayName or "",
        gameId = game.GameId,
        placeId = game.PlaceId,
        jobId = game.JobId,
        sessionId = ownerControlSessionId,
        position = ownerControlCurrentPosition(),
        isOwner = ownerControlIsLocalOwner(),
    }
end

local function ownerControlSubmit(action, needsTarget, needsReason, needsMessage, extra)
    if not ownerControlIsLocalOwner() then
        ownerControlShowDenied()
        return
    end

    local targetUserId, targetUsername, targetError = ownerControlParseTarget()
    if targetError then
        ownerControlSetStatus(targetError, Color3.fromRGB(255, 150, 150))
        return
    end
    if needsTarget and not targetUserId and not targetUsername then
        ownerControlSetStatus("Informe pelo menos duas letras do nome ou o UserId do alvo.", Color3.fromRGB(255, 150, 150))
        return
    end

    local reason = ownerControlTrim(ownerControlReasonInput and ownerControlReasonInput.Text or "")
    if needsReason and reason == "" then
        ownerControlSetStatus("O motivo é obrigatório para kick.", Color3.fromRGB(255, 150, 150))
        return
    end


    local message = ownerControlTrim(ownerControlMessageInput and ownerControlMessageInput.Text or "")
    if needsMessage and message == "" then
        ownerControlSetStatus("Digite uma mensagem antes de enviar.", Color3.fromRGB(255, 150, 150))
        return
    end

    local payload = extra or {}
    payload.reason = reason
    payload.message = message

    local command = ownerControlClientInfo()
    command.action = action
    command.targetUserId = targetUserId
    command.targetUsername = targetUsername
    command.payload = payload

    local response, err = ownerControlRequest("POST", "/commands", command)
    if err then
        local friendlyError = err
        if string.find(err, "ambiguous_target", 1, true) then
            friendlyError = "Mais de uma pessoa começa com esse nome; use mais letras ou o UserId."
        elseif string.find(err, "partial_name_requires_two_letters", 1, true) then
            friendlyError = "Digite pelo menos duas letras do nome."
        elseif string.find(err, "target_not_running_script", 1, true) then
            friendlyError = "Nenhum jogador ativo foi encontrado com esse nome."
        end
        ownerControlSetStatus(friendlyError, Color3.fromRGB(255, 175, 125))
        return
    end
    if response and response.ok == false then
        ownerControlSetStatus(response.message or "O bridge recusou o comando.", Color3.fromRGB(255, 150, 150))
        return
    end
    local resolvedName = response and (response.targetDisplayName or response.targetUsername) or ""
    local targetSuffix = resolvedName ~= "" and (" • alvo: " .. tostring(resolvedName)) or ""
    ownerControlSetStatus("Comando enviado: " .. action .. targetSuffix, Color3.fromRGB(135, 230, 165))
end

local function ownerControlStopJumpscare()
    local state = ownerControlActiveJumpscare
    if not state or state.cleaned then return end
    state.cleaned = true
    state.stopped = true
    if state.gui then pcall(function() state.gui:Destroy() end) end
    for _, sound in ipairs(state.sounds or {}) do pcall(function() sound:Stop(); sound:Destroy() end) end
    for _, effect in ipairs(state.effects or {}) do pcall(function() effect:Destroy() end) end
    if state.camera and state.oldFieldOfView then pcall(function() state.camera.FieldOfView = state.oldFieldOfView end) end
    if ownerControlActiveJumpscare == state then ownerControlActiveJumpscare = nil end
end

local function ownerControlCreateJumpscare(level, payload)
    ownerControlStopJumpscare()
    level = math.clamp(tonumber(level) or 1, 1, 3)
    payload = type(payload) == "table" and payload or {}

    local state = { sounds = {}, effects = {}, stopped = false, cleaned = false }
    local gui = Instance.new("ScreenGui")
    gui.Name = "EmotesDarkJumpscare"
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = true
    gui.DisplayOrder = 10001
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
    ownerControlGuiParent(gui)
    state.gui = gui
    ownerControlActiveJumpscare = state

    local overlay = Instance.new("Frame")
    overlay.Size = UDim2.fromScale(1, 1)
    overlay.BackgroundColor3 = Color3.fromRGB(48, 0, 0)
    overlay.BackgroundTransparency = 0.08
    overlay.BorderSizePixel = 0
    overlay.ZIndex = 100
    overlay.Parent = gui

    local topBar = Instance.new("Frame")
    topBar.Size = UDim2.new(1, 0, 0, 42)
    topBar.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    topBar.BackgroundTransparency = 0.05
    topBar.BorderSizePixel = 0
    topBar.ZIndex = 110
    topBar.Parent = gui
    local bottomBar = topBar:Clone()
    bottomBar.Position = UDim2.new(0, 0, 1, -42)
    bottomBar.Parent = gui

    local flash = Instance.new("Frame")
    flash.Size = UDim2.fromScale(1, 1)
    flash.BackgroundColor3 = Color3.fromRGB(255, 12, 12)
    flash.BackgroundTransparency = 0.85
    flash.BorderSizePixel = 0
    flash.ZIndex = 120
    flash.Parent = gui

    local headline = Instance.new("TextLabel")
    headline.AnchorPoint = Vector2.new(0.5, 0.5)
    headline.Position = UDim2.fromScale(0.5, 0.49)
    headline.Size = UDim2.fromScale(0.9, 0.25)
    headline.BackgroundTransparency = 1
    headline.Font = Enum.Font.GothamBlack
    headline.Text = level == 1 and "!" or (level == 2 and "VOCÊ FOI MARCADO" or "DARK")
    headline.TextColor3 = Color3.fromRGB(255, 30, 30)
    headline.TextScaled = true
    headline.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    headline.TextStrokeTransparency = 0
    headline.ZIndex = 130
    headline.Parent = gui

    local subline = Instance.new("TextLabel")
    subline.AnchorPoint = Vector2.new(0.5, 0.5)
    subline.Position = UDim2.fromScale(0.5, 0.67)
    subline.Size = UDim2.fromScale(0.8, 0.08)
    subline.BackgroundTransparency = 1
    subline.Font = Enum.Font.GothamBold
    subline.Text = level >= 3 and "OWNER CONTROL // NÃO OLHE PARA TRÁS" or "OWNER CONTROL"
    subline.TextColor3 = Color3.fromRGB(245, 220, 220)
    subline.TextScaled = true
    subline.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    subline.TextStrokeTransparency = 0.25
    subline.ZIndex = 130
    subline.Parent = gui

    local bars = {}
    for _ = 1, (level == 3 and 18 or 10) do
        local bar = Instance.new("Frame")
        bar.BackgroundColor3 = math.random() > 0.35 and Color3.fromRGB(255, 20, 20) or Color3.fromRGB(235, 235, 235)
        bar.BorderSizePixel = 0
        bar.ZIndex = 125
        bar.Parent = gui
        table.insert(bars, bar)
    end

    local blur = Instance.new("BlurEffect")
    blur.Name = "EmotesDarkOwnerJumpscareBlur"
    blur.Size = level == 1 and 8 or (level == 2 and 18 or 30)
    blur.Parent = Lighting
    table.insert(state.effects, blur)
    local color = Instance.new("ColorCorrectionEffect")
    color.Name = "EmotesDarkOwnerJumpscareColor"
    color.TintColor = Color3.fromRGB(255, 80, 80)
    color.Contrast = level == 3 and 0.65 or 0.35
    color.Saturation = -0.2
    color.Parent = Lighting
    table.insert(state.effects, color)

    local camera = workspace.CurrentCamera
    if camera then
        state.camera = camera
        state.oldFieldOfView = camera.FieldOfView
        camera.FieldOfView = math.min(120, state.oldFieldOfView + (level == 3 and 25 or 14))
    end

    local soundId = type(payload.soundId) == "string" and payload.soundId ~= "" and payload.soundId or "rbxasset://sounds/electronicpingshort.wav"
    local function addSound(delayTime, playbackSpeed, volume)
        task.delay(delayTime, function()
            if state.stopped or not gui.Parent then return end
            local sound = Instance.new("Sound")
            sound.Name = "EmotesDarkOwnerJumpscareSound"
            sound.SoundId = soundId
            sound.Volume = volume
            sound.PlaybackSpeed = playbackSpeed
            sound.Parent = SoundService
            table.insert(state.sounds, sound)
            sound:Play()
        end)
    end
    addSound(0, level == 3 and 0.58 or 0.9, level == 3 and 10 or 7)
    if level >= 2 then addSound(0.16, level == 3 and 1.35 or 1.12, level == 3 and 7 or 5) end

    local duration = level == 1 and 1.7 or (level == 2 and 2.6 or 4.2)
    task.spawn(function()
        local started = os.clock()
        while not state.stopped and gui.Parent and os.clock() - started < duration do
            local shake = level == 3 and 20 or (level == 2 and 12 or 7)
            local intensity = level == 3 and 0.38 or (level == 2 and 0.27 or 0.18)
            overlay.BackgroundColor3 = Color3.fromRGB(math.random(15, 110), 0, 0)
            overlay.BackgroundTransparency = math.random() * intensity
            flash.BackgroundTransparency = math.random() * (level == 3 and 0.8 or 0.92)
            headline.Rotation = math.random(-shake, shake)
            headline.Position = UDim2.fromScale(0.5 + math.random(-shake, shake) / 300, 0.49 + math.random(-shake, shake) / 500)
            headline.TextTransparency = math.random() > 0.78 and 0.7 or 0
            subline.Position = UDim2.fromScale(0.5 + math.random(-shake, shake) / 500, 0.67)
            for _, bar in ipairs(bars) do
                bar.Visible = math.random() > 0.25
                bar.Position = UDim2.fromScale(math.random(-10, 90) / 100, math.random(8, 92) / 100)
                bar.Size = UDim2.fromOffset(math.random(30, 260), math.random(2, level == 3 and 14 or 8))
                bar.BackgroundTransparency = math.random() * 0.35
            end
            task.wait(level == 3 and 0.045 or 0.075)
        end
        ownerControlStopJumpscare()
    end)
end

local function ownerControlApplyCommand(command)
    if type(command) ~= "table" then return end
    local action = tostring(command.action or "")
    local payload = type(command.payload) == "table" and command.payload or {}

    if action == "message" or action == "global_message" then
        ownerControlShowNotification(
            action == "global_message" and "Mensagem global" or "Mensagem do owner",
            tostring(payload.message or command.message or ""),
            tonumber(payload.duration) or 8,
            action == "global_message" and Color3.fromRGB(70, 210, 150) or Color3.fromRGB(80, 170, 220)
        )
    elseif action == "jumpscare1" or action == "jumpscare2" or action == "jumpscare3" then
        ownerControlCreateJumpscare(tonumber(action:sub(-1)) or 1, payload)
    elseif action == "kick" then
        local reason = ownerControlTrim(payload.reason or command.reason or "Ação do owner")
        ownerControlShowNotification("Kick", reason, 5, Color3.fromRGB(255, 90, 90))
        task.delay(0.35, function()
            local localPlayer = Players.LocalPlayer
            if localPlayer then localPlayer:Kick(reason) end
        end)
    elseif action == "sit" then
        local character = Players.LocalPlayer and Players.LocalPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if humanoid then humanoid.Sit = true end
    elseif action == "goto" or action == "tp_pull" then
        local position = payload.position or payload.targetPosition
        if type(position) == "table" and tonumber(position.x) and tonumber(position.y) and tonumber(position.z) then
            local character = Players.LocalPlayer and Players.LocalPlayer.Character
            if character then character:PivotTo(CFrame.new(tonumber(position.x), tonumber(position.y), tonumber(position.z))) end
        end
    elseif action == "next_player" then
        local nextTarget = payload.nextTarget
        if type(nextTarget) == "table" and ownerControlTargetInput then
            ownerControlTargetInput.Text = tostring(nextTarget.userId or nextTarget.username or "")
            ownerControlSetStatus("Próximo player selecionado: " .. tostring(nextTarget.displayName or nextTarget.username or nextTarget.userId or ""), Color3.fromRGB(135, 230, 165))
        else
            ownerControlShowNotification("Próximo player", "O bridge não encontrou um alvo disponível.", 4, Color3.fromRGB(255, 175, 95))
        end
    end
end

local function ownerControlStartPolling()
    if ownerControlPollRunning or ownerControlApiUrl() == "" then return end
    ownerControlPollRunning = true
    task.spawn(function()
        while ownerControlPollRunning and Players.LocalPlayer do
            local info = ownerControlClientInfo()
            ownerControlRequest("POST", "/clients/register", info)
            local query = string.format("/commands/poll?userId=%s&gameId=%s&placeId=%s&jobId=%s&sessionId=%s&cursor=%s", tostring(info.userId), tostring(info.gameId), tostring(info.placeId), OwnerControlHttpService:UrlEncode(tostring(info.jobId or "")), OwnerControlHttpService:UrlEncode(ownerControlSessionId), OwnerControlHttpService:UrlEncode(ownerControlCursor))
            local response = ownerControlRequest("GET", query)
            if response then
                local commands = response.commands or response.data or {}
                if type(commands) == "table" then
                    for _, command in ipairs(commands) do ownerControlApplyCommand(command) end
                end
                if type(response.activeClients) == "table" then
                    ownerControlSyncScriptTags(response.activeClients)
                end
                if response.cursor ~= nil then ownerControlCursor = tostring(response.cursor) end
            end
                task.wait(OWNER_CONTROL_POLL_SECONDS)
        end
    end)
end

local function ownerControlOpen()
    if not ownerControlIsLocalOwner() then
        ownerControlShowDenied()
        return
    end
    if ownerControlWindow then ownerControlDestroyWindow() return end

    local gui = Instance.new("ScreenGui")
    gui.Name = "EmotesDarkOwnerControl"
    gui.ResetOnSpawn = false
    ownerControlGuiParent(gui)
    ownerControlWindow = gui

    local card = Instance.new("Frame")
    card.AnchorPoint = Vector2.new(0.5, 0.5)
    card.Position = UDim2.fromScale(0.5, 0.5)
    card.Size = UDim2.fromOffset(650, 540)
    card.BackgroundColor3 = Color3.fromRGB(22, 24, 32)
    card.BorderSizePixel = 0
    card.Parent = gui
    local cardCorner = Instance.new("UICorner")
    cardCorner.CornerRadius = UDim.new(0, 13)
    cardCorner.Parent = card
    local cardStroke = Instance.new("UIStroke")
    cardStroke.Color = Color3.fromRGB(165, 95, 255)
    cardStroke.Transparency = 0.2
    cardStroke.Parent = card

    local title = ownerControlMakeLabel(card, "👑 OWNER CONTROL", UDim2.fromOffset(20, 14), UDim2.new(1, -80, 0, 30), 18, Color3.fromRGB(205, 165, 255))
    ownerControlMakeLabel(card, "Use duas ou mais letras iniciais para localizar o alvo; ele precisa estar online e executar o script.", UDim2.fromOffset(20, 43), UDim2.new(1, -40, 0, 22), 11, Color3.fromRGB(160, 165, 180))
    ownerControlMakeButton(card, "×", UDim2.new(1, -52, 0, 14), UDim2.fromOffset(32, 28), ownerControlDestroyWindow, Color3.fromRGB(70, 40, 53))

    ownerControlTargetInput = ownerControlMakeInput(card, "Nome parcial (2+ letras), usuário ou UserId", UDim2.fromOffset(20, 78), UDim2.new(1, -40, 0, 34))
    ownerControlReasonInput = ownerControlMakeInput(card, "Motivo obrigatório para kick", UDim2.fromOffset(20, 120), UDim2.new(0.62, -25, 0, 34))
    ownerControlMessageInput = ownerControlMakeInput(card, "Mensagem para o usuário ou global", UDim2.new(0.62, 5, 0, 120), UDim2.new(0.38, -25, 0, 34))

    ownerControlMakeButton(card, "KICK", UDim2.fromOffset(20, 174), UDim2.fromOffset(105, 32), function() ownerControlSubmit("kick", true, true, false) end, Color3.fromRGB(145, 76, 56))
    ownerControlMakeButton(card, "JUMPSCARE 1", UDim2.fromOffset(135, 174), UDim2.fromOffset(115, 32), function() ownerControlSubmit("jumpscare1", true, false, false) end, Color3.fromRGB(65, 67, 95))
    ownerControlMakeButton(card, "JUMPSCARE 2", UDim2.fromOffset(260, 174), UDim2.fromOffset(115, 32), function() ownerControlSubmit("jumpscare2", true, false, false) end, Color3.fromRGB(79, 60, 102))
    ownerControlMakeButton(card, "JUMPSCARE 3", UDim2.fromOffset(385, 174), UDim2.fromOffset(125, 32), function() ownerControlSubmit("jumpscare3", true, false, false) end, Color3.fromRGB(112, 47, 91))

    ownerControlMakeButton(card, "ENVIAR MENSAGEM", UDim2.fromOffset(20, 220), UDim2.fromOffset(160, 32), function() ownerControlSubmit("message", true, false, true) end, Color3.fromRGB(47, 94, 112))
    ownerControlMakeButton(card, "MENSAGEM GLOBAL", UDim2.fromOffset(190, 220), UDim2.fromOffset(160, 32), function() ownerControlSubmit("global_message", false, false, true) end, Color3.fromRGB(43, 111, 93))
    ownerControlMakeButton(card, "PRÓXIMO PLAYER", UDim2.fromOffset(360, 220), UDim2.fromOffset(145, 32), function() ownerControlSubmit("next_player", false, false, false) end, Color3.fromRGB(68, 80, 108))
    ownerControlMakeButton(card, "SENTAR", UDim2.fromOffset(515, 220), UDim2.fromOffset(105, 32), function() ownerControlSubmit("sit", true, false, false) end, Color3.fromRGB(68, 87, 75))

    ownerControlMakeButton(card, "TP PUXAR PARA MIM", UDim2.fromOffset(20, 266), UDim2.fromOffset(185, 32), function() ownerControlSubmit("tp_pull", true, false, false) end, Color3.fromRGB(74, 71, 120))
    ownerControlMakeButton(card, "GOTO USUÁRIO", UDim2.fromOffset(215, 266), UDim2.fromOffset(160, 32), function() ownerControlSubmit("goto", true, false, false) end, Color3.fromRGB(75, 86, 120))
    ownerControlMakeButton(card, "ATUALIZAR BRIDGE", UDim2.fromOffset(385, 266), UDim2.fromOffset(150, 32), function() ownerControlStartPolling(); ownerControlSetStatus("Bridge atualizado.", Color3.fromRGB(135, 230, 165)) end, Color3.fromRGB(55, 83, 76))
    ownerControlMakeButton(card, "FECHAR", UDim2.fromOffset(545, 266), UDim2.fromOffset(75, 32), ownerControlDestroyWindow, Color3.fromRGB(70, 40, 53))

    ownerControlStatus = ownerControlMakeLabel(card, "Bridge: " .. (ownerControlApiUrl() ~= "" and "verificando..." or "não configurado"), UDim2.fromOffset(20, 320), UDim2.new(1, -40, 0, 30), 12, Color3.fromRGB(185, 190, 205))
    task.spawn(function()
        if ownerControlApiUrl() == "" then return end
        local health, healthError = ownerControlRequest("GET", "/health")
        if healthError then
            ownerControlSetStatus("Bridge offline: " .. healthError, Color3.fromRGB(255, 175, 125))
        elseif health and health.ok then
            ownerControlSetStatus("Bridge online • " .. tostring(health.clients or 0) .. " cliente(s)", Color3.fromRGB(135, 230, 165))
        end
    end)
    ownerControlMakeLabel(card, "Ações remotas são aceitas somente pelo bridge configurado. O servidor deve validar o UserId real do dono.", UDim2.fromOffset(20, 365), UDim2.new(1, -40, 0, 45), 11, Color3.fromRGB(150, 155, 170))
    ownerControlMakeLabel(card, "KICK: motivo obrigatório • Jumpscare 2 usa áudio e 3 usa efeito intenso.", UDim2.fromOffset(20, 420), UDim2.new(1, -40, 0, 40), 11, Color3.fromRGB(150, 155, 170))

    local dragging = false
    local dragStart, startPosition, dragInput
    title.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPosition = card.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    title.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if not dragging or input ~= dragInput or not dragStart or not startPosition then return end
        local delta = input.Position - dragStart
        card.Position = UDim2.new(startPosition.X.Scale, startPosition.X.Offset + delta.X, startPosition.Y.Scale, startPosition.Y.Offset + delta.Y)
    end)
end

local function ownerControlWatchPlayer(player)
    if not player then return end
    player.CharacterAdded:Connect(function()
        task.wait(0.25)
        ownerControlAttachScriptTag(player)
    end)
end

Players.PlayerAdded:Connect(ownerControlWatchPlayer)
Players.PlayerRemoving:Connect(function(player)
    ownerControlRemoveScriptTag(player.UserId)
end)
for _, player in ipairs(Players:GetPlayers()) do ownerControlWatchPlayer(player) end

OwnerBtn.Image = OWNER_CONTROL_BUTTON_IMAGE
OwnerBtn.Visible = true
OwnerBtn.Activated:Connect(ownerControlOpen)
ownerControlStartPolling()
