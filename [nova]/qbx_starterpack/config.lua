Config = {}

-- Give the pack automatically the first time a character loads in.
-- If false, players claim it with the command below.
Config.AutoGive = true

-- Command players can use to claim the pack (set to false to disable).
Config.Command = 'starterpack'

-- Money: account can be 'bank' or 'cash'
Config.Money = {
    account = 'bank',
    amount = 100000,
}

-- Vehicle: 'sultan' = Karin Sultan
Config.Vehicle = {
    model = 'sultan',
    garage = 'legion', -- garage the car is stored in (a key in qbx_easygarage's Config.Garages)
}

-- Items (names from custom_inventory/shared/items.lua or ox_inventory)
Config.Items = {
    { name = 'water',  count = 5 },
    { name = 'burger', count = 5 },
}

-- Metadata key used to remember that a character already received the pack
Config.MetaKey = 'starterpack_claimed'
