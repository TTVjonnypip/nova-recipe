local TOTAL_SECONDS = Config.PregnancyDays * Config.DayLengthSeconds

---------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------
local core = exports.nova_core

local function getPlayer(src)
    return core:GetPlayer(src)
end

local function getData(player)
    local data = player and player.PlayerData.metadata.pregnancy
    if type(data) == 'table' and data.startedAt then return data end
    return nil
end

local function setData(player, data)
    player.Functions.SetMetaData('pregnancy', data or false)
end

local function charName(player)
    local ci = player.PlayerData.charinfo
    return ('%s %s'):format(ci.firstname, ci.lastname)
end

local function buildState(data)
    if not data then return nil end
    local elapsed  = math.max(0, os.time() - data.startedAt)
    local pct      = math.min(1.0, elapsed / TOTAL_SECONDS)
    local weeks    = math.floor(pct * 40)
    local trimester = weeks < 13 and 1 or (weeks < 27 and 2 or 3)
    return {
        weeks      = weeks,
        trimester  = trimester,
        percent    = math.floor(pct * 100),
        due        = elapsed >= TOTAL_SECONDS,
        daysLeft   = math.max(0, math.ceil((TOTAL_SECONDS - elapsed) / Config.DayLengthSeconds)),
        elapsedDays = elapsed / Config.DayLengthSeconds,
        confirmed  = data.confirmed or false,
    }
end

local function sync(src)
    local player = getPlayer(src)
    if not player then return end
    TriggerClientEvent('qbx_pregnancy:client:sync', src, buildState(getData(player)))
end

local function notify(src, msg, typ)
    TriggerClientEvent('ox_lib:notify', src, { title = 'Pregnancy', description = msg, type = typ or 'inform' })
end

local function isMedic(player)
    local job = player.PlayerData.job
    local minGrade = Config.MedicJobs[job.name]
    if not minGrade then return false end
    if job.grade.level < minGrade then return false end
    if Config.RequireOnDuty and not job.onduty then return false end
    return true
end

local function inRange(a, b)
    local pa, pb = GetPlayerPed(a), GetPlayerPed(b)
    if pa == 0 or pb == 0 then return false end
    return #(GetEntityCoords(pa) - GetEntityCoords(pb)) <= Config.MaxDistance
end

-- Validates medic + target, returns medicPlayer, targetPlayer or nil
local function medicCheck(src, target)
    local medic = getPlayer(src)
    if not medic or not isMedic(medic) then
        notify(src, 'Only on-duty medical staff can do this.', 'error')
        return
    end
    local patient = target and getPlayer(target)
    if not patient then
        notify(src, 'Player not found.', 'error')
        return
    end
    if target ~= src and not inRange(src, target) then
        notify(src, 'You need to be closer to the patient.', 'error')
        return
    end
    return medic, patient
end

---------------------------------------------------------------------
-- Callbacks
---------------------------------------------------------------------
lib.callback.register('qbx_pregnancy:server:getState', function(source)
    return buildState(getData(getPlayer(source)))
end)

---------------------------------------------------------------------
-- Pregnancy test item
---------------------------------------------------------------------
core:CreateUseableItem(Config.TestItem, function(source, item)
    local finished = lib.callback.await('qbx_pregnancy:client:useTest', source)
    if not finished then return end

    if not core:RemoveItem(source, Config.TestItem, 1, nil, item and item.slot) then return end

    local state = buildState(getData(getPlayer(source)))
    if state and state.elapsedDays >= Config.TestDetectAfterDays then
        notify(source, 'Two lines... the test is positive.', 'success')
    else
        notify(source, 'One line. The test is negative.', 'inform')
    end
end)

---------------------------------------------------------------------
-- Medic commands
---------------------------------------------------------------------
lib.addCommand('startpregnancy', {
    help = 'Medical: start a pregnancy for a consenting patient',
    params = { { name = 'target', type = 'playerId', help = 'Patient server ID' } },
}, function(source, args)
    local medic, patient = medicCheck(source, args.target)
    if not medic then return end

    if getData(patient) then
        return notify(source, 'This patient is already pregnant.', 'error')
    end

    local accepted = lib.callback.await('qbx_pregnancy:client:consent', args.target, charName(medic))
    if not accepted then
        return notify(source, 'The patient declined.', 'error')
    end

    setData(patient, { startedAt = os.time(), confirmed = false })
    sync(args.target)
    notify(source, ('Pregnancy started for %s.'):format(charName(patient)), 'success')
end)

