local state = nil
local walkstyleApplied = false

---------------------------------------------------------------------
-- State sync
---------------------------------------------------------------------
local function applyMovement()
    local ped = cache.ped
    local late = state and state.trimester == 3

    if late then
        if Config.LateWalkstyle and not walkstyleApplied then
            lib.requestAnimSet(Config.LateWalkstyle)
            SetPedMovementClipset(ped, Config.LateWalkstyle, 0.5)
            walkstyleApplied = true
        end
    elseif walkstyleApplied then
        ResetPedMovementClipset(ped, 0.5)
        walkstyleApplied = false
    end
end

RegisterNetEvent('qbx_pregnancy:client:sync', function(newState)
    state = newState
    applyMovement()
end)

local function refresh()
    state = lib.callback.await('qbx_pregnancy:server:getState', false)
    walkstyleApplied = false
    applyMovement()
end

RegisterNetEvent('nova:client:onPlayerLoaded', refresh)
AddEventHandler('onResourceStart', function(res)
    if res == GetCurrentResourceName() and LocalPlayer.state.isLoggedIn then refresh() end
end)
RegisterNetEvent('nova:client:onPlayerUnload', function()
    state = nil
    walkstyleApplied = false
end)

---------------------------------------------------------------------
-- Callbacks from server
---------------------------------------------------------------------
lib.callback.register('qbx_pregnancy:client:consent', function(medicName)
    local answer = lib.alertDialog({
        header = 'Medical consent',
        content = ('%s is asking for your consent to begin a roleplay pregnancy for your character. Do you accept?'):format(medicName),
        centered = true,
        cancel = true,
        labels = { confirm = 'Accept', cancel = 'Decline' },
    })
    return answer == 'confirm'
end)

lib.callback.register('qbx_pregnancy:client:useTest', function()
    return lib.progressCircle({
        duration = 5000,
        label = 'Taking a pregnancy test...',
        position = 'bottom',
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = 'mp_arresting', clip = 'a_uncuff', flag = 49 },
    })
end)

lib.callback.register('qbx_pregnancy:client:deliverProgress', function()
    return lib.progressBar({
        duration = 15000,
        label = 'Delivering the baby...',
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = 'mini@cpr@char_a@cpr_str', clip = 'cpr_pumpchest', flag = 1 },
    })
end)

---------------------------------------------------------------------
-- Ultrasound / delivery results
---------------------------------------------------------------------
RegisterNetEvent('qbx_pregnancy:client:ultrasound', function(s, patientName)
    local status = s.due and 'Due now — ready for delivery'
        or ('About %d day(s) until due'):format(s.daysLeft)
    lib.alertDialog({
        header = 'Ultrasound results',
        content = ('**Patient:** %s  \n**Gestation:** week %d (trimester %d)  \n**Progress:** %d%%  \n**Status:** %s  \nHeartbeat strong and steady.')
            :format(patientName, s.weeks, s.trimester, s.percent, status),
        centered = true,
    })
end)

RegisterNetEvent('qbx_pregnancy:client:delivered', function()
    DoScreenFadeOut(800)
    Wait(1500)
    DoScreenFadeIn(1500)
end)

---------------------------------------------------------------------
-- Third-trimester movement limits
---------------------------------------------------------------------
CreateThread(function()
    while true do
        if state and state.trimester == 3 then
            SetPedMoveRateOverride(cache.ped, Config.LateMoveRate)
            if Config.DisableSprintLate then
                DisableControlAction(0, 21, true) -- sprint
                DisableControlAction(0, 22, true) -- jump
            end
            Wait(0)
        else
            Wait(1000)
        end
    end
end)

---------------------------------------------------------------------
-- Symptoms (only once the pregnancy is far enough along to notice)
---------------------------------------------------------------------
local function nausea()
    lib.notify({ title = 'Pregnancy', description = 'A wave of nausea hits you...', type = 'warning' })
    lib.requestAnimDict('oddjobs@taxi@tie')
    TaskPlayAnim(cache.ped, 'oddjobs@taxi@tie', 'vomit_outside', 8.0, -8.0, 5000, 49, 0, false, false, false)
    ShakeGameplayCam('DRUNK_SHAKE', 0.5)
    Wait(8000)
    StopGameplayCamShaking(true)
end

local function craving()
    local item = Config.Symptoms.cravings[math.random(#Config.Symptoms.cravings)]
    lib.notify({ title = 'Pregnancy', description = ('You are really craving %s right now.'):format(item), type = 'inform' })
end

local function backPain()
    lib.notify({ title = 'Pregnancy', description = 'Your back is aching. Maybe sit down for a bit.', type = 'warning' })
    lib.requestAnimDict('anim@heists@prison_heistig1_p1_guard_checks_bus')
    TaskPlayAnim(cache.ped, 'anim@heists@prison_heistig1_p1_guard_checks_bus', 'loop', 8.0, -8.0, 4000, 49, 0, false, false, false)
end

CreateThread(function()
    if not Config.Symptoms.enabled then return end
    while true do
        Wait(Config.Symptoms.interval)
        if state and state.elapsedDays >= Config.TestDetectAfterDays
            and not IsPedInAnyVehicle(cache.ped, false) and not IsEntityDead(cache.ped) then
            local roll = math.random(100)
            if state.trimester == 1 and roll <= Config.Symptoms.nauseaChance then
                nausea()
            elseif state.trimester == 2 and roll <= Config.Symptoms.cravingChance then
                craving()
            elseif state.trimester == 3 and roll <= Config.Symptoms.backPainChance then
                backPain()
            end
        end
    end
end)
