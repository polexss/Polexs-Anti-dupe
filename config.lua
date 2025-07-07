Config = {}

Config.Framework = "qb" -- "esx" or "qb" - Choose your server framework
Config.InventorySystem = "ox_inventory" -- "qb-inventory", "ox_inventory", "codem-inventory", "tgiann-inventory", "quasar-inventory" - Choose your inventory system

Config.FiveGuardResourceName = "fiveguard" -- The exact resource name of your FiveGuard installation (e.g., 'fiveguard', 'fiveguard_ac')
Config.BanMessage = "You have been banned for automated dupe detection. Please contact support if you believe this is an error."
Config.LogDupeAttempts = true -- Set to true to log dupe attempts to the server console

-- DUPE DETECTION SETTINGS
Config.ItemThreshold = 50 -- The maximum number of individual items that can be added to inventory within the time window.
                           -- If a player adds more than this amount of items, it will be flagged as suspicious.
                           -- Adjust this value based on your server's economy and normal gameplay.
Config.TimeWindowSeconds = 5 -- The time frame (in seconds) during which inventory changes are monitored for suspicious activity.
                              -- If 'ItemThreshold' is exceeded within this window, a potential dupe is flagged.

Config.BanOnFirstDetection = true -- If true, a player will be banned on their first detected dupe attempt.
                                  -- If false, 'Config.DupeAttemptTolerance' will be used.
Config.DupeAttemptTolerance = 2 -- Number of potential dupe detections before a player is banned (only if BanOnFirstDetection is false).
                               -- e.g., if set to 2, player will be banned on the 3rd detection.

-- ADVANCED SETTINGS (Generally do not need to be changed)
Config.CheckIntervalMs = 1000 

-- DISCORD WEBHOOK SETTINGS
Config.UseDiscordWebhook = true 
Config.DiscordWebhookURL = "YOUR_DISCORD_WEBHOOK_URL_HERE" 
Config.WebhookUsername = "DupeGuard Logs"
Config.WebhookAvatarURL = "https://i.imgur.com/your_bot_avatar.png" -- Optional: URL for the bot's avatar
Config.WebhookColor = 16711680 --  (e.g., Red: 16711680, Green: 65280, Blue: 255)

-- Inventory-Specific Settings (if needed for custom logic)
-- This section can be expanded if specific inventory systems require unique configurations.
-- For example:
-- Config.InventorySpecific = {
--     ["tgiann-inventory"] = {
--         SpecialItemMultiplier = 2 -- Example: Consider some items in tgiann as more critical.
--     }
-- }
