-- Current character's data straight from nova_core
local function playerData()
    return exports.nova_core:GetPlayerData() or {}
end

local function marriageData()
    local md = playerData().metadata
    return md and md.marriage or nil
end

local function relationshipStatus()
    local m = marriageData()
    return m and m.status or nil
end

local function playAnim(dict, clip, flag, duration)
    lib.requestAnimDict(dict)
    TaskPlayAnim(cache.ped, dict, clip, 8.0, -8.0, duration or -1, flag or 0, 0.0, false, false, false)
    RemoveAnimDict(dict)
end

local function faceEntity(ped, target)
    TaskTurnPedToFaceEntity(ped, target, 1500)
    Wait(1000)
end

-- ---------------------------------------------------------------------------
-- Callbacks used by the server
-- ---------------------------------------------------------------------------

lib.callback.register('qbx_marriage:client:getClosestPlayer', function(maxDist)
    local playerId = lib.getClosestPlayer(GetEntityCoords(cache.ped), maxDist, false)
    return playerId and GetPlayerServerId(playerId) or nil
end)

local function timedConfirm(header, content)
    local timedOut = false
    SetTimeout(Config.PromptTimeout * 1000, function()
        timedOut = true
        lib.closeAlertDialog()
    end)

    local answer = lib.alertDialog({
        header = header,
        content = content,
        centered = true,
        cancel = true,
        labels = { confirm = 'Yes', cancel = 'No' },
    })

    return not timedOut and answer == 'confirm'
end

lib.callback.register('qbx_marriage:client:proposalPrompt', function(proposerName)
    return timedConfirm('💍 A proposal!', ('**%s** is down on one knee asking you to marry them.\n\nWill you say yes?'):format(proposerName))
end)

lib.callback.register('qbx_marriage:client:vowPrompt', function(partnerName)
    return timedConfirm('💒 Wedding Ceremony', ('The officiant asks: do you take **%s** to be your lawfully wedded partner?'):format(partnerName))
end)

-- ---------------------------------------------------------------------------
-- Animations
-- ---------------------------------------------------------------------------

RegisterNetEvent('qbx_marriage:client:kneel', function()
    playAnim('amb@medic@standing@kneel@base', 'base', 1)
end)

RegisterNetEvent('qbx_marriage:client:stopAnim', function()
    ClearPedTasks(cache.ped)
end)

RegisterNetEvent('qbx_marriage:client:kiss', function(otherServerId)
    local other = GetPlayerFromServerId(otherServerId)
    if other ~= -1 then
        faceEntity(cache.ped, GetPlayerPed(other))
    end
    playAnim('mp_ped_interaction', 'kisses_guy_a', 0, 5000)
end)

RegisterNetEvent('qbx_marriage:client:ceremony', function(otherServerId)
    local other = GetPlayerFromServerId(otherServerId)
    if other ~= -1 then
        faceEntity(cache.ped, GetPlayerPed(other))
    end

    lib.progressBar({
        duration = Config.CeremonyDuration - 1000,
        label = 'Exchanging vows...',
        canCancel = false,
        disable = { move = true, car = true, combat = true },
        anim = { dict = 'mp_common', clip = 'givetake1_a', flag = 49 },
    })
end)

-- ---------------------------------------------------------------------------
-- NPCs (officiant + clerk), blips and targets
-- ---------------------------------------------------------------------------

local function createBlip(loc)
    if not loc.blip.enabled then return end
    local blip = AddBlipForCoord(loc.coords.x, loc.coords.y, loc.coords.z)
    SetBlipSprite(blip, loc.blip.sprite)
    SetBlipColour(blip, loc.blip.color)
    SetBlipScale(blip, loc.blip.scale)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(loc.blip.label)
    EndTextCommandSetBlipName(blip)
end

local function createNpcPoint(loc, options)
    local ped

    lib.points.new({
        coords = loc.coords.xyz,
        distance = 40.0,
        onEnter = function()
            lib.requestModel(loc.model)
            ped = CreatePed(4, loc.model, loc.coords.x, loc.coords.y, loc.coords.z - 1.0, loc.coords.w, false, true)
            SetModelAsNoLongerNeeded(loc.model)
            FreezeEntityPosition(ped, true)
            SetEntityInvincible(ped, true)
            SetBlockingOfNonTemporaryEvents(ped, true)
            TaskStartScenarioInPlace(ped, loc.scenario, 0, true)
            exports.ox_target:addLocalEntity(ped, options)
        end,
        onExit = function()
            if ped and DoesEntityExist(ped) then
                exports.ox_target:removeLocalEntity(ped)
                DeleteEntity(ped)
            end
            ped = nil
        end,
    })
end

CreateThread(function()
    createBlip(Config.Chapel)
    createBlip(Config.Courthouse)

    createNpcPoint(Config.Chapel, {
        {
            name = 'qbx_marriage_wedding',
            icon = 'fa-solid fa-ring',
            label = ('Hold wedding ceremony ($%s)'):format(Config.WeddingFee),
            distance = 2.5,
            canInteract = function() return relationshipStatus() == 'engaged' end,
            onSelect = function()
                TriggerServerEvent('qbx_marriage:server:wedding')
            end,
        },
        {
            name = 'qbx_marriage_collect_ring',
            icon = 'fa-solid fa-gem',
            label = 'Collect wedding ring',
            distance = 2.5,
            canInteract = function() return relationshipStatus() == 'married' end,
            onSelect = function()
                TriggerServerEvent('qbx_marriage:server:collectRing')
            end,
        },
    })

    createNpcPoint(Config.Courthouse, {
        {
            name = 'qbx_marriage_divorce',
            icon = 'fa-solid fa-heart-crack',
            label = ('File for divorce ($%s)'):format(Config.DivorceFee),
            distance = 2.5,
            canInteract = function() return relationshipStatus() == 'married' end,
            onSelect = function()
                local m = marriageData()
                local answer = lib.alertDialog({
                    header = 'File for divorce',
                    content = ('Are you sure you want to divorce **%s**? This costs $%s and cannot be undone.'):format(m.partnerName, Config.DivorceFee),
                    centered = true,
                    cancel = true,
                })
                if answer == 'confirm' then
                    TriggerServerEvent('qbx_marriage:server:divorce')
                end
            end,
        },
        {
            name = 'qbx_marriage_break_engagement',
            icon = 'fa-solid fa-ban',
            label = 'Call off engagement',
            distance = 2.5,
            canInteract = function() return relationshipStatus() == 'engaged' end,
            onSelect = function()
                local m = marriageData()
                local answer = lib.alertDialog({
                    header = 'Call off engagement',
                    content = ('Call off your engagement to **%s**? The ring will not be returned.'):format(m.partnerName),
                    centered = true,
                    cancel = true,
                })
                if answer == 'confirm' then
                    TriggerServerEvent('qbx_marriage:server:breakEngagement')
                end
            end,
        },
    })
end)
