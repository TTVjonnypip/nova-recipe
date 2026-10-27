fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'qbx_pregnancy'
description 'Roleplay pregnancy system for the Nova framework'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    'server/main.lua',
}

dependencies {
    'nova_core',
    'ox_lib',
}
