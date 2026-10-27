-- Lookups ------------------------------------------------------------------

function Nova.GetPlayer(source)
    if type(source) == 'number' then return Nova.Players[source] end
    if type(source) == 'string' then
        local num = tonumber(source)
        if num then return Nova.Players[num] end
        return Nova.GetPlayerByCitizenId(source)
    end
end

function Nova.GetPlayerByCitizenId(citizenid)
    local src = Nova.CitizenIndex[citizenid]
    return src and Nova.Players[src] or nil
end

function Nova.GetPlayerByPhone(phone)
    for _, player in pairs(Nova.Players) do
        if player.PlayerData.charinfo.phone == phone then return player end
    end
end

function Nova.GetPlayerSources()
    local list = {}
    for src in pairs(Nova.Players) do list[#list + 1] = src end
    return list
end

function Nova.GetSourceByIdentifier(identifier)
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        for _, value in ipairs(GetPlayerIdentifiers(src)) do
            if value == identifier then return src end
        end
    end
end

function Nova.GetDutyCount(jobName)
    local count, sources = 0, {}
    for src, player in pairs(Nova.Players) do
        local job = player.PlayerData.job
        if (job.name == jobName or job.type == jobName) and job.onduty then
            count = count + 1
            sources[#sources + 1] = src
        end
    end
    return count, sources
end

-- Permissions --------------------------------------------------------------

local function levelIndex(permission)
    for i, level in ipairs(ServerConfig.Permissions) do
        if level == permission then return i end
    end
end

function Nova.HasPermission(source, permission)
    if source == 0 then return true end -- server console
    if type(permission) == 'table' then
        for _, perm in ipairs(permission) do
            if Nova.HasPermission(source, perm) then return true end
        end
        return false
    end
    if permission == nil or permission == 'user' then return true end

    local target = levelIndex(permission)
    if not target then return IsPlayerAceAllowed(source, permission) end
    for i = 1, target do
        if IsPlayerAceAllowed(source, ServerConfig.Permissions[i]) then return true end
    end
    return false
end

function Nova.GetPermission(source)
    local perms = {}
    for _, level in ipairs(ServerConfig.Permissions) do
        if IsPlayerAceAllowed(source, level) then perms[level] = true end
    end
    return perms
end

-- Notifications ------------------------------------------------------------

function Nova.Notify(source, message, notifType, duration, title)
    if source == 0 then return print(('[nova_core] %s'):format(message)) end
    TriggerClientEvent('ox_lib:notify', source, {
        title = title,
        description = message,
        type = Utils.NotifyType(notifType),
        duration = duration or Config.Notify.duration,
        position = Config.Notify.position,
    })
end

-- Generators ---------------------------------------------------------------

function Nova.GenerateCitizenId()
    while true do
        local id = Utils.RandomLetters(3) .. Utils.RandomNumbers(5)
        if not Storage.CitizenIdExists(id) then return id end
    end
end

function Nova.GeneratePhone()
    while true do
        local phone = tostring(math.random(200, 999)) .. Utils.RandomNumbers(7)
        if not Storage.PhoneExists(phone) then return phone end
    end
end

function Nova.GenerateAccount()
    return 'US0' .. math.random(1, 9) .. 'NOVA' .. Utils.RandomNumbers(7)
end

function Nova.GenerateFingerprint()
    return Utils.RandomLetters(2) .. Utils.RandomNumbers(3) .. Utils.RandomLetters(1)
        .. Utils.RandomNumbers(2) .. Utils.RandomLetters(3) .. Utils.RandomNumbers(4)
end

function Nova.GenerateWalletId()
    return 'NOVA-' .. Utils.RandomNumbers(8)
end

function Nova.GenerateSerial()
    return Utils.RandomNumbers(11)
end

-- Jobs & gangs -------------------------------------------------------------

-- Accepts numeric or qb-style string grade keys and always stores numeric ones.
local function normaliseGrades(grades)
    local out = {}
    for key, grade in pairs(grades or {}) do
        local level = tonumber(key)
        if level then out[level] = grade end
    end
    if not out[0] then out[0] = { name = 'Default', payment = 0 } end
    return out
end

function Nova.AddJob(name, data)
    if type(name) ~= 'string' or type(data) ~= 'table' then return false, 'invalid_job' end
    name = name:lower()
    data.grades = normaliseGrades(data.grades)
    Nova.Jobs[name] = data
    TriggerEvent('nova:server:jobsUpdated', name, data)
    TriggerClientEvent('nova:client:jobsUpdated', -1, name, data)
    return true
end

function Nova.AddGang(name, data)
    if type(name) ~= 'string' or type(data) ~= 'table' then return false, 'invalid_gang' end
    name = name:lower()
    data.grades = normaliseGrades(data.grades)
    Nova.Gangs[name] = data
    TriggerEvent('nova:server:gangsUpdated', name, data)
    TriggerClientEvent('nova:client:gangsUpdated', -1, name, data)
    return true
end

-- Usable items -------------------------------------------------------------

function Nova.CreateUseableItem(name, cb)
    Nova.UsableItems[name] = cb
end

function Nova.CanUseItem(name)
    return Nova.UsableItems[name]
end

-- Moderation ---------------------------------------------------------------

function Nova.Kick(source, reason)
    DropPlayer(source, reason or 'You were kicked from the server.')
end

-- hours <= 0 or nil means permanent
function Nova.Ban(target, hours, reason, bannedBy)
    hours = tonumber(hours) or 0
    local expire = hours > 0 and (os.time() + math.floor(hours * 3600)) or 2147483647
    reason = reason or 'No reason given'
    Storage.InsertBan({
        name = GetPlayerName(target),
        license = Nova.GetLicense(target),
        discord = GetPlayerIdentifierByType(target, 'discord'),
        ip = GetPlayerIdentifierByType(target, 'ip'),
        reason = reason,
        expire = expire,
        bannedby = bannedBy or 'Console',
    })
    DropPlayer(target, ('You have been banned: %s'):format(reason))
end

-- Exports ------------------------------------------------------------------

exports('GetPlayer', Nova.GetPlayer)
exports('GetPlayerByCitizenId', Nova.GetPlayerByCitizenId)
exports('GetPlayerByPhone', Nova.GetPlayerByPhone)
exports('GetPlayerSources', Nova.GetPlayerSources)
exports('GetDutyCount', Nova.GetDutyCount)
exports('HasPermission', Nova.HasPermission)
exports('GetPermission', Nova.GetPermission)
exports('Notify', Nova.Notify)
exports('GetJobs', function() return Nova.Jobs end)
exports('GetJob', function(name) return Nova.Jobs[name] end)
exports('GetGangs', function() return Nova.Gangs end)
exports('GetGang', function(name) return Nova.Gangs[name] end)
exports('AddJob', Nova.AddJob)
exports('AddGang', Nova.AddGang)
exports('CreateUseableItem', Nova.CreateUseableItem)
exports('CanUseItem', function(name) return Nova.UsableItems[name] ~= nil end)
exports('Kick', Nova.Kick)
exports('Ban', Nova.Ban)
exports('IsPlayerLoaded', function(source) return Nova.Players[source] ~= nil end)
exports('GetVehiclesByName', function(model)
    if model then return Shared.Vehicles[model] end
    return Shared.Vehicles
end)
