local isOpen = false
local previewVeh = nil
local previewToken = 0
local cam = nil
local shopPed = nil

local function notify(message, kind)
    lib.notify({ description = message, type = kind or 'inform' })
end

----------------------------------------------------------------------
-- Blip
----------------------------------------------------------------------
CreateThread(function()
    local d = Config.Dealership
    if not d.blip.enabled then return end

    local blip = AddBlipForCoord(d.coords.x, d.coords.y, d.coords.z)
    SetBlipSprite(blip, d.blip.sprite)
    SetBlipColour(blip, d.blip.color)
    SetBlipScale(blip, d.blip.scale)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(d.name)
    EndTextCommandSetBlipName(blip)
end)

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------
local function loadModel(hash, timeout)
    if not IsModelInCdimage(hash) then return false end
    local ok = pcall(lib.requestModel, hash, timeout or 5000)
    return ok and HasModelLoaded(hash)
end

local function deletePreview()
    previewToken = previewToken + 1
    if previewVeh and DoesEntityExist(previewVeh) then
        DeleteEntity(previewVeh)
    end
    previewVeh = nil
end

local function showPreview(model)
    deletePreview()
    if not model then return end

    local token = previewToken
    local hash = joaat(model)

    if not IsModelAVehicle(hash) or not loadModel(hash) then
        notify('That model is not available on this server.', 'error')
        return
    end

    -- A newer preview was requested while this one was loading
    if token ~= previewToken or not isOpen then
        SetModelAsNoLongerNeeded(hash)
        return
    end

    local c = Config.Preview.coords
    previewVeh = CreateVehicle(hash, c.x, c.y, c.z, c.w, false, false)
    SetModelAsNoLongerNeeded(hash)
    SetVehicleOnGroundProperly(previewVeh)
    FreezeEntityPosition(previewVeh, true)
    SetEntityInvincible(previewVeh, true)
    SetVehicleDoorsLocked(previewVeh, 2)
    SetVehicleNumberPlateText(previewVeh, 'FOR SALE')
end

local function createCamera()
    local p, o = Config.Preview.coords, Config.Preview.camOffset
    cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', p.x + o.x, p.y + o.y, p.z + o.z, 0.0, 0.0, 0.0, Config.Preview.camFov, false, 0)
    PointCamAtCoord(cam, p.x, p.y, p.z + 0.5)
    SetCamActive(cam, true)
    RenderScriptCams(true, true, 700, true, true)
end

local function destroyCamera()
    if cam then
        RenderScriptCams(false, true, 500, true, true)
        DestroyCam(cam, false)
        cam = nil
    end
end

local function closeShop()
    if not isOpen then return end
    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    deletePreview()
    destroyCamera()
    DisplayRadar(true)
    FreezeEntityPosition(cache.ped, false)
end

local function openShop()
    if isOpen then return end

    if cache.vehicle then
        notify('Step out of your vehicle first.', 'error')
        return
    end

    local data = lib.callback.await('fp-dealership:server:getData', false)
    if not data or isOpen then return end

    isOpen = true
    FreezeEntityPosition(cache.ped, true)
    DisplayRadar(false)
    createCamera()
    SetNuiFocus(true, true)

    SendNUIMessage({
        action = 'open',
        name = Config.Dealership.name,
        currency = Config.Currency,
        vehicles = data.vehicles,
        isAdmin = data.isAdmin,
        cash = data.cash,
        bank = data.bank,
    })
end

local function spawnPurchased(model, plate)
    local hash = joaat(model)
    if not loadModel(hash, 8000) then
        notify('Your vehicle is in your garage (model failed to load).', 'inform')
        return
    end

    local s = Config.Dealership.purchaseSpawn
    local veh = CreateVehicle(hash, s.x, s.y, s.z, s.w, true, false)
    SetModelAsNoLongerNeeded(hash)

    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleNumberPlateText(veh, plate)
    SetVehicleHasBeenOwnedByPlayer(veh, true)
    SetVehicleOnGroundProperly(veh)
    TaskWarpPedIntoVehicle(cache.ped, veh, -1)

    -- Wait for the vehicle to be networked so the server can find it
    local deadline = GetGameTimer() + 3000
    while not NetworkGetEntityIsNetworked(veh) and GetGameTimer() < deadline do
        Wait(0)
    end

    if NetworkGetEntityIsNetworked(veh) then
        TriggerServerEvent('fp-dealership:server:claimKeys', NetworkGetNetworkIdFromEntity(veh), plate)
    end

    if Config.OnVehicleSpawned then
        Config.OnVehicleSpawned(veh, plate)
    end
