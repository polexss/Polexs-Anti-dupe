require 'config'

-- Ensure the FiveGuard resource name is correctly set in fxmanifest.lua dependencies if it's dynamic
local FiveGuardExports = exports[Config.FiveGuardResourceName]


local playerInventoryTracker = {}


local function GetTimeMs()
    return os.time() * 1000
end


local function Log(message)
    if Config.LogDupeAttempts then
        print(string.format("[DupeGuard] %s", message))
    end
end

local function SendDiscordWebhook(title, description, color, fields)
    if not Config.UseDiscordWebhook or not Config.DiscordWebhookURL or Config.DiscordWebhookURL == "YOUR_DISCORD_WEBHOOK_URL_HERE" then
        return -- Webhook not enabled or URL not configured
    end

    local embeds = {
        {
            title = title,
            description = description,
            color = color or Config.WebhookColor,
            footer = {
                text = "DupeGuard | " .. os.date("%Y-%m-%d %H:%M:%S"),
                icon_url = Config.WebhookAvatarURL
            },
            fields = fields or {}
        }
    }

    PerformHttpRequest(Config.DiscordWebhookURL, function(err, text, headers)
        if err ~= 200 then
            print(string.format("[DupeGuard Webhook Error] Failed to send webhook: %s", text))
        end
    end, 'POST', json.encode({
        username = Config.WebhookUsername,
        avatar_url = Config.WebhookAvatarURL,
        embeds = embeds
    }), { ['Content-Type'] = 'application/json' })
end

--- Bans a player using FiveGuard's export function.
-- Falls back to DropPlayer if FiveGuard export is not found or fails.
local function BanPlayer(playerId, reason)
    local playerName = GetPlayerName(playerId)
    local identifiers = GetPlayerIdentifiers(playerId) or {}
    local playerIp = GetPlayerIP(playerId) or "N/A"

    Log(string.format("###################################################"))
    Log(string.format("PLAYER BANNING: %s (ID: %d) - Reason: %s", playerName, playerId, reason))
    Log(string.format("###################################################"))

    SendDiscordWebhook(
        "🚫 Player Banned - Dupe Detected!",
        string.format("**Player:** %s (ID: %d)\n**Reason:** %s", playerName, playerId, reason),
        Config.WebhookColor,
        {
            { name = "Identifiers", value = table.concat(identifiers, ", "), inline = false },
            { name = "IP Address", value = playerIp, inline = true }
        }
    )

    if FiveGuardExports and FiveGuardExports.BanPlayer then
        FiveGuardExports.BanPlayer(playerId, reason)
    else
        Log(string.format("WARNING: FiveGuard export 'BanPlayer' not found or resource name incorrect. Kicking player %s (ID: %d) instead. Reason: %s", playerName, playerId, reason))
        DropPlayer(playerId, reason)
    end
end

--- Gets the current total item count for a player based on the configured inventory system.
local function GetPlayerTotalItemCount(playerId)
    local totalCount = 0

    if Config.Framework == "esx" then
        local xPlayer = ESX.GetPlayerFromId(playerId)
        if xPlayer and xPlayer.Inventory then
            for _, item in pairs(xPlayer.Inventory) do
                if item.count then
                    totalCount = totalCount + item.count
                end
            end
        end
    elseif Config.Framework == "qb" then
        local Player = QBCore.Functions.GetPlayer(playerId)
        if Player then
            if Config.InventorySystem == "qb-inventory" or Config.InventorySystem == "ox_inventory" then
                local inventory = Player.Functions.GetInventory()
                if inventory and inventory.items then
                    for _, item in pairs(inventory.items) do
                        if item.amount then
                            totalCount = totalCount + item.amount
                        end
                    end
                end
            elseif Config.InventorySystem == "codem-inventory" then
                local inventory = exports['codem-inventory']:GetPlayerInventory(playerId)
                if inventory and inventory.items then
                    for _, itemData in pairs(inventory.items) do
                        if itemData.amount then
                            totalCount = totalCount + itemData.amount
                        end
                    end
                end
            elseif Config.InventorySystem == "tgiann-inventory" then
                local inventory = exports['tgiann-inventory']:getPlayerInventory(playerId)
                if inventory and inventory.items then
                    for _, itemData in pairs(inventory.items) do
                        if itemData.count then
                            totalCount = totalCount + itemData.count
                        end
                    end
                end
            elseif Config.InventorySystem == "quasar-inventory" then
                local inventory = exports['quasar-inventory']:getInventory(playerId)
                if inventory and inventory.items then
                    for _, itemData in pairs(inventory.items) do
                        if itemData.quantity then
                            totalCount = totalCount + itemData.quantity
                        end
                    end
                end
            else
                Log(string.format("ERROR: Unsupported inventory system '%s' for QB framework.", Config.InventorySystem))
            end
        end
    end

    return totalCount
end

