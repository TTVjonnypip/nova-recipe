Config = {}

-- Text shown in front of prices in the menu
Config.Currency = '$'

-- Nova permission level allowed to add/remove vehicles ('god' / 'admin' / 'mod')
Config.AdminPermission = 'admin'

-- Garage name saved with newly bought vehicles (a key in qbx_easygarage's Config.Garages)
Config.DefaultGarage = 'legion'

----------------------------------------------------------------------
-- Location (default: Premium Deluxe Motorsport). Change to anywhere.
----------------------------------------------------------------------
Config.Dealership = {
    name = 'Premium Deluxe Motorsport',

    -- Where the salesman stands / where players press E.
    -- Use the coords of where a player would stand (z = standing height).
    coords = vec4(-56.79, -1097.52, 26.42, 340.0),
    interactDistance = 2.5,

    ped = {
        enabled = true,
        model = 's_m_m_autoshop_01',
    },

    blip = {
        enabled = true,
        sprite = 326,
        color = 3,
        scale = 0.8,
    },

    -- Where a newly purchased vehicle appears (keep this area clear)
    purchaseSpawn = vec4(-56.79, -1109.85, 26.43, 71.5),
}

----------------------------------------------------------------------
-- Showroom preview. The camera is placed relative to the preview car.
-- If the camera clips through a wall, tweak camOffset.
----------------------------------------------------------------------
Config.Preview = {
    coords = vec4(-47.5, -1097.5, 26.42, 30.0),
    camOffset = vec3(5.0, 5.0, 1.4),
    camFov = 45.0,
}

----------------------------------------------------------------------
-- CLIENT hook: runs after a purchased vehicle spawns (fuel etc.)
----------------------------------------------------------------------
Config.OnVehicleSpawned = function(vehicle, plate)
    -- ox_fuel / most Qbox fuel scripts read this state bag
    Entity(vehicle).state:set('fuel', 100.0, true)
end

----------------------------------------------------------------------
-- SERVER hook: give the buyer keys. Uses qbx_vehiclekeys if it's running,
-- otherwise fires the qb-vehiclekeys event most key scripts listen to.
----------------------------------------------------------------------
Config.GiveKeys = function(src, vehicle, plate)
    if GetResourceState('qbx_vehiclekeys') == 'started' then
        exports.qbx_vehiclekeys:GiveKeys(src, vehicle)
    else
        TriggerClientEvent('vehiclekeys:client:SetOwner', src, plate)
    end
end

----------------------------------------------------------------------
-- Starter stock. Only added the FIRST time the script creates its
-- database table. After that, manage cars in-game (Manage tab) or
-- with /adddealercar and /removedealercar.
----------------------------------------------------------------------
Config.DefaultVehicles = {
    { model = 'blista',   label = 'Blista',        price = 18000,  category = 'Compacts' },
    { model = 'sultan',   label = 'Sultan',        price = 45000,  category = 'Sedans' },
    { model = 'sentinel', label = 'Sentinel',      price = 52000,  category = 'Sedans' },
    { model = 'elegy2',   label = 'Elegy RH8',     price = 95000,  category = 'Sports' },
    { model = 'kuruma',   label = 'Kuruma',        price = 110000, category = 'Sports' },
    { model = 'comet2',   label = 'Comet',         price = 135000, category = 'Sports' },
    { model = 'zentorno', label = 'Zentorno',      price = 450000, category = 'Super' },
    { model = 'adder',    label = 'Adder',         price = 650000, category = 'Super' },
    { model = 'baller',   label = 'Baller',        price = 85000,  category = 'SUVs' },
    { model = 'bison',    label = 'Bison',         price = 60000,  category = 'Trucks' },
    { model = 'sanchez',  label = 'Sanchez',       price = 14000,  category = 'Motorcycles' },
    { model = 'bati',     label = 'Bati 801',      price = 28000,  category = 'Motorcycles' },
}
