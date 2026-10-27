Config = {}

-- ─────────────────────────────────────────────
--  Scene (character preview)
-- ─────────────────────────────────────────────
Config.PreviewPed   = vec4(-813.97, 176.22, 76.74, -7.5)   -- where the preview ped stands
Config.CameraCoords = vec3(-813.46, 178.95, 77.25)         -- camera position
Config.CameraFov    = 40.0
Config.HiddenPlayer = vec3(-813.97, 176.22, 66.0)          -- real player is parked here (invisible) during selection

Config.PreviewScenario = 'WORLD_HUMAN_STAND_IMPATIENT'     -- set to false for no idle animation

-- ─────────────────────────────────────────────
--  Spawning
-- ─────────────────────────────────────────────
-- 'auto' = open nova_spawn's location picker if it's running, otherwise last location
-- 'last' = always spawn existing characters at their last location
Config.SpawnMode = 'auto'

Config.NewCharacterSpawn = vec4(-1037.74, -2737.86, 20.17, 327.0) -- used when no apartment is chosen
Config.DefaultSpawn      = vec4(195.17, -933.77, 30.69, 144.5)    -- fallback if a character has no saved position

-- Event fired for a brand-new character to open the clothing/appearance menu.
-- illenium-appearance listens to this one out of the box.
Config.FirstCharacterEvent = 'qb-clothes:client:CreateFirstCharacter'

Config.DefaultModels = {
    [0] = `mp_m_freemode_01`,
    [1] = `mp_f_freemode_01`,
}

-- ─────────────────────────────────────────────
--  Creation rules (always used)
-- ─────────────────────────────────────────────
Config.NameMinLength = 2
Config.NameMaxLength = 16

-- Blocked anywhere inside a name (case-insensitive). Config.ProfanityWords below are also checked.
Config.BlacklistedNames = {
    'admin', 'staff', 'moderator', 'owner', 'developer',
}

-- ─────────────────────────────────────────────
--  Characters
-- ─────────────────────────────────────────────
-- Character slots are set in nova_core: Config.MaxCharacters (config/shared.lua)
-- and ServerConfig.CharacterSlots (config/server.lua) for per-license extras.
-- Starter items are set in nova_core: ServerConfig.StarterItems.

Config.AllowDelete = true

-- Age limits. Set DateMin / DateMax ('YYYY-MM-DD') to use fixed dates instead.
Config.MinAge = 18
Config.MaxAge = 90
Config.DateMin = nil
Config.DateMax = nil

-- Blocked whole words (in addition to BlacklistedNames above)
Config.ProfanityWords = {}

Config.LimitNationalities = true
Config.Nationalities = {
    'American', 'Canadian', 'Mexican', 'British', 'Irish', 'German', 'French', 'Italian',
    'Spanish', 'Portuguese', 'Dutch', 'Swedish', 'Norwegian', 'Polish', 'Russian', 'Ukrainian',
    'Brazilian', 'Argentinian', 'Colombian', 'Cuban', 'Jamaican', 'Nigerian', 'South African',
    'Egyptian', 'Turkish', 'Indian', 'Pakistani', 'Chinese', 'Japanese', 'Korean', 'Filipino',
    'Vietnamese', 'Australian', 'New Zealander',
}

-- /logout is provided by nova_core (admin only).
