--[[
    ╔═══════════════════════════════════════════════════════════════════════════╗
    ║                        CONFIGURACIÓN DE ZYNC FICHAJE                       ║
    ╚═══════════════════════════════════════════════════════════════════════════╝
    
    Este archivo contiene toda la configuración del script.
    Modifícalo según las necesidades de tu servidor.
]]

Config = {}

-- ═══════════════════════════════════════════════════════════════════════════════
-- CONFIGURACIÓN GLOBAL
-- ═══════════════════════════════════════════════════════════════════════════════

Config.Debug = false                     -- Mostrar mensajes de debug en consola
Config.Locale = "es"                     -- Idioma (es, en)

-- ═══════════════════════════════════════════════════════════════════════════════
-- PERSONALIZACIÓN DE LA NUI
-- ═══════════════════════════════════════════════════════════════════════════════
Config.NUI = {
    -- Logo personalizado (URL a imagen PNG/JPG)
    -- Deja vacío "" para usar el logo por defecto de Zync
    logoUrl = "",                        -- Ejemplo: "https://tuservidor.com/logo.png"
    
    -- Texto junto al logo
    logoText = "ZYNC",                   -- Cambia por el nombre de tu servidor
}

-- ═══════════════════════════════════════════════════════════════════════════════
-- DETECCIÓN DE FRAMEWORK
-- ═══════════════════════════════════════════════════════════════════════════════
-- "auto"       → Detecta automáticamente ESX, QBCore, vRP, etc.
-- "esx"        → Forzar ESX (es_extended)
-- "qbcore"     → Forzar QBCore (qb-core)
-- "vrp"        → Forzar vRP
-- "standalone" → Sin framework (usa identificadores directos de Steam/License)
Config.Framework = "auto"

-- ═══════════════════════════════════════════════════════════════════════════════
-- IDENTIFICADOR PREFERIDO
-- ═══════════════════════════════════════════════════════════════════════════════
-- Qué identificador usar para vincular cuentas:
-- "discord"  → Discord ID (RECOMENDADO - auto-vincula sin paso manual)
-- "steam"    → Steam HEX (requiere vinculación manual)
-- "license"  → Rockstar License (requiere vinculación manual)
-- "fivem"    → FiveM License (requiere vinculación manual)
-- ⚠️ Si usas "discord", los jugadores deben tener Discord vinculado en FiveM
Config.PreferredIdentifier = "discord"

-- ═══════════════════════════════════════════════════════════════════════════════
-- MODO DE FICHAJE GLOBAL
-- ═══════════════════════════════════════════════════════════════════════════════
-- Puede sobrescribirse por negocio individual
-- "command"  → Solo comandos (/fichar, /salir, /tiempo)
-- "point"    → Solo puntos de fichaje físicos
-- "both"     → Ambos métodos disponibles
Config.DefaultMode = "both"

-- ═══════════════════════════════════════════════════════════════════════════════
-- COMANDOS
-- ═══════════════════════════════════════════════════════════════════════════════
Config.Commands = {
    enabled = true,
    clockIn = "fichar",         -- /fichar [negocio]
    clockOut = "salir",         -- /salir
    checkTime = "tiempo",       -- /tiempo [negocio]
    -- DEPRECATED: Vinculación manual ya no necesaria (auto-link por Discord ID)
    -- link = "zvincular",      -- /zvincular <codigo>
    -- status = "zestado",      -- /zestado
}

-- ═══════════════════════════════════════════════════════════════════════════════
-- TECLA DE INTERACCIÓN (para puntos de fichaje)
-- ═══════════════════════════════════════════════════════════════════════════════
-- 38 = E | 47 = G | 51 = E (en teclado numérico)
-- Ver: https://docs.fivem.net/docs/game-references/controls/
Config.InteractionKey = 38          -- Tecla E
Config.InteractionKeyLabel = "E"    -- Texto a mostrar

-- ═══════════════════════════════════════════════════════════════════════════════
-- ⭐ NEGOCIOS CONFIGURADOS
-- ═══════════════════════════════════════════════════════════════════════════════
-- Cada negocio representa un servidor de Discord diferente con Zync Bot.
-- Un servidor de FiveM puede tener MÚLTIPLES negocios.

