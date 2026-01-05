--[[
    ╔═══════════════════════════════════════════════════════════════════════════╗
    ║                          CONTROLADOR NUI                                   ║
    ╚═══════════════════════════════════════════════════════════════════════════╝
    
    Manejo específico de la interfaz NUI para puntos de fichaje.
]]

local NUIActive = false
local CurrentNUIBusiness = nil
local CurrentNUIPoint = nil

-- ═══════════════════════════════════════════════════════════════════════════════
-- ABRIR/CERRAR UI
-- ═══════════════════════════════════════════════════════════════════════════════

function OpenClockPointUI(businessId, point)
    if NUIActive then
        return
    end
    
    NUIActive = true
    CurrentNUIBusiness = businessId
    CurrentNUIPoint = point
    
    -- Deshabilitar controles del juego
    SetNuiFocus(true, true)
    
    -- Obtener datos del servidor (incluir categoría del punto para tiempo total)
    local pointCategory = point and point.category or "General"
    TriggerServerEvent("zync:server:requestUIData", businessId, pointCategory)
end

function CloseClockPointUI()
    if not NUIActive then
        return
    end
    
    NUIActive = false
    CurrentNUIBusiness = nil
    CurrentNUIPoint = nil
    
    -- Restaurar controles del juego
    SetNuiFocus(false, false)
    
    -- Ocultar UI
    SendNUIMessage({
        type = "hide"
    })
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- EVENTOS DESDE SERVIDOR
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterNetEvent("zync:client:receiveUIData", function(data)
    if not NUIActive then
        return
    end
    
    local business = GetBusiness(CurrentNUIBusiness)
    
    -- Obtener configuración de logo
    local logoUrl = Config.NUI and Config.NUI.logoUrl or nil
    local logoText = Config.NUI and Config.NUI.logoText or "ZYNC"
    
    -- Si el negocio tiene logo propio, usarlo
    if business and business.logoUrl then
        logoUrl = business.logoUrl
    end
    if business and business.logoText then
        logoText = business.logoText
    end
    
    SendNUIMessage({
        type = "show",
        businessId = CurrentNUIBusiness,
        businessName = business and business.name or "Desconocido",
        pointName = CurrentNUIPoint and CurrentNUIPoint.name or "",
        isClockedIn = data.isClockedIn,
        currentTime = data.currentTime,
        isLinked = data.isLinked,
        discordName = data.discordName,
        discordAvatar = data.discordAvatar,
        needsLink = data.needsLink,
        totalTime = data.totalTime,
        logoUrl = logoUrl,
        logoText = logoText,
        messages = {
            title = GetMessage("nuiTitle"),
            clockIn = GetMessage("nuiClockIn"),
            clockOut = GetMessage("nuiClockOut"),
            status = GetMessage("nuiStatus"),
            linked = GetMessage("nuiLinked"),
            notLinked = GetMessage("nuiNotLinked"),
            linkAccount = GetMessage("nuiLinkAccount"),
            enterCode = GetMessage("nuiEnterCode"),
            close = GetMessage("nuiClose"),
            working = GetMessage("nuiWorking"),
            notWorking = GetMessage("nuiNotWorking"),
            success = GetMessage("nuiSuccess"),
            error = GetMessage("nuiError"),
            connecting = GetMessage("nuiConnecting")
        }
    })
end)

RegisterNetEvent("zync:client:updateShiftTime", function(time)
    if NUIActive then
        SendNUIMessage({
            type = "updateTime",
            time = time
        })
    end
end)

RegisterNetEvent("zync:client:linkResult", function(success, message)
    if NUIActive then
        SendNUIMessage({
            type = "linkResult",
            success = success,
            message = message
        })
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- CALLBACKS NUI
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterNUICallback("clockIn", function(data, cb)
    if CurrentNUIBusiness then
        local category = CurrentNUIPoint and CurrentNUIPoint.category or "General"
        TriggerServerEvent("zync:server:clockIn", CurrentNUIBusiness, category)
        cb({ok = true})
    else
        cb({ok = false, error = "No business selected"})
    end
end)

RegisterNUICallback("clockOut", function(data, cb)
    if CurrentNUIBusiness then
        TriggerServerEvent("zync:server:clockOut", CurrentNUIBusiness)
        cb({ok = true})
    else
        cb({ok = false, error = "No business selected"})
    end
end)

RegisterNUICallback("linkAccount", function(data, cb)
    local code = data.code
    
    if code and #code > 0 and CurrentNUIBusiness then
        TriggerServerEvent("zync:server:linkAccountWithCode", code, CurrentNUIBusiness)
        cb({ok = true})
    else
        cb({ok = false, error = "Invalid code"})
    end
end)

RegisterNUICallback("close", function(data, cb)
    CloseClockPointUI()
    cb({ok = true})
end)

RegisterNUICallback("refreshStatus", function(data, cb)
    if CurrentNUIBusiness then
        TriggerServerEvent("zync:server:requestUIData", CurrentNUIBusiness)
        cb({ok = true})
    else
        cb({ok = false})
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- TECLA ESC PARA CERRAR
-- ═══════════════════════════════════════════════════════════════════════════════

CreateThread(function()
    while true do
        Wait(0)
        
        if NUIActive then
            DisableControlAction(0, 1, true)   -- LookLeftRight
            DisableControlAction(0, 2, true)   -- LookUpDown
            DisableControlAction(0, 24, true)  -- Attack
            DisableControlAction(0, 25, true)  -- Aim
            DisableControlAction(0, 142, true) -- MeleeAttackAlternate
            DisableControlAction(0, 200, true) -- ESC (Pause Menu)
            
            if IsDisabledControlJustReleased(0, 200) then  -- ESC
                CloseClockPointUI()
            end
        else
            Wait(500)
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- EXPORTS
-- ═══════════════════════════════════════════════════════════════════════════════

exports("IsNUIOpen", function()
    return NUIActive
end)

exports("CloseNUI", function()
    CloseClockPointUI()
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- EVENTO PARA ABRIR UI DESDE SERVIDOR/OTROS SCRIPTS
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterNetEvent("zync:client:openUI", function(businessId)
    local business = GetBusiness(businessId)
    if business then
        -- Crear punto ficticio si no hay uno
        local point = {
            name = business.name,
            coords = GetEntityCoords(PlayerPedId())
        }
        OpenClockPointUI(businessId, point)
    end
end)
