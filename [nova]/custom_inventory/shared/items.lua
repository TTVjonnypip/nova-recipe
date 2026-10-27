--[[
    Item definitions
    ─────────────────
    label        Display name
    weight       Grams per unit
    stack        true = many per slot, false = one per slot
    close        Close the inventory UI when used
    description  Tooltip text
    use          Built-in use behaviour (optional):
                   consume  how many to remove on use
                   effect   'eat' | 'drink' | 'heal' | 'armour' | nil
                   amount   heal / armour amount, or hunger / thirst restored for eat / drink
                   stress   stress removed on use (optional)
                   duration ms the animation runs before the item is consumed
                   anim     { dict = '', clip = '', flag = 49 }
    Images: html/images/<item name>.png (100x100 recommended)

    Need custom logic? From another server resource:
        exports.custom_inventory:RegisterUsableItem('lockpick', function(source, item, slot) ... end)
]]

Items = {
    money = {
        label = 'Cash', weight = 0, stack = true,
        description = 'Cold, hard cash.',
    },
    water = {
        label = 'Water', weight = 500, stack = true, close = true,
        description = 'A bottle of water.',
        use = { consume = 1, effect = 'drink', amount = 30, duration = 2500,
                anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle', flag = 49 } },
    },
    burger = {
        label = 'Burger', weight = 350, stack = true, close = true,
        description = 'Greasy, but it does the job.',
        use = { consume = 1, effect = 'eat', amount = 30, duration = 3000,
                anim = { dict = 'mp_player_inteat@burger', clip = 'mp_player_int_eat_burger', flag = 49 } },
    },
    bandage = {
        label = 'Bandage', weight = 115, stack = true, close = true,
        description = 'Restores a little health.',
        use = { consume = 1, effect = 'heal', amount = 25, duration = 4000,
                anim = { dict = 'missheistdockssetup1clipboard@idle_a', clip = 'idle_a', flag = 49 } },
    },
    armour = {
        label = 'Body Armour', weight = 3000, stack = false, close = true,
        description = 'Light ballistic vest.',
        use = { consume = 1, effect = 'armour', amount = 100, duration = 5000,
                anim = { dict = 'clothingshirt', clip = 'try_shirt_positive_d', flag = 49 } },
    },
    phone = {
        label = 'Phone', weight = 190, stack = false,
        description = 'A smartphone.',
    },
    radio = {
        label = 'Radio', weight = 600, stack = false,
        description = 'Handheld two-way radio.',
    },
    lockpick = {
        label = 'Lockpick', weight = 160, stack = true,
        description = 'Register a usable callback to make this do something.',
    },
    scrap_metal = {
        label = 'Scrap Metal', weight = 1000, stack = true,
        description = 'Could be worth something to the right person.',
    },
    id_card = {
        label = 'ID Card', weight = 10, stack = false,
        description = 'Identification. Carries metadata (name, DOB).',
    },

    -- Used by the Nova scripts ------------------------------------------------
    pregnancy_test = {
        label = 'Pregnancy Test', weight = 50, stack = true,
        description = 'Use it in private.',
    },
    birth_certificate = {
        label = 'Birth Certificate', weight = 10, stack = false,
        description = 'Official record of birth.',
    },
    engagement_ring = {
        label = 'Engagement Ring', weight = 20, stack = false,
        description = 'Use it near someone special to propose.',
    },
    wedding_ring = {
        label = 'Wedding Ring', weight = 20, stack = false,
        description = 'A symbol of commitment.',
    },
}
