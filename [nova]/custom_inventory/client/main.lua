--[[
    custom_inventory — client
    Handles keybinds, deciding what container to open, the NUI, item
    animations and ground-drop props. All item changes happen server-side.
]]

local isOpen       = false
local busy         = false      -- playing an item-use animation
local playerInv    = nil        -- latest copy of our own inventory
local secondary    = nil        -- serialized secondary inventory currently shown
local secondaryCtx = nil        -- { type, coords?, veh? } for auto-close + trunk door
local pendingCtx   = nil
local lastOpenReq  = 0
local drops        = {}         -- [dropId] = vector3
local dropProps    = {}         -- [dropId] = entity

-- ─── Utilities ──────────────────────────────────────────────────────

local function notify(msg, kind)
    SendNUIMessage({ action = 'notify', message = msg, kind = kind or 'info' })
end

local function loadDict(dict)
    if HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 3000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < timeout do Wait(10) end
    return HasAnimDictLoaded(dict)
end

local function helpText(text)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, true, -1)
end

local function canInteract()
    local ped = PlayerPedId()
    return LocalPlayer.state.isLoggedIn and playerInv ~= nil
        and not IsEntityDead(ped) and not IsPauseMenuActive() and not busy
        and not IsPedCuffed(ped) and not IsPedRagdoll(ped)
end

local function showHotbar()
    if playerInv then SendNUIMessage({ action = 'hotbar', inventory = playerInv }) end
end

-- ─── Finding a container to open ──────────────────────────────────

local function closestDrop()
    local pc = GetEntityCoords(PlayerPedId())
    local best, bestDist
    for id, coords in pairs(drops) do
        local d = #(pc - coords)
        if d <= Config.DropDistance and (not bestDist or d < bestDist) then best, bestDist = id, d end
    end
    return best
end

local function trunkVehicle()
    local ped = PlayerPedId()
    local pc = GetEntityCoords(ped)
    local best, bestDist
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        if #(pc - GetEntityCoords(veh)) < 8.0 then
            local min = GetModelDimensions(GetEntityModel(veh))
            local trunkPos = GetOffsetFromEntityInWorldCoords(veh, 0.0, min.y - 0.25, 0.0)
            local d = #(pc - trunkPos)
            if d < 1.6 and (not bestDist or d < bestDist) then best, bestDist = veh, d end
        end
    end
    return best
end

local function openInventory()
    if isOpen or not canInteract() or GetGameTimer() - lastOpenReq < 500 then return end
    lastOpenReq = GetGameTimer()

    local ped = PlayerPedId()
    local target
    pendingCtx = nil

    local dropId = closestDrop()
    if IsPedInAnyVehicle(ped, false) then
        local veh = GetVehiclePedIsIn(ped, false)
        if NetworkGetEntityIsNetworked(veh) then
            target = { type = 'glovebox', netId = NetworkGetNetworkIdFromEntity(veh) }
            pendingCtx = { type = 'glovebox', veh = veh }
        end
    elseif dropId then
        target = { type = 'drop', id = dropId }
        pendingCtx = { type = 'drop', coords = drops[dropId] }
    else
        local veh = trunkVehicle()
        if veh and NetworkGetEntityIsNetworked(veh) then
            local class = GetVehicleClass(veh)
            if Config.Trunk.Classes[class] == false then
                -- no trunk on this vehicle; just open pockets
            elseif GetVehicleDoorLockStatus(veh) >= 2 then
                notify('The trunk is locked.', 'error')
            else
                target = { type = 'trunk', netId = NetworkGetNetworkIdFromEntity(veh), class = class }
                pendingCtx = { type = 'trunk', veh = veh }
            end
        end
    end

    TriggerServerEvent('inv:server:open', target)
end

local function openContainer(kind, id, coords)
    if isOpen or not canInteract() or GetGameTimer() - lastOpenReq < 500 then return end
    lastOpenReq = GetGameTimer()
    pendingCtx = { type = kind, coords = coords }
    TriggerServerEvent('inv:server:open', { type = kind, id = id })
end

