fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'qbx_easygarage'
description 'Simple, easy-to-configure garage for the Nova framework'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    'client.lua',
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
