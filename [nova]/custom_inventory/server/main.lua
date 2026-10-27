--[[
    custom_inventory — server
    The server owns every inventory. Clients only *ask* for things
    (move / use / give / drop); every request is validated here.
]]

local Inventories   = {}  -- [invId] = inventory
local PlayerInv     = {}  -- [src]   = invId
local OpenSecondary = {}  -- [src]   = invId of the container they have open
local PendingUse    = {}  -- [src]   = { slot, name, def, started }
local UsableItems   = {}  -- [name]  = function(src, item, slot)
local Drops         = {}  -- [dropId] = { coords, created }
local Loading       = {}  -- [invId] = true while a DB load is in flight
local dropCounter   = 0

local PERSISTENT = { player = true, stash = true, trunk = true, glovebox = true }

local core = exports.nova_core

-- ─── Helpers ─────────────────────────────────────────────────────────

local function trim(s) return (s:gsub('^%s+', ''):gsub('%s+$', '')) end

local function notify(src, msg, kind)
    TriggerClientEvent('inv:client:notify', src, msg, kind or 'info')
end

-- Inventories belong to the character (Nova citizenid), not the Rockstar license
local function getIdentifier(src)
    local pd = core:GetPlayerData(src)
    return pd and pd.citizenid or nil
end

local function characterName(src)
    local pd = core:GetPlayerData(src)
    if not pd then return GetPlayerName(src) or 'Pockets' end
    return ('%s %s'):format(pd.charinfo.firstname, pd.charinfo.lastname)
end

-- stash.job = 'police'  or  { police = 0, ambulance = 2 }  (job = minimum grade)
local function jobAllowed(src, job)
    if not job then return true end
    local pd = core:GetPlayerData(src)
    if not pd then return false end
    if type(job) == 'string' then return pd.job.name == job end
    local minGrade = job[pd.job.name]
    return minGrade ~= nil and (pd.job.grade.level or 0) >= minGrade
end

local function isEmpty(t) return t == nil or next(t) == nil end

local function itemWeight(name, count)
    local def = Items[name]
    return def and (def.weight * count) or 0
end

local function invWeight(inv)
    local w = 0
    for _, item in pairs(inv.items) do w = w + itemWeight(item.name, item.count) end
    return w
end

local function canStack(a, b)
    if a.name ~= b.name then return false end
    local def = Items[a.name]
    return def and def.stack and isEmpty(a.metadata) and isEmpty(b.metadata)
end

local function copyItem(item, count)
    return { name = item.name, count = count or item.count,
             metadata = item.metadata and json.decode(json.encode(item.metadata)) or {} }
end

local function validSlot(inv, slot)
    return type(slot) == 'number' and slot >= 1 and slot <= inv.slots and slot % 1 == 0
end

-- ─── Serialisation (to client / to DB) ──────────────────────────────

local function itemsToList(inv)
    local list = {}
    for slot, item in pairs(inv.items) do
        list[#list + 1] = { slot = slot, name = item.name, count = item.count,
                            metadata = item.metadata, price = item.price }
    end
    return list
end

local function serialize(inv)
    return {
        id = inv.id, type = inv.type, label = inv.label,
        slots = inv.slots, maxWeight = inv.maxWeight,
        weight = invWeight(inv), items = itemsToList(inv),
    }
end

local function listToItems(list)
    local items = {}
    for _, it in ipairs(list or {}) do
        if Items[it.name] and it.count and it.count > 0 then
            items[it.slot] = { name = it.name, count = it.count, metadata = it.metadata or {} }
        end
    end
    return items
end

-- ─── Sync ──────────────────────────────────────────────────────────

local reconcileCash -- defined in the Nova cash section below

local function sync(inv)
    if inv.type == 'player' and inv.src then reconcileCash(inv) end
    local payload = serialize(inv)
    if inv.type == 'player' and inv.src then
        TriggerClientEvent('inv:client:update', inv.src, payload)
    end
    for s in pairs(inv.openedBy) do
        if s ~= inv.src then TriggerClientEvent('inv:client:update', s, payload) end
    end
