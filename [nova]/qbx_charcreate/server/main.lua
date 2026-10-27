local busy = {}

local core = exports.nova_core

-- ─────────────────────────────────────────────
--  Settings (from config.lua; slots come from nova_core)
-- ─────────────────────────────────────────────
local function isoDate(t) return os.date('%Y-%m-%d', os.time(t)) end

local S = {}

local function buildSettings()
    local now = os.date('*t')
    S.allowDelete        = Config.AllowDelete
    S.startingApartment  = false -- Nova has no apartments resource
    S.dateMin            = Config.DateMin or isoDate({ year = now.year - Config.MaxAge, month = now.month, day = now.day })
    S.dateMax            = Config.DateMax or isoDate({ year = now.year - Config.MinAge, month = now.month, day = now.day })
    S.limitNationalities = Config.LimitNationalities
    S.nationalities      = Config.Nationalities
    S.profanity          = {}
    for _, word in ipairs(Config.ProfanityWords or {}) do S.profanity[word:lower()] = true end
end

buildSettings()
lib.print.info(('Settings loaded - delete: %s, dates: %s -> %s, nationalities: %s'):format(
    tostring(S.allowDelete), S.dateMin, S.dateMax,
    S.limitNationalities and (#S.nationalities .. ' listed') or 'free text'))

-- ─────────────────────────────────────────────
--  Helpers
-- ─────────────────────────────────────────────
local function getLicenses(src)
    return GetPlayerIdentifierByType(src, 'license2'), GetPlayerIdentifierByType(src, 'license')
end

-- Slots are configured once, in nova_core (Config.MaxCharacters / ServerConfig.CharacterSlots)
local function getMaxSlots(src)
    return core:GetMaxCharacters(src) or 3
end

local function decode(str)
    if type(str) ~= 'string' then return str or {} end
    local ok, res = pcall(json.decode, str)
    return ok and res or {}
end

local function fetchCharacters(src)
    local l2, l = getLicenses(src)
    local rows = MySQL.query.await(
        'SELECT citizenid, cid, charinfo, money, job, position FROM players WHERE license = ? OR license = ? ORDER BY cid ASC',
        { l2 or '', l or '' }
    ) or {}

    local list = {}
    for i = 1, #rows do
        local row = rows[i]
        local info  = decode(row.charinfo)
        local money = decode(row.money)
        local job   = decode(row.job)
        list[#list + 1] = {
            citizenid   = row.citizenid,
            cid         = row.cid,
            firstname   = info.firstname or 'Unknown',
            lastname    = info.lastname or '',
            birthdate   = info.birthdate or '',
            gender      = tonumber(info.gender) or 0,
            nationality = info.nationality or '',
            phone       = info.phone or '',
            cash        = money.cash or 0,
            bank        = money.bank or 0,
            job         = job.label or 'Unemployed',
            grade       = job.grade and job.grade.name or '',
        }
    end
    return list
end

local function ownsCharacter(src, citizenid)
    if type(citizenid) ~= 'string' then return false end
    local l2, l = getLicenses(src)
    local row = MySQL.scalar.await(
        'SELECT 1 FROM players WHERE citizenid = ? AND (license = ? OR license = ?)',
        { citizenid, l2 or '', l or '' }
    )
    return row ~= nil
end

local function trim(s) return (s:gsub('^%s+', ''):gsub('%s+$', '')) end

local function formatName(s)
    s = trim(s):lower()
    return (s:gsub("(%a)([%w'%-]*)", function(a, b) return a:upper() .. b end))
end

local function validName(name)
    if type(name) ~= 'string' then return false, 'Invalid name' end
    name = trim(name)
    if #name < Config.NameMinLength or #name > Config.NameMaxLength then
        return false, ('Names must be %d-%d characters'):format(Config.NameMinLength, Config.NameMaxLength)
    end
    if not name:match("^%a[%a' %-]*$") then
        return false, 'Names can only contain letters, spaces, hyphens and apostrophes'
    end
    local lower = name:lower()
    if S.profanity[lower] then return false, 'That name is not allowed' end
    for word in lower:gmatch('%S+') do
        if S.profanity[word] then return false, 'That name is not allowed' end
    end
    for _, bad in ipairs(Config.BlacklistedNames) do
        if lower:find(bad:lower(), 1, true) then return false, 'That name is not allowed' end
    end
    return true
end

local function validBirthdate(date)
    if type(date) ~= 'string' then return false end
    local y, m, d = date:match('^(%d%d%d%d)%-(%d%d)%-(%d%d)$')
    y, m, d = tonumber(y), tonumber(m), tonumber(d)
    if not y or m < 1 or m > 12 or d < 1 or d > 31 then return false end
    -- YYYY-MM-DD strings compare correctly as text
    return date >= S.dateMin and date <= S.dateMax
end

local function validNationality(nat)
    if type(nat) ~= 'string' then return false end
    nat = trim(nat)
    if not S.limitNationalities then
        return #nat >= 2 and #nat <= 50 and nat:match("^%a[%a' %-]*$") ~= nil
    end
    for _, n in ipairs(S.nationalities) do
        if n == nat then return true end
    end
    return false
end

-- Wraps Nova's Login so an error inside the core can't crash our callback
-- (or leave the player stuck as "busy"), and prints the real cause.
local loginErrors = {
    already_logged_in = 'You are already logged in',
    character_in_use = 'That character is already in use',
    character_not_found = 'Character could not be found',
    no_license = 'No Rockstar license found',
}

local function safeLogin(src, citizenid, newData)
    if GetResourceState('nova_core') ~= 'started' then
        lib.print.error(('nova_core is not running (state: %s). Start it before qbx_charcreate.'):format(GetResourceState('nova_core')))
        return false, 'Server error: nova_core is not running'
    end

    local ok, success, result = xpcall(function()
        return core:Login(src, citizenid, newData)
    end, debug.traceback)

    if not ok then
        lib.print.error(('nova_core Login failed for %s (%s):\n%s'):format(GetPlayerName(src), src, success))
        return false, 'Server error while loading - check the server console'
    end
    if not success then
        lib.print.warn(('nova_core Login refused %s (%s): %s'):format(GetPlayerName(src), src, tostring(result)))
        return false, loginErrors[result] or 'Character could not be loaded'
    end
    return true, result -- result = PlayerData
end

-- ─────────────────────────────────────────────
--  Callbacks
-- ─────────────────────────────────────────────
lib.callback.register('qbx_charcreate:getCharacters', function(source)
    SetPlayerRoutingBucket(source, source) -- isolate during selection
    return {
        characters         = fetchCharacters(source),
        maxSlots           = getMaxSlots(source),
        allowDelete        = S.allowDelete,
        limitNationalities = S.limitNationalities,
        nationalities      = S.limitNationalities and S.nationalities or {},
        dateMin            = S.dateMin,
        dateMax            = S.dateMax,
        startingApartment  = S.startingApartment,
        nameMax            = Config.NameMaxLength,
    }
end)

lib.callback.register('qbx_charcreate:getSkin', function(source, citizenid)
    if not ownsCharacter(source, citizenid) then return nil end
    return MySQL.single.await('SELECT model, skin FROM playerskins WHERE citizenid = ? AND active = 1', { citizenid })
end)

lib.callback.register('qbx_charcreate:loadCharacter', function(source, citizenid)
    if busy[source] then return false end
    if not ownsCharacter(source, citizenid) then return false end
    busy[source] = true

    local ok, playerData = safeLogin(source, citizenid)
    busy[source] = nil
    if not ok then return false end

    SetPlayerRoutingBucket(source, 0)
    lib.print.info(('%s (%s) loaded character %s'):format(GetPlayerName(source), source, citizenid))
    local md = playerData.metadata or {}
    return true, playerData.position, ((tonumber(md.injail) or 0) > 0 or md.isdead == true)
end)

lib.callback.register('qbx_charcreate:createCharacter', function(source, data)
    if busy[source] then return false, 'Please wait…' end
    if type(data) ~= 'table' then return false, 'Invalid data' end

    local ok, err = validName(data.firstname)
    if not ok then return false, err end
    ok, err = validName(data.lastname)
    if not ok then return false, err end
    if not validBirthdate(data.birthdate) then
        return false, ('Date of birth must be between %s and %s'):format(S.dateMin, S.dateMax)
    end
    local gender = tonumber(data.gender)
    if gender ~= 0 and gender ~= 1 then return false, 'Invalid gender' end
    if not validNationality(data.nationality) then return false, 'Invalid nationality' end

    local chars = fetchCharacters(source)
    if #chars >= getMaxSlots(source) then return false, 'You have no free character slots' end

    -- next cid, same as qbx_core (last character's cid + 1)
    local cid = 1
    for _, c in ipairs(chars) do
        local n = tonumber(c.cid) or 0
        if n >= cid then cid = n + 1 end
    end

    local newData = {
        cid = cid,
        charinfo = {
            firstname   = formatName(data.firstname),
            lastname    = formatName(data.lastname),
            birthdate   = data.birthdate,
            gender      = gender,
            nationality = S.limitNationalities and data.nationality or formatName(data.nationality),
            backstory   = 'placeholder backstory',
            cid         = cid,
        },
    }

    busy[source] = true
    local success, loginErr = safeLogin(source, nil, newData)
    busy[source] = nil

    if not success then return false, loginErr or 'Character could not be created' end

    -- Starter items are handed out by nova_core (ServerConfig.StarterItems) on first spawn
    SetPlayerRoutingBucket(source, 0)
    lib.print.info(('%s (%s) created a new character: %s %s'):format(
        GetPlayerName(source), source, newData.charinfo.firstname, newData.charinfo.lastname))
    return true, nil, newData
end)

lib.callback.register('qbx_charcreate:deleteCharacter', function(source, citizenid)
    if not S.allowDelete then return false end
    if not ownsCharacter(source, citizenid) then return false end

    local ok, deleted, err = pcall(function()
        return core:DeleteCharacter(source, citizenid)
    end)
    if not ok or not deleted then
        lib.print.error(('Failed to delete character %s: %s'):format(citizenid, tostring(ok and err or deleted)))
        return false
    end
    lib.print.info(('%s (%s) deleted character %s'):format(GetPlayerName(source), source, citizenid))
    return true, fetchCharacters(source)
end)

RegisterNetEvent('qbx_charcreate:server:disconnect', function()
    DropPlayer(source, 'You disconnected from the character menu.')
end)

AddEventHandler('playerDropped', function()
    busy[source] = nil
end)

-- /logout is provided by nova_core (admin only). It fires nova:client:onPlayerUnload,
-- which reopens this menu.
