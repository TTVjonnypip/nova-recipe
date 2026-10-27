local core = exports.nova_core

local function notify(src, msg, type)
    core:Notify(src, msg, type or 'inform')
end

local function generatePlate()
    local plate
    repeat
        plate = ('%s%s'):format(lib.string.random('AAA'), lib.string.random('11111'))
        plate = plate:upper()
        local exists = MySQL.scalar.await('SELECT 1 FROM player_vehicles WHERE plate = ?', { plate })
    until not exists
    return plate
end

-- Stores the car straight into player_vehicles (same table qbx_easygarage and fp-dealership use)
local function createPlayerVehicle(pd, model, garage, plate)
    local hash = joaat(model)
    return MySQL.insert.await(
        'INSERT INTO player_vehicles (license, citizenid, vehicle, hash, mods, plate, garage, state) VALUES (?, ?, ?, ?, ?, ?, ?, 1)',
        { pd.license, pd.citizenid, model, tostring(hash), json.encode({ model = hash, plate = plate }), plate, garage })
end

local function giveStarterPack(src)
    local player = core:GetPlayer(src)
    if not player then return false end

    if player.PlayerData.metadata[Config.MetaKey] then
        notify(src, 'You have already received your starter pack.', 'error')
        return false
    end

    -- Make sure the items fit before giving anything
    for _, item in ipairs(Config.Items) do
        if not core:CanCarryItem(src, item.name, item.count) then
            notify(src, 'Not enough inventory space for your starter pack. Free up space and try again.', 'error')
            return false
        end
    end

    -- Mark as claimed first so it can't be duplicated by spamming
    player.Functions.SetMetaData(Config.MetaKey, true)

    -- Money
    player.Functions.AddMoney(Config.Money.account, Config.Money.amount, 'starter-pack')

    -- Items
    for _, item in ipairs(Config.Items) do
        core:AddItem(src, item.name, item.count)
    end

    -- Vehicle (stored in garage)
    local plate = generatePlate()
    local ok, vehicleId = pcall(createPlayerVehicle, player.PlayerData, Config.Vehicle.model, Config.Vehicle.garage, plate)

    if not ok or not vehicleId then
        lib.print.error(('Starter pack vehicle failed for %s: %s'):format(player.PlayerData.citizenid, tostring(vehicleId)))
        notify(src, 'Starter pack given, but the vehicle could not be added. Contact staff.', 'error')
        return true
    end

    notify(src, ('Starter pack received! $%s, food, water and a Karin Sultan (plate %s) in your garage.')
        :format(lib.math.groupdigits(Config.Money.amount), plate), 'success')
    return true
end

-- Auto-give once the character is actually in the world (inventory is loaded by then)
if Config.AutoGive then
    AddEventHandler('nova:server:onPlayerSpawned', function(src)
        local pd = core:GetPlayerData(src)
        if not pd or pd.metadata[Config.MetaKey] then return end
        SetTimeout(3000, function()
            if core:IsPlayerLoaded(src) then giveStarterPack(src) end
        end)
    end)
end

-- Manual claim command
if Config.Command then
    lib.addCommand(Config.Command, {
        help = 'Claim your one-time starter pack',
    }, function(source)
        giveStarterPack(source)
    end)
end

-- Admin command to reset a player's claim (for testing)
lib.addCommand('resetstarterpack', {
    help = 'Reset a player\'s starter pack claim',
    params = { { name = 'id', type = 'playerId', help = 'Server ID' } },
    restricted = 'group.admin',
}, function(source, args)
    if not core:IsPlayerLoaded(args.id) then return notify(source, 'Player not online.', 'error') end
    core:SetMetaData(args.id, Config.MetaKey, false)
    notify(source, 'Starter pack reset for ID ' .. args.id, 'success')
end)
