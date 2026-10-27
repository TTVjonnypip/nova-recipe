fx_version 'cerulean'
game 'gta5'

author 'Family Legacy RP'
description 'Family Legacy RP loading screen'
version '1.0.0'

loadscreen 'index.html'

-- Keep the loading screen up until character select is ready
-- (qbx_charcreate calls ShutdownLoadingScreenNui when it opens)
loadscreen_manual_shutdown 'yes'

files {
    'index.html'
}
