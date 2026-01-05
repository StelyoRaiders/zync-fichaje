--[[
    ╔═══════════════════════════════════════════════════════════════════════════╗
    ║                         SISTEMA DE MARKERS                                 ║
    ╚═══════════════════════════════════════════════════════════════════════════╝
    
    Renderiza los puntos de fichaje y detecta la interacción del jugador.
]]

-- Cache de puntos cercanos para optimización
local NearbyPoints = {}
local LastCheckTime = 0
local CHECK_INTERVAL = 1000  -- Revisar cada segundo

-- Punto actual donde el jugador puede interactuar
local CurrentInteractPoint = nil
local CurrentInteractBusiness = nil

-- ═══════════════════════════════════════════════════════════════════════════════
-- INICIALIZACIÓN DE BLIPS
-- ═══════════════════════════════════════════════════════════════════════════════

CreateThread(function()
    while not ZyncFramework.Ready do
        Wait(100)
    end
    
    -- Crear blips para todos los puntos de fichaje
    for businessId, business in pairs(Config.Businesses) do
        if business.clockPoints then
            for _, point in ipairs(business.clockPoints) do
                if point.blip and point.blip.enabled then
                    local blip = AddBlipForCoord(point.coords.x, point.coords.y, point.coords.z)
                    
                    SetBlipSprite(blip, point.blip.sprite or 1)
                    SetBlipDisplay(blip, 4)
                    SetBlipScale(blip, point.blip.scale or 0.8)
                    SetBlipColour(blip, point.blip.color or 1)
                    SetBlipAsShortRange(blip, true)
                    
                    BeginTextCommandSetBlipName("STRING")
                    AddTextComponentString(point.blip.label or point.name)
                    EndTextCommandSetBlipName(blip)
                    
                    ZyncDebug("Blip creado: " .. point.name)
                end
            end
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- THREAD PRINCIPAL DE MARKERS
-- ═══════════════════════════════════════════════════════════════════════════════

CreateThread(function()
    while true do
        Wait(0)
        
        if not ZyncFramework.Ready then
            Wait(1000)
            goto continue
        end
        
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local currentTime = GetGameTimer()
        
        -- Actualizar lista de puntos cercanos periódicamente
        if currentTime - LastCheckTime > CHECK_INTERVAL then
            LastCheckTime = currentTime
            UpdateNearbyPoints(playerCoords)
        end
        
        -- Resetear punto de interacción
        local foundInteractPoint = false
        
        -- Procesar puntos cercanos
        for _, pointData in ipairs(NearbyPoints) do
            local point = pointData.point
            local businessId = pointData.businessId
            local distance = pointData.distance
            
            -- Actualizar distancia en tiempo real para puntos muy cercanos
            if distance < 50.0 then
                distance = #(playerCoords - point.coords)
            end
            
            -- Dibujar marker si está habilitado y estamos cerca
            if point.marker and point.marker.enabled and distance < 30.0 then
                DrawMarker(
                    point.marker.type or 1,
                    point.coords.x, point.coords.y, point.coords.z - 0.98,
                    0.0, 0.0, 0.0,
                    0.0, 0.0, 0.0,
                    point.marker.scale.x or 1.0,
                    point.marker.scale.y or 1.0,
                    point.marker.scale.z or 0.5,
                    point.marker.color.r or 255,
                    point.marker.color.g or 255,
                    point.marker.color.b or 255,
                    point.marker.color.a or 150,
                    point.marker.bobUpAndDown or false,
                    false,
                    2,
                    point.marker.rotate or false,
                    nil, nil,
                    false
                )
            end
            
            -- Verificar si podemos interactuar
            if distance < (point.radius or 2.0) then
                -- Verificar si el job tiene acceso
                local job = ZyncFramework.GetPlayerJob()
                local hasAccess = false
                
                if job then
                    hasAccess = CanAccessClockPoint(job.name, job.gradeName or job.grade, businessId)
                else
                    -- Standalone: permitir acceso si el negocio usa puntos
                    hasAccess = CanUseClockPoints(businessId)
                end
                
                if hasAccess then
                    foundInteractPoint = true
                    CurrentInteractPoint = point
                    CurrentInteractBusiness = businessId
                    
                    -- Dibujar texto de interacción
                    local business = GetBusiness(businessId)
                    local keyLabel = Config.InteractionKeyLabel or "E"
                    local text = GetMessage("pressToInteract", keyLabel, business.name)
                    
                    ZyncFramework.DrawText3D(point.coords.x, point.coords.y, point.coords.z + 0.5, text)
                    
                    -- Detectar tecla de interacción
                    if IsControlJustReleased(0, Config.InteractionKey) then
                        OpenClockPointUI(businessId, point)
                    end
                    
                    break  -- Solo un punto a la vez
                else
                    -- No tiene acceso pero está cerca - mostrar mensaje al presionar E
                    if IsControlJustReleased(0, Config.InteractionKey) then
                        ZyncFramework.Notify(GetMessage("noPermission"), "error")
                    end
                end
            end
        end
        
        if not foundInteractPoint then
            CurrentInteractPoint = nil
            CurrentInteractBusiness = nil
        end
        
        ::continue::
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- FUNCIONES DE OPTIMIZACIÓN
-- ═══════════════════════════════════════════════════════════════════════════════

function UpdateNearbyPoints(playerCoords)
    NearbyPoints = {}
    
    for businessId, business in pairs(Config.Businesses) do
        -- Solo procesar negocios que permitan puntos de fichaje
        if not CanUseClockPoints(businessId) then
            goto nextBusiness
        end
        
        if business.clockPoints then
            for _, point in ipairs(business.clockPoints) do
                local distance = #(playerCoords - point.coords)
                
                -- Solo añadir si está relativamente cerca (50 unidades para markers, menos para interacción)
                if distance < 100.0 then
                    table.insert(NearbyPoints, {
                        businessId = businessId,
                        point = point,
                        distance = distance
                    })
                end
            end
        end
        
        ::nextBusiness::
    end
    
    -- Ordenar por distancia
    table.sort(NearbyPoints, function(a, b)
        return a.distance < b.distance
    end)
    
    ZyncDebug("Puntos cercanos: " .. #NearbyPoints)
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- OPTIMIZACIÓN: SLEEP CUANDO NO HAY PUNTOS CERCANOS
-- ═══════════════════════════════════════════════════════════════════════════════

CreateThread(function()
    while true do
        if #NearbyPoints == 0 then
            Wait(500)  -- Dormir más si no hay puntos cercanos
        else
            Wait(0)
        end
    end
end)
