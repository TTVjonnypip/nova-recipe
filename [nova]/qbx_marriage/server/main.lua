local pending = {} -- players currently in a proposal/vow prompt
local core = exports.nova_core

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

local function notify(src, msg, nType)
    core:Notify(src, msg, nType or 'inform')
end

local function fullName(player)
    local c = player.PlayerData.charinfo
    return ('%s %s'):format(c.firstname, c.lastname)
end

local function getRelationship(citizenid)
    return MySQL.single.await(
        "SELECT * FROM marriages WHERE (partner1 = ? OR partner2 = ?) AND status IN ('engaged', 'married') LIMIT 1",
        { citizenid, citizenid }
    )
end

local function partnerOf(rel, citizenid)
    if rel.partner1 == citizenid then
        return rel.partner2, rel.partner2_name
    end
    return rel.partner1, rel.partner1_name
end

local function distanceTo(src, coords)
    return #(GetEntityCoords(GetPlayerPed(src)) - vec3(coords.x, coords.y, coords.z))
end

local function playersNear(a, b, maxDist)
    return #(GetEntityCoords(GetPlayerPed(a)) - GetEntityCoords(GetPlayerPed(b))) <= maxDist
end

--- Writes the current relationship into player metadata so other scripts
--- (ID cards, phones, HUDs) can read it via PlayerData.metadata.marriage.
local function syncMetadata(src)
    local player = core:GetPlayer(src)
    if not player then return end

    local cid = player.PlayerData.citizenid
    local rel = getRelationship(cid)

    if rel then
        local partnerCid, partnerName = partnerOf(rel, cid)
        player.Functions.SetMetaData('marriage', {
            id = rel.id,
            status = rel.status,
            partner = partnerCid,
            partnerName = partnerName,
        })
    else
        player.Functions.SetMetaData('marriage', false)
    end
end

local function syncByCitizenId(citizenid)
    local player = core:GetPlayerByCitizenId(citizenid)
    if player then
        syncMetadata(player.PlayerData.source)
        return player.PlayerData.source
    end
end

--- Gives a wedding ring and reports why if the inventory refuses it.
local function giveWeddingRing(src, partnerName, date)
    local item = Config.Items.weddingRing

    if not core:ItemExists(item) then
        lib.print.error(('Item "%s" does not exist. Add it to your inventory\'s item list (custom_inventory/shared/items.lua or ox_inventory/data/items.lua).'):format(item))
        return notify(src, 'Your wedding ring could not be created. Please tell staff.', 'error')
    end

    local success, response = core:AddItem(src, item, 1, {
        description = ('Married to %s on %s'):format(partnerName, date),
    })

    if not success then
        lib.print.error(('Could not give %s to player %s: %s'):format(item, src, tostring(response)))
        if response == 'inventory_full' or response == 'Not enough space' or response == 'Too heavy' then
            notify(src, 'Your pockets are full, so the ring could not be given. Make space and ask staff for it.', 'error')
        else
            notify(src, 'Your wedding ring could not be given. Please tell staff.', 'error')
        end
    end
end

-- ---------------------------------------------------------------------------
-- Proposal (use the engagement ring near someone)
-- ---------------------------------------------------------------------------