local function closeInventory()
    if not isOpen then return end
    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    TriggerServerEvent('inv:server:close')
    if secondaryCtx and secondaryCtx.type == 'trunk' and DoesEntityExist(secondaryCtx.veh) then
        SetVehicleDoorShut(secondaryCtx.veh, 5, false)
    end
    secondary, secondaryCtx = nil, nil
end

-- ─── Keybinds ──────────────────────────────────────────────────────

RegisterCommand('inventory', openInventory, false)
RegisterKeyMapping('inventory', 'Open inventory', 'keyboard', Config.OpenKey)

for i = 1, Config.HotbarSlots do
    RegisterCommand('hotbar' .. i, function()
        if isOpen or not canInteract() then return end
        showHotbar()
        if playerInv then
            for _, item in ipairs(playerInv.items) do
                if item.slot == i then return TriggerServerEvent('inv:server:use', i) end
            end
        end
    end, false)
    RegisterKeyMapping('hotbar' .. i, ('Use hotbar slot %d'):format(i), 'keyboard', tostring(i))
end

RegisterCommand('showhotbar', showHotbar, false)
RegisterKeyMapping('showhotbar', 'Show inventory hotbar', 'keyboard', 'Z')

-- ─── Server → client ───────────────────────────────────────────────

RegisterNetEvent('inv:client:setPlayerInventory', function(inv)
    playerInv = inv
    TriggerEvent('custom_inventory:client:updated', inv.items)
end)

-- Character logged out: forget their items and close the UI
RegisterNetEvent('inv:client:unload', function()
    if isOpen then
        isOpen = false
        SetNuiFocus(false, false)
        SendNUIMessage({ action = 'close' })
    end
    playerInv, secondary, secondaryCtx = nil, nil, nil
    TriggerEvent('custom_inventory:client:updated', {})
end)

RegisterNetEvent('inv:client:open', function(pInv, sec)
    playerInv, secondary = pInv, sec
    secondaryCtx = sec and pendingCtx or nil
    pendingCtx = nil
    isOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', player = pInv, secondary = sec })

    if secondaryCtx and secondaryCtx.type == 'trunk' and DoesEntityExist(secondaryCtx.veh) then
        SetVehicleDoorOpen(secondaryCtx.veh, 5, false, false)
        TaskTurnPedToFaceEntity(PlayerPedId(), secondaryCtx.veh, 800)
    end
end)

RegisterNetEvent('inv:client:update', function(inv)
    if inv.type == 'player' then
        playerInv = inv
        TriggerEvent('custom_inventory:client:updated', inv.items)
    end
    if secondary and inv.id == secondary.id then secondary = inv end
    if isOpen then SendNUIMessage({ action = 'update', inventory = inv }) end
end)

RegisterNetEvent('inv:client:setSecondary', function(inv)
    secondary = inv
    secondaryCtx = { type = 'drop', coords = GetEntityCoords(PlayerPedId()) }
    if isOpen then SendNUIMessage({ action = 'setSecondary', inventory = inv }) end
end)

RegisterNetEvent('inv:client:closeSecondary', function(id)
    if secondary and secondary.id == id then
        secondary, secondaryCtx = nil, nil
        if isOpen then SendNUIMessage({ action = 'setSecondary', inventory = nil }) end
    end
end)

RegisterNetEvent('inv:client:notify', notify)

RegisterNetEvent('inv:client:drops', function(list)
    drops = {}
    for id, c in pairs(list) do drops[id] = vector3(c.x, c.y, c.z) end
    for id, obj in pairs(dropProps) do
        if not drops[id] then
            if DoesEntityExist(obj) then DeleteEntity(obj) end
            dropProps[id] = nil
        end
    end
end)

