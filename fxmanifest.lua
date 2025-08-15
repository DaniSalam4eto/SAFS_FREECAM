fx_version 'cerulean'
game 'gta5'

name 'Freecam_SAFS'
author 'Dani'
description 'Freecam for Fivem using Ctrl+number presets' (save with Shift+number)'

version '1.7.0'

lua54 'yes'

client_scripts {
    'config.lua',
    'client.lua'
}

server_scripts {
    'server.lua'
}

files {
    'presets.json'
}