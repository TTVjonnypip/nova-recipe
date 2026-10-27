fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'nova_core'
description 'Nova framework core - built on ideas from Qbox and QBCore'
version '1.0.0'

-- Lets existing scripts that call exports['qb-core'] keep working.
-- Do NOT run qb-core or qbx_core alongside this resource.
provide 'qb-core'

dependencies {
    '/onesync',
    'oxmysql',
    'ox_lib',
}

shared_scripts {
    '@ox_lib/init.lua',
    'config/shared.lua',
    'shared/utils.lua',
    'shared/jobs.lua',
    'shared/gangs.lua',
    'shared/vehicles.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'config/server.lua',
    'server/main.lua',
    'server/storage.lua',
    'server/functions.lua',
    'server/inventory.lua',
    'server/player.lua',
    'server/events.lua',
    'server/loops.lua',
    'server/commands.lua',
    'bridge/qb/server.lua',
}

client_scripts {
    'client/main.lua',
    'client/functions.lua',
    'client/inventory.lua',
    'client/events.lua',
    'bridge/qb/client.lua',
}
