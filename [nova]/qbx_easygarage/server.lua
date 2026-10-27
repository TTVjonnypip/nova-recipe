local function trim(s)
    return ((s or ''):gsub('^%s+', ''):gsub('%s+$', ''))
end

local function getCitizenId(src)
    local pd = exports.nova_core:GetPlayerData(src)
    return pd and pd.citizenid or nil
end

local function nearGarage(src, garage)
    local ped = GetPlayerPed(src)
    return #(GetEntityCoords(ped) - garage.coords) <= 20.0
end

local function jobAllowed(src, garage)
    if not garage.job then return true end
    local pd = exports.nova_core:GetPlayerData(src)
    return pd and pd.job.name == garage.job
end

----------------------------------------------------------------------
-- Reset cars that were left "out" (state 0) when the server restarted
----------------------------------------------------------------------
CreateThread(function()
    if Config.ResetOutOnRestart then
        MySQL.update.await('UPDATE player_vehicles SET state = 1 WHERE state = 0')
    end
end)

----------------------------------------------------------------------
-- List the player's vehicles
----------------------------------------------------------------------
lib.callback.register('easygarage:getVehicles', function(src, garageId)
    local garage = Config.Garages[garageId]
    local citizenid = getCitizenId(src)
    if not garage or not citizenid or not jobAllowed(src, garage) then return {} end

    local query = 'SELECT plate, vehicle, fuel, engine, body, state FROM player_vehicles WHERE citizenid = ? AND state IN (0, 1)'
    local params = { citizenid }

    if not Config.SharedGarages then
        query = query .. ' AND garage = ?'
        params[#params + 1] = garageId
    end

    local rows = MySQL.query.await(query, params) or {}
    local shared = exports.nova_core:GetVehiclesByName()
    local result = {}

    for i = 1, #rows do
        local row = rows[i]
        local info = shared and shared[row.vehicle]
        local label = row.vehicle
        if info then
            label = trim(('%s %s'):format(info.brand or '', info.name or row.vehicle))
        end

        result[#result + 1] = {
            plate = row.plate,
            label = label,
            fuel = math.floor(row.fuel or 100),
            engine = math.floor((row.engine or 1000) / 10),
            body = math.floor((row.body or 1000) / 10),
            state = row.state,
        }
    end

    return result
end)

----------------------------------------------------------------------
-- Take a vehicle out
----------------------------------------------------------------------
lib.callback.register('easygarage:takeOut', function(src, garageId, plate)
    local garage = Config.Garages[garageId]
    local citizenid = getCitizenId(src)
    if not garage or not citizenid or type(plate) ~= 'string' then return false end
    if not jobAllowed(src, garage) or not nearGarage(src, garage) then return false end

    local query = 'SELECT id, vehicle, mods, plate, fuel, engine, body FROM player_vehicles WHERE citizenid = ? AND plate = ? AND state = 1'
    local params = { citizenid, plate }

    if not Config.SharedGarages then
        query = query .. ' AND garage = ?'
        params[#params + 1] = garageId
    end

    local row = MySQL.single.await(query .. ' LIMIT 1', params)
    if not row then
        lib.notify(src, { type = 'error', description = 'That vehicle is not in the garage.' })
        return false
    end

    -- Claim it atomically so it can't be taken out twice
    local claimed = MySQL.update.await('UPDATE player_vehicles SET state = 0 WHERE id = ? AND state = 1', { row.id })
    if claimed ~= 1 then return false end

    local props = row.mods and json.decode(row.mods) or {}
    props.plate = row.plate

    return {
        plate = row.plate,
        model = joaat(row.vehicle),
        props = props,
        fuel = row.fuel or 100,
        engine = row.engine or 1000,
        body = row.body or 1000,
    }
end)

-- Client couldn't spawn the car, put it back
RegisterNetEvent('easygarage:spawnFailed', function(plate)
    local citizenid = getCitizenId(source)
    if not citizenid or type(plate) ~= 'string' then return end
    MySQL.update('UPDATE player_vehicles SET state = 1 WHERE citizenid = ? AND plate = ? AND state = 0', { citizenid, plate })
end)

-- Give keys once the car exists
RegisterNetEvent('easygarage:spawned', function(netId)
    local src = source
    if not Config.GiveKeys then return end

    local citizenid = getCitizenId(src)
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if not citizenid or not vehicle or vehicle == 0 then return end

    local plate = trim(GetVehicleNumberPlateText(vehicle))
    local owned = MySQL.scalar.await('SELECT 1 FROM player_vehicles WHERE citizenid = ? AND TRIM(plate) = ? AND state = 0', { citizenid, plate })
    if owned then
        if GetResourceState('qbx_vehiclekeys') == 'started' then
            exports.qbx_vehiclekeys:GiveKeys(src, vehicle)
        else
            TriggerClientEvent('vehiclekeys:client:SetOwner', src, plate)
        end
    end
end)

----------------------------------------------------------------------
-- Store (save) a vehicle
----------------------------------------------------------------------
lib.callback.register('easygarage:store', function(src, garageId, netId, props, fuel, engine, body)
    local garage = Config.Garages[garageId]
    local citizenid = getCitizenId(src)
    if not garage or not citizenid then return false, 'Invalid garage.' end
    if not jobAllowed(src, garage) or not nearGarage(src, garage) then return false, 'You are too far away.' end
    if type(props) ~= 'table' then return false, 'Invalid vehicle data.' end

    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if not vehicle or vehicle == 0 then return false, 'Vehicle not found.' end

    local plate = trim(GetVehicleNumberPlateText(vehicle))
    local row = MySQL.single.await('SELECT id, plate FROM player_vehicles WHERE citizenid = ? AND TRIM(plate) = ? LIMIT 1', { citizenid, plate })
    if not row then return false, 'This is not your vehicle.' end

    props.plate = row.plate

    MySQL.update.await('UPDATE player_vehicles SET mods = ?, garage = ?, state = 1, fuel = ?, engine = ?, body = ? WHERE id = ?', {
        json.encode(props),
        garageId,
        math.floor(math.max(0, math.min(100, tonumber(fuel) or 100))),
        math.max(0, math.min(1000, tonumber(engine) or 1000)),
        math.max(0, math.min(1000, tonumber(body) or 1000)),
        row.id,
    })

    -- Give the player time to climb out, then remove the car
    SetTimeout(2500, function()
        if DoesEntityExist(vehicle) then DeleteEntity(vehicle) end
    end)

    return true
end)

----------------------------------------------------------------------
-- Admin command:  /addgaragecar [playerId] [model] [garage]
-- Example:        /addgaragecar 1 sultan legion
----------------------------------------------------------------------
local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'

local function generatePlate()
    while true do
        local plate = ''
        for _ = 1, 3 do
            local i = math.random(1, #chars)
            plate = plate .. chars:sub(i, i)
        end
        plate = plate .. tostring(math.random(10000, 99999))

        if not MySQL.scalar.await('SELECT 1 FROM player_vehicles WHERE plate = ?', { plate }) then
            return plate
        end
    end
end

lib.addCommand('addgaragecar', {
    help = 'Add a vehicle to a player\'s garage',
    params = {
        { name = 'target', type = 'playerId', help = 'Player server ID' },
        { name = 'model', type = 'string', help = 'Vehicle spawn name (e.g. sultan)' },
        { name = 'garage', type = 'string', help = 'Garage ID from config (optional)', optional = true },
    },
    restricted = 'group.admin',
}, function(source, args)
    local model = args.model:lower()
    local garageId = args.garage or Config.DefaultGarage

    if not Config.Garages[garageId] then
        return lib.notify(source, { type = 'error', description = ('Garage "%s" does not exist in config.'):format(garageId) })
    end

    -- Any spawn name is accepted; vehicles listed in nova_core/shared/vehicles.lua just get nicer labels
    if not model:match('^[%w_]+$') or #model > 50 then
        return lib.notify(source, { type = 'error', description = ('"%s" is not a valid spawn name.'):format(model) })
    end

    local player = exports.nova_core:GetPlayer(args.target)
    if not player then
        return lib.notify(source, { type = 'error', description = 'That player has not selected a character.' })
    end

    local plate = generatePlate()

    MySQL.insert.await('INSERT INTO player_vehicles (license, citizenid, vehicle, hash, mods, plate, garage, state) VALUES (?, ?, ?, ?, ?, ?, ?, 1)', {
        player.PlayerData.license,
        player.PlayerData.citizenid,
        model,
        tostring(joaat(model)),
        json.encode({ model = joaat(model), plate = plate }),
        plate,
        garageId,
    })

    lib.notify(source, { type = 'success', description = ('Added %s (%s) to garage "%s".'):format(model, plate, garageId) })
    lib.notify(args.target, { type = 'success', description = ('A %s was added to your garage.'):format(model) })
end)
