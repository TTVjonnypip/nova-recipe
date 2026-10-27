local cam, previewPed
local inSelection = false
local settings = {} -- sent by the server (from config.lua)

-- ─────────────────────────────────────────────
--  Preview ped / camera
-- ─────────────────────────────────────────────
local function deletePreviewPed()
    if previewPed and DoesEntityExist(previewPed) then
        DeleteEntity(previewPed)
    end
    previewPed = nil
end

local function spawnPreviewPed(model, skin)
    deletePreviewPed()

    model = tonumber(model) or (type(model) == 'string' and joaat(model)) or Config.DefaultModels[0]
    if not IsModelInCdimage(model) then model = Config.DefaultModels[0] end
    lib.requestModel(model, 10000)

    local p = Config.PreviewPed
    local ped = CreatePed(2, model, p.x, p.y, p.z - 0.98, p.w, false, true)
    SetModelAsNoLongerNeeded(model)

    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanRagdoll(ped, false)

    if skin and GetResourceState('illenium-appearance') == 'started' then
        local ok, appearance = pcall(json.decode, skin)
        if ok and appearance then
            exports['illenium-appearance']:setPedAppearance(ped, appearance)
        end
    else
        SetPedDefaultComponentVariation(ped)
    end

    if Config.PreviewScenario then
        TaskStartScenarioInPlace(ped, Config.PreviewScenario, 0, true)
    end

    previewPed = ped
end

local function createCamera()
    local c, p = Config.CameraCoords, Config.PreviewPed
    cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', c.x, c.y, c.z, 0.0, 0.0, 0.0, Config.CameraFov, false, 0)
    PointCamAtCoord(cam, p.x, p.y, p.z + 0.1)
    SetCamActive(cam, true)
    RenderScriptCams(true, false, 0, true, true)
end

local function destroyCamera()
    if not cam then return end
    RenderScriptCams(false, false, 0, true, true)
    DestroyCam(cam, false)
    cam = nil
end

-- ─────────────────────────────────────────────
--  Selection open / close
-- ─────────────────────────────────────────────
local function waitForCollision(ped, coords)
    RequestCollisionAtCoord(coords.x, coords.y, coords.z)
    local timeout = GetGameTimer() + 5000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < timeout do
        Wait(0)
    end
end

local function openSelection()
    if inSelection then return end
    inSelection = true

    DoScreenFadeOut(0)
    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()

    local ped = PlayerPedId()
    local h = Config.HiddenPlayer
    SetEntityCoordsNoOffset(ped, h.x, h.y, h.z, false, false, false)
    FreezeEntityPosition(ped, true)
    SetEntityVisible(ped, false, false)
    SetEntityInvincible(ped, true)
    DisplayRadar(false)

    RequestCollisionAtCoord(Config.PreviewPed.x, Config.PreviewPed.y, Config.PreviewPed.z)
    Wait(500)

    local data = lib.callback.await('qbx_charcreate:getCharacters', false)
    settings = data or {}
    createCamera()

    SendNUIMessage({ action = 'open', data = data })
    SetNuiFocus(true, true)

    Wait(400)
    DoScreenFadeIn(600)
end

local function closeSelection()
    SendNUIMessage({ action = 'close' })
    SetNuiFocus(false, false)
    deletePreviewPed()
    destroyCamera()
    inSelection = false
end

local function releasePlayer(coords)
    local ped = PlayerPedId()
    SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z, false, false, false)
    SetEntityHeading(ped, coords.w or 0.0)
    waitForCollision(ped, coords)
    FreezeEntityPosition(ped, false)
    SetEntityVisible(ped, true, false)
    SetEntityInvincible(ped, false)
    DisplayRadar(true)
end

-- Tell nova_core the player is in the world. Nova then fires nova:client:onPlayerLoaded
-- (and QBCore:Client:OnPlayerLoaded through its bridge) - don't fire those here.
local function fireLoadedEvents()
    TriggerServerEvent('nova:server:onPlayerSpawned')
    TriggerEvent('qb-weathersync:client:EnableSync')
end

