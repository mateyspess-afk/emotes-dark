--[[
    Emotes Dark V2
    A smaller, safer rewrite of the original emote helper.

    Highlights:
      - Owns its UI instead of editing Roblox's private CoreGui hierarchy.
      - Search, favorites, pagination and random emote.
      - Speed control and walk/freeze mode.
      - Cache with a bundled fallback list when the catalog is unavailable.
      - PC hotkeys and a touch-friendly floating button.

    Default key:
      .       Toggle the panel
      Q / E   Previous / next page
      R       Play a random visible emote
      X       Stop the current emote
      Escape  Close the panel

    The catalog endpoint can be replaced without changing the UI:
      https://raw.githubusercontent.com/7yd7/sniper-Emote/refs/heads/test/EmoteSniper.json
]]

if _G.EmotesDarkV2 then
    pcall(function()
        _G.EmotesDarkV2.Destroy()
    end)
end

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer
local CONFIG = {
    Name = "EmotesDarkV2",
    Folder = "EmotesDarkV2",
    CacheFile = "EmotesDarkV2/Emotes.json",
    FavoritesFile = "EmotesDarkV2/Favorites.json",
    CatalogUrl = "https://raw.githubusercontent.com/7yd7/sniper-Emote/refs/heads/test/EmoteSniper.json",
    PageSize = 8,
    EmoteKey = Enum.KeyCode.Period,
    Theme = {
        Background = Color3.fromRGB(13, 16, 24),
        Surface = Color3.fromRGB(21, 25, 36),
        SurfaceHover = Color3.fromRGB(31, 37, 52),
        Stroke = Color3.fromRGB(54, 65, 88),
        Text = Color3.fromRGB(242, 245, 250),
        Muted = Color3.fromRGB(153, 165, 188),
        Accent = Color3.fromRGB(139, 112, 255),
        AccentDark = Color3.fromRGB(78, 57, 166),
        Danger = Color3.fromRGB(232, 95, 116),
        Good = Color3.fromRGB(95, 215, 165),
    },
}

local State = {
    Items = {},
    Filtered = {},
    Favorites = {},
    Query = "",
    Tab = "all",
    Page = 1,
    PanelOpen = false,
    WalkMode = false,
    Speed = 1,
    Track = nil,
    CharacterConnection = nil,
    HeartbeatConnection = nil,
    InputConnection = nil,
    DragConnection = nil,
    Gui = nil,
    Panel = nil,
    Grid = nil,
    Search = nil,
    Status = nil,
    PageLabel = nil,
    AllTab = nil,
    FavoritesTab = nil,
    MobileButton = nil,
    ToastToken = 0,
}

local function getGlobal()
    local ok, value = pcall(function()
        return getgenv()
    end)
    return ok and value or _G
end

local function notify(title, content, duration)
    local globals = getGlobal()
    if type(globals.Notify) == "function" then
        pcall(globals.Notify, {
            Title = title,
            Content = content,
            Duration = duration or 3,
        })
        return
    end

    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title,
            Text = content,
            Duration = duration or 3,
        })
    end)
end

local function canUse(name)
    local ok, value = pcall(function()
        return _G[name] or getgenv()[name]
    end)
    return ok and type(value) == "function" and value or nil
end

local function ensureFolder()
    local isFolder = canUse("isfolder")
    local makeFolder = canUse("makefolder")
    if not isFolder or not makeFolder then
        return
    end

    local ok, exists = pcall(isFolder, CONFIG.Folder)
    if not ok or not exists then
        pcall(makeFolder, CONFIG.Folder)
    end
end

local function readJson(path)
    local isFile = canUse("isfile")
    local readFile = canUse("readfile")
    if not isFile or not readFile then
        return nil
    end

    local exists, present = pcall(isFile, path)
    if not exists or not present then
        return nil
    end

    local ok, decoded = pcall(function()
        return HttpService:JSONDecode(readFile(path))
    end)
    return ok and decoded or nil
end

