--[[
    ╔═══════════════════════════════════════════════════════════════════════════╗
    ║                          CLIENTE PRINCIPAL                                 ║
    ╚═══════════════════════════════════════════════════════════════════════════╝
]]

-- Estado local del jugador
local CurrentShift = nil
local IsNuiOpen = false
local LastKnownJob = nil

-- ═══════════════════════════════════════════════════════════════════════════════
-- INICIALIZACIÓN
-- ═══════════════════════════════════════════════════════════════════════════════

CreateThread(function()
    while not ZyncFramework.Ready do
        Wait(100)
    end
    
    ZyncDebug("Cliente iniciado")
    
    -- Obtener job inicial
    Wait(1000)
    local job = ZyncFramework.GetPlayerJob()
    if job then
        LastKnownJob = job.name
        ZyncDebug("Job inicial: " .. tostring(LastKnownJob))
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- MONITOREO DE CAMBIO DE TRABAJO
-- ═══════════════════════════════════════════════════════════════════════════════

CreateThread(function()
    while not ZyncFramework.Ready do
        Wait(100)
    end
    
    Wait(2000)  -- Esperar a que se cargue todo
    
    while true do
        Wait(2000)  -- Revisar cada 2 segundos
        
        -- Solo revisar si tiene fichaje activo
        if CurrentShift then
            local job = ZyncFramework.GetPlayerJob()
            local currentJobName = job and job.name or nil
            
            -- Si el job cambió
            if currentJobName and LastKnownJob and currentJobName ~= LastKnownJob then
                ZyncDebug("Cambio de trabajo detectado: " .. tostring(LastKnownJob) .. " -> " .. tostring(currentJobName))
                
                -- Notificar al servidor para cerrar el fichaje
                TriggerServerEvent('zync:server:autoClockOut', CurrentShift.businessId, "job_change", LastKnownJob, currentJobName)
                
                -- Limpiar estado local
                CurrentShift = nil
            end
            
            LastKnownJob = currentJobName
        else
            -- Actualizar job conocido aunque no esté fichando
            local job = ZyncFramework.GetPlayerJob()
            if job then
                LastKnownJob = job.name
            end
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- EVENTOS DEL SERVIDOR
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterNetEvent('zync:shiftStarted')
AddEventHandler('zync:shiftStarted', function(businessId, category, response)
    CurrentShift = {
        businessId = businessId,
        category = category,
        startTime = GetGameTimer(),
        serverData = response
    }
    
    ZyncDebug("Fichaje iniciado: " .. businessId .. " - " .. category)
end)

RegisterNetEvent('zync:shiftEnded')
AddEventHandler('zync:shiftEnded', function(businessId, response)
    CurrentShift = nil
    ZyncDebug("Fichaje terminado: " .. businessId)
end)

RegisterNetEvent('zync:clockInResult')
AddEventHandler('zync:clockInResult', function(success, response)
    if success then
        CurrentShift = {
            businessId = response.businessId,
            category = response.category,
            startTime = GetGameTimer(),
            serverData = response
        }
    end
    
    -- Actualizar NUI si está abierto
    if IsNuiOpen then
        SendNUIMessage({
            action = "updateStatus",
            success = success,
            data = response
        })
    end
end)

RegisterNetEvent('zync:clockOutResult')
AddEventHandler('zync:clockOutResult', function(success, response)
    if success then
        CurrentShift = nil
    end
    
    -- Actualizar NUI si está abierto
    if IsNuiOpen then
        SendNUIMessage({
            action = "updateStatus",
            success = success,
            data = response
        })
    end
end)

RegisterNetEvent('zync:statusResult')
AddEventHandler('zync:statusResult', function(success, response)
    if IsNuiOpen then
        SendNUIMessage({
            action = "statusUpdate",
            success = success,
            data = response
        })
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- NUI CALLBACKS - Definidos en nui.lua (para evitar duplicados)
-- ═══════════════════════════════════════════════════════════════════════════════

-- closeUI callback para compatibilidad con el JavaScript legado
RegisterNUICallback('closeUI', function(data, cb)
    IsNuiOpen = false
    SetNuiFocus(false, false)
    cb({})
end)

-- NOTA: Los callbacks clockIn, clockOut, getStatus ahora están en nui.lua
-- para usar el nuevo sistema zync:server:clockIn/clockOut

-- ═══════════════════════════════════════════════════════════════════════════════
-- FUNCIONES PÚBLICAS
-- ═══════════════════════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════════════════════
-- FUNCIONES PÚBLICAS
-- ═══════════════════════════════════════════════════════════════════════════════

-- Nota: Las funciones OpenClockPointUI y CloseClockPointUI están definidas en nui.lua

-- ═══════════════════════════════════════════════════════════════════════════════
-- EXPORTACIONES (CLIENTE)
-- ═══════════════════════════════════════════════════════════════════════════════

exports('GetPlayerShiftStatus', function()
    return CurrentShift
end)

exports('IsPlayerClockedIn', function()
    return CurrentShift ~= nil
end)

exports('GetPlayerTotalTime', function()
    if not CurrentShift then return 0 end
    return math.floor((GetGameTimer() - CurrentShift.startTime) / 1000)
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- TECLA ESC PARA CERRAR
-- ═══════════════════════════════════════════════════════════════════════════════

CreateThread(function()
    while true do
        Wait(0)
        
        if IsNuiOpen then
            DisableControlAction(0, 1, true)   -- LookLeftRight
            DisableControlAction(0, 2, true)   -- LookUpDown
            DisableControlAction(0, 142, true) -- MeleeAttackAlternate
            DisableControlAction(0, 18, true)  -- Enter
            DisableControlAction(0, 322, true) -- ESC
            DisableControlAction(0, 106, true) -- VehicleMouseControlOverride
            
            if IsDisabledControlJustReleased(0, 322) then -- ESC
                CloseClockPointUI()
            end
        end
    end
end)
