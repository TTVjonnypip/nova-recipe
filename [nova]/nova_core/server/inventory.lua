--[[
    Inventory layer

    Every script on Nova goes through these functions instead of calling an
    inventory directly, so you can switch between custom_inventory and
    ox_inventory without touching your scripts.

    Config.Inventory = 'auto' prefers custom_inventory, then ox_inventory.
]]

Inventory = {}

function Inventory.Backend()
    local pref = Config.Inventory or 'auto'
    if pref ~= 'ox_inventory' and GetResourceState('custom_inventory') == 'started' then return 'custom' end
    if pref ~= 'custom_inventory' and GetResourceState('ox_inventory') == 'started' then return 'ox' end
    return nil
end

local function custom() return exports.custom_inventory end
local function ox() return exports.ox_inventory end

function Inventory.AddItem(target, name, count, metadata, slot)
    local b = Inventory.Backend()
    count = count or 1
    if b == 'custom' then return custom():AddItem(target, name, count, metadata, slot) end
    if b == 'ox' then return ox():AddItem(target, name, count, metadata, slot) end
    return false, 'no_inventory'
end

function Inventory.RemoveItem(target, name, count, metadata, slot)
    local b = Inventory.Backend()
    count = count or 1
    if b == 'custom' then return custom():RemoveItem(target, name, count, metadata, slot) end
    if b == 'ox' then return ox():RemoveItem(target, name, count, metadata, slot) end
    return false
end

function Inventory.GetItemCount(target, name, metadata)
    local b = Inventory.Backend()
    if b == 'custom' then return custom():GetItemCount(target, name, metadata) or 0 end
    if b == 'ox' then return ox():Search(target, 'count', name, metadata) or 0 end
    return 0
end

function Inventory.CanCarryItem(target, name, count, metadata)
    local b = Inventory.Backend()
    if b == 'custom' then return custom():CanCarryItem(target, name, count or 1, metadata) end
    if b == 'ox' then return ox():CanCarryItem(target, name, count or 1, metadata) end
    return false
end

-- items: 'name' | { 'a', 'b' } | { a = 2, b = 1 }
function Inventory.HasItem(target, items, amount)
    amount = amount or 1
    if type(items) ~= 'table' then return Inventory.GetItemCount(target, items) >= amount end
    for key, value in pairs(items) do
        local name = type(key) == 'string' and key or value
        local need = type(key) == 'string' and value or amount
        if Inventory.GetItemCount(target, name) < need then return false end
    end
    return true
end

-- Item definitions in one shape: { label, weight, stack, description, close }
function Inventory.GetItems()
    local b = Inventory.Backend()
    local out = {}
    if b == 'custom' then
        for name, def in pairs(custom():GetItemDefinitions() or {}) do
            out[name] = { label = def.label, weight = def.weight or 0, stack = def.stack ~= false,
                          description = def.description, close = def.close }
        end
    elseif b == 'ox' then
        for name, def in pairs(ox():Items() or {}) do
            out[name] = { label = def.label, weight = def.weight or 0, stack = def.stack ~= false,
                          description = def.description, close = def.close, weapon = def.weapon,
                          image = def.client and def.client.image }
        end
    end
    return out
end

function Inventory.ItemExists(name)
    local b = Inventory.Backend()
    if b == 'custom' then return custom():GetItemDefinitions(name) ~= nil end
    if b == 'ox' then return ox():Items(name) ~= nil end
    return false
end

function Inventory.GetItemLabel(name)
    local def = Inventory.GetItems()[name]
    return def and def.label or name
end

-- Returns a list of { slot, name, count, metadata }
function Inventory.GetItemList(target)
    local b = Inventory.Backend()
    if b == 'custom' then
        local inv = custom():GetInventory(target)
        return inv and inv.items or {}
    elseif b == 'ox' then
        local list = {}
        for slot, item in pairs(ox():GetInventoryItems(target) or {}) do
            list[#list + 1] = { slot = item.slot or slot, name = item.name, count = item.count, metadata = item.metadata or {} }
        end
        return list
    end
    return {}
end

function Inventory.GetSlotWithItem(target, name)
    for _, item in ipairs(Inventory.GetItemList(target)) do
        if item.name == name then return item end
    end
end

function Inventory.GetSlotsWithItem(target, name)
    local out = {}
    for _, item in ipairs(Inventory.GetItemList(target)) do
        if item.name == name then out[#out + 1] = item end
    end
    return out
end

function Inventory.ClearInventory(target)
    local b = Inventory.Backend()
    if b == 'custom' then return custom():ClearInventory(target) end
    if b == 'ox' then return ox():ClearInventory(target) end
end

-- Run a usable-item callback registered with CreateUseableItem.
-- custom_inventory calls this for items it has no handler for.
function Inventory.UseItem(source, item)
    local name = type(item) == 'table' and item.name or item
    local cb = Nova.UsableItems[name]
    if not cb then return false end
    local ok, err = pcall(cb, source, type(item) == 'table' and item or { name = name })
    if not ok then print(('^1[nova_core]^7 usable item %s errored: %s'):format(name, err)) end
    return true
end

exports('GetInventoryBackend', Inventory.Backend)
exports('AddItem', Inventory.AddItem)
exports('RemoveItem', Inventory.RemoveItem)
exports('GetItemCount', Inventory.GetItemCount)
exports('CanCarryItem', Inventory.CanCarryItem)
exports('HasItem', Inventory.HasItem)
exports('GetItems', Inventory.GetItems)
exports('ItemExists', Inventory.ItemExists)
exports('GetItemLabel', Inventory.GetItemLabel)
exports('GetItemList', Inventory.GetItemList)
exports('ClearInventory', Inventory.ClearInventory)
exports('UseItem', Inventory.UseItem)
