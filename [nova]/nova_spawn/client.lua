local cam

local function destroyCam()
    if not cam then return end
    RenderScriptCams(false, false, 0, true, true)
    DestroyCam(cam, false)
    cam = nil
    ClearFocus()
end

local function createCam()
    if cam then return end
    local c = Config.MenuCamera
    cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA',
        c.coords.x, c.coords.y, c.coords.z, c.rotation.x, c.rotation.y, c.rotation.z, c.fov, false, 0)
    SetFocusPosAndVel(c.coords.x, c.coords.y, c.coords.z, 0.0, 0.0, 0.0)
    SetCamActive(cam, true)
    RenderScriptCams(true, false, 0, true, true)
end

local function spawnAt(coords, isNew)
    DoScreenFadeOut(500)
    while not IsScreenFadedOut() do Wait(0) end
    destroyCam()

    local ped = PlayerPedId()
    SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z, false, false, false)
    SetEntityHeading(ped, coords.w or 0.0)
    FreezeEntityPosition(ped, true)
    RequestCollisionAtCoord(coords.x, coords.y, coords.z)

    local timeout = GetGameTimer() + 5000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < timeout do Wait(0) end

    FreezeEntityPosition(ped, false)
    SetEntityVisible(ped, true, false)
    SetEntityInvincible(ped, false)

    TriggerServerEvent('nova:server:onPlayerSpawned')
    Wait(250)
    DoScreenFadeIn(750)

    if isNew and Config.OpenAppearanceForNew and GetResourceState('illenium-appearance') == 'started' then
        TriggerEvent('qb-clothes:client:CreateFirstCharacter')
    end
end

AddEventHandler('nova_spawn:client:open', function(data)
    data = data or {}

    if data.isNew then return spawnAt(Config.NewCharacterSpawn, true) end

    local last = data.position
    if data.forceLast and last and last.x then return spawnAt(last, false) end

    local options = {}
    if Config.AllowLastLocation and last and last.x then
        options[#options + 1] = {
            title = 'Last location',
            icon = 'location-dot',
            onSelect = function() spawnAt(last, false) end,
        }
    end
    for _, location in ipairs(Config.Locations) do
        options[#options + 1] = {
            title = location.label,
            icon = location.icon,
            onSelect = function() spawnAt(location.coords, false) end,
        }
    end

    createCam()
    DoScreenFadeIn(500)

    lib.registerContext({
        id = 'nova_spawn',
        title = 'Where do you want to go?',
        canClose = false,
        options = options,
    })
    lib.showContext('nova_spawn')
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then destroyCam() end
end)