end

local function markDirty(inv)
    if PERSISTENT[inv.type] then inv.dirty = true end
end

-- ─── Persistence ────────────────────────────────────────────────────

local function saveInventory(inv)
    if not PERSISTENT[inv.type] or not inv.dirty then return end
    inv.dirty = false
    local data = json.encode(itemsToList(inv))
    MySQL.prepare('INSERT INTO inventories (id, data) VALUES (?, ?) ON DUPLICATE KEY UPDATE data = ?',
        { inv.id, data, data })
end

local function saveAll()
    local n = 0
    for _, inv in pairs(Inventories) do
        if inv.dirty then saveInventory(inv); n = n + 1 end
    end
    return n
end

local function newInventory(id, invType, label, slots, maxWeight, items, extra)
    local inv = {
        id = id, type = invType, label = label,
        slots = slots, maxWeight = maxWeight,
        items = items or {}, openedBy = {}, dirty = false,
    }
    for k, v in pairs(extra or {}) do inv[k] = v end
    Inventories[id] = inv
    return inv
end

-- Loads from DB if needed. Must be called from a thread (it awaits).
local function loadInventory(id, invType, label, slots, maxWeight, extra, defaultItems)
    if Inventories[id] then return Inventories[id] end
    while Loading[id] do Wait(0) end
    if Inventories[id] then return Inventories[id] end

    Loading[id] = true
    local data = MySQL.scalar.await('SELECT data FROM inventories WHERE id = ?', { id })
    Loading[id] = nil
    if Inventories[id] then return Inventories[id] end

    local inv
    if data then
        inv = newInventory(id, invType, label, slots, maxWeight, listToItems(json.decode(data)), extra)
    else
        inv = newInventory(id, invType, label, slots, maxWeight, {}, extra)
        if defaultItems then inv.pendingDefaults = defaultItems end
    end
    return inv
end

-- ─── Core item operations ─────────────────────────────────────────

local function countItem(inv, name, metadata)
    local total = 0
    for _, item in pairs(inv.items) do
        if item.name == name and (not metadata or json.encode(item.metadata) == json.encode(metadata)) then
            total = total + item.count
        end
    end
    return total
end

