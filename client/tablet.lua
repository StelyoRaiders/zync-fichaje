--[[
    ╔═══════════════════════════════════════════════════════════════════════════╗
    ║                          TABLET DE GESTIÓN                                 ║
    ╚═══════════════════════════════════════════════════════════════════════════╝
    
    Permite a usuarios autorizados ver fichajes en tiempo real desde FiveM.
    Incluye: ver fichajes activos, forzar salidas, historial.
]]

local TabletActive = false
local CurrentTabletBusiness = nil
local TabletProp = nil
local RefreshInterval = nil

-- ═══════════════════════════════════════════════════════════════════════════════
-- VERIFICACIÓN DE PERMISOS
-- ═══════════════════════════════════════════════════════════════════════════════

function CanUseTablet(businessId)
    local business = GetBusiness(businessId)
    if not business then return false end
    if not business.tablet or not business.tablet.enabled then return false end
    
    local jobData = ZyncFramework.GetPlayerJob()
    if not jobData then return false end
    
    local playerJob = jobData.name
    local playerRank = jobData.gradeName
    
    if Config.Debug then
        print("[Zync Tablet] Verificando permisos - Job: " .. tostring(playerJob) .. ", Rank: " .. tostring(playerRank))
    end
    
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

-- Obtener el negocio que puede usar el jugador para la tablet
function GetTabletBusiness()
    for businessId, business in pairs(Config.Businesses) do
        if business.tablet and business.tablet.enabled then
            if CanUseTablet(businessId) then
                return businessId, business
            end
        end
    end
    return nil, nil
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- REGISTRO DE COMANDOS
-- ═══════════════════════════════════════════════════════════════════════════════

-- Variable para rastrear comandos ya registrados
local RegisteredCommands = {}

function RegisterTabletCommands()
    for businessId, business in pairs(Config.Businesses) do
        if business.tablet and business.tablet.enabled and business.tablet.command then
            local cmdConfig = business.tablet.command
            if cmdConfig.enabled and cmdConfig.name then
                local cmdName = cmdConfig.name
                
                -- Evitar registrar el mismo comando varias veces
                if not RegisteredCommands[cmdName] then
                    RegisteredCommands[cmdName] = businessId
                    
                    RegisterCommand(cmdName, function(source, args, rawCommand)
                        -- Buscar qué negocio puede usar el jugador
                        local bId, bData = GetTabletBusiness()
                        if bId then
                            if TabletActive then
                                CloseTablet()
                            else
                                OpenTablet(bId)
                            end
                        else
                            ZyncFramework.Notify("No tienes permiso para usar la tablet", "error")
                        end
                    end, false)
                    
                    if Config.Debug then
                        print("[Zync Tablet] Comando registrado: /" .. cmdName)
                    end
                end
            end
        end
    end
end

