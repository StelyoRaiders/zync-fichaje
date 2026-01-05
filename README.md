# 🕐 Zync Fichaje - FiveM Script

Sistema de fichajes para FiveM integrado con **ZyncBot** Discord. Permite a los empleados registrar sus horas de trabajo desde dentro del juego y gestionar fichajes desde una tablet in-game.

## ✨ Características

- 🎮 **Compatible con ESX y QBCore**: Detección automática de framework
- 📍 **Puntos de fichaje físicos**: Markers interactivos en ubicaciones configurables
- 💬 **Comandos de texto**: `/fichar`, `/salir`, `/tiempo`
- 📱 **Tablet de Gestión**: Panel in-game para supervisores con control total
- 🏢 **Multi-negocio**: Soporte para múltiples negocios con diferentes API keys
- 🎨 **UI Moderna**: Interfaces NUI elegantes y responsive
- 📊 **Sincronización en tiempo real**: Los datos se sincronizan con el bot de Discord
- 👤 **Identificación de personaje**: Muestra el nombre del personaje en los registros

## 📦 Instalación

### 1. Descarga el script

Copia la carpeta `zync-fichaje` a tu directorio `resources`.

### 2. Añade al server.cfg

```cfg
ensure zync-fichaje
```

### 3. Configura el script

Edita `config.lua` con los datos de tu servidor:

```lua
Config.Businesses = {
    ["mi_negocio"] = {
        name = "Mi Negocio",
        apiKey = "TU_API_KEY_AQUI",  -- Genera esto desde el Panel Web de ZyncBot
        jobs = {"policia", "mecanico"},  -- Jobs que pueden fichar
        allowCommands = true,
        allowClockPoints = true,
        clockPoints = {
            {
                name = "Entrada Principal",
                coords = vector3(0.0, 0.0, 0.0),
                radius = 2.0,
                marker = { enabled = true, ... },
                blip = { enabled = true, ... }
            }
        },
        -- Tablet de Gestión (opcional)
        tablet = {
            enabled = true,
            allowedJobs = {
                ["police"] = { ranks = {"boss", "supervisor"} },
                ["ambulance"] = { ranks = nil }  -- nil = todos los rangos
            },
            command = { enabled = true, name = "tablet" },
            keybind = { enabled = true, key = "F6" }
        }
    }
}
```

## 🎮 Uso

### Comandos para Empleados

| Comando | Descripción |
|---------|-------------|
| `/fichar` | Registra entrada (fichar) |
| `/salir`  | Registra salida (desfichar) |
| `/tiempo` | Ver tiempo actual trabajando |

### Puntos de Fichaje

1. Acércate a un punto de fichaje (marker)
2. Presiona **E** para abrir la interfaz
3. Usa los botones para fichar entrada/salida
4. Tu nombre de personaje se registrará automáticamente

### Tablet de Gestión

La tablet permite a supervisores y administradores:
- 👀 Ver todos los empleados fichados en tiempo real
- ⏱️ Ver tiempos acumulados por categoría
- 🚪 Forzar salidas de empleados
- 📊 Ver historial de fichajes
- 🏷️ Filtrar por categorías

**Abrir tablet:**
- Comando: `/tablet` (configurable)
- Tecla: F6 (configurable)

## ⚙️ Configuración Avanzada

### Tecla de Interacción

```lua
Config.InteractionKey = 38  -- E por defecto
Config.InteractionKeyLabel = "E"
```

### Markers

```lua
marker = {
    enabled = true,
    type = 1,
    scale = { x = 1.0, y = 1.0, z = 0.5 },
    color = { r = 124, g = 58, b = 237, a = 150 },
    bobUpAndDown = false,
    rotate = true
}
```

### Blips

```lua
blip = {
    enabled = true,
    sprite = 351,
    color = 49,
    scale = 0.8,
    label = "Punto de Fichaje"
}
```

### Configuración de Tablet

```lua
tablet = {
    enabled = true,
    allowedJobs = {
        ["police"] = {
            ranks = {"boss", "supervisor"}  -- Solo estos rangos
        },
        ["ambulance"] = {
            ranks = nil  -- nil = cualquier rango del job
        }
    },
    command = {
        enabled = true,
        name = "tablet"  -- Comando para abrir
    },
    keybind = {
        enabled = true,
        key = "F6",  -- Tecla para abrir
        description = "Abrir Tablet de Gestión"
    },
    animation = true  -- Mostrar animación con prop de tablet
}
```

### Múltiples Negocios

```lua
Config.Businesses = {
    ["policia"] = {
        name = "Policía",
        apiKey = "zync_fv_POLICIA",
        jobs = {"police", "sheriff"},
        -- ...
    },
    ["ems"] = {
        name = "EMS",
        apiKey = "zync_fv_EMS",
        jobs = {"ambulance", "doctor"},
        -- ...
    }
}
```

## 🔑 Obtener API Key

1. Accede al Panel Web de ZyncBot
2. Selecciona tu servidor
3. Ve a la sección **Integración FiveM**
4. Genera una API Key
5. Copia la API key a tu `config.lua`

## 🛠️ API para Desarrolladores

### Exports

```lua
-- Fichar entrada
exports['zync-fichaje']:ClockIn(businessId)

-- Fichar salida
exports['zync-fichaje']:ClockOut(businessId)

-- Obtener estado
exports['zync-fichaje']:GetStatus(businessId)

-- Verificar si está fichado
exports['zync-fichaje']:IsClockedIn()
```

### Eventos (Server)

```lua
-- Escuchar fichaje entrada
AddEventHandler('zync:server:playerClockedIn', function(source, businessId, discordId)
    print(("Jugador %d fichó entrada en %s"):format(source, businessId))
end)

-- Escuchar fichaje salida
AddEventHandler('zync:server:playerClockedOut', function(source, businessId, discordId, duration)
    print(("Jugador %d fichó salida en %s (duración: %d segundos)"):format(source, businessId, duration))
end)
```

## 📋 Requisitos

- FiveM Server actualizado
- Framework ESX o QBCore
- ZyncBot configurado en Discord
- API Key generada desde el Panel Web

## 🐛 Solución de Problemas

### El script no detecta mi framework

Asegúrate de que tu framework (es_extended o qb-core) esté iniciado antes que `zync-fichaje` en server.cfg.

### No puedo conectar con la API

1. Verifica que la API key sea correcta
2. Comprueba que el bot de Discord esté online
3. Revisa los logs del servidor con `Config.Debug = true`

### Los markers no aparecen

Verifica las coordenadas en `config.lua` y que `marker.enabled = true`.

### La tablet no se abre

1. Verifica que tienes el job y rango correcto
2. Comprueba la configuración de `tablet.allowedJobs`
3. Asegúrate de que `tablet.enabled = true`

### Error al fichar

1. Verifica que tu API key es válida
2. Comprueba que el bot de ZyncBot esté online
3. Revisa que tu job esté en la lista de `jobs` permitidos

## 📄 Licencia

Este script es parte de ZyncBot Premium. Requiere una suscripción activa y API Key válida.

## 🤝 Soporte

- Discord: [Servidor de soporte de ZyncBot]
- Panel Web: https://zyncbot.net

- Discord: [Servidor de Soporte](https://discord.gg/HkyASK3Sg3)
- Documentación: [docs.zyncbot.net](https://docs.zyncbot.net)

---

Hecho con ❤️ por el equipo de Zync
