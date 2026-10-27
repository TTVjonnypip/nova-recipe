function Nova.Notify(message, notifType, duration, title)
    lib.notify({
        title = title,
        description = message,
        type = Utils.NotifyType(notifType),
        duration = duration or Config.Notify.duration,
        position = Config.Notify.position,
    })
end

function Nova.GetPlate(vehicle)
    if not vehicle or vehicle == 0 then return nil end
    return Utils.Trim(GetVehicleNumberPlateText(vehicle))
end

function Nova.SpawnVehicle(model, coords, heading, networked)
    local hash = type(model) == 'string' and GetHashKey(model) or model
    if not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then return nil end
    lib.requestModel(hash)
    local vehicle = CreateVehicle(hash, coords.x, coords.y, coords.z, heading or 0.0, networked ~= false, false)
    SetModelAsNoLongerNeeded(hash)
    SetVehicleHasBeenOwnedByPlayer(vehicle, true)
    SetVehicleNeedsToBeHotwired(vehicle, false)
    SetVehRadioStation(vehicle, 'OFF')
    if networked ~= false then
        local netId = NetworkGetNetworkIdFromEntity(vehicle)
        SetNetworkIdCanMigrate(netId, true)
    end
    return vehicle
end

function Nova.DeleteVehicle(vehicle)
    if not vehicle or vehicle == 0 then return end
    SetEntityAsMissionEntity(vehicle, true, true)
    DeleteVehicle(vehicle)
end

exports('Notify', Nova.Notify)
exports('SpawnVehicle', Nova.SpawnVehicle)
exports('DeleteVehicle', Nova.DeleteVehicle)
exports('GetPlate', Nova.GetPlate)
