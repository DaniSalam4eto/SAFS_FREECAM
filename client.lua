local AUTO_SLOT = "AUTO"
local BONE_HEAD = 31086

local FOV_MIN = 15.0
local FOV_MAX = 120.0
local FOV_RATE_PER_SEC = 35.0

local AXIS_NONE = 0.0

local CTRL_ALT = 19
local CTRL_SLOW = 36
local CTRL_FAST = 21
local CTRL_UP = 38
local CTRL_DOWN = 44
local CTRL_FWD = 32
local CTRL_BACK = 33
local CTRL_LEFT = 34
local CTRL_RIGHT = 35
local CTRL_ZOOM_IN = 15
local CTRL_ZOOM_OUT = 14
local CTRL_TOGGLE = 178
local CTRL_MOUSE_X = 1

local KEY_NUMS = {
    ["1"] = 157, ["2"] = 158, ["3"] = 160, ["4"] = 164, ["5"] = 165,
    ["6"] = 159, ["7"] = 161, ["8"] = 162, ["9"] = 163, ["0"] = 217
}

local inFreecam = false
local lockMode = false
local cam = nil
local pos = vector3(0.0, 0.0, 0.0)
local yaw = 0.0
local pitch = 0.0
local roll = 0.0
local moveSpeed = Config.DefaultMoveSpeed
local fov = Config.StartFov
local activePreset = nil
local activeVehName = nil
local activeSlot = nil
local lastVeh = nil
local wasInVeh = false


local function clamp(v, mn, mx)
    if v < mn then return mn elseif v > mx then return mx else return v end
end

local function wrapDeg(d)
    d = d % 360.0
    if d > 180.0 then d = d - 360.0 end
    return d
end

local function rightFromYaw(y)
    local r = math.rad(y)
    return vector3(math.cos(r), math.sin(r), 0.0)
end

local function fwdFlat(y)
    local r = math.rad(y)
    return vector3(-math.sin(r), math.cos(r), 0.0)
end

local function pressed(code)
    return IsControlJustPressed(0, code) or IsDisabledControlJustPressed(0, code)
end

local function held(code)
    return IsControlPressed(0, code) or IsDisabledControlPressed(0, code)
end

local function ped()
    return PlayerPedId()
end

local function isInVehicle()
    return IsPedInAnyVehicle(ped(), false)
end

local function veh()
    if not isInVehicle() then return nil end
    local v = GetVehiclePedIsIn(ped(), false)
    return (v ~= 0) and v or nil
end

local function vehDisplayName(v)
    local model = GetEntityModel(v)
    local disp = GetDisplayNameFromVehicleModel(model) or tostring(model)
    local label = GetLabelText(disp)
    local name = (label and label ~= "NULL" and label ~= "") and label or disp
    return string.lower(name)
end

local function ensureCamFirstPerson()
    local p = ped()
    local v = veh()
    if not v then return false end

    local head = GetPedBoneCoords(p, BONE_HEAD, 0.0, 0.0, 0.0)
    pos = vector3(head.x, head.y, head.z)

    local rot = GetEntityRotation(v, 2)
    yaw = rot.z
    pitch = AXIS_NONE
    roll = AXIS_NONE
    fov = Config.StartFov

    if cam and DoesCamExist(cam) then
        SetCamCoord(cam, pos.x, pos.y, pos.z)
        SetCamRot(cam, pitch, roll, yaw, 2)
        SetCamFov(cam, fov)
        return true
    end

    cam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    SetCamCoord(cam, pos.x, pos.y, pos.z)
    SetCamRot(cam, pitch, roll, yaw, 2)
    SetCamFov(cam, fov)
    return true
end

local function setPlayerHidden(hidden)
    local p = ped()
    SetEntityVisible(p, not hidden, false)
    SetEntityCollision(p, not hidden, not hidden)
    FreezeEntityPosition(p, hidden)
    SetPlayerInvincible(PlayerId(), hidden)
    DisplayRadar(not hidden)
end

local function renderCam(enable)
    RenderScriptCams(enable, false, 0, true, true)
end

