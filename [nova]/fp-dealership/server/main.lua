math.randomseed(os.time())

----------------------------------------------------------------------
-- Database setup
----------------------------------------------------------------------
CreateThread(function()
    local tableExists = MySQL.scalar.await([[
        SELECT COUNT(*) FROM information_schema.tables
        WHERE table_schema = DATABASE() AND table_name = 'dealership_vehicles'
    ]]) > 0

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `dealership_vehicles` (
            `model` VARCHAR(50) NOT NULL,
            `label` VARCHAR(100) NOT NULL,
            `price` INT NOT NULL,
            `category` VARCHAR(50) NOT NULL DEFAULT 'Other',
            PRIMARY KEY (`model`)
        )
    ]])

    if not tableExists then
        for _, v in ipairs(Config.DefaultVehicles) do
            MySQL.insert.await(
                'INSERT INTO dealership_vehicles (model, label, price, category) VALUES (?, ?, ?, ?)',
                { v.model, v.label, v.price, v.category }
            )
        end
        print('[fp-dealership] Created table and added starter vehicles.')
    end
end)

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------
local function getVehicles()
    return MySQL.query.await(
        'SELECT model, label, price, category FROM dealership_vehicles ORDER BY category, price'
    ) or {}
end

local function isAdmin(src)
    return exports.nova_core:HasPermission(src, Config.AdminPermission)
end

local function trim(s)
    return (tostring(s or ''):gsub('^%s+', ''):gsub('%s+$', ''))
end

local function notify(src, message, kind)
    if src == 0 then
        print('[fp-dealership] ' .. message)
    else
        TriggerClientEvent('ox_lib:notify', src, { description = message, type = kind or 'inform' })
    end
end

-- Returns ok, message
local function saveVehicle(model, label, price, category)
    model = trim(model):lower()
    label = trim(label)
    category = trim(category)
    price = math.floor(tonumber(price) or 0)

    if model == '' or #model > 50 or not model:match('^[%w_]+$') then
        return false, 'Model must be the spawn name (letters, numbers, underscores).'
    end
    if label == '' or #label > 100 then
        return false, 'Enter a display name up to 100 characters.'
    end
    if price < 1 or price > 2000000000 then
        return false, 'Enter a price greater than 0.'
    end
    if category == '' then category = 'Other' end
    if #category > 50 then category = category:sub(1, 50) end

    MySQL.query.await([[
        INSERT INTO dealership_vehicles (model, label, price, category) VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE label = VALUES(label), price = VALUES(price), category = VALUES(category)
    ]], { model, label, price, category })

    return true, ('%s saved.'):format(label)
end

local function removeVehicle(model)
    model = trim(model):lower()
    local res = MySQL.query.await('DELETE FROM dealership_vehicles WHERE model = ?', { model })
    local affected = type(res) == 'table' and res.affectedRows or res
    if affected and affected > 0 then
        return true, 'Vehicle removed.'
    end
    return false, 'That vehicle is not in the dealership.'
end

