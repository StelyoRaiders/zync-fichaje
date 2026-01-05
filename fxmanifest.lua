--[[
    ╔═══════════════════════════════════════════════════════════════════════════╗
    ║                           ZYNC FICHAJE                                     ║
    ║                    Sistema de Fichaje para FiveM                          ║
    ║                         https://zyncbot.net                               ║
    ╚═══════════════════════════════════════════════════════════════════════════╝
    
    Versión: 1.0.0
    Autor: Zync Team
    Licencia: MIT
    
    Este recurso permite a los jugadores fichar entrada/salida desde FiveM,
    sincronizándose con el bot de Discord Zync.
]]

fx_version 'cerulean'
game 'gta5'

author 'Zync Team'
description 'Sistema de fichaje para FiveM integrado con Zync Bot'
version '1.0.0'
repository 'https://github.com/zyncbot/zync-fichaje-fivem'

-- Archivos de configuración
shared_scripts {
    'config.lua',
    'shared/*.lua'
}

-- Scripts del servidor
server_scripts {
    'server/framework.lua',
    'server/api.lua',
    'server/main.lua',
    'server/tablet.lua'
}

-- Scripts del cliente
client_scripts {
    'client/framework.lua',
    'client/nui.lua',
    'client/main.lua',
    'client/markers.lua',
    'client/tablet.lua'
}

-- Interfaz NUI (múltiples páginas)
ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/tablet/index.html',
    'html/tablet/style.css',
    'html/tablet/script.js',
    'html/fonts/*.ttf',
    'html/fonts/*.woff',
    'html/fonts/*.woff2'
}

-- Dependencias opcionales (se detectan automáticamente)
dependencies {
    '/server:5181',  -- Requiere FiveM server build 5181+
}

-- Exportaciones
exports {
    'GetPlayerShiftStatus',
    'IsPlayerClockedIn',
    'GetPlayerTotalTime'
}

server_exports {
    'ClockIn',
    'ClockOut',
    'GetPlayerStatus',
    'IsLinked'
}

lua54 'yes'
