fx_version 'cerulean'
game 'gta5'

name 'sergeis-warehouse'
author 'sergeis + samrobinson'
description 'Player-owned warehouses with instanced interiors and purchasable storage slots (QBCore)'
lua54 'yes'

ui_page 'ui/index.html'

files {
    'ui/index.html',
    'ui/script.js',
    'ui/style.css'
}

shared_scripts {
    '@qb-core/shared/locale.lua',
    'config.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

-- NUI callbacks
lua54 'yes'

dependencies {
    'qb-core',
    'oxmysql',
}

provides {
    'sergeis-warehouse'
}

