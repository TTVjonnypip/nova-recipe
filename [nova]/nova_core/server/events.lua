AddEventHandler('playerConnecting', function(_, _, deferrals)
    local src = source
    deferrals.defer()
    Wait(0)
    deferrals.update(('Checking your profile on %s...'):format(Config.ServerName))

    local license = Nova.GetLicense(src)
    if not license then
        return deferrals.done('No Rockstar license was found. Restart FiveM and try again.')
    end

    for _, id in ipairs(GetPlayers()) do
        if Nova.GetLicense(tonumber(id)) == license then
            return deferrals.done('Someone with your license is already connected.')
        end
    end

    local ban = Storage.FetchActiveBan(license,
        GetPlayerIdentifierByType(src, 'discord'), GetPlayerIdentifierByType(src, 'ip'))
    if ban then
        local expires = ban.expire >= 2147483647 and 'Never' or os.date('%Y-%m-%d %H:%M', ban.expire)
        return deferrals.done(('You are banned from %s.\nReason: %s\nExpires: %s\nBan ID: %s'):format(
            Config.ServerName, ban.reason or 'n/a', expires, ban.id))
    end

    if ServerConfig.Whitelist and not ServerConfig.WhitelistLicenses[license]
        and not IsPlayerAceAllowed(src, ServerConfig.WhitelistAce) then
        return deferrals.done(('%s is whitelisted. Apply on our Discord to join.'):format(Config.ServerName))
    end

    deferrals.done()
end)

AddEventHandler('playerDropped', function()
    local src = source
    if Nova.Players[src] then Nova.UnloadPlayer(src, true) end
end)

RegisterNetEvent('nova:server:onPlayerSpawned', function()
    Nova.OnPlayerSpawned(source)
end)

RegisterNetEvent('nova:server:toggleDuty', function()
    local player = Nova.Players[source]
    if player then player.Functions.SetJobDuty(not player.PlayerData.job.onduty) end
end)

-- Save everyone when txAdmin announces a restart / shutdown
AddEventHandler('txAdmin:events:serverShuttingDown', function()
    for _, src in ipairs(Nova.GetPlayerSources()) do Nova.SavePlayer(src) end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for _, src in ipairs(Nova.GetPlayerSources()) do Nova.SavePlayer(src) end
end)
