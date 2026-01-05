--[[
    ╔═══════════════════════════════════════════════════════════════════════════╗
    ║                      TABLET DE GESTIÓN (SERVIDOR)                          ║
    ╚═══════════════════════════════════════════════════════════════════════════╝
    
    Manejo de peticiones de la tablet: obtener datos, forzar salidas, logs.
]]

-- ═══════════════════════════════════════════════════════════════════════════════
-- VERIFICACIÓN DE PERMISOS (SERVIDOR)
-- ═══════════════════════════════════════════════════════════════════════════════

function CanPlayerUseTablet(source, businessId)
    local business = GetBusiness(businessId)
    if not business then return false end
    if not business.tablet or not business.tablet.enabled then return false end
    
    local jobInfo = ZyncFramework.GetPlayerJob(source)
    if not jobInfo then return false end
    
    local playerJob = jobInfo.name
    local playerRank = jobInfo.gradeName or jobInfo.grade
    
    local allowedJobs = business.tablet.allowedJobs
    if not allowedJobs then return false end
    
    local jobConfig = allowedJobs[playerJob]
    if not jobConfig then return false end
    
    -- Si ranks es nil, todos los rangos están permitidos
    if jobConfig.ranks == nil then
        return true
    end
    
    -- Verificar si el rango está en la lista
    for _, rank in ipairs(jobConfig.ranks) do
        if rank == playerRank then
            return true
        end
    end
    
    return false
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- ABRIR TABLET
-- ═══════════════════════════════════════════════════════════════════════════════

-- Obtener la categoría configurada para el job del jugador
function GetPlayerCategory(source, businessId)
    local business = GetBusiness(businessId)
    if not business or not business.jobs then return nil end
    
    local jobInfo = ZyncFramework.GetPlayerJob(source)
    if not jobInfo then return nil end
    
    local jobConfig = business.jobs[jobInfo.name]
    if jobConfig and jobConfig.category then
        return jobConfig.category
    end
    
    return nil
end

-- Obtener información completa del jugador para la tablet
function GetPlayerTabletInfo(source)
    local jobInfo = ZyncFramework.GetPlayerJob(source)
    local charName = ZyncFramework.GetPlayerName(source)
    
    return {
        charName = charName or "Desconocido",
        jobLabel = jobInfo and jobInfo.label or "Sin empleo",
        rankName = jobInfo and jobInfo.gradeName or "Sin rango"
    }
end