local function isStarted(res) return GetResourceState(res):find('start') ~= nil end

-- Hand the (still invisible) player over to an apartment / spawn resource,
-- which handles position, visibility, fades and the loaded events itself.
local function prepareHandOff()
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)
    SetEntityInvincible(ped, false)
    DisplayRadar(true)
end

local function setFreemodeModel(gender)
    local model = Config.DefaultModels[tonumber(gender) or 0]
    lib.requestModel(model, 10000)
    SetPlayerModel(PlayerId(), model)
    SetModelAsNoLongerNeeded(model)
    SetPedDefaultComponentVariation(PlayerPedId())
end

-- ─────────────────────────────────────────────
--  NUI callbacks
-- ─────────────────────────────────────────────
RegisterNUICallback('preview', function(data, cb)
    cb('ok')
    if data.citizenid then
        local skin = lib.callback.await('qbx_charcreate:getSkin', false, data.citizenid)
        spawnPreviewPed(skin and skin.model, skin and skin.skin)
    else
        spawnPreviewPed(Config.DefaultModels[tonumber(data.gender) or 0])
    end
end)

RegisterNUICallback('clearPreview', function(_, cb)
    cb('ok')
    deletePreviewPed()
end)

RegisterNUICallback('play', function(data, cb)
    local ok, position, forceLast = lib.callback.await('qbx_charcreate:loadCharacter', false, data.citizenid)
    cb({ ok = ok })
    if not ok then return end

    DoScreenFadeOut(500)
    Wait(600)
    closeSelection()

    local pos = (position and position.x) and vec4(position.x, position.y, position.z, position.w or 0.0)
        or Config.DefaultSpawn

    -- nova_spawn shows the location picker, then handles position, fades and the loaded event
    if Config.SpawnMode == 'auto' and isStarted('nova_spawn') then
        prepareHandOff()
        TriggerEvent('nova_spawn:client:open', {
            isNew = false,
            position = { x = pos.x, y = pos.y, z = pos.z, w = pos.w },
            forceLast = forceLast,
        })
        return
    end

    releasePlayer(pos)
    fireLoadedEvents()
    Wait(250)
    DoScreenFadeIn(800)
end)

RegisterNUICallback('create', function(data, cb)
    local ok, err, newData = lib.callback.await('qbx_charcreate:createCharacter', false, data)
    cb({ ok = ok, error = err })
    if not ok then return end

    DoScreenFadeOut(500)
    Wait(600)
    closeSelection()
    setFreemodeModel(data.gender)

    releasePlayer(Config.NewCharacterSpawn)
    fireLoadedEvents()
    Wait(500)
    DoScreenFadeIn(800)

    if Config.FirstCharacterEvent then
        TriggerEvent(Config.FirstCharacterEvent)
    end
end)

RegisterNUICallback('delete', function(data, cb)
    local ok, characters = lib.callback.await('qbx_charcreate:deleteCharacter', false, data.citizenid)
    if ok then deletePreviewPed() end
    cb({ ok = ok, characters = characters })
end)

RegisterNUICallback('disconnect', function(_, cb)
    cb('ok')
    TriggerServerEvent('qbx_charcreate:server:disconnect')
end)

-- ─────────────────────────────────────────────
--  Entry points
-- ─────────────────────────────────────────────
RegisterNetEvent('qbx_charcreate:client:open', openSelection)
-- nova_core's /logout sends this
RegisterNetEvent('nova:client:onPlayerUnload', function()
    if GetInvokingResource() then return end -- only accept it from the server
    Wait(500)
    openSelection()
end)

CreateThread(function()
    while not NetworkIsSessionStarted() do Wait(100) end
    -- nova_multicharacter's job is done by this script; stop spawnmanager auto-spawning
    if GetResourceState('spawnmanager') == 'started' then
        pcall(function() exports.spawnmanager:setAutoSpawn(false) end)
    end
    Wait(250)
    if LocalPlayer.state.isLoggedIn then return end -- resource restart while playing
    openSelection()
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if inSelection then
        SetNuiFocus(false, false)
        deletePreviewPed()
        destroyCamera()
    end
end)
