Nova = {
    PlayerData = {},
    IsLoggedIn = false,
}

function Nova.GetPlayerData()
    return Nova.PlayerData
end

local function applyWorldSettings()
    if Config.World.disableWantedLevel then
        SetMaxWantedLevel(0)
        ClearPlayerWantedLevel(cache.playerId)
    end
    if Config.World.disableDispatch then
        for i = 1, 15 do EnableDispatchService(i, false) end
    end
end
Nova.ApplyWorldSettings = applyWorldSettings

CreateThread(function()
    AddTextEntry('FE_THDR_GTAO', Config.ServerName)
    applyWorldSettings()
end)

-- Starving / dehydrated damage
CreateThread(function()
    while true do
        Wait(5000)
        if Nova.IsLoggedIn and Config.Status.enabled and Config.Status.starvingDamage then
            local md = Nova.PlayerData.metadata
            if md and not md.isdead and ((md.hunger or 100) <= 0 or (md.thirst or 100) <= 0) then
                local ped = cache.ped
                local health = GetEntityHealth(ped)
                if health > 100 then
                    SetEntityHealth(ped, health - math.random(5, 10))
                end
            end
        end
    end
end)

exports('GetPlayerData', Nova.GetPlayerData)
exports('IsLoggedIn', function() return Nova.IsLoggedIn end)
exports('GetJobs', function() return Shared.Jobs end)
exports('GetGangs', function() return Shared.Gangs end)
exports('GetVehiclesByName', function(model)
    if model then return Shared.Vehicles[model] end
    return Shared.Vehicles
end)
