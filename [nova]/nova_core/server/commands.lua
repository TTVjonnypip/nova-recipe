-- Commands use ox_lib. `restricted` groups map to server.cfg principals
-- (group.god inherits group.admin, which inherits group.mod - see README).

local function reply(source, message, notifType)
    Nova.Notify(source, message, notifType)
end

local function requireLoaded(source, target)
    local player = Nova.Players[target]
    if not player then reply(source, 'That player has not selected a character.', 'error') end
    return player
end

-- Admin: vehicles ----------------------------------------------------------

lib.addCommand('car', {
    help = 'Spawn a vehicle',
    params = { { name = 'model', type = 'string', help = 'Vehicle model name' } },
    restricted = 'group.admin',
}, function(source, args)
    if source == 0 then return end
    TriggerClientEvent('nova:client:spawnVehicle', source, args.model)
end)

lib.addCommand('dv', {
    help = 'Delete the vehicle you are in, or vehicles within a radius',
    params = { { name = 'radius', type = 'number', help = 'Radius in metres (default 5)', optional = true } },
    restricted = 'group.admin',
}, function(source, args)
    if source == 0 then return end
    local ped = GetPlayerPed(source)
    local current = GetVehiclePedIsIn(ped, false)
    if current ~= 0 then
        DeleteEntity(current)
        return
    end

    local radius = math.min(args.radius or 5.0, 50.0)
    local coords = GetEntityCoords(ped)
    local removed = 0
    for _, vehicle in ipairs(GetAllVehicles()) do
        if #(GetEntityCoords(vehicle) - coords) <= radius then
            DeleteEntity(vehicle)
            removed = removed + 1
        end
    end
    reply(source, ('Deleted %d vehicle(s).'):format(removed), 'success')
end)

-- Admin: teleport ----------------------------------------------------------

lib.addCommand('tp', {
    help = 'Teleport to a player or to coordinates',
    params = {
        { name = 'x', type = 'string', help = 'Player ID, or X coordinate' },
        { name = 'y', type = 'number', help = 'Y coordinate', optional = true },
        { name = 'z', type = 'number', help = 'Z coordinate', optional = true },
    },
    restricted = 'group.admin',
}, function(source, args)
    if source == 0 then return end
    local ped = GetPlayerPed(source)
    if args.y and args.z then
        local x = tonumber(args.x)
        if not x then return reply(source, 'Invalid X coordinate.', 'error') end
        SetEntityCoords(ped, x, args.y, args.z, false, false, false, false)
        return
    end

    local target = tonumber(args.x)
    if not target or not GetPlayerName(target) then return reply(source, 'Player not found.', 'error') end
    local coords = GetEntityCoords(GetPlayerPed(target))
    SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, false)
end)

lib.addCommand('tpm', {
    help = 'Teleport to your waypoint',
    restricted = 'group.admin',
}, function(source)
    if source == 0 then return end
    TriggerClientEvent('nova:client:tpToWaypoint', source)
end)

lib.addCommand('coords', {
    help = 'Copy your current coordinates (vec4) to the clipboard',
    restricted = 'group.mod',
}, function(source)
    if source == 0 then return end
    TriggerClientEvent('nova:client:copyCoords', source)
end)

-- Admin: economy & groups --------------------------------------------------

lib.addCommand('givemoney', {
    help = 'Give money to a player',
    params = {
        { name = 'target', type = 'playerId', help = 'Player ID' },
        { name = 'account', type = 'string', help = 'cash / bank / crypto' },
        { name = 'amount', type = 'number', help = 'Amount' },
    },
    restricted = 'group.admin',
}, function(source, args)
    local player = requireLoaded(source, args.target)
    if not player then return end
    if player.Functions.AddMoney(args.account, args.amount, 'admin givemoney') then
        reply(source, ('Gave $%s %s to %s.'):format(args.amount, args.account, args.target), 'success')
    else
        reply(source, 'Invalid account or amount.', 'error')
    end
end)

lib.addCommand('setmoney', {
    help = "Set a player's balance",
    params = {
        { name = 'target', type = 'playerId', help = 'Player ID' },
        { name = 'account', type = 'string', help = 'cash / bank / crypto' },
        { name = 'amount', type = 'number', help = 'New balance' },
    },
    restricted = 'group.admin',
}, function(source, args)
    local player = requireLoaded(source, args.target)
    if not player then return end
    if player.Functions.SetMoney(args.account, args.amount, 'admin setmoney') then
        reply(source, ("Set %s's %s to $%s."):format(args.target, args.account, args.amount), 'success')
    else
        reply(source, 'Invalid account or amount.', 'error')
    end
end)

