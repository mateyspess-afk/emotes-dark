-- Emote Dark - Verified Donation Leaderboard
-- Place this Script in ServerScriptService inside your Roblox experience.
-- Configure the same IDs here and in Emotes.lua.

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

local DonationProductIds = {
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
local profileStore = DataStoreService:GetDataStore("EmoteDarkDonationProfiles_v1")
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

local function calculateVerifiedGamePassTotal(player)
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
    if not checkedAnyPass then return nil end
    return total
end

local function updateOrderedTotal(userId, total)
    local key = tostring(userId)
    local ok, err = pcall(function()
        if total > 0 then
            donationStore:SetAsync(key, total)
        else
            donationStore:RemoveAsync(key)
        end
    end)
    if not ok then
        warn("[EmoteDark] Could not update donation leaderboard: " .. tostring(err))
    end
    return ok
end

local function syncPlayerGamePassDonation(player)
    if not player or player.Parent ~= Players then return end
    local gamePassTotal = calculateVerifiedGamePassTotal(player)
    if gamePassTotal == nil then return end

    local key = tostring(player.UserId)
    local ok, profile = pcall(function()
        return profileStore:UpdateAsync(key, function(oldProfile)
            oldProfile = type(oldProfile) == "table" and oldProfile or {}
            oldProfile.ProductTotal = tonumber(oldProfile.ProductTotal) or 0
            oldProfile.GamePassTotal = gamePassTotal
            oldProfile.Total = oldProfile.ProductTotal + gamePassTotal
            return oldProfile
        end)
    end)
    if not ok then
        warn("[EmoteDark] Could not save verified Game Pass total: " .. tostring(profile))
        return
    end
    updateOrderedTotal(player.UserId, tonumber(profile.Total) or 0)
end

local productAmounts = {}
for amount, productId in pairs(DonationProductIds) do
    productId = tonumber(productId) or 0
    if productId > 0 then
        productAmounts[productId] = amount
    end
end

MarketplaceService.ProcessReceipt = function(receiptInfo)
    local amount = productAmounts[tonumber(receiptInfo.ProductId)]
    if not amount then
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end

    local key = tostring(receiptInfo.PlayerId)
    local ok, profile = pcall(function()
        return profileStore:UpdateAsync(key, function(oldProfile)
            oldProfile = type(oldProfile) == "table" and oldProfile or {}
            oldProfile.ProductTotal = tonumber(oldProfile.ProductTotal) or 0
            oldProfile.GamePassTotal = tonumber(oldProfile.GamePassTotal) or 0
            oldProfile.Receipts = type(oldProfile.Receipts) == "table" and oldProfile.Receipts or {}
            local purchaseKey = tostring(receiptInfo.PurchaseId)
            if not oldProfile.Receipts[purchaseKey] then
                oldProfile.Receipts[purchaseKey] = true
                oldProfile.ProductTotal += amount
            end
            oldProfile.Total = oldProfile.ProductTotal + oldProfile.GamePassTotal
            return oldProfile
        end)
    end)
    if not ok then
        warn("[EmoteDark] Could not process donation receipt: " .. tostring(profile))
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end

    if not updateOrderedTotal(receiptInfo.PlayerId, tonumber(profile.Total) or 0) then
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end
    return Enum.ProductPurchaseDecision.PurchaseGranted
end

Players.PlayerAdded:Connect(function(player)
    task.delay(3, function()
        syncPlayerGamePassDonation(player)
    end)
end)

for _, player in ipairs(Players:GetPlayers()) do
    task.spawn(syncPlayerGamePassDonation, player)
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
