Nova = {
    Players = {},       -- [source] = player object
    CitizenIndex = {},  -- [citizenid] = source
    UsableItems = {},   -- [itemName] = callback
    Jobs = Shared.Jobs,
    Gangs = Shared.Gangs,
}

function Nova.GetIdentifier(source, idType)
    return GetPlayerIdentifierByType(source, idType or 'license')
end

-- qb databases key characters on `license`; fall back to license2 if that's all we get.
function Nova.GetLicense(source)
    return GetPlayerIdentifierByType(source, 'license') or GetPlayerIdentifierByType(source, 'license2')
end

CreateThread(function()
    print(('^2[nova_core]^7 %s framework started (v%s)'):format(
        Config.ServerName, GetResourceMetadata(GetCurrentResourceName(), 'version', 0) or '1.0.0'))
end)