end

----------------------------------------------------------------------
-- NUI callbacks
----------------------------------------------------------------------
RegisterNUICallback('close', function(_, cb)
    closeShop()
    cb({})
end)

RegisterNUICallback('preview', function(data, cb)
    cb({})
    showPreview(data.model)
end)

RegisterNUICallback('rotate', function(data, cb)
    if previewVeh and DoesEntityExist(previewVeh) then
        SetEntityHeading(previewVeh, GetEntityHeading(previewVeh) - (tonumber(data.delta) or 0.0))
    end
    cb({})
end)

RegisterNUICallback('buy', function(data, cb)
    local s = Config.Dealership.purchaseSpawn
    if IsAnyVehicleNearPoint(s.x, s.y, s.z, 3.0) then
        return cb({ success = false, message = 'The delivery spot is blocked. Try again in a moment.' })
    end

    local result = lib.callback.await('fp-dealership:server:buy', false, data.model, data.method)

    if result and result.success then
        closeShop()
        notify(('You bought a %s.'):format(result.label), 'success')
        cb(result)
        spawnPurchased(result.model, result.plate)
        return
    end

    cb(result or { success = false, message = 'Purchase failed.' })
end)

RegisterNUICallback('saveVehicle', function(data, cb)
    -- Quick client-side check that the model really exists on this server
    local model = tostring(data.model or ''):lower()
    local hash = joaat(model)
    if not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then
        return cb({ success = false, message = ('"%s" is not a vehicle on this server.'):format(model) })
    end

    local result = lib.callback.await('fp-dealership:server:saveVehicle', false, data)
    cb(result or { success = false, message = 'Something went wrong.' })
end)

RegisterNUICallback('removeVehicle', function(data, cb)
    local result = lib.callback.await('fp-dealership:server:removeVehicle', false, data.model)
    cb(result or { success = false, message = 'Something went wrong.' })
end)

----------------------------------------------------------------------
-- Salesman ped + interaction
----------------------------------------------------------------------
local function ensurePed()
    local d = Config.Dealership
    if not d.ped.enabled or (shopPed and DoesEntityExist(shopPed)) then return end

    local hash = joaat(d.ped.model)
    if not loadModel(hash, 3000) then return end

    shopPed = CreatePed(4, hash, d.coords.x, d.coords.y, d.coords.z - 1.0, d.coords.w, false, true)
    SetModelAsNoLongerNeeded(hash)
    SetEntityInvincible(shopPed, true)
    SetBlockingOfNonTemporaryEvents(shopPed, true)
    FreezeEntityPosition(shopPed, true)
    TaskStartScenarioInPlace(shopPed, 'WORLD_HUMAN_CLIPBOARD', 0, true)
end

local function removePed()
    if shopPed and DoesEntityExist(shopPed) then
        DeleteEntity(shopPed)
    end
    shopPed = nil
end

CreateThread(function()
    local d = Config.Dealership
    local spot = vec3(d.coords.x, d.coords.y, d.coords.z)

    while true do
        local sleep = 1000
        local dist = #(GetEntityCoords(cache.ped) - spot)

        if dist < 60.0 then
            ensurePed()
        else
            removePed()
        end

        if dist < 15.0 and not isOpen then
            sleep = 0
            DrawMarker(2, spot.x, spot.y, spot.z + 1.1, 0.0, 0.0, 0.0, 180.0, 0.0, 0.0,
                0.25, 0.25, 0.25, 224, 164, 58, 180, true, false, 2, false, nil, nil, false)

            if dist < d.interactDistance then
                BeginTextCommandDisplayHelp('STRING')
                AddTextComponentSubstringPlayerName('Press ~INPUT_CONTEXT~ to browse vehicles')
                EndTextCommandDisplayHelp(0, false, true, -1)

                if IsControlJustReleased(0, 38) then
                    openShop()
                end
            end
        end

        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    closeShop()
    removePed()
    deletePreview()
    destroyCamera()
end)