RegisterNetEvent('inv:client:addStash', function(data)
    for i, s in ipairs(Config.Stashes) do
        if s.id == data.id then Config.Stashes[i] = data; return end
    end
    Config.Stashes[#Config.Stashes + 1] = data
end)

RegisterNetEvent('inv:client:giveAnim', function()
    local ped = PlayerPedId()
    if loadDict('mp_common') then
        TaskPlayAnim(ped, 'mp_common', 'givetake1_a', 8.0, -8.0, 1500, 49, 0, false, false, false)
    end
end)

-- ─── Using items ───────────────────────────────────────────────────

RegisterNetEvent('inv:client:useItem', function(name, use, shouldClose)
    if busy then return TriggerServerEvent('inv:server:finishUse', true) end
    if shouldClose then closeInventory() end
    busy = true

    CreateThread(function()
        local ped = PlayerPedId()
        local anim = use.anim
        if anim and loadDict(anim.dict) then
            TaskPlayAnim(ped, anim.dict, anim.clip, 8.0, -8.0, -1, anim.flag or 49, 0, false, false, false)
        end

        local duration = use.duration or 0
        local label = Items[name] and Items[name].label or name
        if duration > 0 then
            SendNUIMessage({ action = 'progress', label = 'Using ' .. label, duration = duration })
        end

        local endAt = GetGameTimer() + duration
        local cancelled = false
        while GetGameTimer() < endAt do
            Wait(0)
            DisableControlAction(0, 24, true)  -- attack
            DisableControlAction(0, 25, true)  -- aim
            if IsEntityDead(ped) or IsPedRagdoll(ped) or IsControlJustPressed(0, 73) then -- X cancels
                cancelled = true
                break
            end
        end

        if anim then StopAnimTask(ped, anim.dict, anim.clip, 1.0) end
        if duration > 0 then SendNUIMessage({ action = 'progressEnd', cancelled = cancelled }) end
        busy = false
        TriggerServerEvent('inv:server:finishUse', cancelled)
    end)
end)

RegisterNetEvent('inv:client:applyEffect', function(name, use)
    local ped = PlayerPedId()
    if use.effect == 'heal' then
        SetEntityHealth(ped, math.min(GetEntityMaxHealth(ped), GetEntityHealth(ped) + (use.amount or 0)))
    elseif use.effect == 'armour' then
        SetPedArmour(ped, math.min(100, GetPedArmour(ped) + (use.amount or 0)))
    end
    -- Hook for HUD / needs scripts (hunger, thirst, etc.)
    TriggerEvent('custom_inventory:client:itemUsed', name, use)
end)

-- ─── NUI callbacks ─────────────────────────────────────────────────

RegisterNUICallback('close', function(_, cb)
    closeInventory(); cb('ok')
end)

RegisterNUICallback('move', function(d, cb)
    TriggerServerEvent('inv:server:move', d.fromInv, d.fromSlot, d.toInv, d.toSlot, d.count)
    cb('ok')
end)

RegisterNUICallback('use', function(d, cb)
    TriggerServerEvent('inv:server:use', d.slot)
    cb('ok')
end)

RegisterNUICallback('drop', function(d, cb)
    TriggerServerEvent('inv:server:drop', d.slot, d.count)
    cb('ok')
end)

RegisterNUICallback('give', function(d, cb)
    local ped = PlayerPedId()
    local pc = GetEntityCoords(ped)
    local best, bestDist
    for _, pid in ipairs(GetActivePlayers()) do
        if pid ~= PlayerId() then
            local dist = #(pc - GetEntityCoords(GetPlayerPed(pid)))
            if dist <= Config.GiveDistance and (not bestDist or dist < bestDist) then best, bestDist = pid, dist end
        end
    end
    if best then
        TriggerServerEvent('inv:server:give', d.slot, d.count, GetPlayerServerId(best))
    else
        notify('Nobody nearby.', 'error')
    end
    cb('ok')
end)

-- ─── Threads ───────────────────────────────────────────────────────

-- Tell the server we're ready, send item definitions to the UI
CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do Wait(500) end
    local defs = {}
    for name, def in pairs(Items) do
        defs[name] = { label = def.label, weight = def.weight, stack = def.stack,
                       description = def.description, usable = def.use ~= nil }
    end
    SendNUIMessage({ action = 'init', items = defs, hotbarSlots = Config.HotbarSlots })
    TriggerServerEvent('inv:server:ready')
end)

-- Stop 1-5 / TAB from also triggering the weapon wheel
if Config.DisableWeaponWheelKeys then
    CreateThread(function()
        while true do
            Wait(0)
            DisableControlAction(0, 37, true)
            DisableControlAction(0, 157, true)
            DisableControlAction(0, 158, true)
            DisableControlAction(0, 160, true)
            DisableControlAction(0, 164, true)
            DisableControlAction(0, 165, true)
        end
    end)