local function propose(src)
    if pending[src] then return end

    local player = core:GetPlayer(src)
    if not player then return end
    local cid = player.PlayerData.citizenid

    if getRelationship(cid) then
        return notify(src, 'You are already engaged or married.', 'error')
    end

    local target = lib.callback.await('qbx_marriage:client:getClosestPlayer', src, Config.ProposalDistance)
    target = tonumber(target)
    if not target or target == src then
        return notify(src, 'There is no one close enough to propose to.', 'error')
    end

    local targetPlayer = core:GetPlayer(target)
    if not targetPlayer or not playersNear(src, target, Config.ProposalDistance + 1.0) then
        return notify(src, 'There is no one close enough to propose to.', 'error')
    end

    local targetCid = targetPlayer.PlayerData.citizenid
    if getRelationship(targetCid) then
        return notify(src, 'They are already spoken for.', 'error')
    end

    if pending[target] then
        return notify(src, 'They are busy right now.', 'error')
    end

    pending[src], pending[target] = true, true
    TriggerClientEvent('qbx_marriage:client:kneel', src)

    local accepted = lib.callback.await('qbx_marriage:client:proposalPrompt', target, fullName(player))

    pending[src], pending[target] = nil, nil
    TriggerClientEvent('qbx_marriage:client:stopAnim', src)

    if not accepted then
        notify(src, ('%s said no.'):format(fullName(targetPlayer)), 'error')
        return notify(target, 'You turned down the proposal.', 'inform')
    end

    -- Re-check in case anything changed while the prompt was open.
    if getRelationship(cid) or getRelationship(targetCid) then return end
    if not core:RemoveItem(src, Config.Items.engagementRing, 1) then
        return notify(src, 'You no longer have the ring!', 'error')
    end

    MySQL.insert.await(
        'INSERT INTO marriages (partner1, partner2, partner1_name, partner2_name, status) VALUES (?, ?, ?, ?, ?)',
        { cid, targetCid, fullName(player), fullName(targetPlayer), 'engaged' }
    )

    syncMetadata(src)
    syncMetadata(target)

    TriggerClientEvent('qbx_marriage:client:kiss', src, target)
    TriggerClientEvent('qbx_marriage:client:kiss', target, src)
    notify(src, ('%s said yes! You are now engaged.'):format(fullName(targetPlayer)), 'success')
    notify(target, ('You are now engaged to %s!'):format(fullName(player)), 'success')
end

core:CreateUseableItem(Config.Items.engagementRing, function(source)
    propose(source)
end)

-- ---------------------------------------------------------------------------
-- Wedding ceremony (chapel officiant)
-- ---------------------------------------------------------------------------

RegisterNetEvent('qbx_marriage:server:wedding', function()
    local src = source
    if pending[src] then return end

    local player = core:GetPlayer(src)
    if not player then return end
    local cid = player.PlayerData.citizenid

    if distanceTo(src, Config.Chapel.coords) > Config.CeremonyDistance then return end

    local rel = getRelationship(cid)
    if not rel or rel.status ~= 'engaged' then
        return notify(src, 'You need to be engaged before you can marry.', 'error')
    end

    local partnerCid, partnerName = partnerOf(rel, cid)
    local partner = core:GetPlayerByCitizenId(partnerCid)
    if not partner then
        return notify(src, ('%s needs to be here for the ceremony.'):format(partnerName), 'error')
    end

    local partnerSrc = partner.PlayerData.source
    if distanceTo(partnerSrc, Config.Chapel.coords) > Config.CeremonyDistance then
        return notify(src, ('%s needs to be at the chapel.'):format(partnerName), 'error')
    end

    if pending[partnerSrc] then
        return notify(src, ('%s is busy right now.'):format(partnerName), 'error')
    end

    if player.Functions.GetMoney('bank') < Config.WeddingFee then
        return notify(src, ('The ceremony costs $%s.'):format(Config.WeddingFee), 'error')
    end

    pending[src], pending[partnerSrc] = true, true
    notify(src, ('Waiting for %s to say "I do"...'):format(partnerName), 'inform')
    local accepted = lib.callback.await('qbx_marriage:client:vowPrompt', partnerSrc, fullName(player))
    pending[src], pending[partnerSrc] = nil, nil

    if not accepted then
        notify(src, ('%s is not ready to say "I do".'):format(partnerName), 'error')
        return
    end

    -- Exchange vows: both play the ceremony, and must still be at the chapel afterwards.
    pending[src], pending[partnerSrc] = true, true
    TriggerClientEvent('qbx_marriage:client:ceremony', src, partnerSrc)
    TriggerClientEvent('qbx_marriage:client:ceremony', partnerSrc, src)
    Wait(Config.CeremonyDuration)
    pending[src], pending[partnerSrc] = nil, nil

    player = core:GetPlayer(src)
    partner = core:GetPlayer(partnerSrc)
    if not player or not partner
        or distanceTo(src, Config.Chapel.coords) > Config.CeremonyDistance
        or distanceTo(partnerSrc, Config.Chapel.coords) > Config.CeremonyDistance then
        if player then notify(src, 'The ceremony was interrupted.', 'error') end
        if partner then notify(partnerSrc, 'The ceremony was interrupted.', 'error') end
        return
    end

    -- Re-validate after the prompt and ceremony.
    rel = getRelationship(cid)
    if not rel or rel.status ~= 'engaged' then return end

    if not player.Functions.RemoveMoney('bank', Config.WeddingFee, 'wedding-ceremony') then
        return notify(src, ('The ceremony costs $%s.'):format(Config.WeddingFee), 'error')
    end

    MySQL.update.await("UPDATE marriages SET status = 'married', married_at = NOW() WHERE id = ?", { rel.id })

    TriggerClientEvent('qbx_marriage:client:kiss', src, partnerSrc)
    TriggerClientEvent('qbx_marriage:client:kiss', partnerSrc, src)
    notify(src, ('You are now married to %s!'):format(partnerName), 'success')
    notify(partnerSrc, ('You are now married to %s!'):format(fullName(player)), 'success')

    if Config.GiveWeddingRings then
        local date = os.date('%B %d, %Y')
        giveWeddingRing(src, partnerName, date)
        giveWeddingRing(partnerSrc, fullName(player), date)
    end

    syncMetadata(src)
    syncMetadata(partnerSrc)

    if Config.AnnounceWeddings then
        notify(-1, ('%s and %s just got married!'):format(fullName(player), partnerName), 'success')
    end
end)

