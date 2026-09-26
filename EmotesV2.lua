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
    ViewportConnection = nil,
    Gui = nil,
    Panel = nil,
    Wheel = nil,
    Slots = nil,
    PanelScale = nil,
    Search = nil,
    Status = nil,
    PageLabel = nil,
    CenterTitle = nil,
    CenterMeta = nil,
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

local function shortName(name, limit)
    local text = tostring(name or "")
    if #text <= limit then
        return text
    end
    return text:sub(1, limit - 1) .. "…"
end

local function render()
    if not State.Slots then
        return
    end

    State.Filtered = filteredItems()
    local pages = pageCount()
    State.Page = math.clamp(State.Page, 1, pages)

    local first = (State.Page - 1) * CONFIG.PageSize + 1
    local last = math.min(first + CONFIG.PageSize - 1, #State.Filtered)
    local rangeText = #State.Filtered == 0 and "0" or string.format("%d ───── %d", first, last)

    if State.PageLabel then
        State.PageLabel.Text = rangeText
    end
    if State.Status then
        State.Status.Text = string.format(
            "%d emotes  •  %s",
            #State.Filtered,
            State.Tab == "all" and "Todos" or "Favoritos"
        )
    end
    updateTabs()

    if State.CenterTitle then
        State.CenterTitle.Text = #State.Filtered == 0 and "Nenhum emote" or "Selecione um emote"
    end
    if State.CenterMeta then
        State.CenterMeta.Text = #State.Filtered == 0 and "Tente outra busca" or "Escolha uma posição"
    end

    for _, child in ipairs(State.Slots:GetChildren()) do
        child:Destroy()
    end

    local wheelCenter = Vector2.new(190, 148)
    local radius = 112
    local slotSize = 76
    for slotIndex = 1, CONFIG.PageSize do
        local index = first + slotIndex - 1
        local item = State.Filtered[index]
        local angle = -math.pi / 2 + ((slotIndex - 1) / CONFIG.PageSize) * math.pi * 2
        local position = wheelCenter + Vector2.new(math.cos(angle), math.sin(angle)) * radius

        local slot = new("TextButton", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            AutoButtonColor = false,
            BackgroundColor3 = item and CONFIG.Theme.Surface or CONFIG.Theme.Background,
            BackgroundTransparency = item and 0.08 or 0.38,
            BorderSizePixel = 0,
            Position = UDim2.fromOffset(position.X, position.Y),
            Size = UDim2.fromOffset(slotSize, slotSize),
            Text = "",
            ZIndex = 4,
        }, State.Slots)
        round(slot, slotSize / 2)
        stroke(
            slot,
            item and (State.Favorites[item.id] and CONFIG.Theme.Accent or CONFIG.Theme.Stroke) or CONFIG.Theme.Stroke,
            item and 0.05 or 0.55
        )

        new("TextLabel", {
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamBold,
            Position = UDim2.fromOffset(0, 7),
            Size = UDim2.new(1, 0, 0, 16),
            Text = tostring(slotIndex),
            TextColor3 = item and CONFIG.Theme.Accent or CONFIG.Theme.Muted,
            TextSize = 12,
            ZIndex = 5,
        }, slot)

        if item then
            new("TextLabel", {
                BackgroundTransparency = 1,
                Font = Enum.Font.GothamSemibold,
                Position = UDim2.fromOffset(5, 25),
                Size = UDim2.new(1, -10, 0, 24),
                Text = shortName(item.name, 14),
                TextColor3 = CONFIG.Theme.Text,
                TextSize = 10,
                TextTruncate = Enum.TextTruncate.AtEnd,
                ZIndex = 5,
            }, slot)
            new("TextLabel", {
                BackgroundTransparency = 1,
                Font = Enum.Font.Code,
                Position = UDim2.fromOffset(4, 52),
                Size = UDim2.new(1, -8, 0, 14),
                Text = State.Favorites[item.id] and "★" or tostring(item.id),
                TextColor3 = State.Favorites[item.id] and CONFIG.Theme.Good or CONFIG.Theme.Muted,
                TextSize = 9,
                TextTruncate = Enum.TextTruncate.AtEnd,
                ZIndex = 5,
            }, slot)
            local favorite = new("TextButton", {
                AutoButtonColor = false,
                BackgroundTransparency = 1,
                Font = Enum.Font.GothamBold,
                Position = UDim2.fromOffset(51, 4),
                Size = UDim2.fromOffset(20, 18),
                Text = State.Favorites[item.id] and "★" or "☆",
                TextColor3 = State.Favorites[item.id] and CONFIG.Theme.Good or CONFIG.Theme.Muted,
                TextSize = 13,
                ZIndex = 7,
            }, slot)
            favorite.Activated:Connect(function()
                State.Favorites[item.id] = not State.Favorites[item.id] or nil
                saveFavorites()
                render()
            end)

            slot.MouseEnter:Connect(function()
                slot.BackgroundColor3 = CONFIG.Theme.SurfaceHover
                if State.CenterTitle then
                    State.CenterTitle.Text = item.name
                end
                if State.CenterMeta then
                    State.CenterMeta.Text = tostring(item.id)
                end
            end)
            slot.MouseLeave:Connect(function()
                slot.BackgroundColor3 = CONFIG.Theme.Surface
                if State.CenterTitle then
                    State.CenterTitle.Text = "Selecione um emote"
                end
                if State.CenterMeta then
                    State.CenterMeta.Text = "Escolha uma posição"
                end
            end)
            slot.Activated:Connect(function()
                playItem(item)
            end)
        end
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