Config.Businesses = {

    -- ════════════════════════════════════════════════════════════════════════
    -- EJEMPLO: POLICÍA LSPD
    -- ════════════════════════════════════════════════════════════════════════
    ["lspd"] = {
        -- Información básica
        name = "Policía LSPD",
        description = "Departamento de Policía de Los Santos",
        
        -- 🎨 Logo personalizado (opcional - sobrescribe Config.NUI)
        -- logoUrl = "https://tuservidor.com/logo-policia.png",
        -- logoText = "LSPD",
        
        -- ⭐ Conexión con Zync (OBLIGATORIO)
        api = {
            url = "https://api.zyncbot.net",    -- URL de la API de Zync
            key = "zync_fv_XXXXXXXXXXXXXXXXXX", -- Tu API Key (desde /fivem setup en Discord)
        },
        
        -- Modo de fichaje para este negocio
        -- Sobrescribe Config.DefaultMode si se especifica
        mode = "both",  -- "command", "point", "both"
        
        -- Jobs que pertenecen a este negocio
        -- Si el jugador tiene uno de estos jobs, puede fichar en este negocio
        -- ⚠️ IMPORTANTE: El nombre del job debe coincidir EXACTAMENTE con el job de tu servidor
        -- Ejemplo: si tu job es "lspd", usa ["lspd"]. Si es "police", usa ["police"]
        jobs = {
            ["lspd"] = {
                category = "Patrulla",    -- Categoría de Zync donde fichará
                ranks = nil,               -- nil = todos los rangos permitidos
                -- ranks = {"officer", "sergeant", "lieutenant"},  -- Solo ciertos rangos
            },
            ["police"] = {
                category = "Patrulla",    -- Alias para servidores que usen "police"
                ranks = nil,
            },
            ["sheriff"] = {
                category = "Patrulla",
                ranks = nil,
            },
        },
        
        -- Puntos de fichaje físicos (marcadores en el mapa)
        clockPoints = {
            {
                name = "Comisaría Central",
                category = "Patrulla",              -- Categoría al fichar desde este punto
                coords = vector3(441.8, -982.0, 30.7),
                radius = 2.0,                       -- Radio de interacción
                marker = {
                    enabled = true,
                    type = 1,                       -- Tipo de marker (1 = cilindro)
                    color = {r = 0, g = 100, b = 255, a = 150},
                    scale = vector3(1.0, 1.0, 0.5),
                    bobUpAndDown = false,
                    rotate = false,
                },
                blip = {
                    enabled = true,
                    sprite = 60,
                    color = 3,
                    scale = 0.8,
                    label = "Fichaje LSPD"
                }
            },
            -- Puedes añadir más puntos de fichaje aquí
        },
        
        -- UI personalizada (opcional)
        ui = {
            theme = "dark",              -- "dark" o "light"
            accentColor = "#3B82F6",     -- Color de acento (hex)
            logo = "",                    -- URL del logo (vacío = logo de Zync)
        },
        
        -- 📱 Tablet de gestión (opcional)
        -- Permite a usuarios autorizados ver fichajes en tiempo real desde FiveM
        tablet = {
            enabled = true,              -- Activar/desactivar tablet para este negocio
            key = 56,                    -- Tecla para abrir (56 = F9)
            keyLabel = "F9",             -- Texto a mostrar
            animation = true,            -- Animación de sacar tablet
            
            -- Comando alternativo (opcional)
            command = {
                enabled = true,          -- Activar/desactivar comando
                name = "tablet",         -- Nombre del comando (/tablet)
            },
            
            -- Quién puede usar la tablet (por job y rango)
            -- Si un job no está listado aquí, no podrá usar la tablet
            allowedJobs = {
                ["lspd"] = {
                    ranks = nil,         -- nil = todos los rangos de este job
                    -- ranks = {"boss", "supervisor", "lieutenant"}, -- Solo ciertos rangos
                },
                ["police"] = {
                    ranks = nil,
                },
            },
        },
    },

    -- ════════════════════════════════════════════════════════════════════════
    -- EJEMPLO: HOSPITAL / EMS
    -- ════════════════════════════════════════════════════════════════════════
    ["ems"] = {
        name = "Hospital Pillbox",
        description = "Servicios Médicos de Emergencia",
        
        api = {
            url = "https://api.zyncbot.net",
            key = "zync_fv_YYYYYYYYYYYYYYYY",  -- API Key diferente (otro Discord)
        },
        
        mode = "both",
        
        jobs = {
            ["ambulance"] = {
                category = "EMS",
                ranks = nil,
            },
            ["doctor"] = {
                category = "Médico",
                ranks = nil,
            },
        },
        
        clockPoints = {
            {
                name = "Recepción Hospital",
                category = "EMS",
                coords = vector3(311.2, -590.1, 43.3),
                radius = 2.5,
                marker = {
                    enabled = true,
                    type = 1,
                    color = {r = 255, g = 50, b = 50, a = 150},
                    scale = vector3(1.2, 1.2, 0.5),
                },
                blip = {
                    enabled = true,
                    sprite = 61,
                    color = 1,
                    scale = 0.8,
                    label = "Fichaje EMS"
                }
            },
        },
        
        ui = {
            theme = "dark",
            accentColor = "#EF4444",
            logo = "",
        },
    },

    -- ════════════════════════════════════════════════════════════════════════
    -- EJEMPLO: TALLER MECÁNICO (solo punto de fichaje, sin comandos)
    -- ════════════════════════════════════════════════════════════════════════
    ["bennys"] = {
        name = "Taller Benny's",
        description = "Taller de customización",
        
        api = {
            url = "https://api.zyncbot.net",
            key = "zync_fv_ZZZZZZZZZZZZZZZZ",
        },
        
        mode = "point",  -- SOLO punto de fichaje, no comandos
        
        jobs = {
            ["mechanic"] = {
                category = "Mecánico",
                ranks = nil,
            },
        },
        
        clockPoints = {
            {
                name = "Taller Principal",
                category = "Mecánico",
                coords = vector3(-211.0, -1324.0, 31.0),
                radius = 3.0,
                marker = {
                    enabled = true,
                    type = 1,
                    color = {r = 255, g = 165, b = 0, a = 150},
                    scale = vector3(1.5, 1.5, 0.5),
                },
                blip = {
                    enabled = true,
                    sprite = 446,
                    color = 47,
                    scale = 0.8,
                    label = "Fichaje Taller"
                }
            },
        },
        
        ui = {
            theme = "dark",
            accentColor = "#F59E0B",
            logo = "",
        },
    },

    -- ════════════════════════════════════════════════════════════════════════
    -- EJEMPLO: TAXI (solo comandos, sin puntos físicos)
    -- ════════════════════════════════════════════════════════════════════════
    ["taxi"] = {
        name = "Taxi Downtown",
        description = "Servicio de taxi",
        
        api = {
            url = "https://api.zyncbot.net",
            key = "zync_fv_WWWWWWWWWWWWWWWW",
        },
        
        mode = "command",  -- SOLO comandos, sin puntos físicos
        
        jobs = {
            ["taxi"] = {
                category = "Conductor",
                ranks = nil,
            },
        },
        
        clockPoints = {},  -- Sin puntos de fichaje
        
        ui = {
            theme = "light",
            accentColor = "#FBBF24",
            logo = "",
        },
    },

    -- ════════════════════════════════════════════════════════════════════════
    -- Añade más negocios aquí siguiendo el mismo formato...
    -- ════════════════════════════════════════════════════════════════════════
}