-- Married players without a ring (lost it, or it failed to give) can collect one.
RegisterNetEvent('qbx_marriage:server:collectRing', function()
    local src = source
    local player = core:GetPlayer(src)
    if not player then return end
    if distanceTo(src, Config.Chapel.coords) > Config.CeremonyDistance then return end

    local cid = player.PlayerData.citizenid
    local rel = getRelationship(cid)
    if not rel or rel.status ~= 'married' then
        return notify(src, 'You are not married.', 'error')
    end

    if (core:GetItemCount(src, Config.Items.weddingRing) or 0) > 0 then
        return notify(src, 'You already have your wedding ring.', 'error')
    end

    local _, partnerName = partnerOf(rel, cid)
    local date = rel.married_at and os.date('%B %d, %Y', math.floor(rel.married_at / 1000)) or os.date('%B %d, %Y')
    giveWeddingRing(src, partnerName, date)
end)

-- ---------------------------------------------------------------------------
-- Courthouse: divorce / calling off an engagement
-- ---------------------------------------------------------------------------

RegisterNetEvent('qbx_marriage:server:divorce', function()
    local src = source
    local player = core:GetPlayer(src)
    if not player then return end
    if distanceTo(src, Config.Courthouse.coords) > 5.0 then return end

    local cid = player.PlayerData.citizenid
    local rel = getRelationship(cid)
    if not rel or rel.status ~= 'married' then
        return notify(src, 'You are not married.', 'error')
    end

    if not player.Functions.RemoveMoney('bank', Config.DivorceFee, 'divorce-filing') then
        return notify(src, ('Filing for divorce costs $%s.'):format(Config.DivorceFee), 'error')
    end

    MySQL.update.await("UPDATE marriages SET status = 'divorced', ended_at = NOW() WHERE id = ?", { rel.id })

    local partnerCid, partnerName = partnerOf(rel, cid)
    syncMetadata(src)
    notify(src, ('You are now divorced from %s.'):format(partnerName), 'inform')

    local partnerSrc = syncByCitizenId(partnerCid)
    if partnerSrc then
        notify(partnerSrc, ('%s has divorced you.'):format(fullName(player)), 'error')
    end
end)