lib.addCommand('setjob', {
    help = "Set a player's job",
    params = {
        { name = 'target', type = 'playerId', help = 'Player ID' },
        { name = 'job', type = 'string', help = 'Job name' },
        { name = 'grade', type = 'number', help = 'Grade (default 0)', optional = true },
    },
    restricted = 'group.admin',
}, function(source, args)
    local player = requireLoaded(source, args.target)
    if not player then return end
    if player.Functions.SetJob(args.job, args.grade or 0) then
        reply(source, ('Set job of %s to %s (%s).'):format(args.target, args.job, args.grade or 0), 'success')
    else
        reply(source, 'That job or grade does not exist.', 'error')
    end
end)

lib.addCommand('setgang', {
    help = "Set a player's gang",
    params = {
        { name = 'target', type = 'playerId', help = 'Player ID' },
        { name = 'gang', type = 'string', help = 'Gang name' },
        { name = 'grade', type = 'number', help = 'Grade (default 0)', optional = true },
    },
    restricted = 'group.admin',
}, function(source, args)
    local player = requireLoaded(source, args.target)
    if not player then return end
    if player.Functions.SetGang(args.gang, args.grade or 0) then
        reply(source, ('Set gang of %s to %s (%s).'):format(args.target, args.gang, args.grade or 0), 'success')
    else
        reply(source, 'That gang or grade does not exist.', 'error')
    end
end)

lib.addCommand('logout', {
    help = 'Return to character selection',
    restricted = 'group.admin',
}, function(source)
    if source == 0 then return end
    Nova.Logout(source)
end)

-- Admin: moderation --------------------------------------------------------

lib.addCommand('kick', {
    help = 'Kick a player',
    params = {
        { name = 'target', type = 'playerId', help = 'Player ID' },
        { name = 'reason', type = 'longString', help = 'Reason', optional = true },
    },
    restricted = 'group.mod',
}, function(_, args)
    Nova.Kick(args.target, args.reason or 'Kicked by staff')
end)

lib.addCommand('ban', {
    help = 'Ban a player',
    params = {
        { name = 'target', type = 'playerId', help = 'Player ID' },
        { name = 'hours', type = 'number', help = 'Duration in hours (0 = permanent)' },
        { name = 'reason', type = 'longString', help = 'Reason' },
    },
    restricted = 'group.admin',
}, function(source, args)
    local by = source == 0 and 'Console' or GetPlayerName(source)
    Nova.Ban(args.target, args.hours, args.reason, by)
    reply(source, 'Player banned.', 'success')
end)

lib.addCommand('unban', {
    help = 'Remove a ban by its ID',
    params = { { name = 'banid', type = 'number', help = 'Ban ID shown on the ban screen' } },
    restricted = 'group.admin',
}, function(source, args)
    if Storage.DeleteBan(args.banid) then
        reply(source, ('Ban %s removed.'):format(args.banid), 'success')
    else
        reply(source, 'No ban with that ID.', 'error')
    end
end)

-- Everyone -----------------------------------------------------------------

lib.addCommand('id', { help = 'Show your server ID' }, function(source)
    reply(source, ('Your ID is %s'):format(source))
end)

lib.addCommand('job', { help = 'Show your job' }, function(source)
    local player = Nova.Players[source]
    if not player then return end
    local job = player.PlayerData.job
    reply(source, ('%s - %s (%s)'):format(job.label, job.grade.name, job.onduty and 'on duty' or 'off duty'))
end)

lib.addCommand('gang', { help = 'Show your gang' }, function(source)
    local player = Nova.Players[source]
    if not player then return end
    local gang = player.PlayerData.gang
    reply(source, ('%s - %s'):format(gang.label, gang.grade.name))
end)

lib.addCommand('cash', { help = 'Show your cash' }, function(source)
    local player = Nova.Players[source]
    if player then reply(source, ('Cash: $%s'):format(player.PlayerData.money.cash)) end
end)

lib.addCommand('bank', { help = 'Show your bank balance' }, function(source)
    local player = Nova.Players[source]
    if player then reply(source, ('Bank: $%s'):format(player.PlayerData.money.bank)) end
end)
