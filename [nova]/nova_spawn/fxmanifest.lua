fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'nova_spawn'
description 'Spawn selector for the Nova framework (ox_lib UI)'
version '1.0.0'

dependencies { 'nova_core', 'ox_lib' }

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_script 'client.lua'