RegisterNetEvent('qbx_marriage:server:breakEngagement', function()
    local src = source
    local player = core:GetPlayer(src)
    if not player then return end
    if distanceTo(src, Config.Courthouse.coords) > 5.0 then return end

    local cid = player.PlayerData.citizenid
    local rel = getRelationship(cid)
    if not rel or rel.status ~= 'engaged' then
        return notify(src, 'You are not engaged.', 'error')
    end

    MySQL.update.await("UPDATE marriages SET status = 'cancelled', ended_at = NOW() WHERE id = ?", { rel.id })

    local partnerCid, partnerName = partnerOf(rel, cid)
    syncMetadata(src)
    notify(src, ('You called off your engagement to %s.'):format(partnerName), 'inform')

    local partnerSrc = syncByCitizenId(partnerCid)
    if partnerSrc then
        notify(partnerSrc, ('%s called off your engagement.'):format(fullName(player)), 'error')
    end
end)

-- ---------------------------------------------------------------------------
-- Command, login sync, cleanup
-- ---------------------------------------------------------------------------

lib.addCommand('spouse', { help = 'Check your relationship status' }, function(source)
    local player = core:GetPlayer(source)
    if not player then return end

    local cid = player.PlayerData.citizenid
    local rel = getRelationship(cid)
    if not rel then
        return notify(source, 'You are single.', 'inform')
    end

    local partnerCid, partnerName = partnerOf(rel, cid)
    local online = core:GetPlayerByCitizenId(partnerCid) and 'in the city' or 'away'
    local label = rel.status == 'married' and 'Married to' or 'Engaged to'
    notify(source, ('%s %s (%s)'):format(label, partnerName, online), 'inform')
end)

AddEventHandler('nova:server:playerLoaded', function(src)
    local player = core:GetPlayer(src)
    if not player then return end
    syncMetadata(src)

    local rel = getRelationship(player.PlayerData.citizenid)
    if rel and rel.status == 'married' then
        local partnerCid = partnerOf(rel, player.PlayerData.citizenid)
        local partner = core:GetPlayerByCitizenId(partnerCid)
        if partner then
            notify(partner.PlayerData.source, ('Your spouse %s just arrived in the city.'):format(fullName(player)), 'inform')
        end
    end
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    -- Create the table automatically so marriage.sql is optional.
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `marriages` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `partner1` VARCHAR(50) NOT NULL,
            `partner2` VARCHAR(50) NOT NULL,
            `partner1_name` VARCHAR(100) NOT NULL,
            `partner2_name` VARCHAR(100) NOT NULL,
            `status` ENUM('engaged', 'married', 'divorced', 'cancelled') NOT NULL DEFAULT 'engaged',
            `engaged_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            `married_at` TIMESTAMP NULL DEFAULT NULL,
            `ended_at` TIMESTAMP NULL DEFAULT NULL,
            PRIMARY KEY (`id`),
            KEY `partner1` (`partner1`),
            KEY `partner2` (`partner2`),
            KEY `status` (`status`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    for _, src in ipairs(core:GetPlayerSources()) do
        syncMetadata(src)
    end
end)

AddEventHandler('playerDropped', function()
    pending[source] = nil
end)

-- ---------------------------------------------------------------------------
-- Exports for other resources
-- ---------------------------------------------------------------------------

exports('GetRelationship', function(citizenid)
    return getRelationship(citizenid)
end)

exports('IsMarried', function(citizenid)
    local rel = getRelationship(citizenid)
    return rel ~= nil and rel.status == 'married'
end)

exports('GetSpouse', function(citizenid)
    local rel = getRelationship(citizenid)
    if not rel or rel.status ~= 'married' then return nil end
    local partnerCid, partnerName = partnerOf(rel, citizenid)
    return { citizenid = partnerCid, name = partnerName }
end)
