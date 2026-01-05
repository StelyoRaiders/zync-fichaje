--[[
    ╔═══════════════════════════════════════════════════════════════════════════╗
    ║                    ABSTRACCIÓN DE FRAMEWORK (SERVIDOR)                     ║
    ╚═══════════════════════════════════════════════════════════════════════════╝
    
    Este archivo detecta y abstrae el framework de roleplay utilizado.
    Soporta: ESX, QBCore, vRP, y modo Standalone.
]]

local ESX = nil
local QBCore = nil
local vRP = nil

-- ═══════════════════════════════════════════════════════════════════════════════
-- DETECCIÓN DE FRAMEWORK
-- ═══════════════════════════════════════════════════════════════════════════════

CreateThread(function()
    local framework = Config.Framework
    
    if framework == "auto" then
        -- Detectar automáticamente
        if GetResourceState('es_extended') == 'started' then
            framework = "esx"
        elseif GetResourceState('qb-core') == 'started' then
            framework = "qbcore"
        elseif GetResourceState('vrp') == 'started' then
            framework = "vrp"
        else
            framework = "standalone"
        end
    end
    
    ZyncFramework.Name = framework
    ZyncPrint("Framework detectado: " .. framework)
    
    -- Inicializar framework específico
    if framework == "esx" then
        -- ESX Legacy / ESX 1.x
        if GetResourceState('es_extended') == 'started' then
            ESX = exports['es_extended']:getSharedObject()
            if not ESX then
                -- Fallback para versiones antiguas
                TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
            end
        end
        
    elseif framework == "qbcore" then
        QBCore = exports['qb-core']:GetCoreObject()
        
    elseif framework == "vrp" then
        vRP = exports.vrp
    end
    
    Wait(500)  -- Esperar a que se cargue todo
    ZyncFramework.Ready = true
    ZyncPrint("Framework inicializado correctamente")
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- FUNCIONES UNIFICADAS (SERVIDOR)
-- ═══════════════════════════════════════════════════════════════════════════════

-- Obtener identificador del jugador
function ZyncFramework.GetPlayerIdentifier(source, idType)
    if not source or source <= 0 then
        ZyncError("Source inválido: " .. tostring(source))
        return nil
    end
    
    idType = idType or Config.PreferredIdentifier or "steam"
    
    local numIds = GetNumPlayerIdentifiers(source)
    
    if numIds == 0 then
        ZyncError("El jugador " .. source .. " no tiene identificadores")
        return nil
    end
    
    -- Debug: mostrar todos los identificadores disponibles
    if Config.Debug then
        ZyncDebug("Identificadores para jugador " .. source .. ":")
        for i = 0, numIds - 1 do
            local id = GetPlayerIdentifier(source, i)
            ZyncDebug("  [" .. i .. "] " .. tostring(id))
        end
    end
    
    -- Buscar el identificador preferido
    for i = 0, numIds - 1 do
        local id = GetPlayerIdentifier(source, i)
        if id then
            local prefix = idType .. ":"
            if string.sub(id, 1, #prefix) == prefix then
                ZyncDebug("Identificador encontrado: " .. id)
                return id
            end
        end
    end
    
    -- Fallback: buscar cualquier identificador válido
    local fallbacks = {"steam", "license", "discord", "fivem", "xbl", "live"}
    for _, fallback in ipairs(fallbacks) do
        if fallback ~= idType then
            for i = 0, numIds - 1 do
                local id = GetPlayerIdentifier(source, i)
                if id then
                    local prefix = fallback .. ":"
                    if string.sub(id, 1, #prefix) == prefix then
                        ZyncDebug("Usando identificador fallback (" .. fallback .. "): " .. id)
                        return id
                    end
                end
            end
        end
    end
    
    -- Último intento: devolver el primer identificador disponible
    for i = 0, numIds - 1 do
        local id = GetPlayerIdentifier(source, i)
        if id then
            ZyncDebug("Usando primer identificador disponible: " .. id)
            return id
        end
    end
    
    ZyncError("No se pudo obtener ningún identificador para el jugador " .. source)
    return nil
end

-- Obtener tipo de identificador
function ZyncFramework.GetIdentifierType(identifier)
    if not identifier then return nil end
    local colonPos = string.find(identifier, ":")
    if colonPos then
        return string.sub(identifier, 1, colonPos - 1)
    end
    return "unknown"
end

-- Obtener Discord ID del jugador (sin prefijo)
function ZyncFramework.GetPlayerDiscordId(source)
    if not source or source <= 0 then
        return nil
    end
    
    local numIds = GetNumPlayerIdentifiers(source)
    for i = 0, numIds - 1 do
        local id = GetPlayerIdentifier(source, i)
        if id and string.sub(id, 1, 8) == "discord:" then
            -- Devolver solo el ID numérico
            return string.sub(id, 9)
        end
    end
    
    return nil
end

-- Obtener job del jugador (servidor)
function ZyncFramework.GetPlayerJob(source)
    local framework = ZyncFramework.Name
    
    if framework == "esx" and ESX then
        local xPlayer = ESX.GetPlayerFromId(source)
        if xPlayer then
            local job = xPlayer.getJob()
            return {
                name = job.name,
                label = job.label,
                grade = job.grade,
                gradeName = job.grade_name or job.grade_label or tostring(job.grade),
            }
        end
        
    elseif framework == "qbcore" and QBCore then
        local player = QBCore.Functions.GetPlayer(source)
        if player then
            local job = player.PlayerData.job
            return {
                name = job.name,
                label = job.label,
                grade = job.grade.level,
                gradeName = job.grade.name,
            }
        end
        
    elseif framework == "vrp" and vRP then
        local user_id = vRP.getUserId({source})
        if user_id then
            local identity = vRP.getUserIdentity({user_id})
            local groups = vRP.getUserGroups({user_id})
            
            -- En vRP, los jobs suelen ser grupos
            for group, _ in pairs(groups or {}) do
                return {
                    name = group,
                    label = group,
                    grade = 0,
                    gradeName = "",
                }
            end
        end
        
    elseif framework == "standalone" then
        -- En modo standalone, no hay jobs
        -- Los administradores deberán configurar los negocios sin restricción de jobs
        -- o usar otro sistema de permisos
        return nil
    end
    
    return nil
end

-- Obtener nombre del jugador
function ZyncFramework.GetPlayerName(source)
    local framework = ZyncFramework.Name
    
    if framework == "esx" and ESX then
        local xPlayer = ESX.GetPlayerFromId(source)
        if xPlayer then
            return xPlayer.getName()
        end
        
    elseif framework == "qbcore" and QBCore then
        local player = QBCore.Functions.GetPlayer(source)
        if player then
            local charInfo = player.PlayerData.charinfo
            return charInfo.firstname .. " " .. charInfo.lastname
        end
        
    elseif framework == "vrp" and vRP then
        local user_id = vRP.getUserId({source})
        if user_id then
            local identity = vRP.getUserIdentity({user_id})
            if identity then
                return (identity.firstname or "") .. " " .. (identity.name or "")
            end
        end
    end
    
    -- Fallback: nombre de Steam/FiveM
    return GetPlayerName(source) or "Jugador"
end

-- Notificar al jugador (servidor → cliente)
function ZyncFramework.Notify(source, message, type)
    type = type or "info"
    TriggerClientEvent('zync:notify', source, message, type)
end

-- Registrar comando (compatible con todos los frameworks)
function ZyncFramework.RegisterCommand(name, callback, restricted)
    RegisterCommand(name, function(source, args, rawCommand)
        callback(source, args, rawCommand)
    end, restricted or false)
end
