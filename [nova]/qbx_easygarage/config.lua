Config = {}

-- true  = any garage can retrieve any of your cars (easiest, works with any dealership)
-- false = a car can only be retrieved from the garage it was stored in
Config.SharedGarages = true

-- On resource start, mark every "out" vehicle as stored again (fixes cars lost after a restart/crash)
Config.ResetOutOnRestart = true

-- Give keys when taking a car out (qbx_vehiclekeys if running, otherwise the qb-vehiclekeys event)
Config.GiveKeys = true

-- How close you need to be to the garage marker to interact
Config.InteractDistance = 2.5

-- Garage used by /addgaragecar when you don't specify one (must match a key below)
Config.DefaultGarage = 'legion'

-- Default blip look (each garage can override with its own blip = { ... } or blip = false to hide)
Config.DefaultBlip = { sprite = 357, color = 3, scale = 0.7 }

----------------------------------------------------------------------
-- ADD A NEW GARAGE: copy one block, give it a unique key, change the values.
--   coords = where you press E (store / open menu)
--   spawns = list of places cars can appear (the first free one is used)
--   job    = optional, restricts the garage to one job name
-- NOTE: these coordinates are examples - adjust them to your map.
----------------------------------------------------------------------
Config.Garages = {
    legion = {
        label = 'Legion Square Garage',
        coords = vec3(215.8, -809.7, 30.7),
        spawns = {
            vec4(223.5, -800.2, 30.6, 248.0),
            vec4(226.4, -805.9, 30.6, 248.0),
        },
    },

    sandy = {
        label = 'Sandy Shores Garage',
        coords = vec3(1737.6, 3710.2, 34.1),
        spawns = {
            vec4(1741.2, 3714.6, 34.1, 20.0),
        },
        blip = { sprite = 357, color = 2, scale = 0.7 },
    },

    -- police = {
    --     label = 'MRPD Garage',
    --     coords = vec3(451.0, -1018.0, 28.4),
    --     spawns = { vec4(447.0, -1025.0, 28.5, 3.0) },
    --     job = 'police',
    --     blip = false,
    -- },
}