local function writeJson(path, value)
    local writeFile = canUse("writefile")
    if not writeFile then
        return false
    end

    ensureFolder()
    local ok = pcall(function()
        writeFile(path, HttpService:JSONEncode(value))
    end)
    return ok
end

local function httpGet(url)
    local ok, body = pcall(function()
        return game:HttpGet(url)
    end)
    if ok and type(body) == "string" and #body > 0 then
        return body
    end

    local request = canUse("request") or canUse("http_request")
    if request then
        local requestOk, response = pcall(request, {
            Url = url,
            Method = "GET",
        })
        if requestOk and response then
            return response.Body or response.body
        end
    end

    return nil
end

local function normalizeId(value)
    if value == nil then
        return nil
    end
    local text = tostring(value):gsub("rbxassetid://", "")
    local id = tonumber(text:match("%d+"))
    return id and id > 0 and math.floor(id) or nil
end

local function normalizeItems(payload)
    local source = payload
    if type(payload) == "table" and type(payload.data) == "table" then
        source = payload.data
    end
    if type(source) ~= "table" then
        return {}
    end

    local items = {}
    local seen = {}
    for _, raw in pairs(source) do
        if type(raw) == "table" then
            local id = normalizeId(raw.id or raw.assetId or raw.animationId)
            if id and not seen[id] then
                seen[id] = true
                table.insert(items, {
                    id = id,
                    name = tostring(raw.name or raw.title or ("Emote " .. id)),
                })
            end
        end
    end

    table.sort(items, function(a, b)
        return a.name:lower() < b.name:lower()
    end)
    return items
end

local function fallbackItems()
    return {
        { id = 3360686498, name = "Stadium" },
        { id = 3360692915, name = "Tilt" },
        { id = 3576968026, name = "Shrug" },
        { id = 3360689775, name = "Salute" },
    }
end

local function loadFavorites()
    local value = readJson(CONFIG.FavoritesFile)
    if type(value) ~= "table" then
        return
    end
    for _, id in pairs(value) do
        local normalized = normalizeId(id)
        if normalized then
            State.Favorites[normalized] = true
        end
    end
end

local function saveFavorites()
    local values = {}
    for id in pairs(State.Favorites) do
        table.insert(values, id)
    end
    table.sort(values)
    writeJson(CONFIG.FavoritesFile, values)
end

