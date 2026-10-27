fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nova_phone'
author 'Custom'
description 'Nova Phone - multi-app smartphone for the Nova framework'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
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
    'html/app.js',
}

dependencies {
    'nova_core',
    'ox_lib',
    'oxmysql',
}