local function freeSlots(inv)
    local free = {}
    for i = 1, inv.slots do if not inv.items[i] then free[#free + 1] = i end end
    return free
end

local function canCarry(inv, name, count, metadata)
    local def = Items[name]
    if not def then return false, 'Unknown item' end
    if invWeight(inv) + itemWeight(name, count) > inv.maxWeight then return false, 'Too heavy' end

    local needed
    if def.stack and isEmpty(metadata) then
        for _, item in pairs(inv.items) do
            if item.name == name and isEmpty(item.metadata) then return true end
        end
        needed = 1
    else
        needed = def.stack and 1 or count
    end
    if #freeSlots(inv) < needed then return false, 'Not enough space' end
    return true
end

local function addItem(inv, name, count, metadata, slot)
    count = math.floor(tonumber(count) or 0)
    if count <= 0 then return false, 'Invalid amount' end
    local def = Items[name]
    metadata = metadata or {}

    local ok, reason = canCarry(inv, name, count, metadata)
    if not ok then return false, reason end

    -- Preferred slot (used when a specific target slot was chosen)
    if slot and validSlot(inv, slot) then
        local existing = inv.items[slot]
        local incoming = { name = name, count = count, metadata = metadata }
        if not existing and (def.stack or count == 1) then
            inv.items[slot] = incoming
            markDirty(inv); return true
        elseif existing and canStack(existing, incoming) then
            existing.count = existing.count + count
            markDirty(inv); return true
        end
    end

    if def.stack then
        if isEmpty(metadata) then
            for _, item in pairs(inv.items) do
                if item.name == name and isEmpty(item.metadata) then
                    item.count = item.count + count
                    markDirty(inv); return true
                end
            end
        end
        local free = freeSlots(inv)
        inv.items[free[1]] = { name = name, count = count, metadata = metadata }
    else
        local free = freeSlots(inv)
        for i = 1, count do
            inv.items[free[i]] = { name = name, count = 1, metadata = copyItem({ name = name, metadata = metadata }).metadata }
        end
    end
    markDirty(inv)
    return true
end

local function removeItem(inv, name, count, metadata, slot)
    count = math.floor(tonumber(count) or 0)
    if count <= 0 then return false end
    if countItem(inv, name, metadata) < count then return false end

    local function take(s)
        local item = inv.items[s]
        if not item or item.name ~= name then return end
        if metadata and json.encode(item.metadata) ~= json.encode(metadata) then return end
        local n = math.min(item.count, count)
        item.count = item.count - n
        count = count - n
        if item.count <= 0 then inv.items[s] = nil end
    end

    if slot then take(slot) end
    for s = 1, inv.slots do
        if count <= 0 then break end
        take(s)
    end
    markDirty(inv)
    return true
end

-- ─── Drops ────────────────────────────────────────────────────────

local function broadcastDrops()
    local list = {}
    for id, d in pairs(Drops) do list[id] = d.coords end
    TriggerClientEvent('inv:client:drops', -1, list)
end

local function removeDrop(id)
    local inv = Inventories[id]
    if inv then
        for s in pairs(inv.openedBy) do
            OpenSecondary[s] = nil
            TriggerClientEvent('inv:client:closeSecondary', s, id)
        end
        Inventories[id] = nil
    end
    Drops[id] = nil
    broadcastDrops()
end

local function createDrop(coords)
    -- Reuse a drop that's right next to the player
    for id, d in pairs(Drops) do
        if #(d.coords - coords) < 1.0 and Inventories[id] then return Inventories[id] end
    end
    dropCounter = dropCounter + 1
    local id = ('drop:%d'):format(dropCounter)
    local ground = vector3(coords.x, coords.y, coords.z - 0.98)
    Drops[id] = { coords = ground, created = os.time() }
    local inv = newInventory(id, 'drop', 'Ground', Config.DropSlots, 1000000, {}, { coords = ground })
    broadcastDrops()
    return inv
end

local function cleanupDropIfEmpty(inv)
    if inv and inv.type == 'drop' and isEmpty(inv.items) then removeDrop(inv.id) end
end

-- ─── Access checks ────────────────────────────────────────────────

local function playerCoords(src)
    return GetEntityCoords(GetPlayerPed(src))
end

local function inRange(src, inv)
    if inv.type == 'player' then return inv.src == src end
    local pc = playerCoords(src)
    if inv.netId then
        local veh = NetworkGetEntityFromNetworkId(inv.netId)
        if not veh or veh == 0 or not DoesEntityExist(veh) then return false end
        if inv.type == 'glovebox' then return GetVehiclePedIsIn(GetPlayerPed(src), false) == veh end
        return #(pc - GetEntityCoords(veh)) <= Config.MaxAccessDistance + 2.0
    end
    if inv.coords then return #(pc - inv.coords) <= Config.MaxAccessDistance end
    return true
end

local function canAccess(src, invId)
    local inv = Inventories[invId]
    if not inv then return nil end
    if inv.type == 'player' then return inv.src == src and inv or nil end
    if OpenSecondary[src] ~= invId then return nil end
    if not inRange(src, inv) then return nil end
    return inv
end

local function closeSecondary(src)
    local id = OpenSecondary[src]
    if not id then return end
    OpenSecondary[src] = nil
    local inv = Inventories[id]
    if inv then
        inv.openedBy[src] = nil
        cleanupDropIfEmpty(inv)
    end
end

-- ─── Nova cash ↔ money item ───────────────────────────────────────
-- Nova's money.cash is the real balance. The money item mirrors it:
--   • Nova cash changes (paycheck, script, admin) → item count is updated
--   • Item count changes (shop, drop, give)        → Nova cash is updated
-- If the item can't be placed (pockets full) we stop pushing item → cash
-- until it fits again, so a full inventory can never wipe someone's cash.

local function setCashItem(inv, amount)
    amount = math.max(0, math.floor(tonumber(amount) or 0))
    local current = countItem(inv, Config.MoneyItem)
    if current > amount then
        removeItem(inv, Config.MoneyItem, current - amount)
    elseif current < amount then
        if not addItem(inv, Config.MoneyItem, amount - current) then
            inv.cashSynced = false
            return false
        end
    end
    inv.cashSynced = true
    return true
end

reconcileCash = function(inv)
    local cash = core:GetMoney(inv.src, 'cash')
    if not cash then return end
    if not inv.cashSynced then
        setCashItem(inv, cash)
        return
    end
    local count = countItem(inv, Config.MoneyItem)
    if count ~= math.floor(cash) then
        core:SetMoney(inv.src, 'cash', count, 'inventory')
    end
end

-- ─── Player lifecycle (driven by Nova login / logout) ──────────────

local function getPlayerInv(src)
    local id = PlayerInv[src]
    return id and Inventories[id]
end

-- Only call for a player with a loaded Nova character. Must run in a thread.
local function loadPlayer(src)
    if getPlayerInv(src) then return getPlayerInv(src) end
    local citizenid = getIdentifier(src)
    if not citizenid then return nil end

    local id = 'player:' .. citizenid
    local inv = loadInventory(id, 'player', characterName(src),
        Config.PlayerSlots, Config.PlayerMaxWeight, {}, Config.StartingItems)
    inv.src = src
    inv.cashSynced = false
    PlayerInv[src] = id
    if inv.pendingDefaults then
        for _, it in ipairs(inv.pendingDefaults) do addItem(inv, it.name, it.count, it.metadata) end
        inv.pendingDefaults = nil
        markDirty(inv)
    end
    setCashItem(inv, core:GetMoney(src, 'cash'))
    return inv
end

local function unloadPlayer(src)
    closeSecondary(src)
    PendingUse[src] = nil
    local inv = getPlayerInv(src)
    if inv then
        inv.dirty = true
        saveInventory(inv)
        Inventories[inv.id] = nil
    end
    PlayerInv[src] = nil
end

local function sendDrops(src)
    local list = {}
    for id, d in pairs(Drops) do list[id] = d.coords end
    TriggerClientEvent('inv:client:drops', src, list)
end

local function loadAndSend(src)
    local inv = loadPlayer(src)
    if inv and GetPlayerName(src) then
        TriggerClientEvent('inv:client:setPlayerInventory', src, serialize(inv))
    end
end

-- Character selected
AddEventHandler('nova:server:playerLoaded', function(src)
    CreateThread(function() loadAndSend(src) end)
end)

-- Logout (/logout) or disconnect
AddEventHandler('nova:server:onPlayerUnload', function(src, _, dropped)
    unloadPlayer(src)
    if not dropped then TriggerClientEvent('inv:client:unload', src) end
end)

-- Client UI is ready: send drops, and the inventory if a character is already loaded
RegisterNetEvent('inv:server:ready', function()
    local src = source
    sendDrops(src)
    if core:IsPlayerLoaded(src) then loadAndSend(src) end
end)

-- Safety net in case the unload event was missed
AddEventHandler('playerDropped', function()
    unloadPlayer(source)
end)

-- Keep Nova cash and the money item in step
AddEventHandler('nova:server:onMoneyChange', function(src, account)
    if account ~= 'cash' then return end
    local inv = getPlayerInv(src)
    if not inv then return end
    local cash = core:GetMoney(src, 'cash')
    if cash and countItem(inv, Config.MoneyItem) ~= math.floor(cash) then
        setCashItem(inv, cash)
        sync(inv)
    end
end)

-- Resource restarted while people are playing: reload their inventories
CreateThread(function()
    Wait(1000)
    for _, src in ipairs(core:GetPlayerSources() or {}) do loadAndSend(src) end
end)

-- ─── Opening containers ───────────────────────────────────────────

local function findStash(id)
    for _, s in ipairs(Config.Stashes) do if s.id == id then return s end end
end

local function findShop(id)
    for _, s in ipairs(Config.Shops) do if s.id == id then return s end end
end

local function getShopInventory(shop)
    local id = 'shop:' .. shop.id
    if Inventories[id] then return Inventories[id] end
    local items = {}
    for i, entry in ipairs(shop.items) do
        if Items[entry.name] then
            items[i] = { name = entry.name, count = 1, metadata = {}, price = entry.price }
        end
    end
    return newInventory(id, 'shop', shop.label, #shop.items, 0, items, { coords = shop.coords })
end

RegisterNetEvent('inv:server:open', function(target)
    local src = source
    local pInv = getPlayerInv(src)
    if not pInv then return end -- no character loaded (e.g. still in character select)
    closeSecondary(src)

    local secondary
    if type(target) == 'table' then
        local pc = playerCoords(src)

        if target.type == 'stash' then
            local stash = findStash(target.id)
            if stash and #(pc - stash.coords) <= Config.InteractDistance + 1.5 then
                if (stash.ace and not IsPlayerAceAllowed(src, stash.ace)) or not jobAllowed(src, stash.job) then
                    notify(src, 'You can\'t open this.', 'error')
                else
                    local id = 'stash:' .. stash.id .. (stash.personal and (':' .. getIdentifier(src)) or '')
                    secondary = loadInventory(id, 'stash', stash.label, stash.slots, stash.weight,
                        { coords = stash.coords })
                end
            end

        elseif target.type == 'shop' then
            local shop = findShop(target.id)
            if shop and #(pc - shop.coords) <= Config.InteractDistance + 1.5 then
                secondary = getShopInventory(shop)
            end

        elseif target.type == 'drop' then
            local inv = Inventories[target.id]
            if inv and inv.type == 'drop' and #(pc - inv.coords) <= Config.DropDistance + 1.5 then
                secondary = inv
            end

        elseif (target.type == 'trunk' or target.type == 'glovebox') and type(target.netId) == 'number' then
            local veh = NetworkGetEntityFromNetworkId(target.netId)
            if veh and veh ~= 0 and DoesEntityExist(veh) and GetEntityType(veh) == 2 then
                local plate = trim(GetVehicleNumberPlateText(veh) or '')
                if plate ~= '' then
                    if target.type == 'glovebox' then
                        if GetVehiclePedIsIn(GetPlayerPed(src), false) == veh then
                            secondary = loadInventory('glovebox:' .. plate, 'glovebox', 'Glovebox ' .. plate,
                                Config.Glovebox.slots, Config.Glovebox.weight, { netId = target.netId })
                        end
                    elseif #(pc - GetEntityCoords(veh)) <= Config.MaxAccessDistance + 2.0 then
                        local size = Config.Trunk.Classes[tonumber(target.class) or -1]
                        if size ~= false then
                            size = size or Config.Trunk.Default
                            secondary = loadInventory('trunk:' .. plate, 'trunk', 'Trunk ' .. plate,
                                size.slots, size.weight, { netId = target.netId })
                        end
                    end
                    if secondary then secondary.netId = target.netId end
                end
            end
        end
    end

    if secondary then
        -- A load may have yielded; make sure the player is still here
        if not GetPlayerName(src) then return end
        OpenSecondary[src] = secondary.id
        secondary.openedBy[src] = true
    end

    TriggerClientEvent('inv:client:open', src, serialize(pInv), secondary and serialize(secondary) or nil)
end)

RegisterNetEvent('inv:server:close', function()
    closeSecondary(source)
end)

-- ─── Moving items ─────────────────────────────────────────────────

local function buyFromShop(src, shopInv, fromSlot, pInv, toSlot, count)
    local entry = shopInv.items[fromSlot]
    if not entry then return end
    local def = Items[entry.name]
    if not def.stack then count = 1 end
    local total = entry.price * count

    if countItem(pInv, Config.MoneyItem) < total then
        return notify(src, ('You need $%d.'):format(total), 'error')
    end
    -- Weight check accounts for the cash leaving the inventory
    local newWeight = invWeight(pInv) - itemWeight(Config.MoneyItem, total) + itemWeight(entry.name, count)
    if newWeight > pInv.maxWeight then return notify(src, 'You can\'t carry that.', 'error') end

    removeItem(pInv, Config.MoneyItem, total)
    local ok, reason = addItem(pInv, entry.name, count, {}, toSlot)
    if not ok then
        addItem(pInv, Config.MoneyItem, total) -- refund
        return notify(src, reason or 'No space.', 'error')
    end
    notify(src, ('Bought %dx %s for $%d'):format(count, def.label, total), 'success')
    sync(pInv)
end

RegisterNetEvent('inv:server:move', function(fromId, fromSlot, toId, toSlot, count)
    local src = source
    local fromInv, toInv = canAccess(src, fromId), canAccess(src, toId)
    if not fromInv or not toInv then return end
    fromSlot, toSlot = tonumber(fromSlot), tonumber(toSlot)
    if not validSlot(fromInv, fromSlot) or not validSlot(toInv, toSlot) then return end
    if fromInv == toInv and fromSlot == toSlot then return end

    local item = fromInv.items[fromSlot]
    if not item then return end
    count = math.floor(tonumber(count) or 0)

    if fromInv.type == 'shop' then
        if toInv.type ~= 'player' then return end
        return buyFromShop(src, fromInv, fromSlot, toInv, toSlot, math.max(1, math.min(count, 1000)))
    end
    if count <= 0 or count > item.count then count = item.count end
    if toInv.type == 'shop' then return end

    local target = toInv.items[toSlot]
    local crossing = fromInv ~= toInv

    if not target then
        -- Move or split into an empty slot
        if crossing and invWeight(toInv) + itemWeight(item.name, count) > toInv.maxWeight then
            return notify(src, 'Not enough room.', 'error')
        end
        if count == item.count then
            toInv.items[toSlot] = item
            fromInv.items[fromSlot] = nil
        else
            toInv.items[toSlot] = copyItem(item, count)
            item.count = item.count - count
        end

    elseif canStack(item, target) then
        if crossing and invWeight(toInv) + itemWeight(item.name, count) > toInv.maxWeight then
            return notify(src, 'Not enough room.', 'error')
        end
        target.count = target.count + count
        item.count = item.count - count
        if item.count <= 0 then fromInv.items[fromSlot] = nil end

    else
        -- Swap whole stacks
        if count ~= item.count then return end
        if crossing then
            local toNew = invWeight(toInv) - itemWeight(target.name, target.count) + itemWeight(item.name, item.count)
            local fromNew = invWeight(fromInv) - itemWeight(item.name, item.count) + itemWeight(target.name, target.count)
            if toNew > toInv.maxWeight or fromNew > fromInv.maxWeight then
                return notify(src, 'Not enough room.', 'error')
            end
        end
        fromInv.items[fromSlot], toInv.items[toSlot] = target, item
    end

    markDirty(fromInv); markDirty(toInv)
    sync(fromInv)
    if crossing then sync(toInv) end
end)

-- ─── Dropping on the ground ───────────────────────────────────────

RegisterNetEvent('inv:server:drop', function(slot, count)
    local src = source
    local pInv = getPlayerInv(src)
    slot = tonumber(slot)
    if not pInv or not validSlot(pInv, slot) or not pInv.items[slot] then return end
    if GetVehiclePedIsIn(GetPlayerPed(src), false) ~= 0 then
        return notify(src, 'You can\'t drop items in a vehicle.', 'error')
    end

    local item = pInv.items[slot]
    count = math.floor(tonumber(count) or 0)
    if count <= 0 or count > item.count then count = item.count end

    local drop = createDrop(playerCoords(src))
    local free = freeSlots(drop)
    if #free == 0 then return notify(src, 'There\'s no room here.', 'error') end

    drop.items[free[1]] = copyItem(item, count)
    item.count = item.count - count
    if item.count <= 0 then pInv.items[slot] = nil end
    markDirty(pInv)

    -- Open the drop next to the player inventory so they can keep moving things
    closeSecondary(src)
    OpenSecondary[src] = drop.id
    drop.openedBy[src] = true
    sync(pInv)
    TriggerClientEvent('inv:client:setSecondary', src, serialize(drop))
    for s in pairs(drop.openedBy) do
        if s ~= src then TriggerClientEvent('inv:client:update', s, serialize(drop)) end
    end
end)

-- ─── Giving to another player ─────────────────────────────────────

RegisterNetEvent('inv:server:give', function(slot, count, targetSrc)
    local src = source
    targetSrc = tonumber(targetSrc)
    local pInv, tInv = getPlayerInv(src), targetSrc and getPlayerInv(targetSrc)
    slot = tonumber(slot)
    if not pInv or not tInv or targetSrc == src then return end
    if not validSlot(pInv, slot) or not pInv.items[slot] then return end

    if #(playerCoords(src) - playerCoords(targetSrc)) > Config.GiveDistance + 1.0 then
        return notify(src, 'They\'re too far away.', 'error')
    end

    local item = pInv.items[slot]
    count = math.floor(tonumber(count) or 0)
    if count <= 0 or count > item.count then count = item.count end

    local ok, reason = addItem(tInv, item.name, count, copyItem(item).metadata)
    if not ok then return notify(src, 'They ' .. (reason == 'Too heavy' and 'can\'t carry that.' or 'have no space.'), 'error') end

    item.count = item.count - count
    if item.count <= 0 then pInv.items[slot] = nil end
    markDirty(pInv)

    local label = Items[item.name].label
    notify(src, ('You gave %dx %s'):format(count, label), 'success')
    notify(targetSrc, ('You received %dx %s'):format(count, label), 'success')
    sync(pInv); sync(tInv)
    TriggerClientEvent('inv:client:giveAnim', src)
end)

-- ─── Using items ──────────────────────────────────────────────────

RegisterNetEvent('inv:server:use', function(slot)
    local src = source
    local pInv = getPlayerInv(src)
    slot = tonumber(slot)
    if not pInv or not validSlot(pInv, slot) then return end
    local item = pInv.items[slot]
    if not item then return end
    local def = Items[item.name]

    if UsableItems[item.name] then
        local ok, err = pcall(UsableItems[item.name], src, copyItem(item), slot)
        if not ok then print(('[custom_inventory] usable item %s errored: %s'):format(item.name, err)) end
        return
    end

    -- Items registered through Nova (exports.nova_core:CreateUseableItem / QBCore CreateUseableItem)
    if core:CanUseItem(item.name) then
        local data = copyItem(item)
        data.slot = slot
        core:UseItem(src, data)
        return
    end

    if not def.use then return notify(src, 'You can\'t use that.', 'error') end
    if PendingUse[src] and GetGameTimer() - PendingUse[src].started < 30000 then return end

    PendingUse[src] = { slot = slot, name = item.name, started = GetGameTimer() }
    TriggerClientEvent('inv:client:useItem', src, item.name, def.use, def.close)
end)

RegisterNetEvent('inv:server:finishUse', function(cancelled)
    local src = source
    local pending = PendingUse[src]
    PendingUse[src] = nil
    if not pending or cancelled then return end

    local def = Items[pending.name]
    -- Must have waited the animation out (small tolerance for latency)
    if GetGameTimer() - pending.started < (def.use.duration or 0) - 500 then return end

    local pInv = getPlayerInv(src)
    if not pInv then return end
    local consume = def.use.consume or 0
    if consume > 0 then
        if not removeItem(pInv, pending.name, consume, nil, pending.slot) then
            return notify(src, 'You don\'t have that anymore.', 'error')
        end
        sync(pInv)
    end
    TriggerClientEvent('inv:client:applyEffect', src, pending.name, def.use)
    TriggerEvent('custom_inventory:itemUsed', src, pending.name)

    -- Feed Nova's hunger / thirst / stress
    local use = def.use
    if use.effect == 'eat' then
        core:SetMetaData(src, 'hunger', (core:GetMetaData(src, 'hunger') or 0) + (use.amount or 25))
    elseif use.effect == 'drink' then
        core:SetMetaData(src, 'thirst', (core:GetMetaData(src, 'thirst') or 0) + (use.amount or 25))
    end
    if use.stress then
        core:SetMetaData(src, 'stress', (core:GetMetaData(src, 'stress') or 0) - use.stress)
    end
end)

-- ─── Background jobs ─────────────────────────────────────────────

CreateThread(function()
    while true do
        Wait(Config.SaveIntervalMinutes * 60000)
        local n = saveAll()
        if n > 0 then print(('[custom_inventory] saved %d inventories'):format(n)) end
    end
end)

CreateThread(function()
    while true do
        Wait(60000)
        local now = os.time()
        for id, d in pairs(Drops) do
            local inv = Inventories[id]
            if now - d.created > Config.DropDespawnMinutes * 60 and (not inv or isEmpty(inv.openedBy)) then
                removeDrop(id)
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, inv in pairs(Inventories) do
        if PERSISTENT[inv.type] then inv.dirty = true; saveInventory(inv) end
    end
end)

AddEventHandler('txAdmin:events:serverShuttingDown', saveAll)

-- ─── Admin commands (restricted: needs ACE "command.<name>") ────────

RegisterCommand('giveitem', function(src, args)
    local target, name, count = tonumber(args[1]), args[2], tonumber(args[3]) or 1
    local reply = function(msg)
        if src == 0 then print(msg) else notify(src, msg) end
    end
    if not target or not name or not Items[name] then return reply('Usage: /giveitem [id] [item] [count]') end
    local inv = getPlayerInv(target)
    if not inv then return reply('Player not found.') end
    local ok, reason = addItem(inv, name, count)
    if ok then sync(inv); reply(('Gave %dx %s to %d'):format(count, name, target))
    else reply('Failed: ' .. tostring(reason)) end
end, true)

RegisterCommand('clearinv', function(src, args)
    local target = tonumber(args[1]) or src
    local inv = getPlayerInv(target)
    if not inv then return end
    inv.items = {}
    markDirty(inv); sync(inv)
end, true)

-- ─── Exports ─────────────────────────────────────────────────────

-- Accepts a server id (player) or an inventory id string
local function resolve(target)
    if type(target) == 'number' then return getPlayerInv(target) end
    return Inventories[target]
end

exports('AddItem', function(target, name, count, metadata, slot)
    local inv = resolve(target)
    if not inv then return false, 'No inventory' end
    local ok, reason = addItem(inv, name, count, metadata, slot)
    if ok then sync(inv) end
    return ok, reason
end)

exports('RemoveItem', function(target, name, count, metadata, slot)
    local inv = resolve(target)
    if not inv then return false end
    local ok = removeItem(inv, name, count, metadata, slot)
    if ok then sync(inv) end
    return ok
end)

exports('GetItemCount', function(target, name, metadata)
    local inv = resolve(target)
    return inv and countItem(inv, name, metadata) or 0
end)

exports('CanCarryItem', function(target, name, count, metadata)
    local inv = resolve(target)
    if not inv then return false end
    return canCarry(inv, name, count or 1, metadata)
end)

exports('GetInventory', function(target)
    local inv = resolve(target)
    return inv and serialize(inv) or nil
end)

exports('RegisterUsableItem', function(name, cb)
    UsableItems[name] = cb
end)

-- Item definitions (all, or one by name). Used by nova_core's inventory layer.
exports('GetItemDefinitions', function(name)
    if name then return Items[name] end
    return Items
end)

exports('RegisterStash', function(data)
    -- data = { id, label, coords (vector3), slots, weight, personal?, ace? }
    for i, s in ipairs(Config.Stashes) do
        if s.id == data.id then Config.Stashes[i] = data; return end
    end
    Config.Stashes[#Config.Stashes + 1] = data
    TriggerClientEvent('inv:client:addStash', -1, data)
end)

exports('ClearInventory', function(target)
    local inv = resolve(target)
    if not inv then return end
    inv.items = {}
    markDirty(inv); sync(inv)
end)
