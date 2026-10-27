-- Nova Phone - client
local isOpen = false
local phoneProp = nil
local inCall = false

local Allowed = {
    getProfile = true, settingsSave = true,
    contactsGet = true, contactsAdd = true, contactsDelete = true,
    messagesThreads = true, messagesGet = true, messagesSend = true,
    callStart = true, callAccept = true, callEnd = true, callHistory = true,
    bankGet = true, bankTransfer = true,
    chirpGet = true, chirpPost = true, chirpLike = true, chirpDelete = true,
    adsGet = true, adsPost = true, adsDelete = true,
    mailGet = true, mailRead = true, mailDelete = true,
    notesGet = true, notesSave = true, notesDelete = true,
    garageGet = true,
    servicesSend = true,
}

-- Works with custom_inventory or ox_inventory through nova_core's inventory layer
local function hasPhone()
    if not Config.RequireItem then return true end
    local ok, count = pcall(function() return exports.nova_core:GetItemCount(Config.PhoneItem) end)
    return ok and (count or 0) > 0
end

---------------------------------------------------------------------------
-- Animation / prop
---------------------------------------------------------------------------
local function startAnim()
    local ped = cache.ped
    local anim = IsPedInAnyVehicle(ped, false) and 'cellphone@in_car@ds' or 'cellphone@'
    lib.requestAnimDict(anim)
    TaskPlayAnim(ped, anim, 'cellphone_text_read_base', 3.0, 3.0, -1, 49, 0, false, false, false)

    local model = `prop_npc_phone_02`
    lib.requestModel(model)
    phoneProp = CreateObject(model, 0.0, 0.0, 0.0, true, true, false)
    AttachEntityToEntity(phoneProp, ped, GetPedBoneIndex(ped, 28422), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, true, true, false, true, 1, true)
    SetModelAsNoLongerNeeded(model)
end

local function stopAnim()
    if inCall then return end -- keep holding the phone during a call
    local ped = cache.ped
    StopAnimTask(ped, 'cellphone@', 'cellphone_text_read_base', 2.5)
    StopAnimTask(ped, 'cellphone@in_car@ds', 'cellphone_text_read_base', 2.5)
    if phoneProp and DoesEntityExist(phoneProp) then DeleteEntity(phoneProp) end
    phoneProp = nil
end

---------------------------------------------------------------------------
-- Open / close
---------------------------------------------------------------------------
local function isLoggedIn()
    if LocalPlayer.state.isLoggedIn then return true end
    -- fallback in case the statebag hasn't replicated yet
    local ok, pd = pcall(function() return exports.nova_core:GetPlayerData() end)
    return ok and pd and pd.citizenid ~= nil
end

local function phoneError(msg)
    print('^1[nova_phone]^7 ' .. msg)
    lib.notify({ title = 'Phone', description = msg, type = 'error' })
end

local function openPhone()
    if isOpen then return end
    if not isLoggedIn() then return phoneError('Character not loaded yet') end
    if IsPauseMenuActive() then return end
    if not hasPhone() then return phoneError("You don't have a phone") end

    local ok, profile = pcall(lib.callback.await, 'nova_phone:server:getProfile', false)
    if not ok or not profile then
        return phoneError('Phone failed to load: no response from server. Check the server console (did you run sql/install.sql?)')
    end
    if not profile.ok then return phoneError('Phone failed to load: ' .. tostring(profile.msg)) end
    isOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', profile = profile })
    startAnim()
end

local function closePhone()
    if not isOpen then return end
    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    stopAnim()
end

lib.addKeybind({
    name = 'nova_phone_open',
    description = 'Open phone',
    defaultKey = Config.OpenKey,
    onPressed = function()
        if isOpen then closePhone() else openPhone() end
    end,
})

RegisterCommand('phone', function() openPhone() end, false)

-- /phonedebug: prints every check the phone makes when opening (open F8 to read it)
RegisterCommand('phonedebug', function()
    local function line(label, value) print(('^3[nova_phone]^7 %-22s %s'):format(label, tostring(value))) end
    line('statebag isLoggedIn', LocalPlayer.state.isLoggedIn)
    local ok, pd = pcall(function() return exports.nova_core:GetPlayerData() end)
    line('nova citizenid', ok and pd and pd.citizenid or ('ERROR ' .. tostring(pd)))
    line('RequireItem', Config.RequireItem)
    line('custom_inventory state', GetResourceState('custom_inventory'))
    line('ox_inventory state', GetResourceState('ox_inventory'))
    local okc, count = pcall(function() return exports.nova_core:GetItemCount(Config.PhoneItem) end)
    line('phone item count', okc and count or ('ERROR ' .. tostring(count)))
    line('voice resource', Config.Voice and GetResourceState(Config.Voice) or 'disabled')
    line('pause menu active', IsPauseMenuActive())
    line('phone open', isOpen)
    local okp, profile = pcall(lib.callback.await, 'nova_phone:server:getProfile', false)
    line('server profile', okp and profile and (profile.ok and ('OK, number ' .. tostring(profile.number)) or profile.msg) or 'NO RESPONSE')
    print('^3[nova_phone]^7 Keybind: check Settings > Key Bindings > FiveM > "Open phone"')
end, false)
exports('OpenPhone', openPhone)
exports('ClosePhone', closePhone)
exports('IsOpen', function() return isOpen end)

