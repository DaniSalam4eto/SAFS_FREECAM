local resourceName = GetCurrentResourceName()
local fileName = "presets.json"

local presets = {}

local function loadPresets()
    local raw = LoadResourceFile(resourceName, fileName)
    if not raw or raw == "" then
        presets = {}
        SaveResourceFile(resourceName, fileName, json.encode(presets, {indent=true}), -1)
        return
    end
    local ok, data = pcall(json.decode, raw)
    if ok and type(data) == "table" then
        presets = data
    else
        presets = {}
    end
end

local function savePresets()
    SaveResourceFile(resourceName, fileName, json.encode(presets, {indent=true}), -1)
end

local function ownerKeyFor(src)
    local num = GetNumPlayerIdentifiers(src) or 0
    local fallback = "src:"..tostring(src)
    local best = nil
    for i=0,num-1 do
        local id = GetPlayerIdentifier(src, i)
        if id and id ~= "" then
            if string.sub(id,1,8) == "license:" then return id end
            if string.sub(id,1,6) == "steam:" then best = best or id end
            if string.sub(id,1,8) == "discord:" then best = best or id end
        end
    end
    return best or fallback
end

AddEventHandler("onResourceStart", function(res)
    if res == resourceName then
        loadPresets()
    end
end)

RegisterNetEvent("fc:savePreset", function(vehName, preset)
    local src = source
    if type(vehName) ~= "string" or type(preset) ~= "table" or type(preset.name) ~= "string" then return end
    local owner = ownerKeyFor(src)
    local vkey = string.lower(vehName)
    local skey = string.lower(preset.name)
    presets[owner] = presets[owner] or {}
    presets[owner][vkey] = presets[owner][vkey] or {}
    presets[owner][vkey][skey] = preset
    savePresets()
end)

RegisterNetEvent("fc:requestPreset", function(vehName, slot)
    local src = source
    if type(vehName) ~= "string" or type(slot) ~= "string" then return end
    local owner = ownerKeyFor(src)
    local vkey = string.lower(vehName)
    local skey = string.lower(slot)
    local p = presets[owner] and presets[owner][vkey] and presets[owner][vkey][skey] or nil
    TriggerClientEvent("fc:applyPreset", src, p, vehName)
end)