lib.addCommand('ultrasound', {
    help = 'Medical: perform an ultrasound on a patient',
    params = { { name = 'target', type = 'playerId', help = 'Patient server ID' } },
}, function(source, args)
    local medic, patient = medicCheck(source, args.target)
    if not medic then return end

    local data = getData(patient)
    if not data then
        return notify(source, 'The scan shows no pregnancy.', 'inform')
    end

    data.confirmed = true
    setData(patient, data)

    local state = buildState(data)
    TriggerClientEvent('qbx_pregnancy:client:ultrasound', args.target, state, charName(patient))
    if args.target ~= source then
        TriggerClientEvent('qbx_pregnancy:client:ultrasound', source, state, charName(patient))
    end
    sync(args.target)
end)

lib.addCommand('deliver', {
    help = 'Medical: deliver a patient\'s baby',
    params = { { name = 'target', type = 'playerId', help = 'Patient server ID' } },
}, function(source, args)
    local medic, patient = medicCheck(source, args.target)
    if not medic then return end

    local state = buildState(getData(patient))
    if not state then
        return notify(source, 'This patient is not pregnant.', 'error')
    end
    if not state.due and not Config.AllowEarlyDelivery then
        return notify(source, ('Not due yet — about %d day(s) to go.'):format(state.daysLeft), 'error')
    end

    local done = lib.callback.await('qbx_pregnancy:client:deliverProgress', source)
    if not done then return end

    TriggerClientEvent('qbx_pregnancy:client:delivered', args.target)
    setData(patient, nil)
    sync(args.target)

    if Config.BirthItem then
        core:AddItem(args.target, Config.BirthItem, 1, {
            description = ('Mother: %s | Delivered by: %s | %s'):format(
                charName(patient), charName(medic), os.date('%Y-%m-%d')),
        })
    end

    notify(args.target, 'Congratulations! Your baby has been delivered.', 'success')
    notify(source, 'Delivery complete.', 'success')
end)

---------------------------------------------------------------------
-- Player self-check & admin commands
---------------------------------------------------------------------
lib.addCommand('pregnancy', {
    help = 'Check how your pregnancy is going (after an ultrasound)',
}, function(source)
    local state = buildState(getData(getPlayer(source)))
    if not state or not state.confirmed then
        return notify(source, 'You have no confirmed pregnancy. See a doctor for an ultrasound.', 'inform')
    end
    notify(source, ('Week %d (trimester %d). %s'):format(
        state.weeks, state.trimester,
        state.due and 'You are due — get to a hospital!' or ('About %d day(s) to go.'):format(state.daysLeft)))
end)

lib.addCommand('setpregnancy', {
    help = 'Admin: set a player\'s pregnancy progress',
    params = {
        { name = 'target', type = 'playerId', help = 'Player server ID' },
        { name = 'days', type = 'number', help = 'Days already elapsed' },
    },
    restricted = Config.AdminGroup,
}, function(source, args)
    local patient = getPlayer(args.target)
    if not patient then return notify(source, 'Player not found.', 'error') end
    setData(patient, {
        startedAt = os.time() - math.floor(args.days * Config.DayLengthSeconds),
        confirmed = true,
    })
    sync(args.target)
    notify(source, 'Pregnancy progress set.', 'success')
end)

lib.addCommand('endpregnancy', {
    help = 'Admin: end a player\'s pregnancy',
    params = { { name = 'target', type = 'playerId', help = 'Player server ID' } },
    restricted = Config.AdminGroup,
}, function(source, args)
    local patient = getPlayer(args.target)
    if not patient then return notify(source, 'Player not found.', 'error') end
    setData(patient, nil)
    sync(args.target)
    notify(source, 'Pregnancy cleared.', 'success')
end)

---------------------------------------------------------------------
-- Periodic sync (progress keeps moving in real time)
---------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(5 * 60 * 1000)
        for _, src in ipairs(core:GetPlayerSources()) do
            local pd = core:GetPlayerData(src)
            if pd and type(pd.metadata.pregnancy) == 'table' then sync(src) end
        end
    end
end)