local function generatePlate()
    local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    while true do
        local plate = ''
        for _ = 1, 8 do
            local r = math.random(#chars)
            plate = plate .. chars:sub(r, r)
        end
        local exists = MySQL.scalar.await('SELECT 1 FROM player_vehicles WHERE plate = ?', { plate })
        if not exists then return plate end
    end
end

----------------------------------------------------------------------
-- Callbacks used by the menu
----------------------------------------------------------------------
lib.callback.register('fp-dealership:server:getData', function(source)
    local Player = exports.nova_core:GetPlayer(source)
    if not Player then return nil end

    return {
        vehicles = getVehicles(),
        isAdmin = isAdmin(source),
        cash = Player.PlayerData.money.cash,
        bank = Player.PlayerData.money.bank,
    }
end)

local buying = {}
local pendingKeys = {} -- [source] = plate of the car they just bought

lib.callback.register('fp-dealership:server:buy', function(source, model, method)
    if buying[source] then
        return { success = false, message = 'Hang on, finishing your last purchase.' }
    end
    buying[source] = true

    local function finish(result)
        buying[source] = nil
        return result
    end

    local Player = exports.nova_core:GetPlayer(source)
    if not Player then
        return finish({ success = false, message = 'Could not find your character.' })
    end

    if type(model) ~= 'string' or (method ~= 'cash' and method ~= 'bank') then
        return finish({ success = false, message = 'Invalid purchase request.' })
    end

    -- Price always comes from the database, never from the client
    local veh = MySQL.single.await(
        'SELECT model, label, price FROM dealership_vehicles WHERE model = ?',
        { model:lower() }
    )
    if not veh then
        return finish({ success = false, message = 'That vehicle is no longer for sale.' })
    end

    if (Player.PlayerData.money[method] or 0) < veh.price then
        return finish({ success = false, message = ('Not enough %s for the %s.'):format(method, veh.label) })
    end

    local plate = generatePlate()

    if not Player.Functions.RemoveMoney(method, veh.price, 'dealership-purchase') then
        return finish({ success = false, message = 'Payment failed.' })
    end

    local ok = MySQL.insert.await([[
        INSERT INTO player_vehicles (license, citizenid, vehicle, hash, mods, plate, garage, state)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        Player.PlayerData.license,
        Player.PlayerData.citizenid,
        veh.model,
        tostring(joaat(veh.model)),
        '{}',
        plate,
        Config.DefaultGarage,
        0,
    })

    if not ok then
        Player.Functions.AddMoney(method, veh.price, 'dealership-refund')
        return finish({ success = false, message = 'Could not register the vehicle. You were not charged.' })
    end

    pendingKeys[source] = plate

    return finish({ success = true, model = veh.model, label = veh.label, price = veh.price, plate = plate })
end)

lib.callback.register('fp-dealership:server:saveVehicle', function(source, data)
    if not isAdmin(source) then
        return { success = false, message = 'You do not have permission.' }
    end
    if type(data) ~= 'table' then
        return { success = false, message = 'Invalid data.' }
    end

    local ok, msg = saveVehicle(data.model, data.label, data.price, data.category)
    return { success = ok, message = msg, vehicles = ok and getVehicles() or nil }
end)

lib.callback.register('fp-dealership:server:removeVehicle', function(source, model)
    if not isAdmin(source) then
        return { success = false, message = 'You do not have permission.' }
    end

    local ok, msg = removeVehicle(model)
    return { success = ok, message = msg, vehicles = getVehicles() }
end)

----------------------------------------------------------------------
-- Keys: the client reports the spawned car, the server checks it is
-- the one this player just bought before handing over keys.
----------------------------------------------------------------------
RegisterNetEvent('fp-dealership:server:claimKeys', function(netId, plate)
    local src = source
    if type(netId) ~= 'number' or type(plate) ~= 'string' then return end
    if pendingKeys[src] ~= plate then return end

    local veh = NetworkGetEntityFromNetworkId(netId)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return end
    if trim(GetVehicleNumberPlateText(veh)) ~= plate then return end

    pendingKeys[src] = nil
    if Config.GiveKeys then
        Config.GiveKeys(src, veh, plate)
    end
end)

----------------------------------------------------------------------
-- Admin commands (work in game and from the server console)
----------------------------------------------------------------------
lib.addCommand('adddealercar', {
    help = 'Add/update a dealership vehicle',
    params = {
        { name = 'model', type = 'string', help = 'Spawn name, e.g. sultan' },
        { name = 'price', type = 'number', help = 'Price' },
        { name = 'category', type = 'string', help = 'Category, e.g. Sports' },
        { name = 'label', type = 'longString', help = 'Display name (can be several words)' },
    },
    restricted = 'group.' .. Config.AdminPermission,
}, function(source, args)
    local ok, msg = saveVehicle(args.model, args.label, args.price, args.category)
    notify(source, msg, ok and 'success' or 'error')
end)

lib.addCommand('removedealercar', {
    help = 'Remove a dealership vehicle',
    params = {
        { name = 'model', type = 'string', help = 'Spawn name, e.g. sultan' },
    },
    restricted = 'group.' .. Config.AdminPermission,
}, function(source, args)
    local ok, msg = removeVehicle(args.model)
    notify(source, msg, ok and 'success' or 'error')
end)

AddEventHandler('playerDropped', function()
    buying[source] = nil
    pendingKeys[source] = nil
end)