local function loadItems()
    local cached = normalizeItems(readJson(CONFIG.CacheFile))
    State.Items = #cached > 0 and cached or fallbackItems()

    task.spawn(function()
        local body = httpGet(CONFIG.CatalogUrl)
        if not body then
            return
        end

        local ok, payload = pcall(function()
            return HttpService:JSONDecode(body)
        end)
        if not ok then
            return
        end

        local fresh = normalizeItems(payload)
        if #fresh == 0 then
            return
        end

        State.Items = fresh
        writeJson(CONFIG.CacheFile, fresh)
        if State.Gui and State.Render then
            State.Page = 1
            State.Filtered = {}
            task.defer(function()
                if State.Gui and State.Render then
                    State.Render()
                end
            end)
        end
        notify("Emotes Dark", tostring(#fresh) .. " emotes carregados", 3)
    end)
end

local function getCharacter()
    local character = LocalPlayer and LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        return nil, nil
    end
    return character, humanoid
end

local function stopTrack()
    if State.Track then
        pcall(function()
            State.Track:Stop(0.12)
            State.Track:Destroy()
        end)
        State.Track = nil
    end
end

local function playItem(item)
    local _, humanoid = getCharacter()
    if not humanoid or not item then
        notify("Emotes Dark", "Personagem ainda não está pronto.", 3)
        return
    end

    stopTrack()

    local ok, authenticTrack = pcall(function()
        return humanoid:PlayEmoteAndGetAnimTrackById(item.id)
    end)
    if ok and authenticTrack and typeof(authenticTrack) == "Instance" then
        State.Track = authenticTrack
    else
        local animator = humanoid:FindFirstChildOfClass("Animator")
        if not animator then
            animator = Instance.new("Animator")
            animator.Parent = humanoid
        end

        local animation = Instance.new("Animation")
        animation.AnimationId = "rbxassetid://" .. item.id
        local loaded, track = pcall(function()
            return animator:LoadAnimation(animation)
        end)
        animation:Destroy()
        if not loaded or not track then
            notify("Emotes Dark", "Não foi possível tocar esse emote.", 3)
            return
        end
        State.Track = track
        State.Track.Priority = Enum.AnimationPriority.Action
        State.Track.Looped = true
    end

    pcall(function()
        State.Track:Play(0.12, 1, State.Speed)
        State.Track:AdjustSpeed(State.Speed)
    end)
    State.PanelOpen = false
    if State.Panel then
        State.Panel.Visible = false
    end
end

local function filteredItems()
    local query = State.Query:lower():gsub("^%s+", ""):gsub("%s+$", "")
    local values = {}
    for _, item in ipairs(State.Items) do
        local matchesTab = State.Tab == "all" or State.Favorites[item.id]
        local matchesQuery = query == ""
            or item.name:lower():find(query, 1, true)
            or tostring(item.id):find(query, 1, true)
        if matchesTab and matchesQuery then
            table.insert(values, item)
        end
    end
    return values
end

local function pageCount()
    return math.max(1, math.ceil(#State.Filtered / CONFIG.PageSize))
end

local function new(className, properties, parent)
    local object = Instance.new(className)
    for property, value in pairs(properties or {}) do
        object[property] = value
    end
    object.Parent = parent
    return object
end

local function round(object, radius)
    new("UICorner", {
        CornerRadius = UDim.new(0, radius or 10),
    }, object)
end

local function stroke(object, color, transparency)
    new("UIStroke", {
        Color = color,
        Transparency = transparency or 0,
        Thickness = 1,
    }, object)
end

local function button(parent, text, size, position)
    local item = new("TextButton", {
        AutoButtonColor = false,
        BackgroundColor3 = CONFIG.Theme.Surface,
        BorderSizePixel = 0,
        Font = Enum.Font.GothamSemibold,
        Size = size,
        Position = position,
        Text = text,
        TextColor3 = CONFIG.Theme.Text,
        TextSize = 13,
    }, parent)
    round(item, 9)
    stroke(item, CONFIG.Theme.Stroke, 0.1)
    item.MouseEnter:Connect(function()
        item.BackgroundColor3 = CONFIG.Theme.SurfaceHover
    end)
    item.MouseLeave:Connect(function()
        item.BackgroundColor3 = CONFIG.Theme.Surface
    end)
    return item
end

local function updateTabs()
    if not State.AllTab or not State.FavoritesTab then
        return
    end
    State.AllTab.BackgroundColor3 = State.Tab == "all" and CONFIG.Theme.AccentDark or CONFIG.Theme.Surface
    State.FavoritesTab.BackgroundColor3 = State.Tab == "favorites" and CONFIG.Theme.AccentDark or CONFIG.Theme.Surface
end

local function render()
    if not State.Grid then
        return
    end

    State.Filtered = filteredItems()
    local pages = pageCount()
    State.Page = math.clamp(State.Page, 1, pages)
    State.PageLabel.Text = string.format("%d / %d", State.Page, pages)
    State.Status.Text = string.format("%d emotes  •  %s", #State.Filtered, State.Tab == "all" and "Todos" or "Favoritos")
    updateTabs()

    for _, child in ipairs(State.Grid:GetChildren()) do
        if not child:IsA("UIGridLayout") then
            child:Destroy()
        end
    end

    local first = (State.Page - 1) * CONFIG.PageSize + 1
    for index = first, math.min(first + CONFIG.PageSize - 1, #State.Filtered) do
        local item = State.Filtered[index]
        local slot = new("TextButton", {
            AutoButtonColor = false,
            BackgroundColor3 = CONFIG.Theme.Surface,
            BorderSizePixel = 0,
            Text = "",
        }, State.Grid)
        round(slot, 12)
        stroke(slot, State.Favorites[item.id] and CONFIG.Theme.Accent or CONFIG.Theme.Stroke, 0.05)

        new("TextLabel", {
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamBold,
            Position = UDim2.fromScale(0.08, 0.12),
            Size = UDim2.fromScale(0.84, 0.3),
            Text = string.format("%02d", index),
            TextColor3 = CONFIG.Theme.Accent,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, slot)
        new("TextLabel", {
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamSemibold,
            Position = UDim2.fromScale(0.08, 0.38),
            Size = UDim2.fromScale(0.84, 0.42),
            Text = item.name,
            TextColor3 = CONFIG.Theme.Text,
            TextSize = 13,
            TextTruncate = Enum.TextTruncate.AtEnd,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, slot)
        new("TextLabel", {
            BackgroundTransparency = 1,
            Font = Enum.Font.Code,
            Position = UDim2.fromScale(0.08, 0.78),
            Size = UDim2.fromScale(0.75, 0.16),
            Text = tostring(item.id),
            TextColor3 = CONFIG.Theme.Muted,
            TextSize = 10,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, slot)

        local favorite = new("TextButton", {
            AutoButtonColor = false,
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamBold,
            Position = UDim2.fromScale(0.78, 0.08),
            Size = UDim2.fromScale(0.18, 0.25),
            Text = State.Favorites[item.id] and "★" or "☆",
            TextColor3 = State.Favorites[item.id] and CONFIG.Theme.Good or CONFIG.Theme.Muted,
            TextSize = 19,
        }, slot)
        favorite.Activated:Connect(function()
            State.Favorites[item.id] = not State.Favorites[item.id] or nil
            saveFavorites()
            render()
        end)

        slot.MouseEnter:Connect(function()
            slot.BackgroundColor3 = CONFIG.Theme.SurfaceHover
        end)
        slot.MouseLeave:Connect(function()
            slot.BackgroundColor3 = CONFIG.Theme.Surface
        end)
        slot.Activated:Connect(function()
            playItem(item)
        end)
    end
end

local function togglePanel(force)
    if not State.Panel then
        return
    end
    State.PanelOpen = force == nil and not State.PanelOpen or force
    State.Panel.Visible = State.PanelOpen
    if State.PanelOpen then
        render()
        if State.Search and not UserInputService.TouchEnabled then
            State.Search:CaptureFocus()
            State.Search:ReleaseFocus()
        end
    end
end

local function randomVisible()
    State.Filtered = filteredItems()
    if #State.Filtered == 0 then
        notify("Emotes Dark", "Nenhum emote encontrado.", 3)
        return
    end
    playItem(State.Filtered[math.random(1, #State.Filtered)])
end

local function setSpeed(text)
    local value = tonumber(text) or 1
    State.Speed = math.clamp(value, 0.1, 4)
    if State.Track then
        pcall(function()
            State.Track:AdjustSpeed(State.Speed)
        end)
    end
end

local function createGui()
    local parent = CoreGui
    local getHui = canUse("gethui")
    if getHui then
        local ok, hui = pcall(getHui)
        if ok and hui then
            parent = hui
        end
    end

    local old = parent:FindFirstChild(CONFIG.Name)
    if old then
        old:Destroy()
    end

    State.Gui = new("ScreenGui", {
        DisplayOrder = 100,
        IgnoreGuiInset = true,
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    }, parent)
    State.Gui.Name = CONFIG.Name

    State.Panel = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = CONFIG.Theme.Background,
        BorderSizePixel = 0,
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(560, 440),
        Visible = false,
    }, State.Gui)
    round(State.Panel, 18)
    stroke(State.Panel, CONFIG.Theme.Stroke, 0)
    new("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(25, 29, 43)),
            ColorSequenceKeypoint.new(1, CONFIG.Theme.Background),
        }),
        Rotation = 135,
    }, State.Panel)

    local header = new("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -32, 0, 58),
        Position = UDim2.fromOffset(16, 12),
    }, State.Panel)
    new("TextLabel", {
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBlack,
        Position = UDim2.fromOffset(0, 1),
        Size = UDim2.fromOffset(300, 25),
        Text = "EMOTES DARK",
        TextColor3 = CONFIG.Theme.Text,
        TextSize = 18,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, header)
    State.Status = new("TextLabel", {
        BackgroundTransparency = 1,
        Font = Enum.Font.Gotham,
        Position = UDim2.fromOffset(0, 28),
        Size = UDim2.fromOffset(300, 20),
        TextColor3 = CONFIG.Theme.Muted,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, header)
    local close = button(header, "×", UDim2.fromOffset(34, 34), UDim2.new(1, -34, 0, 0))
    close.TextSize = 22
    close.Activated:Connect(function()
        togglePanel(false)
    end)

    State.Search = new("TextBox", {
        BackgroundColor3 = CONFIG.Theme.Surface,
        BorderSizePixel = 0,
        ClearTextOnFocus = false,
        Font = Enum.Font.Gotham,
        PlaceholderColor3 = CONFIG.Theme.Muted,
        PlaceholderText = "Buscar por nome ou ID...",
        Position = UDim2.fromOffset(16, 78),
        Size = UDim2.new(1, -32, 0, 36),
        Text = "",
        TextColor3 = CONFIG.Theme.Text,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, State.Panel)
    round(State.Search, 10)
    stroke(State.Search, CONFIG.Theme.Stroke, 0.1)
    new("UIPadding", {
        PaddingLeft = UDim.new(0, 12),
        PaddingRight = UDim.new(0, 12),
    }, State.Search)
    State.Search:GetPropertyChangedSignal("Text"):Connect(function()
        State.Query = State.Search.Text
        State.Page = 1
        render()
    end)

    State.AllTab = button(State.Panel, "Todos", UDim2.fromOffset(90, 30), UDim2.fromOffset(16, 126))
    State.FavoritesTab = button(State.Panel, "Favoritos", UDim2.fromOffset(90, 30), UDim2.fromOffset(112, 126))
    State.AllTab.Activated:Connect(function()
        State.Tab = "all"
        State.Page = 1
        render()
    end)
    State.FavoritesTab.Activated:Connect(function()
        State.Tab = "favorites"
        State.Page = 1
        render()
    end)

    State.Grid = new("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(16, 168),
        Size = UDim2.new(1, -32, 0, 190),
    }, State.Panel)
    new("UIGridLayout", {
        CellPadding = UDim2.fromOffset(10, 10),
        CellSize = UDim2.new(0.25, -8, 0.5, -5),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, State.Grid)

    local footer = new("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(16, 367),
        Size = UDim2.new(1, -32, 0, 54),
    }, State.Panel)
    local previous = button(footer, "‹", UDim2.fromOffset(42, 36), UDim2.fromOffset(0, 0))
    local next = button(footer, "›", UDim2.fromOffset(42, 36), UDim2.fromOffset(48, 0))
    State.PageLabel = new("TextLabel", {
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamSemibold,
        Position = UDim2.fromOffset(96, 0),
        Size = UDim2.fromOffset(70, 36),
        TextColor3 = CONFIG.Theme.Text,
        TextSize = 12,
    }, footer)
    local random = button(footer, "Aleatório", UDim2.fromOffset(92, 36), UDim2.new(1, -286, 0, 0))
    local stop = button(footer, "Parar", UDim2.fromOffset(72, 36), UDim2.new(1, -186, 0, 0))
    local speed = new("TextBox", {
        BackgroundColor3 = CONFIG.Theme.Surface,
        BorderSizePixel = 0,
        ClearTextOnFocus = false,
        Font = Enum.Font.GothamSemibold,
        PlaceholderText = "1.0x",
        Position = UDim2.new(1, -104, 0, 0),
        Size = UDim2.fromOffset(48, 36),
        Text = "1",
        TextColor3 = CONFIG.Theme.Text,
        TextSize = 12,
    }, footer)
    round(speed, 9)
    stroke(speed, CONFIG.Theme.Stroke, 0.1)
    speed.FocusLost:Connect(function()
        setSpeed(speed.Text)
        speed.Text = tostring(State.Speed)
    end)
    local walk = button(footer, "Andar", UDim2.fromOffset(72, 30), UDim2.new(1, -78, 0, 46))
    walk.TextColor3 = CONFIG.Theme.Muted

    previous.Activated:Connect(function()
        State.Page -= 1
        render()
    end)
    next.Activated:Connect(function()
        State.Page += 1
        render()
    end)
    random.Activated:Connect(randomVisible)
    stop.Activated:Connect(stopTrack)
    walk.Activated:Connect(function()
        State.WalkMode = not State.WalkMode
        walk.Text = State.WalkMode and "Andar: ON" or "Andar"
        walk.TextColor3 = State.WalkMode and CONFIG.Theme.Good or CONFIG.Theme.Muted
    end)

    State.MobileButton = button(State.Gui, "✦", UDim2.fromOffset(48, 48), UDim2.new(1, -70, 1, -82))
    State.MobileButton.BackgroundColor3 = CONFIG.Theme.AccentDark
    State.MobileButton.TextColor3 = CONFIG.Theme.Text
    State.MobileButton.TextSize = 20
    State.MobileButton.Visible = UserInputService.TouchEnabled
    State.MobileButton.Activated:Connect(function()
        togglePanel()
    end)

    local dragging = false
    local dragStart
    local panelStart
    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            panelStart = State.Panel.Position
        end
    end)
    header.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    State.DragConnection = UserInputService.InputChanged:Connect(function(input)
        if not dragging then
            return
        end
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            local delta = input.Position - dragStart
            State.Panel.Position = UDim2.new(
                panelStart.X.Scale,
                panelStart.X.Offset + delta.X,
                panelStart.Y.Scale,
                panelStart.Y.Offset + delta.Y
            )
        end
    end)
end

local function bind()
    State.InputConnection = UserInputService.InputBegan:Connect(function(input, processed)
        if processed then
            return
        end
        if input.KeyCode == CONFIG.EmoteKey then
            togglePanel()
        elseif input.KeyCode == Enum.KeyCode.Escape then
            togglePanel(false)
        elseif input.KeyCode == Enum.KeyCode.Q and State.PanelOpen then
            State.Page -= 1
            render()
        elseif input.KeyCode == Enum.KeyCode.E and State.PanelOpen then
            State.Page += 1
            render()
        elseif input.KeyCode == Enum.KeyCode.R and State.PanelOpen then
            randomVisible()
        elseif input.KeyCode == Enum.KeyCode.X then
            stopTrack()
        end
    end)

    State.HeartbeatConnection = RunService.Heartbeat:Connect(function()
        if not State.Track or not State.Track.IsPlaying then
            return
        end
        local _, humanoid = getCharacter()
        if humanoid and not State.WalkMode and humanoid.MoveDirection.Magnitude > 0 then
            stopTrack()
        end
    end)

    if LocalPlayer then
        State.CharacterConnection = LocalPlayer.CharacterAdded:Connect(function()
            stopTrack()
        end)
    end
end

local function destroy()
    if State.Track then
        stopTrack()
    end
    for _, connectionName in ipairs({ "InputConnection", "HeartbeatConnection", "CharacterConnection", "DragConnection" }) do
        local connection = State[connectionName]
        if connection then
            connection:Disconnect()
            State[connectionName] = nil
        end
    end
    if State.Gui then
        State.Gui:Destroy()
        State.Gui = nil
    end
    _G.EmotesDarkV2 = nil
end

State.Render = render
State.Destroy = destroy
_G.EmotesDarkV2 = State

ensureFolder()
loadFavorites()
loadItems()
createGui()
bind()
notify("Emotes Dark V2", "Pronto. Pressione . para abrir.", 4)