local function fitPanel()
    if not State.PanelScale then
        return
    end

    local camera = workspace.CurrentCamera
    if not camera then
        return
    end

    local viewport = camera.ViewportSize
    State.PanelScale.Scale = math.clamp(math.min(viewport.X / 540, viewport.Y / 470), 0.72, 1)
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
        BackgroundTransparency = 1,
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(500, 430),
        Visible = false,
    }, State.Gui)
    State.PanelScale = new("UIScale", { Scale = 1 }, State.Panel)

    local header = new("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 48),
        Position = UDim2.fromOffset(0, 0),
    }, State.Panel)
    new("TextLabel", {
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBlack,
        Position = UDim2.fromOffset(8, 1),
        Size = UDim2.fromOffset(140, 18),
        Text = "EMOTES DARK",
        TextColor3 = CONFIG.Theme.Text,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, header)
    State.Status = new("TextLabel", {
        BackgroundTransparency = 1,
        Font = Enum.Font.Gotham,
        Position = UDim2.fromOffset(8, 20),
        Size = UDim2.fromOffset(220, 16),
        TextColor3 = CONFIG.Theme.Muted,
        TextSize = 9,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, header)
    local close = button(header, "×", UDim2.fromOffset(30, 30), UDim2.new(1, -38, 0, 0))
    close.TextSize = 18
    close.Activated:Connect(function()
        togglePanel(false)
    end)

    State.Search = new("TextBox", {
        BackgroundColor3 = CONFIG.Theme.Surface,
        BorderSizePixel = 0,
        ClearTextOnFocus = false,
        Font = Enum.Font.Gotham,
        PlaceholderColor3 = CONFIG.Theme.Muted,
        PlaceholderText = "Search/ID",
        Position = UDim2.fromOffset(128, 4),
        Size = UDim2.fromOffset(236, 34),
        Text = "",
        TextColor3 = CONFIG.Theme.Text,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, State.Panel)
    round(State.Search, 17)
    stroke(State.Search, CONFIG.Theme.Stroke, 0.35)
    new("UIPadding", {
        PaddingLeft = UDim.new(0, 12),
        PaddingRight = UDim.new(0, 12),
    }, State.Search)
    State.Search:GetPropertyChangedSignal("Text"):Connect(function()
        State.Query = State.Search.Text
        State.Page = 1
        render()
    end)

    State.AllTab = button(State.Panel, "Todos", UDim2.fromOffset(64, 26), UDim2.fromOffset(8, 52))
    State.FavoritesTab = button(State.Panel, "★", UDim2.fromOffset(34, 26), UDim2.fromOffset(76, 52))
    State.AllTab.TextSize = 10
    State.FavoritesTab.TextSize = 14
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

    State.Wheel = new("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, 78),
        Size = UDim2.fromOffset(380, 296),
    }, State.Panel)
    local ring = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = CONFIG.Theme.Background,
        BackgroundTransparency = 0.2,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(190, 148),
        Size = UDim2.fromOffset(292, 292),
        ZIndex = 1,
    }, State.Wheel)
    round(ring, 146)
    stroke(ring, CONFIG.Theme.Stroke, 0.4)

    State.Slots = new("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(380, 296),
        ZIndex = 3,
    }, State.Wheel)
    State.CenterTitle = new("TextLabel", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Color3.fromRGB(10, 11, 16),
        BackgroundTransparency = 0.08,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(190, 142),
        Size = UDim2.fromOffset(126, 98),
        Font = Enum.Font.GothamSemibold,
        Text = "Selecione um emote",
        TextColor3 = CONFIG.Theme.Text,
        TextSize = 13,
        TextWrapped = true,
        ZIndex = 6,
    }, State.Wheel)
    round(State.CenterTitle, 63)
    stroke(State.CenterTitle, CONFIG.Theme.Stroke, 0.45)
    State.CenterMeta = new("TextLabel", {
        AnchorPoint = Vector2.new(0.5, 0),
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(190, 160),
        Size = UDim2.fromOffset(112, 22),
        Font = Enum.Font.Code,
        Text = "Escolha uma posição",
        TextColor3 = CONFIG.Theme.Muted,
        TextSize = 9,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 7,
    }, State.Wheel)

    local footer = new("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(8, 382),
        Size = UDim2.fromOffset(484, 48),
    }, State.Panel)
    local previous = button(footer, "◀", UDim2.fromOffset(36, 34), UDim2.fromOffset(60, 0))
    local next = button(footer, "▶", UDim2.fromOffset(36, 34), UDim2.fromOffset(312, 0))
    State.PageLabel = new("TextLabel", {
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamSemibold,
        Position = UDim2.fromOffset(100, 0),
        Size = UDim2.fromOffset(208, 34),
        TextColor3 = CONFIG.Theme.Text,
        TextSize = 11,
    }, footer)
    State.PageLabel.TextXAlignment = Enum.TextXAlignment.Center
    local random = button(footer, "↻", UDim2.fromOffset(36, 34), UDim2.fromOffset(358, 0))
    random.TextSize = 18
    local stop = button(footer, "■", UDim2.fromOffset(36, 34), UDim2.fromOffset(402, 0))
    stop.TextSize = 12
    local speed = new("TextBox", {
        BackgroundColor3 = CONFIG.Theme.Surface,
        BorderSizePixel = 0,
        ClearTextOnFocus = false,
        Font = Enum.Font.GothamSemibold,
        PlaceholderText = "1.0x",
        Position = UDim2.fromOffset(446, 0),
        Size = UDim2.fromOffset(38, 34),
        Text = "1",
        TextColor3 = CONFIG.Theme.Text,
        TextSize = 10,
    }, footer)
    round(speed, 17)
    stroke(speed, CONFIG.Theme.Stroke, 0.25)
    speed.FocusLost:Connect(function()
        setSpeed(speed.Text)
        speed.Text = tostring(State.Speed)
    end)
    local walk = button(State.Panel, "Andar", UDim2.fromOffset(66, 26), UDim2.new(1, -74, 0, 52))
    walk.TextSize = 10
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
    fitPanel()
    local camera = workspace.CurrentCamera
    if camera then
        State.ViewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(fitPanel)
    end
end

local function bind()
    State.InputConnection = UserInputService.InputBegan:Connect(function(input, processed)
        if processed then
            return
        end
        local slotKeys = {
            [Enum.KeyCode.One] = 1,
            [Enum.KeyCode.Two] = 2,
            [Enum.KeyCode.Three] = 3,
            [Enum.KeyCode.Four] = 4,
            [Enum.KeyCode.Five] = 5,
            [Enum.KeyCode.Six] = 6,
            [Enum.KeyCode.Seven] = 7,
            [Enum.KeyCode.Eight] = 8,
        }
        local slotIndex = slotKeys[input.KeyCode]
        if slotIndex and State.PanelOpen then
            State.Filtered = filteredItems()
            local item = State.Filtered[(State.Page - 1) * CONFIG.PageSize + slotIndex]
            if item then
                playItem(item)
            end
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
    for _, connectionName in ipairs({ "InputConnection", "HeartbeatConnection", "CharacterConnection", "DragConnection", "ViewportConnection" }) do
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