local function makePresetFromSnap(v, slotName, snapPos, snapYaw, snapPitch, snapFov)
    local off = GetOffsetFromEntityGivenWorldCoords(v, snapPos.x, snapPos.y, snapPos.z)
    local rot = GetEntityRotation(v, 2)
    local yawRel = wrapDeg((snapYaw or 0.0) - (rot.z or 0.0))
    local pitchRel = wrapDeg((snapPitch or 0.0) - (rot.x or 0.0))

    return {
        name = tostring(slotName),
        offset = { x = off.x, y = off.y, z = off.z },
        yawRel = yawRel,
        pitchRel = pitchRel,
        fov = snapFov or Config.StartFov
    }
end

local function captureForSave()
    local v = veh()
    if not v then return nil end

    if inFreecam and cam then
        return { pos = pos, yaw = yaw, pitch = pitch, fov = fov }
    else
        local head = GetPedBoneCoords(ped(), BONE_HEAD, 0.0, 0.0, 0.0)
        local h = vector3(head.x, head.y, head.z)
        local rot = GetEntityRotation(v, 2)
        return { pos = h, yaw = rot.z, pitch = rot.x, fov = Config.StartFov }
    end
end

local function saveSlot(slot)
    local v = veh()
    if not v then return end
    local snap = captureForSave()
    if not snap then return end
    local preset = makePresetFromSnap(v, slot, snap.pos, snap.yaw, snap.pitch, snap.fov)
    TriggerServerEvent("fc:savePreset", vehDisplayName(v), preset)
end

local function requestSlot(slot)
    local v = veh()
    if not v then return end
    TriggerServerEvent("fc:requestPreset", vehDisplayName(v), tostring(slot))
end

local function chosenAutosaveSlot()
    if lockMode and activeSlot and string.match(activeSlot, "^%w+$") then
        return activeSlot
    end
    return AUTO_SLOT
end

local function autoSaveForVehicle(v)
    if not v or not DoesEntityExist(v) then return end
    local preset = makePresetFromSnap(v, chosenAutosaveSlot(), pos, yaw, pitch, fov)
    TriggerServerEvent("fc:savePreset", vehDisplayName(v), preset)
end

local function enterMode(isLock, preset, vehName)
    if not isInVehicle() then return end

    inFreecam = true
    lockMode = isLock or false

    ensureCamFirstPerson()
    renderCam(true)
    setPlayerHidden(true)

    if isLock then
        activePreset = preset
        activeVehName = vehName
        activeSlot = preset and preset.name or nil
    else
        local v = veh()
        activeVehName = v and vehDisplayName(v) or nil
        activePreset = nil
        activeSlot = nil
    end
end

local function exitCam(doAutosave)
    if doAutosave then
        local v = lastVeh or veh()
        if v then autoSaveForVehicle(v) end
    end

    inFreecam = false
    lockMode = false

    if cam and DoesCamExist(cam) then
        renderCam(false)
        DestroyCam(cam, false)
        cam = nil
    else
        renderCam(false)
    end

    setPlayerHidden(false)
    activePreset = nil
    activeVehName = nil
    activeSlot = nil
end

RegisterNetEvent("fc:applyPreset", function(preset, vehName)
    if type(preset) ~= "table" then return end
    enterMode(true, preset, vehName)
end)

AddEventHandler("onResourceStop", function(name)
    if name ~= GetCurrentResourceName() then return end
    if inFreecam then
        local v = lastVeh or veh()
        if v then autoSaveForVehicle(v) end
    end
end)

