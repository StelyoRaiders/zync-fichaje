--[[
    ╔═══════════════════════════════════════════════════════════════════════════╗
    ║                         API DE ZYNC (SERVIDOR)                             ║
    ╚═══════════════════════════════════════════════════════════════════════════╝
    
    Comunicación con la API de Zync para fichajes y vinculaciones.
]]

ZyncAPI = {}

-- ═══════════════════════════════════════════════════════════════════════════════
-- FUNCIONES DE API
-- ═══════════════════════════════════════════════════════════════════════════════

-- Realizar petición HTTP a la API de Zync
function ZyncAPI.Request(businessId, endpoint, method, data, callback)
    local business = GetBusiness(businessId)
    if not business then
        ZyncError("Negocio no encontrado: " .. tostring(businessId))
        if callback then callback(false, {error = "business_not_found"}) end
        return
    end
    
    local apiUrl = business.api.url or "https://api.zyncbot.net"
    local apiKey = business.api.key
    
    if not apiKey or apiKey == "" or string.find(apiKey, "XXXX") then
        ZyncError("API key no configurada para negocio: " .. businessId)
        if callback then callback(false, {error = "api_key_not_configured"}) end
        return
    end
    
    local url = apiUrl .. "/api/fivem" .. endpoint
    
    local headers = {
        ["Content-Type"] = "application/json",
        ["X-Zync-FiveM-Key"] = apiKey,
        ["User-Agent"] = "ZyncFiveM/1.0"
    }
    
    local body = nil
    if data then
        body = json.encode(data)
    end
    
    ZyncDebug("API Request: " .. method .. " " .. endpoint)
    
    PerformHttpRequest(url, function(statusCode, responseText, responseHeaders)
        ZyncDebug("API Response: " .. tostring(statusCode))
        
        if statusCode == 200 or statusCode == 201 then
            local response = json.decode(responseText)
            if callback then callback(true, response) end
        else
            local errorResponse = nil
            pcall(function()
                errorResponse = json.decode(responseText)
            end)
            
            -- No loguear como error si es un 404 con respuesta válida (ej: not_clocked_in)
            if statusCode ~= 404 or not errorResponse then
                ZyncError("API Error " .. tostring(statusCode) .. ": " .. tostring(responseText))
            else
                ZyncDebug("API Response 404: " .. tostring(responseText))
            end
            
            if callback then 
                callback(false, errorResponse or {
                    error = "api_error",
                    statusCode = statusCode,
                    message = responseText
                }) 
            end
        end
    end, method, body, headers)
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- ENDPOINTS ESPECÍFICOS
-- ═══════════════════════════════════════════════════════════════════════════════

-- Fichar entrada
-- charName y charRank son opcionales (para integración FiveM)
function ZyncAPI.ClockIn(businessId, identifier, category, callback, charName, charRank)
    ZyncAPI.Request(businessId, "/clock-in", "POST", {
        identifier = identifier,
        category = category,
        charName = charName,     -- Nombre del personaje FiveM (opcional)
        charRank = charRank      -- Rango del job (opcional)
    }, callback)
end

-- Fichar salida
function ZyncAPI.ClockOut(businessId, identifier, category, callback)
    ZyncAPI.Request(businessId, "/clock-out", "POST", {
        identifier = identifier,
        category = category
    }, callback)
end

-- Obtener estado (con categoría opcional para obtener tiempo específico)
function ZyncAPI.GetStatus(businessId, identifier, category, callback)
    -- Si category es una función, es el callback (compatibilidad hacia atrás)
    if type(category) == "function" then
        callback = category
        category = nil
    end
    
    local data = {
        identifier = identifier
    }
    
    if category then
        data.category = category
    end
    
    ZyncAPI.Request(businessId, "/status", "POST", data, callback)
end

-- Verificar vinculación
function ZyncAPI.CheckLink(businessId, identifier, callback)
    ZyncAPI.Request(businessId, "/check-link", "POST", {
        identifier = identifier
    }, callback)
end

-- Vincular cuenta
function ZyncAPI.Link(businessId, code, identifier, identifierType, callback)
    ZyncAPI.Request(businessId, "/link", "POST", {
        code = code,
        identifier = identifier,
        identifierType = identifierType
    }, callback)
end

-- Validar API key
function ZyncAPI.ValidateKey(businessId, callback)
    local business = GetBusiness(businessId)
    if not business then
        ZyncError("ValidateKey: Negocio no encontrado: " .. tostring(businessId))
        if callback then callback(false, {error = "business_not_found"}) end
        return
    end
    
    local apiUrl = business.api.url or "https://api.zyncbot.net"
    local apiKey = business.api.key
    
    ZyncDebug("ValidateKey: URL=" .. apiUrl .. "/api/fivem/validate")
    ZyncDebug("ValidateKey: Key=" .. string.sub(apiKey, 1, 15) .. "...")
    
    PerformHttpRequest(apiUrl .. "/api/fivem/validate", function(statusCode, responseText, headers)
        ZyncDebug("ValidateKey: StatusCode=" .. tostring(statusCode))
        ZyncDebug("ValidateKey: Response=" .. tostring(responseText))
        
        if statusCode == 200 then
            local success, response = pcall(json.decode, responseText)
            if success and response then
                ZyncDebug("ValidateKey: valid=" .. tostring(response.valid))
                if callback then callback(response.valid, response) end
            else
                ZyncError("ValidateKey: Error parsing JSON: " .. tostring(responseText))
                if callback then callback(false, {error = "json_parse_error"}) end
            end
        else
            ZyncError("ValidateKey: HTTP Error " .. tostring(statusCode) .. ": " .. tostring(responseText))
            if callback then callback(false, {error = "validation_failed", statusCode = statusCode}) end
        end
    end, "POST", json.encode({apiKey = apiKey}), {
        ["Content-Type"] = "application/json",
        ["User-Agent"] = "ZyncFiveM/1.0 (FiveM Server)",
        ["Accept"] = "application/json"
    })
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- CACHÉ LOCAL
-- ═══════════════════════════════════════════════════════════════════════════════

local LinkCache = {}
local StatusCache = {}

local CACHE_TTL = 60000  -- 60 segundos

-- Obtener del caché
function ZyncAPI.GetCachedLink(businessId, identifier)
    local key = businessId .. ":" .. identifier
    local cached = LinkCache[key]
    
    if cached and (GetGameTimer() - cached.time) < CACHE_TTL then
        return cached.data
    end
    
    return nil
end

-- Guardar en caché
function ZyncAPI.CacheLink(businessId, identifier, data)
    local key = businessId .. ":" .. identifier
    LinkCache[key] = {
        time = GetGameTimer(),
        data = data
    }
end

-- Limpiar caché
function ZyncAPI.ClearCache(businessId, identifier)
    if identifier then
        local key = businessId .. ":" .. identifier
        LinkCache[key] = nil
        StatusCache[key] = nil
    else
        -- Limpiar todo el caché del negocio
        for key, _ in pairs(LinkCache) do
            if string.find(key, "^" .. businessId .. ":") then
                LinkCache[key] = nil
            end
        end
        for key, _ in pairs(StatusCache) do
            if string.find(key, "^" .. businessId .. ":") then
                StatusCache[key] = nil
            end
        end
    end
end