-- Registrar comandos al cargar el script
CreateThread(function()
    Wait(1000) -- Esperar a que todo esté cargado
    RegisterTabletCommands()
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- ANIMACIÓN Y PROP
-- ═══════════════════════════════════════════════════════════════════════════════

function PlayTabletAnimation()
    local ped = PlayerPedId()
    
    -- Cargar animación
    local animDict = "amb@code_human_in_bus_passenger_idles@female@tablet@base"
    RequestAnimDict(animDict)
    while not HasAnimDictLoaded(animDict) do
        Wait(10)
    end
    
    -- Crear prop de tablet
    local propModel = `prop_cs_tablet`
    RequestModel(propModel)
    while not HasModelLoaded(propModel) do
        Wait(10)
    end
    
    local coords = GetEntityCoords(ped)
    TabletProp = CreateObject(propModel, coords.x, coords.y, coords.z, true, true, true)
    
    local boneIndex = GetPedBoneIndex(ped, 28422) -- Mano derecha
    AttachEntityToEntity(TabletProp, ped, boneIndex, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, true, true, false, true, 1, true)
    
    -- Reproducir animación
    TaskPlayAnim(ped, animDict, "base", 8.0, -8.0, -1, 49, 0, false, false, false)
    
    SetModelAsNoLongerNeeded(propModel)
    RemoveAnimDict(animDict)
end

function StopTabletAnimation()
    local ped = PlayerPedId()
    
    -- Eliminar prop
    if TabletProp and DoesEntityExist(TabletProp) then
        DeleteEntity(TabletProp)
        TabletProp = nil
    end
    
    -- Detener animación
    ClearPedTasks(ped)
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- ABRIR/CERRAR TABLET
-- ═══════════════════════════════════════════════════════════════════════════════

function OpenTablet(businessId)
    if TabletActive then return end
    
    local business = GetBusiness(businessId)
    if not business then
        ZyncFramework.Notify(GetMessage("tabletError") or "Error al abrir tablet", "error")
        return
    end
    
    TabletActive = true
    CurrentTabletBusiness = businessId
    
    -- Animación
    if business.tablet.animation ~= false then
        PlayTabletAnimation()
    end
    
    -- Activar NUI
    SetNuiFocus(true, true)
    
    -- Solicitar datos al servidor
    TriggerServerEvent("zync:server:tabletOpen", businessId)
end

function CloseTablet()
    if not TabletActive then return end
    
    TabletActive = false
    
    -- Detener refresco automático
    if RefreshInterval then
        RefreshInterval = nil
    end
    
    -- Restaurar controles
    SetNuiFocus(false, false)
    
    -- Detener animación
    StopTabletAnimation()
    
    -- Ocultar NUI
    SendNUIMessage({
        type = "hideTablet"
    })
    
    CurrentTabletBusiness = nil
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- EVENTOS DESDE SERVIDOR
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterNetEvent("zync:client:tabletData", function(data)
    if not TabletActive then return end
    
    local business = GetBusiness(CurrentTabletBusiness)
    
    SendNUIMessage({
        type = "showTablet",
        businessId = CurrentTabletBusiness,
        businessName = business and business.name or "Desconocido",
        activeShifts = data.activeShifts or {},
        recentShifts = data.recentShifts or {},
        allUsers = data.allUsers or {},
        categories = data.categories or {},
        stats = data.stats or {},
        messages = {
            title = GetMessage("tabletTitle") or "Panel de Gestión",
            activeNow = GetMessage("tabletActiveNow") or "Fichando ahora",
            recentShifts = GetMessage("tabletRecentShifts") or "Fichajes recientes",
            allShifts = GetMessage("tabletAllShifts") or "Todos los fichajes",
            forceClockOut = GetMessage("tabletForceClockOut") or "Forzar salida",
            noActiveShifts = GetMessage("tabletNoActiveShifts") or "Nadie está fichando",
            close = GetMessage("tabletClose") or "Cerrar",
            user = GetMessage("tabletUser") or "Usuario",
            category = GetMessage("tabletCategory") or "Categoría",
            time = GetMessage("tabletTime") or "Tiempo",
            status = GetMessage("tabletStatus") or "Estado",
            totalTime = GetMessage("tabletTotalTime") or "Tiempo total",
            active = GetMessage("tabletActive") or "Activo",
            inactive = GetMessage("tabletInactive") or "Inactivo",
            confirmForceOut = GetMessage("tabletConfirmForceOut") or "¿Forzar salida de este usuario?",
            forceOutSuccess = GetMessage("tabletForceOutSuccess") or "Salida forzada correctamente",
            forceOutError = GetMessage("tabletForceOutError") or "Error al forzar salida",
        }
    })
    
    -- Iniciar refresco automático cada 5 segundos
    if not RefreshInterval then
        RefreshInterval = true
        CreateThread(function()
            while RefreshInterval and TabletActive do
                Wait(5000)
                if TabletActive and CurrentTabletBusiness then
                    TriggerServerEvent("zync:server:tabletRefresh", CurrentTabletBusiness)
                end
            end
        end)
    end
end)

RegisterNetEvent("zync:client:tabletRefresh", function(data)
    if not TabletActive then return end
    
    SendNUIMessage({
        type = "refreshTablet",
        activeShifts = data.activeShifts or {},
        recentShifts = data.recentShifts or {},
        allUsers = data.allUsers or {},
        stats = data.stats or {}
    })
end)

RegisterNetEvent("zync:client:tabletForceOutResult", function(success, message)
    if not TabletActive then return end
    
    SendNUIMessage({
        type = "forceOutResult",
        success = success,
        message = message
    })
    
    -- Refrescar datos
    if success and CurrentTabletBusiness then
        Wait(500)
        TriggerServerEvent("zync:server:tabletRefresh", CurrentTabletBusiness)
    end
end)

RegisterNetEvent("zync:client:tabletError", function(message)
    ZyncFramework.Notify(message or "Error", "error")
    CloseTablet()
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- CALLBACKS NUI
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterNUICallback("closeTablet", function(data, cb)
    CloseTablet()
    cb({ok = true})
end)

RegisterNUICallback("forceClockOut", function(data, cb)
    if CurrentTabletBusiness and data.discordId then
        TriggerServerEvent("zync:server:tabletForceOut", CurrentTabletBusiness, data.discordId, data.category)
        cb({ok = true})
    else
        cb({ok = false, error = "Invalid data"})
    end
end)

RegisterNUICallback("refreshData", function(data, cb)
    if CurrentTabletBusiness then
        TriggerServerEvent("zync:server:tabletRefresh", CurrentTabletBusiness)
        cb({ok = true})
    else
        cb({ok = false})
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- CONTROL DE TECLA
-- ═══════════════════════════════════════════════════════════════════════════════

CreateThread(function()
    while true do
        Wait(0)
        
        -- Buscar si el jugador puede usar alguna tablet
        local businessId, business = GetTabletBusiness()
        
        if businessId and business and business.tablet then
            local key = business.tablet.key or 56 -- F9 por defecto
            
            if IsControlJustPressed(0, key) then
                print("[Zync Tablet] Tecla presionada, abriendo tablet para: " .. businessId)
                if TabletActive then
                    CloseTablet()
                else
                    OpenTablet(businessId)
                end
            end
        else
            -- Debug: mostrar cada 5 segundos por qué no puede usar tablet
            if Config.Debug then
                local jobData = ZyncFramework.GetPlayerJob()
                local job = jobData and jobData.name or "nil"
                local rank = jobData and jobData.gradeName or "nil"
                print("[Zync Tablet] No puede usar tablet. Job: " .. tostring(job) .. ", Rank: " .. tostring(rank))
            end
            Wait(500) -- Si no tiene acceso, revisar menos frecuentemente
        end
    end
end)

-- Cerrar tablet si el jugador muere o cambia de job
AddEventHandler("esx:onPlayerDeath", function()
    if TabletActive then
        CloseTablet()
    end
end)

AddEventHandler("QBCore:Client:OnPlayerLoaded", function()
    if TabletActive then
        CloseTablet()
    end
end)

-- ESC para cerrar
CreateThread(function()
    while true do
        Wait(0)
        if TabletActive then
            if IsControlJustPressed(0, 200) then -- ESC
                CloseTablet()
            end
        else
            Wait(500)
        end
    end
end)
