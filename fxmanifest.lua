fx_version 'cerulean'
game 'gta5'

author 'Polexs'
description 'Anti Dupe for Fiveguard'
version '1.0.0'

server_scripts 'server.lua'

shared_script 'config.lua'


-- Replace 'fiveguard' with the actual resource name of your FiveGuard installation.
-- Only works for fiveguard
dependencies {
    'fiveguard' -- This will be dynamically set from config.lua
}