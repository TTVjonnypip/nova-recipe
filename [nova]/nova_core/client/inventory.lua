-- Client side of the inventory layer (see server/inventory.lua)

local function backend()
    local pref = Config.Inventory or 'auto'
    if pref ~= 'ox_inventory' and GetResourceState('custom_inventory') == 'started' then return 'custom' end
    if pref ~= 'custom_inventory' and GetResourceState('ox_inventory') == 'started' then return 'ox' end
end

function Nova.GetItemCount(name)
    local b = backend()
    if b == 'custom' then
        local total = 0
        for _, item in ipairs(exports.custom_inventory:GetPlayerItems() or {}) do
            if item.name == name then total = total + (item.count or 0) end
        end
        return total
    elseif b == 'ox' then
        return exports.ox_inventory:Search('count', name) or 0
    end
    return 0
end

function Nova.HasItem(items, amount)
    amount = amount or 1
    if type(items) ~= 'table' then return Nova.GetItemCount(items) >= amount end
    for key, value in pairs(items) do
        local name = type(key) == 'string' and key or value
        local need = type(key) == 'string' and value or amount
        if Nova.GetItemCount(name) < need then return false end
    end
    return true
end

function Nova.GetItems()
    local b, out = backend(), {}
    if b == 'custom' then
        for name, def in pairs(exports.custom_inventory:GetItemDefinitions() or {}) do
            out[name] = { label = def.label, weight = def.weight or 0, stack = def.stack ~= false, description = def.description }
        end
    elseif b == 'ox' then
        for name, def in pairs(exports.ox_inventory:Items() or {}) do
            out[name] = { label = def.label, weight = def.weight or 0, stack = def.stack ~= false,
                          description = def.description, weapon = def.weapon, image = def.client and def.client.image }
        end
    end
    return out
end

exports('GetItemCount', Nova.GetItemCount)
exports('HasItem', Nova.HasItem)
exports('GetItems', Nova.GetItems)
