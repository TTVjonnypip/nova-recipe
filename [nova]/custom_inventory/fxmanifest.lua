fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'custom_inventory'
description 'Slot-based inventory for the Nova framework: stashes, trunks, gloveboxes, drops, giving, usable items and shops'
version '1.0.0'

shared_scripts {
    'config.lua',
    'shared/items.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/images/*.png',
}

dependencies {
    'nova_core',
    'oxmysql',
}
