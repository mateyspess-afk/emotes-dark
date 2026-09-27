-- Emote Dark - Verified Donation Leaderboard
-- Place this Script in ServerScriptService inside your Roblox experience.
-- Configure the same Game Pass IDs here and in Emotes.lua.

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DonationPassIds = {
    [10] = 0,
    [50] = 0,
    [100] = 0,
    [200] = 0,
    [300] = 0,
    [400] = 0,
    [500] = 0,
    [1000] = 0,
}

local MAX_LEADERBOARD_ENTRIES = 100
local donationStore = DataStoreService:GetOrderedDataStore("EmoteDarkDonations_v1")
local nameCache = {}

local leaderboardRemote = ReplicatedStorage:FindFirstChild("EmoteDarkDonationLeaderboard")
if leaderboardRemote and not leaderboardRemote:IsA("RemoteFunction") then
    leaderboardRemote:Destroy()
    leaderboardRemote = nil
end
if not leaderboardRemote then
    leaderboardRemote = Instance.new("RemoteFunction")
    leaderboardRemote.Name = "EmoteDarkDonationLeaderboard"
    leaderboardRemote.Parent = ReplicatedStorage
end

local function getPlayerName(userId)
    if nameCache[userId] then return nameCache[userId] end
    local ok, name = pcall(function()
        return Players:GetNameFromUserIdAsync(userId)
    end)
    if ok and name then
        nameCache[userId] = name
        return name
    end
    return "User " .. tostring(userId)
end

local function calculateVerifiedTotal(player)
    local total = 0
    local checkedAnyPass = false
    for amount, passId in pairs(DonationPassIds) do
        passId = tonumber(passId) or 0
        if passId > 0 then
            checkedAnyPass = true
            local ok, ownsPass = pcall(function()
                return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
            end)
            if not ok then
                warn("[EmoteDark] Could not verify Game Pass " .. tostring(passId) .. " for " .. player.Name)
                return nil
            end
            if ownsPass then
                total += amount
            end
        end
    end
    if not checkedAnyPass then return 0 end
    return total
end

local function syncPlayerDonation(player)
    if not player or player.Parent ~= Players then return end
    local total = calculateVerifiedTotal(player)
    if total == nil then return end

    local key = tostring(player.UserId)
    local ok, err = pcall(function()
        if total > 0 then
            donationStore:SetAsync(key, total)
        else
            donationStore:RemoveAsync(key)
        end
    end)
    if not ok then
        warn("[EmoteDark] Could not save donation for " .. player.Name .. ": " .. tostring(err))
    end
end

local function refreshAfterPurchase(player, purchasedPassId, wasPurchased)
    if not wasPurchased then return end
    local expectedPass = false
    for _, passId in pairs(DonationPassIds) do
        if tonumber(passId) == tonumber(purchasedPassId) then
            expectedPass = true
            break
        end
    end
    if not expectedPass then return end
    task.delay(3, function()
        syncPlayerDonation(player)
    end)
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(refreshAfterPurchase)

Players.PlayerAdded:Connect(function(player)
    task.delay(3, function()
        syncPlayerDonation(player)
    end)
end)

for _, player in ipairs(Players:GetPlayers()) do
    task.spawn(syncPlayerDonation, player)
end

leaderboardRemote.OnServerInvoke = function()
    local ok, pages = pcall(function()
        return donationStore:GetSortedAsync(false, MAX_LEADERBOARD_ENTRIES)
    end)
    if not ok then
        warn("[EmoteDark] Could not load donation leaderboard: " .. tostring(pages))
        return {}
    end

    local entries = {}
    for _, item in ipairs(pages:GetCurrentPage()) do
        local userId = tonumber(item.key)
        local amount = tonumber(item.value) or 0
        if userId and amount > 0 then
            table.insert(entries, {
                UserId = userId,
                Name = getPlayerName(userId),
                Amount = amount,
            })
        end
        if #entries >= MAX_LEADERBOARD_ENTRIES then break end
    end
    return entries
end
