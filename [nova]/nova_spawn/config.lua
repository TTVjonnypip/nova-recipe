Config = {}

-- Where brand-new characters wake up
Config.NewCharacterSpawn = vec4(-1035.71, -2731.87, 12.86, 0.0)

-- Offer "Last location" to returning characters
Config.AllowLastLocation = true

-- Open the appearance editor for new characters when illenium-appearance is running
Config.OpenAppearanceForNew = true

-- Camera shown behind the spawn menu
Config.MenuCamera = { coords = vec3(-206.0, -1015.0, 280.0), rotation = vec3(-35.0, 0.0, 20.0), fov = 60.0 }

Config.Locations = {
    { label = 'Legion Square', icon = 'building', coords = vec4(195.17, -933.77, 29.7, 144.5) },
    { label = 'Mission Row', icon = 'shield-halved', coords = vec4(428.23, -984.28, 29.76, 3.5) },
    { label = 'Pink Cage Motel', icon = 'bed', coords = vec4(327.56, -205.08, 53.08, 163.5) },
    { label = 'Paleto Bay', icon = 'tree', coords = vec4(80.35, 6424.12, 31.67, 45.5) },
}