CreateThread(function()
    while true do
        local vnow = veh()
        if vnow ~= nil then lastVeh = vnow end

        local nowIn = isInVehicle()
        if wasInVeh and not nowIn then
            if lastVeh and inFreecam then autoSaveForVehicle(lastVeh) end
        end
        wasInVeh = nowIn

        if inFreecam and cam and DoesCamExist(cam) then
            if not isInVehicle() then
                exitCam(true)
            else
                if lockMode and activePreset then
                    local v = veh()
                    if v then
                        local world = GetOffsetFromEntityInWorldCoords(v, activePreset.offset.x, activePreset.offset.y, activePreset.offset.z)
                        pos = vector3(world.x, world.y, world.z)
                        local rot = GetEntityRotation(v, 2)
                        yaw = wrapDeg((rot.z or 0.0) + (activePreset.yawRel or 0.0))
                        pitch = wrapDeg((rot.x or 0.0) + (activePreset.pitchRel or 0.0))
                        roll = rot.y or AXIS_NONE
                        SetCamCoord(cam, pos.x, pos.y, pos.z)
                        SetCamRot(cam, pitch, roll, yaw, 2)
                        SetCamFov(cam, activePreset.fov or fov)
                    end
                else
                    DisableAllControlActions(0)
                    EnableControlAction(0, 245, true)
                    EnableControlAction(0, 200, true)

                    local lx = GetDisabledControlNormal(0, CTRL_MOUSE_X)
                    yaw = yaw - (lx * Config.MouseSensitivity)

                    local speed = moveSpeed
                    if IsDisabledControlPressed(0, CTRL_FAST) then
                        speed = speed * Config.FastMultiplier
                    elseif IsDisabledControlPressed(0, CTRL_SLOW) then
                        speed = speed * Config.SlowMultiplier
                    end

                    local dt = GetFrameTime()
                    local f = fwdFlat(yaw)
                    local r = rightFromYaw(yaw)

                    if IsDisabledControlPressed(0, CTRL_FWD) then pos = pos + (f * speed * dt) end
                    if IsDisabledControlPressed(0, CTRL_BACK) then pos = pos - (f * speed * dt) end
                    if IsDisabledControlPressed(0, CTRL_LEFT) then pos = pos - (r * speed * dt) end
                    if IsDisabledControlPressed(0, CTRL_RIGHT) then pos = pos + (r * speed * dt) end
                    if IsDisabledControlPressed(0, CTRL_DOWN) then pos = pos - (vector3(0.0, 0.0, 1.0) * speed * dt) end
                    if IsDisabledControlPressed(0, CTRL_UP) then pos = pos + (vector3(0.0, 0.0, 1.0) * speed * dt) end

                    if IsDisabledControlPressed(0, CTRL_ZOOM_OUT) then
                        fov = clamp(fov + (FOV_RATE_PER_SEC * dt), FOV_MIN, FOV_MAX)
                    end
                    if IsDisabledControlPressed(0, CTRL_ZOOM_IN) then
                        fov = clamp(fov - (FOV_RATE_PER_SEC * dt), FOV_MIN, FOV_MAX)
                    end

                    local v = veh()
                    if v then
                        local vx, vy, vz = table.unpack(GetEntityVelocity(v))
                        pos = pos + vector3(vx, vy, vz) * dt
                    end

                    SetCamCoord(cam, pos.x, pos.y, pos.z)
                    SetCamRot(cam, AXIS_NONE, AXIS_NONE, yaw, 2)
                    SetCamFov(cam, fov)
                end
            end
        end

        local altHeld = held(CTRL_ALT)
        local ctrlHeld = held(CTRL_SLOW)

        for n, code in pairs(KEY_NUMS) do
            if altHeld and (IsDisabledControlJustPressed(0, code) or IsControlJustPressed(0, code)) then
                if isInVehicle() then saveSlot(n) end
            elseif ctrlHeld and (IsDisabledControlJustPressed(0, code) or IsControlJustPressed(0, code)) then
                if isInVehicle() then
                    if inFreecam and lockMode and activeSlot == n then
                        exitCam(true)
                    else
                        requestSlot(n)
                    end
                end
            end
        end

        if pressed(CTRL_TOGGLE) then
            if inFreecam then
                exitCam(true)
            else
                if isInVehicle() then enterMode(false) end
            end
        end

        if (held(CTRL_SLOW) and (IsDisabledControlJustPressed(0, 172) or IsControlJustPressed(0, 172))) then
            moveSpeed = clamp(moveSpeed + 0.5, 0.1, 200.0)
        end
        if (held(CTRL_SLOW) and (IsDisabledControlJustPressed(0, 173) or IsControlJustPressed(0, 173))) then
            moveSpeed = clamp(moveSpeed - 0.5, 0.1, 200.0)
        end

        Wait(0)
    end
end)
