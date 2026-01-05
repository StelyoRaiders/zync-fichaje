--[[
    ╔═══════════════════════════════════════════════════════════════════════════╗
    ║                       SERVIDOR PRINCIPAL                                   ║
    ╚═══════════════════════════════════════════════════════════════════════════╝
    
    Lógica principal del servidor: comandos, eventos y exportaciones.
]]

-- Estado de fichaje por jugador (global para acceso desde tablet.lua)
PlayerShiftStatus = {}

-- ═══════════════════════════════════════════════════════════════════════════════
-- INICIALIZACIÓN
-- ═══════════════════════════════════════════════════════════════════════════════

CreateThread(function()
    -- Esperar a que el framework esté listo
    while not ZyncFramework.Ready do
        Wait(100)
    end
    
    ZyncPrint("═══════════════════════════════════════════════════")
    ZyncPrint("          ZYNC FICHAJE - SERVIDOR INICIADO")
    ZyncPrint("═══════════════════════════════════════════════════")
    
    -- Validar configuración de negocios
    local businessCount = 0
    for businessId, business in pairs(Config.Businesses) do
        businessCount = businessCount + 1
        
        if not business.api or not business.api.key then
            ZyncError("Negocio '" .. businessId .. "' no tiene API key configurada")
        elseif string.find(business.api.key, "XXXX") then
            ZyncPrint("⚠️ Negocio '" .. businessId .. "' tiene API key de ejemplo. Configúrala correctamente.")
        else
            -- Validar API key
            ZyncAPI.ValidateKey(businessId, function(valid, response)
                if valid then
                    ZyncPrint("✅ Negocio '" .. businessId .. "' conectado correctamente")
                    if response.guildName then
                        ZyncPrint("   → Discord: " .. response.guildName)
                    end
                else
                    local errorMsg = response and response.error or "unknown"
                    local statusCode = response and response.statusCode or "N/A"
                    ZyncError("❌ API key inválida para negocio: " .. businessId .. " (error: " .. tostring(errorMsg) .. ", status: " .. tostring(statusCode) .. ")")
                end
            end)
        end
    end
    
    ZyncPrint("Negocios configurados: " .. businessCount)
    ZyncPrint("═══════════════════════════════════════════════════")
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- COMANDOS
-- ═══════════════════════════════════════════════════════════════════════════════

-- /fichar [negocio]
if Config.Commands.enabled then
    RegisterCommand(Config.Commands.clockIn, function(source, args, rawCommand)
        local player = source
        if player <= 0 then return end
        
        local job = ZyncFramework.GetPlayerJob(player)
        local identifier = ZyncFramework.GetPlayerIdentifier(player)
        
        if not identifier then
            ZyncFramework.Notify(player, GetMessage("apiError"), "error")
            return
        end
        
        -- Obtener negocios disponibles
        local available = {}
        if job then
            available = GetAvailableBusinessesForJob(job.name, job.gradeName or job.grade)
        else
            -- Standalone: todos los negocios sin restricción de job
            for id, business in pairs(Config.Businesses) do
                if CanUseCommands(id) then
                    table.insert(available, {
                        id = id,
                        name = business.name,
                        category = "General"
                    })
                end
            end
        end
        
        -- Filtrar solo los que permiten comandos
        local commandAvailable = {}
        for _, biz in ipairs(available) do
            if CanUseCommands(biz.id) then
                table.insert(commandAvailable, biz)
            end
        end
        
        if #commandAvailable == 0 then
            ZyncFramework.Notify(player, GetMessage("jobNotAllowed"), "error")
            return
        end
        
        local targetBusiness = nil
        
        if #commandAvailable == 1 then
            -- Solo un negocio disponible, usar ese
            targetBusiness = commandAvailable[1]
        elseif args[1] then
            -- Buscar por nombre/id
            local searchTerm = string.lower(args[1])
            for _, biz in ipairs(commandAvailable) do
                if string.lower(biz.id) == searchTerm or string.find(string.lower(biz.name), searchTerm) then
                    targetBusiness = biz
                    break
                end
            end
            
            if not targetBusiness then
                ZyncFramework.Notify(player, GetMessage("businessNotFound", args[1]), "error")
                return
            end
        else
            -- Múltiples negocios, mostrar lista
            local names = {}
            for _, biz in ipairs(commandAvailable) do
                table.insert(names, biz.id)
            end
            ZyncFramework.Notify(player, GetMessage("specifyBusiness", Config.Commands.clockIn), "info")
            ZyncFramework.Notify(player, GetMessage("availableBusinesses", table.concat(names, ", ")), "info")
            return
        end
        
        -- Obtener info del personaje para guardar
        local charName = ZyncFramework.GetPlayerName(player)
        local jobInfo = ZyncFramework.GetPlayerJob(player)
        local charRank = jobInfo and jobInfo.gradeName or nil
        
        -- Realizar fichaje
        ZyncAPI.ClockIn(targetBusiness.id, identifier, targetBusiness.category, function(success, response)
            if success then
                local businessName = GetBusiness(targetBusiness.id).name
                ZyncFramework.Notify(player, GetMessage("clockInSuccess", businessName, targetBusiness.category), "success")
                
                -- Guardar estado local
                PlayerShiftStatus[player] = {
                    businessId = targetBusiness.id,
                    category = targetBusiness.category,
                    startTime = os.time()
                }
                
                -- Notificar al cliente
                TriggerClientEvent('zync:shiftStarted', player, targetBusiness.id, targetBusiness.category, response)
            else
                if response and response.error == "already_clocked_in" then
                    ZyncFramework.Notify(player, GetMessage("alreadyClockedIn", targetBusiness.category), "warning")
                elseif response and response.error == "not_linked" then
                    ZyncFramework.Notify(player, GetMessage("notLinked"), "error")
                else
                    ZyncFramework.Notify(player, GetMessage("apiError"), "error")
                end
            end
        end, charName, charRank)
    end, false)
    
    -- /salir
    RegisterCommand(Config.Commands.clockOut, function(source, args, rawCommand)
        local player = source
        if player <= 0 then return end
        
        local identifier = ZyncFramework.GetPlayerIdentifier(player)
        
        if not identifier then
            ZyncFramework.Notify(player, GetMessage("apiError"), "error")
            return
        end
        
        -- Verificar si tiene fichaje activo local
        local currentShift = PlayerShiftStatus[player]
        
        if currentShift then
            -- Salir del fichaje conocido
            ZyncAPI.ClockOut(currentShift.businessId, identifier, currentShift.category, function(success, response)
                if success then
                    local businessName = GetBusiness(currentShift.businessId).name
                    local timeWorked = response.sessionFormatted or FormatTime(response.sessionSeconds or 0)
                    ZyncFramework.Notify(player, GetMessage("clockOutSuccess", businessName, timeWorked), "success")
                    
                    PlayerShiftStatus[player] = nil
                    TriggerClientEvent('zync:shiftEnded', player, currentShift.businessId, response)
                else
                    if response and response.error == "not_clocked_in" then
                        ZyncFramework.Notify(player, GetMessage("notClockedIn"), "warning")
                        PlayerShiftStatus[player] = nil  -- Limpiar estado local desincronizado
                    else
                        ZyncFramework.Notify(player, GetMessage("apiError"), "error")
                    end
                end
            end)
        else
            -- Intentar salir de cualquier fichaje activo
            -- Probar con cada negocio donde el jugador tenga acceso
            local job = ZyncFramework.GetPlayerJob(player)
            local available = {}
            
            if job then
                available = GetAvailableBusinessesForJob(job.name, job.gradeName or job.grade)
            else
                for id, _ in pairs(Config.Businesses) do
                    table.insert(available, {id = id})
                end
            end
            
            local found = false
            for _, biz in ipairs(available) do
                ZyncAPI.ClockOut(biz.id, identifier, nil, function(success, response)
                    if success and not found then
                        found = true
                        local businessName = GetBusiness(biz.id).name
                        local timeWorked = response.sessionFormatted or FormatTime(response.sessionSeconds or 0)
                        ZyncFramework.Notify(player, GetMessage("clockOutSuccess", businessName, timeWorked), "success")
                        
                        PlayerShiftStatus[player] = nil
                        TriggerClientEvent('zync:shiftEnded', player, biz.id, response)
                    end
                end)
            end
            
            -- Si no encuentra ninguno después de un momento
            SetTimeout(2000, function()
                if not found then
                    ZyncFramework.Notify(player, GetMessage("notClockedIn"), "warning")
                end
            end)
        end
    end, false)
    
    -- /tiempo [negocio]
    RegisterCommand(Config.Commands.checkTime, function(source, args, rawCommand)
        local player = source
        if player <= 0 then return end
        
        local identifier = ZyncFramework.GetPlayerIdentifier(player)
        
        if not identifier then
            ZyncFramework.Notify(player, GetMessage("apiError"), "error")
            return
        end
        
        local job = ZyncFramework.GetPlayerJob(player)
        local available = {}
        
        if job then
            available = GetAvailableBusinessesForJob(job.name, job.gradeName or job.grade)
        else
            for id, business in pairs(Config.Businesses) do
                table.insert(available, {id = id, name = business.name})
            end
        end
        
        if #available == 0 then
            ZyncFramework.Notify(player, GetMessage("jobNotAllowed"), "error")
            return
        end
        
        local targetBusiness = nil
        
        if args[1] then
            local searchTerm = string.lower(args[1])
            for _, biz in ipairs(available) do
                if string.lower(biz.id) == searchTerm then
                    targetBusiness = biz
                    break
                end
            end
        else
            targetBusiness = available[1]
        end
        
        if not targetBusiness then
            ZyncFramework.Notify(player, GetMessage("businessNotFound", args[1] or ""), "error")
            return
        end
        
        ZyncAPI.GetStatus(targetBusiness.id, identifier, function(success, response)
            if success then
                if response.linked then
                    local businessName = GetBusiness(targetBusiness.id).name
                    
                    if response.currentShift and response.currentShift.active then
                        local sessionTime = FormatTime(response.currentShift.currentSessionSeconds or 0)
                        ZyncFramework.Notify(player, "🟢 Fichando en " .. response.currentShift.category .. " - Sesión: " .. sessionTime, "info")
                    else
                        ZyncFramework.Notify(player, "⚫ No estás fichando actualmente", "info")
                    end
                    
                    local totalTime = FormatTime(response.stats.totalAllTimeSeconds or 0)
                    ZyncFramework.Notify(player, GetMessage("timeWorked", businessName, totalTime), "info")
                else
                    ZyncFramework.Notify(player, GetMessage("notLinked"), "error")
                end
            else
                ZyncFramework.Notify(player, GetMessage("apiError"), "error")
            end
        end)
    end, false)
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- EVENTOS DEL CLIENTE
-- ═══════════════════════════════════════════════════════════════════════════════

-- Solicitar datos para NUI (punto de fichaje)
RegisterNetEvent('zync:server:requestUIData')
AddEventHandler('zync:server:requestUIData', function(businessId, pointCategory)
    local player = source
    local category = pointCategory or "General"
    
    ZyncDebug("requestUIData: player=" .. tostring(player) .. ", businessId=" .. tostring(businessId) .. ", category=" .. tostring(category))
    
    if not player or player <= 0 then
        ZyncError("requestUIData: Source inválido")
        return
    end
    
    local identifier = ZyncFramework.GetPlayerIdentifier(player)
    
    ZyncDebug("requestUIData: identifier=" .. tostring(identifier))
    
    if not identifier then
        TriggerClientEvent('zync:client:receiveUIData', player, {
            isClockedIn = false,
            currentTime = 0,
            isLinked = false,
            discordName = "",
            discordAvatar = "",
            needsLink = true,
            totalTime = 0,
            error = "no_identifier"
        })
        return
    end
    
    -- Obtener estado del servidor (enviar categoría para obtener tiempo específico)
    ZyncAPI.GetStatus(businessId, identifier, category, function(success, response)
        local data = {
            isClockedIn = false,
            currentTime = 0,
            isLinked = false,
            discordName = "",
            discordAvatar = "",
            needsLink = true,
            totalTime = 0
        }
        
        if success and response then
            data.isLinked = response.linked or false
            data.discordName = response.discordName or response.discordUsername or response.username or ""
            data.discordAvatar = response.discordAvatar or ""
            data.needsLink = not data.isLinked
            
            if response.currentShift and response.currentShift.active then
                data.isClockedIn = true
                data.currentTime = response.currentShift.currentSessionSeconds or 0
                -- Tiempo total en la categoría activa
                data.totalTime = response.currentShift.categoryTotalSeconds or 0
            else
                -- Si no está fichado, usar tiempo de la categoría del punto de fichaje
                if response.categoryStats then
                    data.totalTime = response.categoryStats.totalSeconds or 0
                elseif response.stats then
                    data.totalTime = response.stats.totalAllTimeSeconds or 0
                end
            end
        end
        
        TriggerClientEvent('zync:client:receiveUIData', player, data)
    end)
end)

-- Vincular cuenta desde NUI
RegisterNetEvent('zync:server:linkAccountWithCode')
AddEventHandler('zync:server:linkAccountWithCode', function(code, businessId)
    local player = source
    local identifier = ZyncFramework.GetPlayerIdentifier(player)
    local identifierType = ZyncFramework.GetIdentifierType(identifier)
    
    if not identifier then
        TriggerClientEvent('zync:client:linkResult', player, false, "Error al obtener identificador")
        return
    end
    
    ZyncAPI.Link(businessId, code, identifier, identifierType, function(success, response)
        if success then
            ZyncAPI.ClearCache(businessId, identifier)
            local discordName = response.discordName or response.username or ""
            TriggerClientEvent('zync:client:linkResult', player, true, "Cuenta vinculada correctamente")
            -- Refrescar datos de la NUI
            TriggerEvent('zync:server:requestUIData', businessId)
        else
            local errorMsg = "Código inválido o expirado"
            if response and response.error == "already_linked" then
                errorMsg = "Ya estás vinculado a este servidor"
            elseif response and response.error == "code_expired" then
                errorMsg = "El código ha expirado"
            elseif response and response.error == "code_not_found" then
                errorMsg = "Código no encontrado"
            end
            TriggerClientEvent('zync:client:linkResult', player, false, errorMsg)
        end
    end)
end)

-- Solicitar fichaje desde NUI
RegisterNetEvent('zync:server:clockIn')
AddEventHandler('zync:server:clockIn', function(businessId, pointCategory)
    local player = source
    
    ZyncDebug("clockIn NUI: player=" .. tostring(player) .. ", businessId=" .. tostring(businessId) .. ", category=" .. tostring(pointCategory))
    
    if not player or player <= 0 then
        ZyncError("clockIn NUI: Source inválido")
        return
    end
    
    local identifier = ZyncFramework.GetPlayerIdentifier(player)
    
    ZyncDebug("clockIn NUI: identifier=" .. tostring(identifier))
    
    if not identifier then
        ZyncFramework.Notify(player, GetMessage("apiError"), "error")
        TriggerClientEvent('zync:client:receiveUIData', player, {
            isClockedIn = false,
            currentTime = 0,
            isLinked = false,
            discordName = "",
            discordAvatar = "",
            needsLink = true,
            totalTime = 0,
            error = "no_identifier"
        })
        return
    end
    
    -- Usar categoría del punto de fichaje o General
    local category = pointCategory or "General"
    
    -- Obtener info del personaje para guardar
    local charName = ZyncFramework.GetPlayerName(player)
    local jobInfo = ZyncFramework.GetPlayerJob(player)
    local charRank = jobInfo and jobInfo.gradeName or nil
    
    ZyncAPI.ClockIn(businessId, identifier, category, function(success, response)
        if success then
            local businessName = GetBusiness(businessId).name
            ZyncFramework.Notify(player, GetMessage("clockInSuccess", businessName, category), "success")
            
            PlayerShiftStatus[player] = {
                businessId = businessId,
                category = category,
                startTime = os.time()
            }
            
            TriggerClientEvent('zync:shiftStarted', player, businessId, category, response)
            
            -- Actualizar NUI
            TriggerClientEvent('zync:client:receiveUIData', player, {
                isClockedIn = true,
                currentTime = 0,
                isLinked = true,
                discordName = response.discordName or "",
                discordAvatar = response.discordAvatar or "",
                needsLink = false,
                totalTime = response.totalSeconds or 0
            })
        else
            if response and response.error == "not_linked" then
                ZyncFramework.Notify(player, GetMessage("notLinked"), "error")
            elseif response and response.error == "already_clocked_in" then
                ZyncFramework.Notify(player, GetMessage("alreadyClockedIn", category), "warning")
            elseif response and response.error == "invalid_category" then
                local availableCats = response.available_categories or {}
                ZyncFramework.Notify(player, "\226\157\140 La categor\195\173a '" .. category .. "' no existe en Discord", "error")
                if #availableCats > 0 then
                    ZyncFramework.Notify(player, "\240\159\147\139 Categor\195\173as disponibles: " .. table.concat(availableCats, ", "), "info")
                end
            else
                ZyncFramework.Notify(player, GetMessage("apiError"), "error")
            end
        end
    end, charName, charRank)
end)

-- Solicitar salida desde NUI
RegisterNetEvent('zync:server:clockOut')
AddEventHandler('zync:server:clockOut', function(businessId)
    local player = source
    
    ZyncDebug("clockOut NUI: player=" .. tostring(player) .. ", businessId=" .. tostring(businessId))
    
    if not player or player <= 0 then
        ZyncError("clockOut NUI: Source inválido")
        return
    end
    
    local identifier = ZyncFramework.GetPlayerIdentifier(player)
    
    if not identifier then
        ZyncFramework.Notify(player, GetMessage("apiError"), "error")
        return
    end
    
    ZyncAPI.ClockOut(businessId, identifier, nil, function(success, response)
        if success then
            local businessName = GetBusiness(businessId).name
            local timeWorked = response.sessionFormatted or FormatTime(response.sessionSeconds or 0)
            ZyncFramework.Notify(player, GetMessage("clockOutSuccess", businessName, timeWorked), "success")
            
            PlayerShiftStatus[player] = nil
            TriggerClientEvent('zync:shiftEnded', player, businessId, response)
            
            -- Actualizar NUI
            TriggerClientEvent('zync:client:receiveUIData', player, {
                isClockedIn = false,
                currentTime = 0,
                isLinked = true,
                discordName = "",
                discordAvatar = "",
                needsLink = false,
                totalTime = response.totalSeconds or 0
            })
        else
            if response and response.error == "not_clocked_in" then
                ZyncFramework.Notify(player, GetMessage("notClockedIn"), "warning")
            else
                ZyncFramework.Notify(player, GetMessage("apiError"), "error")
            end
        end
    end)
end)

-- Solicitar fichaje desde punto de fichaje (cliente) - LEGACY, usar zync:server:clockIn
RegisterNetEvent('zync:requestClockIn')
AddEventHandler('zync:requestClockIn', function(businessId, category)
    local player = source
    local identifier = ZyncFramework.GetPlayerIdentifier(player)
    
    if not identifier then
        ZyncFramework.Notify(player, GetMessage("apiError"), "error")
        TriggerClientEvent('zync:clockInResult', player, false, {error = "no_identifier"})
        return
    end
    
    -- Nota: La verificación de job se hace en el cliente (markers.lua) antes de abrir la NUI
    
    -- Obtener info del personaje para guardar
    local charName = ZyncFramework.GetPlayerName(player)
    local jobInfo = ZyncFramework.GetPlayerJob(player)
    local charRank = jobInfo and jobInfo.gradeName or nil
    
    ZyncAPI.ClockIn(businessId, identifier, category, function(success, response)
        if success then
            local businessName = GetBusiness(businessId).name
            ZyncFramework.Notify(player, GetMessage("clockInSuccess", businessName, category), "success")
            
            PlayerShiftStatus[player] = {
                businessId = businessId,
                category = category,
                startTime = os.time()
            }
        else
            if response and response.error == "not_linked" then
                ZyncFramework.Notify(player, GetMessage("notLinked"), "error")
            elseif response and response.error == "already_clocked_in" then
                ZyncFramework.Notify(player, GetMessage("alreadyClockedIn", category), "warning")
            elseif response and response.error == "invalid_category" then
                local availableCats = response.available_categories or {}
                ZyncFramework.Notify(player, "\226\157\140 La categor\195\173a '" .. category .. "' no existe en Discord", "error")
                if #availableCats > 0 then
                    ZyncFramework.Notify(player, "\240\159\147\139 Categor\195\173as disponibles: " .. table.concat(availableCats, ", "), "info")
                end
            else
                ZyncFramework.Notify(player, GetMessage("apiError"), "error")
            end
        end
        
        TriggerClientEvent('zync:clockInResult', player, success, response)
    end, charName, charRank)
end)

-- Solicitar salida desde punto de fichaje (cliente)
RegisterNetEvent('zync:requestClockOut')
AddEventHandler('zync:requestClockOut', function(businessId, category)
    local player = source
    local identifier = ZyncFramework.GetPlayerIdentifier(player)
    
    if not identifier then
        ZyncFramework.Notify(player, GetMessage("apiError"), "error")
        TriggerClientEvent('zync:clockOutResult', player, false, {error = "no_identifier"})
        return
    end
    
    ZyncAPI.ClockOut(businessId, identifier, category, function(success, response)
        if success then
            local businessName = GetBusiness(businessId).name
            local timeWorked = response.sessionFormatted or FormatTime(response.sessionSeconds or 0)
            ZyncFramework.Notify(player, GetMessage("clockOutSuccess", businessName, timeWorked), "success")
            
            PlayerShiftStatus[player] = nil
        else
            if response and response.error == "not_clocked_in" then
                ZyncFramework.Notify(player, GetMessage("notClockedIn"), "warning")
            else
                ZyncFramework.Notify(player, GetMessage("apiError"), "error")
            end
        end
        
        TriggerClientEvent('zync:clockOutResult', player, success, response)
    end)
end)

-- Solicitar estado (para NUI)
RegisterNetEvent('zync:requestStatus')
AddEventHandler('zync:requestStatus', function(businessId)
    local player = source
    local identifier = ZyncFramework.GetPlayerIdentifier(player)
    
    if not identifier then
        TriggerClientEvent('zync:statusResult', player, false, {error = "no_identifier"})
        return
    end
    
    ZyncAPI.GetStatus(businessId, identifier, function(success, response)
        TriggerClientEvent('zync:statusResult', player, success, response)
    end)
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- LIMPIEZA AL DESCONECTAR (Auto clock-out)
-- ═══════════════════════════════════════════════════════════════════════════════

AddEventHandler('playerDropped', function(reason)
    local player = source
    local shiftData = PlayerShiftStatus[player]
    
    -- Si el jugador tenía un fichaje activo, cerrarlo
    if shiftData and shiftData.businessId then
        local identifier = ZyncFramework.GetPlayerIdentifier(player)
        
        if identifier then
            local businessId = shiftData.businessId
            local category = shiftData.category or "General"
            
            ZyncDebug("playerDropped: Cerrando fichaje de " .. tostring(player) .. " - Business: " .. businessId .. ", Category: " .. category)
            
            -- Llamar a la API para cerrar el fichaje
            ZyncAPI.ClockOut(businessId, identifier, category, function(success, response)
                if success then
                    ZyncDebug("playerDropped: Fichaje cerrado correctamente para " .. tostring(player))
                else
                    ZyncDebug("playerDropped: Error al cerrar fichaje de " .. tostring(player))
                end
            end)
        end
    end
    
    -- Limpiar estado local
    PlayerShiftStatus[player] = nil
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- EXPORTACIONES
-- ═══════════════════════════════════════════════════════════════════════════════

-- Fichar entrada (para otros recursos)
exports('ClockIn', function(source, businessId, category)
    local identifier = ZyncFramework.GetPlayerIdentifier(source)
    if not identifier then return false end
    
    -- Obtener info del personaje
    local charName = ZyncFramework.GetPlayerName(source)
    local jobInfo = ZyncFramework.GetPlayerJob(source)
    local charRank = jobInfo and jobInfo.gradeName or nil
    
    local result = nil
    local done = false
    
    ZyncAPI.ClockIn(businessId, identifier, category, function(success, response)
        result = {success = success, response = response}
        done = true
    end, charName, charRank)
    
    while not done do Wait(10) end
    return result
end)

-- Fichar salida (para otros recursos)
exports('ClockOut', function(source, businessId)
    local identifier = ZyncFramework.GetPlayerIdentifier(source)
    if not identifier then return false end
    
    local result = nil
    local done = false
    
    ZyncAPI.ClockOut(businessId, identifier, nil, function(success, response)
        result = {success = success, response = response}
        done = true
    end)
    
    while not done do Wait(10) end
    return result
end)

-- Obtener estado (para otros recursos)
exports('GetPlayerStatus', function(source, businessId)
    local identifier = ZyncFramework.GetPlayerIdentifier(source)
    if not identifier then return nil end
    
    local result = nil
    local done = false
    
    ZyncAPI.GetStatus(businessId, identifier, function(success, response)
        result = response
        done = true
    end)
    
    while not done do Wait(10) end
    return result
end)

-- Verificar si está vinculado (para otros recursos)
exports('IsLinked', function(source, businessId)
    local identifier = ZyncFramework.GetPlayerIdentifier(source)
    if not identifier then return false end
    
    local result = false
    local done = false
    
    ZyncAPI.CheckLink(businessId, identifier, function(success, response)
        result = success and response.linked
        done = true
    end)
    
    while not done do Wait(10) end
    return result
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- AUTO CLOCK-OUT POR CAMBIO DE TRABAJO
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterNetEvent('zync:server:autoClockOut')
AddEventHandler('zync:server:autoClockOut', function(businessId, reason, oldJob, newJob)
    local player = source
    local identifier = ZyncFramework.GetPlayerIdentifier(player)
    
    if not identifier then
        return
    end
    
    ZyncDebug("Auto clock-out: player=" .. tostring(player) .. ", reason=" .. tostring(reason) .. ", oldJob=" .. tostring(oldJob) .. " -> " .. tostring(newJob))
    
    -- Cerrar el fichaje activo
    ZyncAPI.ClockOut(businessId, identifier, nil, function(success, response)
        if success then
            local businessName = GetBusiness(businessId) and GetBusiness(businessId).name or businessId
            local timeWorked = response.sessionFormatted or FormatTime(response.sessionSeconds or 0)
            
            -- Notificar al jugador
            ZyncFramework.Notify(player, GetMessage("autoClockOut"), "warning")
            ZyncFramework.Notify(player, GetMessage("autoClockOutTime", timeWorked), "info")
            
            PlayerShiftStatus[player] = nil
            TriggerClientEvent('zync:shiftEnded', player, businessId, response)
        end
    end)
end)
