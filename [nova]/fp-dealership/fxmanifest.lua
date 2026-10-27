fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'fp-dealership'
description 'Vehicle dealership with in-game admin management (Nova)'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_script 'client/main.lua'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
}

dependencies {
    'nova_core',
    'ox_lib',
    'oxmysql',
}
