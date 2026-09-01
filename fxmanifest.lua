fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'oph3z-phone-app-valet'
author 'no name'
description '配車アプリ for a third-party oph3z-phone app'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_script 'client.lua'
server_script 'server.lua'

files {
    'locales/*.json',
    'ui/index.html',
    'ui/style.css',
    'ui/app.js',
    'ui/icon.svg',
}