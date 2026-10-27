Config = {}

-- Key that opens / closes the phone (players can rebind it in GTA settings > Key Bindings > FiveM)
Config.OpenKey = 'M'

-- Require the player to carry an item to use the phone (custom_inventory or ox_inventory)
Config.RequireItem = true
Config.PhoneItem = 'phone'

-- Voice resource used for calls. Set to false to disable voice in calls.
Config.Voice = 'pma-voice'

-- Seconds an unanswered call keeps ringing before it is dropped
Config.RingTime = 30

-- Banking
Config.MaxTransfer = 1000000       -- largest single transfer allowed
Config.TransferFee = 0             -- percent fee taken on transfers (0 = none)

-- Chirp (social feed)
Config.ChirpMaxLength = 280
Config.ChirpFeedSize = 50

-- Yellow Pages ads
Config.AdCost = 50                 -- charged from bank per ad posted (0 = free)
Config.AdLifetimeHours = 72        -- ads older than this are hidden

-- Emergency / services app. job = Nova job name; only on-duty members receive the alert.
Config.Services = {
    { job = 'police',    label = 'Police',    icon = 'fa-shield-halved', color = '#2f6bff' },
    { job = 'ambulance', label = 'EMS',       icon = 'fa-truck-medical', color = '#ff3b30' },
    { job = 'mechanic',  label = 'Mechanic',  icon = 'fa-wrench',        color = '#ff9500' },
    { job = 'taxi',      label = 'Taxi',      icon = 'fa-taxi',          color = '#ffcc00' },
}
Config.DispatchBlipTime = 90       -- seconds a service alert blip stays on the receiver's map

-- Garage app: labels for the player_vehicles.state column
Config.VehicleStates = {
    [0] = { label = 'Out',       color = '#ff9500' },
    [1] = { label = 'Garaged',   color = '#34c759' },
    [2] = { label = 'Impounded', color = '#ff3b30' },
}
