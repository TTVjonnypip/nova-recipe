ServerConfig = {}

ServerConfig.SaveInterval = 5        -- minutes between automatic saves
ServerConfig.PaycheckInterval = 10   -- minutes between paychecks (0 disables)
ServerConfig.StatusInterval = 5      -- minutes between hunger/thirst ticks

-- Whitelist ----------------------------------------------------------------
-- When enabled a player may join if their license is listed below OR they have the ace.
ServerConfig.Whitelist = false
ServerConfig.WhitelistAce = 'nova.whitelisted'
ServerConfig.WhitelistLicenses = {
    -- ['license:abc123...'] = true,
}

-- Permissions --------------------------------------------------------------
-- Highest first. A player with a higher level passes checks for lower ones.
-- Each level is an ace checked with IsPlayerAceAllowed (see README for server.cfg lines).
ServerConfig.Permissions = { 'god', 'admin', 'mod' }

-- Extra character slots for specific licenses
ServerConfig.CharacterSlots = {
    -- ['license:abc123...'] = 6,
}

-- Items given to a brand-new character after their first spawn (works with either inventory).
-- qbx_starterpack separately gives food, water, a car and money, so they aren't listed here.
ServerConfig.StarterItems = {
    { name = 'phone', count = 1 },
}

-- Other tables cleaned up when a character is deleted. Tables that don't exist are skipped.
ServerConfig.DeleteTables = {
    { table = 'player_vehicles', column = 'citizenid' },
    { table = 'playerskins', column = 'citizenid' },
    { table = 'player_outfits', column = 'citizenid' },
    { table = 'apartments', column = 'citizenid' },
    { table = 'player_houses', column = 'citizenid' },
}

ServerConfig.BloodTypes = { 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-' }