--- Checks for potential dupe attempts for a given player.
local function CheckForDupe(playerId, currentItemCount)
    local playerName = GetPlayerName(playerId)
    if not playerInventoryTracker[playerId] then
        -- Initialize tracker for new players or after a restart
        playerInventoryTracker[playerId] = {
            lastItemCount = currentItemCount,
            lastCheckTime = GetTimeMs(),
            potentialDupeCount = 0
        }
        Log(string.format("Initialized inventory tracker for player %s (ID: %d)", playerName, playerId))
        return
    end

    local tracker = playerInventoryTracker[playerId]
    local currentTime = GetTimeMs()
    local timeElapsed = (currentTime - tracker.lastCheckTime) / 1000 -- Time in seconds

    -- Skip if it's the very first check after init, or if item count hasn't changed
    if tracker.lastItemCount == nil or currentItemCount == tracker.lastItemCount then
        tracker.lastItemCount = currentItemCount
        tracker.lastCheckTime = currentTime
        return
    end

    local increaseAmount = currentItemCount - tracker.lastItemCount


    if timeElapsed <= Config.TimeWindowSeconds and increaseAmount >= Config.ItemThreshold then
        tracker.potentialDupeCount = tracker.potentialDupeCount + 1
        Log(string.format("Potential dupe attempt detected! Player: %s (ID: %d), Item Increase: %d, Time Elapsed: %.2f sec. Total Detections: %d",
            playerName, playerId, increaseAmount, timeElapsed, tracker.potentialDupeCount))

        SendDiscordWebhook(
            "⚠️ Potential Dupe Detected!",
            string.format("**Player:** %s (ID: %d)\n**Item Increase:** %d\n**Time Elapsed:** %.2f seconds\n**Total Detections:** %d",
                playerName, playerId, increaseAmount, timeElapsed, tracker.potentialDupeCount),
            Config.WebhookColor,
            {
                { name = "Threshold", value = Config.ItemThreshold .. " items in " .. Config.TimeWindowSeconds .. "s", inline = true },
                { name = "IP Address", value = GetPlayerIP(playerId) or "N/A", inline = true }
            }
        )

        if Config.BanOnFirstDetection or (tracker.potentialDupeCount >= Config.DupeAttemptTolerance + 1) then
            BanPlayer(playerId, Config.BanMessage)
        end
    elseif timeElapsed > Config.TimeWindowSeconds then
        -- Reset counter and start a new detection cycle if time window passed
        tracker.potentialDupeCount = 0
        tracker.lastCheckTime = currentTime
    end

    -- Update last known item count and check time
    tracker.lastItemCount = currentItemCount
    tracker.lastCheckTime = currentTime
end

--- Event handler for player connection. Initializes inventory tracking.
AddEventHandler('playerConnecting', function(playerName, setKickReason, deferrals)
    local playerId = source
    deferrals.defer()
    deferrals.update("Initializing DupeGuard for " .. playerName .. "...")
    Citizen.Wait(100) -- Small delay to ensure player object is ready
    playerInventoryTracker[playerId] = {
        lastItemCount = nil, 
        lastCheckTime = GetTimeMs(),
        potentialDupeCount = 0
    }
    deferrals.done()
    Log(string.format("Started inventory tracker for player %s (ID: %d) on connect.", playerName, playerId))
end)

--- Event handler for player disconnection. Cleans up inventory tracking.
AddEventHandler('playerDropped', function(reason)
    local playerId = source
    if playerInventoryTracker[playerId] then
        playerInventoryTracker[playerId] = nil
        Log(string.format("Stopped inventory tracker for player %s (ID: %d) on disconnect.", GetPlayerName(playerId), playerId))
    end
end)


if Config.Framework == "esx" then
    ESX = nil
    TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)


    Citizen.CreateThread(function()
        while ESX == nil do Citizen.Wait(100) end -- Wait for ESX to load
        Log("ESX Framework detected. DupeGuard will use periodic inventory checks or specific item events (if hooked).")
        while true do
            Citizen.Wait(Config.CheckIntervalMs)
            for id, player in pairs(ESX.GetPlayers()) do
                local xPlayer = ESX.GetPlayerFromId(id)
                if xPlayer then
                    local currentCount = GetPlayerTotalItemCount(id)
                    CheckForDupe(id, currentCount)
                end
            end
        end
    end)

elseif Config.Framework == "qb" then
    QBCore = nil

    Citizen.CreateThread(function()
        while QBCore == nil do
            TriggerEvent('QBCore:GetObject', function(obj) QBCore = obj end)
            Citizen.Wait(100) -- Wait for QBCore to be available
        end
        Log("QBCore Framework detected. DupeGuard will use player loaded event and periodic checks.")


        AddEventHandler('QBCore:Server:PlayerLoaded', function(Player)
            local playerId = Player.PlayerData.source
            local currentCount = GetPlayerTotalItemCount(playerId)
            CheckForDupe(playerId, currentCount)
            Log(string.format("Initial inventory check for %s (ID: %d) on QBCore load.", GetPlayerName(playerId), playerId))
        end)


        while true do
            Citizen.Wait(Config.CheckIntervalMs)
            for _, player in ipairs(QBCore.Functions.GetPlayers()) do
                local playerId = player
                local currentCount = GetPlayerTotalItemCount(playerId)
                CheckForDupe(playerId, currentCount)
            end
        end
    end)
else
    Log("ERROR: Unsupported Framework configured in config.lua. Please set Config.Framework to 'esx' or 'qb'.")
end

--- Server Command for manual testing (development purposes only).
-- Usage: /testdupecheck [player_id] [current_item_count]
RegisterCommand('testdupecheck', function(source, args, rawCommand)
    if source == 0 then -- Only callable from server console
        local targetPlayerId = tonumber(args[1])
        local currentItemCount = tonumber(args[2])
        if targetPlayerId and currentItemCount then
            CheckForDupe(targetPlayerId, currentItemCount)
            Log(string.format("TEST: Inventory check performed for player %d, current item count: %d", targetPlayerId, currentItemCount))
        else
            Log("Usage: testdupecheck [player_id] [current_item_count]")
        end
    else
        TriggerClientEvent('chat:addMessage', source, { args = { '^1ERROR: ^0This command can only be used from the server console.' } })
    end
end, false)



