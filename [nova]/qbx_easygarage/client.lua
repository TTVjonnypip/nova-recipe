local shownFor, shownText
local busy = false

local function hideUI()
    if shownText then
        lib.hideTextUI()
        shownFor, shownText = nil, nil
    end
end

local function jobAllowed(garage)
    if not garage.job then return true end
    local data = exports.nova_core:GetPlayerData()
    return data and data.job and data.job.name == garage.job
end

----------------------------------------------------------------------
-- Take a vehicle out
----------------------------------------------------------------------
local function findFreeSpawn(garage)
    for i = 1, #garage.spawns do
        local s = garage.spawns[i]
        if not IsAnyVehicleNearPoint(s.x, s.y, s.z, 2.5) then
            return s
        end
    end
end

local function takeOut(garageId, plate)
    local garage = Config.Garages[garageId]
    local spawn = findFreeSpawn(garage)

    if not spawn then
        return lib.notify({ type = 'error', description = 'All parking spots are blocked.' })
    end

    local data = lib.callback.await('easygarage:takeOut', false, garageId, plate)
    if not data then return end

    local loaded = pcall(lib.requestModel, data.model, 10000)
    local vehicle = loaded and CreateVehicle(data.model, spawn.x, spawn.y, spawn.z, spawn.w, true, false) or 0

    if vehicle == 0 then
        TriggerServerEvent('easygarage:spawnFailed', data.plate)
        return lib.notify({ type = 'error', description = 'Could not spawn the vehicle.' })
    end

    SetVehicleOnGroundProperly(vehicle)
    lib.setVehicleProperties(vehicle, data.props)
    SetVehicleNumberPlateText(vehicle, data.plate)
    Entity(vehicle).state.fuel = data.fuel
    SetVehicleEngineHealth(vehicle, data.engine + 0.0)
    SetVehicleBodyHealth(vehicle, data.body + 0.0)
    SetModelAsNoLongerNeeded(data.model)

    TaskWarpPedIntoVehicle(cache.ped, vehicle, -1)
    TriggerServerEvent('easygarage:spawned', NetworkGetNetworkIdFromEntity(vehicle))
end

----------------------------------------------------------------------
-- Open the garage menu
----------------------------------------------------------------------
local function openGarage(garageId)
    local garage = Config.Garages[garageId]
    local vehicles = lib.callback.await('easygarage:getVehicles', false, garageId)

    if not vehicles or #vehicles == 0 then
        return lib.notify({ type = 'inform', description = 'You have no vehicles here.' })
    end

    local options = {}
    for i = 1, #vehicles do
        local v = vehicles[i]
        local isOut = v.state ~= 1

        options[#options + 1] = {
            title = ('%s [%s]'):format(v.label, v.plate),
            description = isOut and 'Currently out'
                or ('Fuel %d%% | Engine %d%% | Body %d%%'):format(v.fuel, v.engine, v.body),
            icon = 'car',
            disabled = isOut,
            onSelect = function()
                takeOut(garageId, v.plate)
            end,
        }
    end

    lib.registerContext({
        id = 'easygarage_menu',
        title = garage.label,
        options = options,
    })
    lib.showContext('easygarage_menu')
end

----------------------------------------------------------------------
-- Store the vehicle you're driving
----------------------------------------------------------------------
local function storeVehicle(garageId)
    local vehicle = cache.vehicle
    if not vehicle then return end

    if GetPedInVehicleSeat(vehicle, -1) ~= cache.ped then
        return lib.notify({ type = 'error', description = 'You must be the driver.' })
    end

    local props = lib.getVehicleProperties(vehicle)
    local fuel = Entity(vehicle).state.fuel or GetVehicleFuelLevel(vehicle)

    local ok, err = lib.callback.await(
        'easygarage:store', false,
        garageId,
        NetworkGetNetworkIdFromEntity(vehicle),
        props,
        fuel,
        GetVehicleEngineHealth(vehicle),
        GetVehicleBodyHealth(vehicle)
    )

    if not ok then
        return lib.notify({ type = 'error', description = err or 'Could not store the vehicle.' })
    end

    TaskLeaveVehicle(cache.ped, vehicle, 0)
    lib.notify({ type = 'success', description = 'Vehicle saved to the garage.' })
end

----------------------------------------------------------------------
-- Blips + interaction points
----------------------------------------------------------------------
for id, garage in pairs(Config.Garages) do
    if garage.blip ~= false then
        local b = garage.blip or Config.DefaultBlip
        local blip = AddBlipForCoord(garage.coords.x, garage.coords.y, garage.coords.z)
        SetBlipSprite(blip, b.sprite or Config.DefaultBlip.sprite)
        SetBlipColour(blip, b.color or Config.DefaultBlip.color)
        SetBlipScale(blip, b.scale or Config.DefaultBlip.scale)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(garage.label)
        EndTextCommandSetBlipName(blip)
    end

    local point = lib.points.new({
        coords = garage.coords,
        distance = 10.0,
        garageId = id,
    })

    function point:nearby()
        if busy or not jobAllowed(garage) then return end

        DrawMarker(36, garage.coords.x, garage.coords.y, garage.coords.z + 0.3,
            0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.7, 0.7, 0.7,
            50, 150, 255, 160, false, true, 2, false, nil, nil, false)

        if self.currentDistance <= Config.InteractDistance then
            local text = cache.vehicle and '[E] Store Vehicle' or '[E] Open Garage'

            if shownFor ~= self.garageId or shownText ~= text then
                shownFor, shownText = self.garageId, text
                lib.showTextUI(text)
            end

            if IsControlJustReleased(0, 38) then
                busy = true
                if cache.vehicle then
                    storeVehicle(self.garageId)
                else
                    openGarage(self.garageId)
                end
                busy = false
            end
        elseif shownFor == self.garageId then
            hideUI()
        end
    end

    function point:onExit()
        if shownFor == self.garageId then hideUI() end
    end
end

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then hideUI() end
end)
