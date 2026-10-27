Config = {}

-- ─── Player inventory ────────────────────────────────────────────────
Config.PlayerSlots      = 40
Config.PlayerMaxWeight  = 30000   -- grams (30 kg)
Config.HotbarSlots      = 5       -- slots 1-5 are bound to keys 1-5
Config.OpenKey          = 'TAB'   -- players can rebind in Settings > Key Bindings > FiveM
Config.DisableWeaponWheelKeys = true -- stops 1-5 from also switching weapons

-- Items given to a brand-new character's inventory.
-- Leave empty on Nova: nova_core gives the phone (ServerConfig.StarterItems) and
-- qbx_starterpack gives food and water. Cash is NOT an item you hand out here -
-- the money item always mirrors the character's Nova cash balance.
Config.StartingItems = {}

-- Item that mirrors Nova cash (money.cash). Shops charge with it.
Config.MoneyItem = 'money'

-- ─── Distances (metres) ──────────────────────────────────────────────
Config.InteractDistance = 2.0   -- stashes / shops
Config.DropDistance     = 1.75  -- picking up ground drops
Config.GiveDistance     = 3.0   -- giving to another player
Config.MaxAccessDistance = 6.0  -- server rejects moves if player is farther than this from the open container

-- ─── Saving / drops ─────────────────────────────────────────────────
Config.SaveIntervalMinutes = 5
Config.DropDespawnMinutes  = 30
Config.DropSlots           = 30
Config.DropProp            = 'prop_paper_bag_small'

-- ─── Vehicles ───────────────────────────────────────────────────────
Config.Glovebox = { slots = 5, weight = 10000 }

-- Trunk size by vehicle class (GetVehicleClass). Classes not listed use Default.
-- A class set to false has no trunk.
Config.Trunk = {
    Default = { slots = 20, weight = 60000 },
    Classes = {
        [0]  = { slots = 15, weight = 40000 },  -- Compacts
        [2]  = { slots = 30, weight = 90000 },  -- SUVs
        [6]  = { slots = 10, weight = 25000 },  -- Sports
        [7]  = { slots = 8,  weight = 20000 },  -- Super
        [8]  = false,                           -- Motorcycles
        [12] = { slots = 40, weight = 150000 }, -- Vans
        [13] = false,                           -- Cycles
        [20] = { slots = 50, weight = 250000 }, -- Commercial
    },
}

-- ─── Stashes ────────────────────────────────────────────────────────
-- personal = true  → every player gets their own copy of the stash
-- ace      = 'x'   → only players with that ACE permission can open it
--                    e.g. add_ace group.police inventory.stash.police allow
-- job      = 'police'  or  { police = 0, ambulance = 2 }  → Nova job (and minimum grade)
-- Coordinates are examples – change them to fit your map.
Config.Stashes = {
    {
        id = 'legion_locker', label = 'Public Locker',
        coords = vector3(195.17, -933.77, 30.69),
        slots = 20, weight = 50000, personal = true,
    },
    {
        id = 'police_evidence', label = 'Evidence Locker',
        coords = vector3(472.9, -990.5, 26.27),
        slots = 60, weight = 300000, job = 'police',
    },
}

-- ─── Shops ──────────────────────────────────────────────────────────
-- Drag an item from the shop into your inventory to buy it.
Config.Shops = {
    {
        id = 'strawberry_247', label = '24/7 Supermarket',
        coords = vector3(25.7, -1347.3, 29.49),
        blip = { sprite = 52, color = 2, scale = 0.7 },
        items = {
            { name = 'water',   price = 5 },
            { name = 'burger',  price = 10 },
            { name = 'bandage', price = 50 },
            { name = 'phone',   price = 300 },
            { name = 'radio',   price = 250 },
        },
    },
}