---------------------------------------------------------------------------
-- NUI callbacks
---------------------------------------------------------------------------
RegisterNUICallback('close', function(_, cb)
    closePhone()
    cb(1)
end)

RegisterNUICallback('request', function(data, cb)
    if type(data) ~= 'table' or not Allowed[data.action] then return cb({ ok = false, msg = 'Invalid action' }) end
    local result = lib.callback.await('nova_phone:server:' .. data.action, false, data.payload or {})
    cb(result or { ok = false, msg = 'No response' })
end)

RegisterNUICallback('setWaypoint', function(data, cb)
    if data and data.x and data.y then
        SetNewWaypoint(data.x + 0.0, data.y + 0.0)
        lib.notify({ title = 'GPS', description = 'Waypoint set', type = 'inform' })
    end
    cb(1)
end)

---------------------------------------------------------------------------
-- Server pushes
---------------------------------------------------------------------------
local function playTone()
    PlaySoundFrontend(-1, 'Text_Arrive_Tone', 'Phone_SoundSet_Default', true)
end

RegisterNetEvent('nova_phone:client:push', function(kind, data)
    SendNUIMessage({ action = 'push', kind = kind, data = data })

    if kind == 'incomingCall' then
        PlaySoundFrontend(-1, 'Remote_Ring', 'Phone_SoundSet_Michael', true)
        if not isOpen then
            lib.notify({ title = 'Incoming call', description = ('%s is calling - open your phone to answer'):format(data.number), type = 'inform', duration = 8000 })
        end
    elseif not isOpen then
        if kind == 'message' then
            playTone()
            lib.notify({ title = 'New message', description = ('From %s'):format(data.from), type = 'inform' })
        elseif kind == 'mail' then
            playTone()
            lib.notify({ title = 'New mail', description = data.subject or '', type = 'inform' })
        elseif kind == 'bank' then
            lib.notify({ title = 'Bank', description = data.text, type = 'success' })
        elseif kind == 'callEnded' then
            lib.notify({ title = 'Phone', description = data.reason or 'Call ended', type = 'inform' })
        end
    end

    if kind == 'dispatch' then
        playTone()
        lib.notify({ title = data.service .. ' alert', description = ('%s (%s): %s'):format(data.name, data.number, data.text), type = 'warning', duration = 10000 })
        if data.coords then
            local blip = AddBlipForCoord(data.coords.x, data.coords.y, data.coords.z)
            SetBlipSprite(blip, 280)
            SetBlipColour(blip, 1)
            SetBlipScale(blip, 1.0)
            SetBlipFlashes(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(data.service .. ' call')
            EndTextCommandSetBlipName(blip)
            SetTimeout(Config.DispatchBlipTime * 1000, function() RemoveBlip(blip) end)
        end
    end

    if kind == 'callEnded' then
        inCall = false
        if Config.Voice and GetResourceState(Config.Voice) == 'started' then
            exports[Config.Voice]:setCallChannel(0)
        end
        if not isOpen then stopAnim() end
    end
end)

RegisterNetEvent('nova_phone:client:joinCall', function(callId)
    inCall = true
    if Config.Voice and GetResourceState(Config.Voice) == 'started' then
        exports[Config.Voice]:setCallChannel(callId)
    end
end)

-- Close the phone if the item is lost / player logs out
RegisterNetEvent('nova:client:onPlayerUnload', closePhone)

-- Phone item opened from custom_inventory (use / hotbar)
RegisterNetEvent('nova_phone:client:usePhone', function()
    if isOpen then closePhone() else openPhone() end
end)

-- custom_inventory: close the phone if the item is gone
AddEventHandler('custom_inventory:client:updated', function()
    if isOpen and Config.RequireItem and not hasPhone() then
        if inCall then lib.callback.await('nova_phone:server:callEnd', false) end
        closePhone()
    end
end)
AddEventHandler('ox_inventory:itemCount', function(item, count)
    if item == Config.PhoneItem and count < 1 and Config.RequireItem then
        if inCall then lib.callback.await('nova_phone:server:callEnd', false) end
        closePhone()
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    SetNuiFocus(false, false)
    inCall = false
    stopAnim()
end)
