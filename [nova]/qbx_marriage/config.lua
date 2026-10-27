Config = {}

Config.Items = {
    engagementRing = 'engagement_ring', -- used to propose
    weddingRing = 'wedding_ring',       -- given to both partners after the ceremony
}

Config.ProposalDistance = 3.0   -- how close the person you propose to must be
Config.PromptTimeout = 30       -- seconds before an unanswered proposal/vow prompt closes

Config.WeddingFee = 5000        -- paid from bank by the partner who starts the ceremony
Config.DivorceFee = 10000       -- paid from bank by the partner who files
Config.CeremonyDistance = 15.0  -- both partners must be this close to the officiant
Config.CeremonyDuration = 10000 -- ms of "exchanging vows" progress
Config.GiveWeddingRings = true
Config.AnnounceWeddings = true  -- notify the whole server when a couple marries

-- Placeholder locations: move these to your chapel / courthouse MLO.
Config.Chapel = {
    coords = vec4(-766.25, -23.65, 41.08, 210.0),
    model = 'cs_priest',
    scenario = 'WORLD_HUMAN_STAND_IMPATIENT',
    blip = { enabled = true, sprite = 280, color = 8, scale = 0.8, label = 'Wedding Chapel' },
}

Config.Courthouse = {
    coords = vec4(-544.90, -204.40, 38.22, 210.0),
    model = 'a_m_y_business_02',
    scenario = 'WORLD_HUMAN_CLIPBOARD',
    blip = { enabled = true, sprite = 419, color = 0, scale = 0.8, label = 'Courthouse' },
}