end

-- Stash & shop markers / prompts
CreateThread(function()
    for _, shop in ipairs(Config.Shops) do
        if shop.blip then
            local b = AddBlipForCoord(shop.coords.x, shop.coords.y, shop.coords.z)
            SetBlipSprite(b, shop.blip.sprite or 52)
            SetBlipColour(b, shop.blip.color or 2)
            SetBlipScale(b, shop.blip.scale or 0.7)
            SetBlipAsShortRange(b, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(shop.label)
            EndTextCommandSetBlipName(b)
        end
    end

    while true do
        local sleep = 750
        if not isOpen then
            local pc = GetEntityCoords(PlayerPedId())
            local function handle(list, kind, prompt)
                for _, p in ipairs(list) do
                    local d = #(pc - p.coords)
                    if d < 10.0 then
                        sleep = 0
                        DrawMarker(2, p.coords.x, p.coords.y, p.coords.z, 0, 0, 0, 0, 180.0, 0,
                            0.2, 0.2, 0.2, 120, 180, 255, 160, false, true, 2, false, nil, nil, false)
                        if d <= Config.InteractDistance then
                            helpText(('~INPUT_CONTEXT~ %s %s'):format(prompt, p.label))
                            if IsControlJustReleased(0, 38) then openContainer(kind, p.id, p.coords) end
                        end
                    end
                end
            end
            handle(Config.Stashes, 'stash', 'Open')
            handle(Config.Shops, 'shop', 'Browse')
        end
        Wait(sleep)
    end
end)

-- Ground-drop props
CreateThread(function()
    local model = GetHashKey(Config.DropProp)
    while true do
        Wait(1000)
        local pc = GetEntityCoords(PlayerPedId())
        for id, coords in pairs(drops) do
            local near = #(pc - coords) < 60.0
            local obj = dropProps[id]
            if near and not obj then
                RequestModel(model)
                local t = GetGameTimer() + 3000
                while not HasModelLoaded(model) and GetGameTimer() < t do Wait(10) end
                if HasModelLoaded(model) then
                    obj = CreateObject(model, coords.x, coords.y, coords.z, false, false, false)
                    PlaceObjectOnGroundProperly(obj)
                    FreezeEntityPosition(obj, true)
                    SetEntityCollision(obj, false, false)
                    dropProps[id] = obj
                end
            elseif not near and obj then
                if DoesEntityExist(obj) then DeleteEntity(obj) end
                dropProps[id] = nil
            end
        end
    end
end)

-- Close automatically when walking away from the open container
CreateThread(function()
    while true do
        Wait(400)
        if isOpen and secondaryCtx then
            local ped = PlayerPedId()
            local far = false
            if secondaryCtx.type == 'glovebox' then
                far = not IsPedInAnyVehicle(ped, false)
            elseif secondaryCtx.veh then
                far = not DoesEntityExist(secondaryCtx.veh)
                    or #(GetEntityCoords(ped) - GetEntityCoords(secondaryCtx.veh)) > Config.MaxAccessDistance
            elseif secondaryCtx.coords then
                far = #(GetEntityCoords(ped) - secondaryCtx.coords) > Config.MaxAccessDistance - 1.0
            end
            if far or IsEntityDead(ped) then closeInventory() end
        end
    end
end)

-- Clean up
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if isOpen then SetNuiFocus(false, false) end
    for _, obj in pairs(dropProps) do if DoesEntityExist(obj) then DeleteEntity(obj) end end
end)

-- ─── Client exports ────────────────────────────────────────────────

exports('IsOpen', function() return isOpen end)
exports('CloseInventory', closeInventory)
exports('GetPlayerItems', function() return playerInv and playerInv.items or {} end)
exports('GetItemDefinitions', function(name)
    if name then return Items[name] end
    return Items
end)
exports('OpenStash', function(id)
    for _, s in ipairs(Config.Stashes) do
        if s.id == id then return openContainer('stash', id, s.coords) end
    end
end)
