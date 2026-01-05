--[[
    ╔═══════════════════════════════════════════════════════════════════════════╗
    ║                    ABSTRACCIÓN DE FRAMEWORK (CLIENTE)                      ║
    ╚═══════════════════════════════════════════════════════════════════════════╝
]]

local ESX = nil
local QBCore = nil

-- ═══════════════════════════════════════════════════════════════════════════════
-- DETECCIÓN DE FRAMEWORK
-- ═══════════════════════════════════════════════════════════════════════════════

CreateThread(function()
    local framework = Config.Framework
    
    if framework == "auto" then
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
    
    if framework == "esx" then
        ESX = exports['es_extended']:getSharedObject()
        if not ESX then
            TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
        end
        
    elseif framework == "qbcore" then
        QBCore = exports['qb-core']:GetCoreObject()
    end
    
    Wait(500)
    ZyncFramework.Ready = true
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- FUNCIONES UNIFICADAS (CLIENTE)
-- ═══════════════════════════════════════════════════════════════════════════════

-- Obtener job del jugador local
function ZyncFramework.GetPlayerJob()
    local framework = ZyncFramework.Name
    
    if framework == "esx" and ESX then
        local playerData = ESX.GetPlayerData()
        if playerData and playerData.job then
            return {
                name = playerData.job.name,
                label = playerData.job.label,
                grade = playerData.job.grade,
                gradeName = playerData.job.grade_name or playerData.job.grade_label or tostring(playerData.job.grade),
            }
        end
        
    elseif framework == "qbcore" and QBCore then
        local playerData = QBCore.Functions.GetPlayerData()
        if playerData and playerData.job then
            return {
                name = playerData.job.name,
                label = playerData.job.label,
                grade = playerData.job.grade.level,
                gradeName = playerData.job.grade.name,
            }
        end
        
    elseif framework == "standalone" then
        return nil
    end
    
    return nil
end

-- Mostrar notificación
function ZyncFramework.Notify(message, type)
    local framework = ZyncFramework.Name
    type = type or "info"
    
    local notifySystem = Config.NotificationSystem or "auto"
    
    -- Custom notification function
    if notifySystem == "custom" and Config.CustomNotify then
        Config.CustomNotify(message, type)
        return
    end
    
    -- Auto-detect: usar notificaciones del framework activo
    if notifySystem == "auto" then
        if framework == "esx" and ESX then
            ESX.ShowNotification(message)
            return
        elseif framework == "qbcore" and QBCore then
            QBCore.Functions.Notify(message, type)
            return
        elseif GetResourceState('ox_lib') == 'started' then
            exports['ox_lib']:notify({ title = 'Zync', description = message, type = type })
            return
        elseif GetResourceState('okokNotify') == 'started' then
            exports['okokNotify']:Alert('Zync', message, 5000, type)
            return
        end
        -- Fallback a native si no hay framework
        notifySystem = "native"
    end
    
    -- ESX notifications
    if notifySystem == "esx" then
        if ESX then
            ESX.ShowNotification(message)
        else
            -- Fallback si ESX no está disponible
            BeginTextCommandThefeedPost("STRING")
            AddTextComponentSubstringPlayerName(message)
            EndTextCommandThefeedPostTicker(false, true)
        end
        return
    end
    
    -- QBCore notifications
    if notifySystem == "qbcore" then
        if QBCore then
            QBCore.Functions.Notify(message, type)
        else
            BeginTextCommandThefeedPost("STRING")
            AddTextComponentSubstringPlayerName(message)
            EndTextCommandThefeedPostTicker(false, true)
        end
        return
    end
    
    -- ox_lib notifications
    if notifySystem == "ox_lib" then
        if GetResourceState('ox_lib') == 'started' then
            exports['ox_lib']:notify({ title = 'Zync', description = message, type = type })
        else
            BeginTextCommandThefeedPost("STRING")
            AddTextComponentSubstringPlayerName(message)
            EndTextCommandThefeedPostTicker(false, true)
        end
        return
    end
    
    -- okokNotify
    if notifySystem == "okokNotify" then
        if GetResourceState('okokNotify') == 'started' then
            exports['okokNotify']:Alert('Zync', message, 5000, type)
        else
            BeginTextCommandThefeedPost("STRING")
            AddTextComponentSubstringPlayerName(message)
            EndTextCommandThefeedPostTicker(false, true)
        end
        return
    end
    
    -- Chat messages
    if notifySystem == "chat" then
        TriggerEvent('chat:addMessage', {
            color = {255, 255, 255},
            multiline = true,
            args = {"Zync", message}
        })
        return
    end
    
    -- Native GTA notification (default)
    BeginTextCommandThefeedPost("STRING")
    AddTextComponentSubstringPlayerName(message)
    EndTextCommandThefeedPostTicker(false, true)
end

-- Dibujar texto 3D
function ZyncFramework.DrawText3D(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    local pX, pY, pZ = table.unpack(GetGameplayCamCoords())
    
    if onScreen then
        SetTextScale(0.35, 0.35)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextColour(255, 255, 255, 215)
        SetTextEntry("STRING")
        SetTextCentre(1)
        AddTextComponentString(text)
        DrawText(_x, _y)
        
        local factor = (string.len(text)) / 370
        DrawRect(_x, _y + 0.0125, 0.015 + factor, 0.03, 0, 0, 0, 100)
    end
end

-- Dibujar texto 2D
function ZyncFramework.DrawText2D(x, y, text, scale, centered)
    scale = scale or 0.35
    SetTextFont(4)
    SetTextProportional(0)
    SetTextScale(scale, scale)
    SetTextColour(255, 255, 255, 255)
    SetTextDropShadow(0, 0, 0, 0, 255)
    SetTextEdge(2, 0, 0, 0, 150)
    SetTextDropShadow()
    SetTextOutline()
    if centered then
        SetTextCentre(true)
    end
    SetTextEntry("STRING")
    AddTextComponentString(text)
    DrawText(x, y)
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- EVENTOS
-- ═══════════════════════════════════════════════════════════════════════════════

-- Recibir notificación del servidor
RegisterNetEvent('zync:notify')
AddEventHandler('zync:notify', function(message, type)
    ZyncFramework.Notify(message, type)
end)
