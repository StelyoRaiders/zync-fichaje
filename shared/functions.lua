--[[
    ╔═══════════════════════════════════════════════════════════════════════════╗
    ║                      FUNCIONES COMPARTIDAS                                 ║
    ╚═══════════════════════════════════════════════════════════════════════════╝
]]

ZyncFramework = {}
ZyncFramework.Name = "unknown"
ZyncFramework.Ready = false

-- ═══════════════════════════════════════════════════════════════════════════════
-- UTILIDADES
-- ═══════════════════════════════════════════════════════════════════════════════

-- Debug print
function ZyncDebug(...)
    if Config.Debug then
        print("[Zync Debug]", ...)
    end
end

-- Print info
function ZyncPrint(...)
    print("[Zync]", ...)
end

-- Print error
function ZyncError(...)
    print("[Zync ERROR]", ...)
end

-- Formatear tiempo en HH:MM:SS
function FormatTime(seconds)
    if not seconds or seconds < 0 then
        return "00:00:00"
    end
    
    local hours = math.floor(seconds / 3600)
    local mins = math.floor((seconds % 3600) / 60)
    local secs = math.floor(seconds % 60)
    
    return string.format("%02d:%02d:%02d", hours, mins, secs)
end

-- Formatear tiempo largo (Xh Xm Xs)
function FormatTimeLong(seconds)
    if not seconds or seconds < 0 then
        return "0 segundos"
    end
    
    local hours = math.floor(seconds / 3600)
    local mins = math.floor((seconds % 3600) / 60)
    local secs = math.floor(seconds % 60)
    
    local parts = {}
    if hours > 0 then
        table.insert(parts, hours .. "h")
    end
    if mins > 0 then
        table.insert(parts, mins .. "m")
    end
    if secs > 0 or #parts == 0 then
        table.insert(parts, secs .. "s")
    end
    
    return table.concat(parts, " ")
end

-- Obtener mensaje de configuración
function GetMessage(key, ...)
    local msg = Config.Messages[key]
    if not msg then
        return key
    end
    
    local args = {...}
    if #args > 0 then
        return string.format(msg, ...)
    end
    return msg
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- FUNCIONES DE NEGOCIOS
-- ═══════════════════════════════════════════════════════════════════════════════

-- Obtener negocio por ID
function GetBusiness(businessId)
    return Config.Businesses[businessId]
end

-- Obtener todos los IDs de negocios
function GetBusinessIds()
    local ids = {}
    for id, _ in pairs(Config.Businesses) do
        table.insert(ids, id)
    end
    return ids
end

-- Verificar si un job tiene acceso a un negocio específico
function JobHasAccessToBusiness(jobName, jobGrade, businessId)
    local business = Config.Businesses[businessId]
    if not business then
        return false, nil
    end
    
    local jobConfig = business.jobs[jobName]
    if not jobConfig then
        return false, nil
    end
    
    -- Verificar rangos si están especificados
    if jobConfig.ranks and type(jobConfig.ranks) == "table" then
        local hasRank = false
        for _, rank in ipairs(jobConfig.ranks) do
            if rank == jobGrade then
                hasRank = true
                break
            end
        end
        if not hasRank then
            return false, nil
        end
    end
    
    return true, jobConfig.category
end

-- Obtener negocios disponibles para un job
function GetAvailableBusinessesForJob(jobName, jobGrade)
    local available = {}
    
    for businessId, business in pairs(Config.Businesses) do
        local hasAccess, category = JobHasAccessToBusiness(jobName, jobGrade, businessId)
        if hasAccess then
            table.insert(available, {
                id = businessId,
                name = business.name,
                category = category,
                mode = business.mode or Config.DefaultMode
            })
        end
    end
    
    return available
end

-- Verificar si un punto de fichaje permite cierto job
function CanAccessClockPoint(jobName, jobGrade, businessId)
    local business = Config.Businesses[businessId]
    if not business then
        return false
    end
    
    -- Verificar modo
    local mode = business.mode or Config.DefaultMode
    if mode == "command" then
        return false  -- Este negocio solo permite comandos
    end
    
    return JobHasAccessToBusiness(jobName, jobGrade, businessId)
end

-- Verificar si un negocio permite comandos
function CanUseCommands(businessId)
    local business = Config.Businesses[businessId]
    if not business then
        return false
    end
    
    local mode = business.mode or Config.DefaultMode
    return mode == "command" or mode == "both"
end

-- Verificar si un negocio permite puntos de fichaje
function CanUseClockPoints(businessId)
    local business = Config.Businesses[businessId]
    if not business then
        return false
    end
    
    local mode = business.mode or Config.DefaultMode
    return mode == "point" or mode == "both"
end
