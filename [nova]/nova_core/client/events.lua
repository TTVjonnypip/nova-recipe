RegisterNetEvent('nova:client:setPlayerData', function(data)
    local old = Nova.PlayerData
    Nova.PlayerData = data
    TriggerEvent('nova:client:playerDataUpdated', data, old)
end)

RegisterNetEvent('nova:client:onPlayerLoaded', function()
    Nova.IsLoggedIn = true
    Nova.ApplyWorldSettings()
end)

RegisterNetEvent('nova:client:onPlayerUnload', function()
    Nova.IsLoggedIn = false
    Nova.PlayerData = {}
end)

RegisterNetEvent('nova:client:jobsUpdated', function(name, data)
    Shared.Jobs[name] = data
end)

RegisterNetEvent('nova:client:gangsUpdated', function(name, data)
    Shared.Gangs[name] = data
end)

-- Admin command handlers ----------------------------------------------------

RegisterNetEvent('nova:client:spawnVehicle', function(model)
    local ped = cache.ped
    local hash = GetHashKey(model)
    if not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then
        return Nova.Notify(('"%s" is not a valid vehicle model.'):format(model), 'error')
    end

    local current = GetVehiclePedIsIn(ped, false)
    if current ~= 0 then Nova.DeleteVehicle(current) end

    local coords = GetEntityCoords(ped)
    local vehicle = Nova.SpawnVehicle(hash, coords, GetEntityHeading(ped), true)
    if not vehicle then return end

    TaskWarpPedIntoVehicle(ped, vehicle, -1)
    SetVehicleEngineOn(vehicle, true, true, false)
    -- qb-vehiclekeys and most forks listen for this
    TriggerEvent('vehiclekeys:client:SetOwner', Nova.GetPlate(vehicle))
end)

RegisterNetEvent('nova:client:tpToWaypoint', function()
    local blip = GetFirstBlipInfoId(8)
    if not DoesBlipExist(blip) then return Nova.Notify('You have no waypoint set.', 'error') end

    local target = GetBlipInfoIdCoord(blip)
    local ped = cache.ped
    local entity = (cache.vehicle and cache.seat == -1) and cache.vehicle or ped

    DoScreenFadeOut(250)
    while not IsScreenFadedOut() do Wait(0) end
    FreezeEntityPosition(entity, true)

    local found, groundZ = false, 0.0
    for z = 1000.0, 0.0, -25.0 do
        SetPedCoordsKeepVehicle(ped, target.x, target.y, z)
        RequestCollisionAtCoord(target.x, target.y, z)
        Wait(25)
        found, groundZ = GetGroundZFor_3dCoord(target.x, target.y, z, false)
        if found then break end
    end

    SetPedCoordsKeepVehicle(ped, target.x, target.y, found and groundZ or 100.0)
    FreezeEntityPosition(entity, false)
    DoScreenFadeIn(250)
    if not found then Nova.Notify('Could not find ground; dropped you at 100m.', 'warning') end
end)

RegisterNetEvent('nova:client:copyCoords', function()
    local coords = GetEntityCoords(cache.ped)
    local text = ('vec4(%.2f, %.2f, %.2f, %.2f)'):format(coords.x, coords.y, coords.z, GetEntityHeading(cache.ped))
    lib.setClipboard(text)
    Nova.Notify(('Copied %s'):format(text), 'success')
end)
