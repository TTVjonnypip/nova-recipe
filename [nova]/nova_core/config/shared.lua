Config = {}

Config.ServerName = 'Nova RP'

-- Characters ---------------------------------------------------------------
Config.MaxCharacters = 4                              -- default slots per license
Config.DefaultSpawn = vec4(-1035.71, -2731.87, 12.86, 0.0)

-- Inventory ----------------------------------------------------------------
-- 'auto' uses custom_inventory if it's running, otherwise ox_inventory.
-- Set 'custom_inventory' or 'ox_inventory' to force one.
Config.Inventory = 'auto'

-- Money --------------------------------------------------------------------
Config.Money = {
    -- account name = starting balance for a new character
    types = { cash = 500, bank = 5000, crypto = 0 },
    -- accounts that can never go below zero
    dontAllowMinus = { cash = true, crypto = true },
    -- where paychecks are deposited
    paycheckAccount = 'bank',
}

-- Jobs ---------------------------------------------------------------------
-- When true, players log in with their job's defaultDuty instead of their saved duty state
Config.ForceDefaultDutyAtLogin = true

-- Status (hunger / thirst) -------------------------------------------------
Config.Status = {
    enabled = true,
    hungerRate = 4.2,        -- removed every status tick (see ServerConfig.StatusInterval)
    thirstRate = 3.8,
    starvingDamage = true,   -- lose health while hunger or thirst is 0
}

-- World --------------------------------------------------------------------
Config.World = {
    disableWantedLevel = true,
    disableDispatch = true,
}

-- Notifications (ox_lib) ---------------------------------------------------
Config.Notify = {
    position = 'top-right',
    duration = 5000,
}