-- ═══════════════════════════════════════════════════════════════════════════════
-- MENSAJES
-- ═══════════════════════════════════════════════════════════════════════════════
Config.Messages = {
    -- Fichaje
    clockInSuccess = "✅ Has fichado en %s (%s)",           -- negocio, categoría
    clockOutSuccess = "✅ Has salido de %s. Tiempo: %s",    -- negocio, tiempo
    alreadyClockedIn = "⚠️ Ya estás fichando en %s",
    notClockedIn = "⚠️ No tienes fichaje activo",
    autoClockOut = "⚠️ Fichaje finalizado automáticamente por cambio de trabajo",
    autoClockOutTime = "⏱️ Tiempo registrado: %s",
    
    -- Errores
    noPermission = "❌ No tienes acceso a este punto de fichaje",
    jobNotAllowed = "❌ Tu trabajo no pertenece a ningún negocio configurado",
    notLinked = "❌ No tienes Discord conectado a FiveM. Conecta Discord en Ajustes de FiveM",
    noDiscord = "❌ Debes tener Discord vinculado en FiveM para fichar",
    apiError = "❌ Error de conexión. Inténtalo de nuevo",
    
    -- Vinculación
    linkSuccess = "✅ Cuenta vinculada correctamente a %s",
    linkFailed = "❌ Código inválido o expirado",
    alreadyLinked = "ℹ️ Ya estás vinculado a este servidor",
    
    -- Información
    timeWorked = "⏱️ Tiempo en %s: %s",
    pressToInteract = "[%s] Fichaje - %s",                  -- tecla, nombre negocio
    
    -- Comandos
    specifyBusiness = "⚠️ Especifica el negocio: /%s [nombre]",
    businessNotFound = "❌ Negocio '%s' no encontrado",
    availableBusinesses = "📋 Negocios disponibles: %s",
    
    -- Vinculación
    linkUsage = "Uso: /%s <código>",
    linkCodeInvalid = "❌ El código debe tener el formato ZYNC-XXXXXX",
    
    -- NUI (Interfaz de punto de fichaje)
    nuiTitle = "Fichaje",
    nuiClockIn = "Fichar Entrada",
    nuiClockOut = "Fichar Salida",
    nuiStatus = "ESTADO",
    nuiLinked = "Cuenta vinculada",
    nuiNotLinked = "Cuenta no vinculada",
    nuiLinkAccount = "Vincular cuenta",
    nuiEnterCode = "Introduce tu código",
    nuiClose = "Cerrar",
    nuiWorking = "Trabajando",
    nuiNotWorking = "Sin fichar",
    nuiSuccess = "¡Operación completada!",
    nuiError = "Error en la operación",
    nuiConnecting = "Conectando...",
    
    -- Tablet de gestión
    tabletTitle = "Panel de Gestión",
    tabletActiveNow = "Fichando ahora",
    tabletRecentShifts = "Fichajes recientes",
    tabletAllShifts = "Todos los fichajes",
    tabletForceClockOut = "Forzar salida",
    tabletNoActiveShifts = "Nadie está fichando en esta categoría",
    tabletNoPermission = "No tienes permiso para usar la tablet",
    tabletClose = "Cerrar",
    tabletUser = "Usuario",
    tabletCategory = "Categoría",
    tabletTime = "Tiempo",
    tabletStatus = "Estado",
    tabletTotalTime = "Tiempo total",
    tabletActive = "Activo",
    tabletInactive = "Inactivo",
    tabletConfirmForceOut = "¿Estás seguro de que quieres forzar la salida de este usuario?",
    tabletForceOutSuccess = "Salida forzada correctamente",
    tabletForceOutError = "Error al forzar salida",
    forcedClockOut = "⚠️ Tu fichaje ha sido cerrado por un supervisor",
}