RegisterNetEvent("zync:server:tabletOpen")
AddEventHandler("zync:server:tabletOpen", function(businessId)
    local player = source
    
    if not CanPlayerUseTablet(player, businessId) then
        TriggerClientEvent("zync:client:tabletError", player, "No tienes permiso para usar la tablet")
        return
    end
    
    local identifier = ZyncFramework.GetPlayerIdentifier(player)
    if not identifier then
        TriggerClientEvent("zync:client:tabletError", player, "Error al obtener identificador")
        return
    end
    
    -- Obtener la categoría del job del jugador
    local playerCategory = GetPlayerCategory(player, businessId)
    
    -- Obtener datos de la API
    ZyncAPI.Request(businessId, "/tablet/data", "POST", {
        identifier = identifier,
        category = playerCategory  -- Solo mostrar esta categoría
    }, function(success, response)
        if success and response then
            TriggerClientEvent("zync:client:tabletData", player, {
                activeShifts = response.activeShifts or {},
                recentShifts = response.recentShifts or {},
                allUsers = response.allUsers or {},
                categories = response.categories or {},
                stats = response.stats or {}
            })
            
            -- Log de apertura de tablet
            ZyncAPI.Request(businessId, "/tablet/log", "POST", {
                identifier = identifier,
                action = "tablet_open",
                details = "Usuario abrió la tablet de gestión"
            }, function() end)
        else
            TriggerClientEvent("zync:client:tabletError", player, "Error al obtener datos")
        end
    end)
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- REFRESCAR DATOS
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterNetEvent("zync:server:tabletRefresh")
AddEventHandler("zync:server:tabletRefresh", function(businessId)
    local player = source
    
    if not CanPlayerUseTablet(player, businessId) then
        return
    end
    
    local identifier = ZyncFramework.GetPlayerIdentifier(player)
    if not identifier then return end
    
    local playerCategory = GetPlayerCategory(player, businessId)
    
    ZyncAPI.Request(businessId, "/tablet/data", "POST", {
        identifier = identifier,
        category = playerCategory
    }, function(success, response)
        if success and response then
            TriggerClientEvent("zync:client:tabletRefresh", player, {
                activeShifts = response.activeShifts or {},
                recentShifts = response.recentShifts or {},
                allUsers = response.allUsers or {},
                stats = response.stats or {}
            })
        end
    end)
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- FORZAR SALIDA
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterNetEvent("zync:server:tabletForceOut")
AddEventHandler("zync:server:tabletForceOut", function(businessId, targetDiscordId, category)
    local player = source
    
    if not CanPlayerUseTablet(player, businessId) then
        TriggerClientEvent("zync:client:tabletForceOutResult", player, false, "Sin permiso")
        return
    end
    
    local identifier = ZyncFramework.GetPlayerIdentifier(player)
    if not identifier then
        TriggerClientEvent("zync:client:tabletForceOutResult", player, false, "Error de identificador")
        return
    end
    
    -- Llamar a la API para forzar salida
    local actorInfo = GetPlayerTabletInfo(player)
    
    ZyncAPI.Request(businessId, "/tablet/force-clock-out", "POST", {
        identifier = identifier,        -- Quién hace la acción
        targetDiscordId = targetDiscordId,
        category = category,
        actorCharName = actorInfo.charName,
        actorRank = actorInfo.rankName
    }, function(success, response)
        if success then
            local business = GetBusiness(businessId)
            local businessName = business and business.name or businessId
            
            TriggerClientEvent("zync:client:tabletForceOutResult", player, true, "Salida forzada correctamente")
            
            -- Notificar al jugador afectado si está conectado
            local targetPlayer = FindPlayerByDiscordId(targetDiscordId)
            if targetPlayer then
                ZyncFramework.Notify(targetPlayer, GetMessage("forcedClockOut") or "Tu fichaje ha sido cerrado por un supervisor", "warning")
                
                -- Limpiar su estado local (PlayerShiftStatus es global desde main.lua)
                if PlayerShiftStatus and PlayerShiftStatus[targetPlayer] then
                    PlayerShiftStatus[targetPlayer] = nil
                end
                
                TriggerClientEvent("zync:shiftEnded", targetPlayer, businessId, {
                    forced = true,
                    forcedBy = "Tablet"
                })
            end
            
            ZyncDebug("Tablet: " .. GetPlayerName(player) .. " forzó salida de Discord ID " .. targetDiscordId)
        else
            local errorMsg = "Error al forzar salida"
            if response and response.error then
                if response.error == "not_clocked_in" then
                    errorMsg = "El usuario no está fichado"
                elseif response.error == "permission_denied" then
                    errorMsg = "Sin permiso para esta acción"
                end
            end
            TriggerClientEvent("zync:client:tabletForceOutResult", player, false, errorMsg)
        end
    end)
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- FUNCIONES AUXILIARES
-- ═══════════════════════════════════════════════════════════════════════════════

-- Buscar jugador conectado por Discord ID
function FindPlayerByDiscordId(discordId)
    local players = GetPlayers()
    
    for _, playerId in ipairs(players) do
        local identifiers = GetPlayerIdentifiers(playerId)
        for _, id in ipairs(identifiers) do
            if string.find(id, "discord:") then
                local playerDiscordId = string.gsub(id, "discord:", "")
                if playerDiscordId == tostring(discordId) then
                    return tonumber(playerId)
                end
            end
        end
    end
    
    return nil
end

-- Obtener todos los jugadores
function GetPlayers()
    local players = {}
    for i = 0, GetNumPlayerIndices() - 1 do
        local player = GetPlayerFromIndex(i)
        if player then
            table.insert(players, player)
        end
    end
    return players
end
