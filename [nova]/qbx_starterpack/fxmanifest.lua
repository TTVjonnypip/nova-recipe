fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'qbx_starterpack'
description 'One-time starter pack for new Nova characters'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua',
}

dependencies {
    'nova_core',
    'ox_lib',
    'oxmysql',
}