-- ═══════════════════════════════════════════════════════════════════════════════
-- NOTIFICACIONES
-- ═══════════════════════════════════════════════════════════════════════════════
-- Sistema de notificaciones a usar:
-- "auto"     → Detecta automáticamente el framework y usa sus notificaciones (RECOMENDADO)
-- "esx"      → ESX.ShowNotification (si usas ESX)
-- "qbcore"   → QBCore.Functions.Notify (si usas QBCore)
-- "ox_lib"   → ox_lib notifications (si usas ox_lib)
-- "okokNotify" → okokNotify (si usas okokNotify)
-- "native"   → Notificaciones nativas de GTA V (arriba izquierda)
-- "chat"     → Mensajes en el chat
-- "custom"   → Función personalizada (define Config.CustomNotify)
Config.NotificationSystem = "auto"

-- Si usas "custom", define esta función:
-- Config.CustomNotify = function(message, type)
--     -- type puede ser: "success", "error", "info", "warning"
--     -- Implementa tu lógica aquí
--     -- Ejemplo con ox_lib:
--     -- exports['ox_lib']:notify({ title = 'Zync', description = message, type = type })
-- end

-- ═══════════════════════════════════════════════════════════════════════════════
-- UI POR DEFECTO
-- ═══════════════════════════════════════════════════════════════════════════════
Config.DefaultUI = {
    theme = "dark",
    accentColor = "#5865F2",    -- Azul Discord
    logo = "",                   -- Logo de Zync por defecto
}
