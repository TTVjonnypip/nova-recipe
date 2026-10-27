-- Building player data -----------------------------------------------------

function Nova.BuildJob(name, grade, onduty)
    local job = Nova.Jobs[name]
    if not job then
        name, job, grade = 'unemployed', Nova.Jobs.unemployed, 0
    end
    grade = tonumber(grade) or 0
    local gradeData = job.grades[grade]
    if not gradeData then
        grade, gradeData = 0, job.grades[0]
    end
    if onduty == nil then onduty = job.defaultDuty ~= false end

    return {
        name = name,
        label = job.label,
        type = job.type,
        payment = gradeData.payment or 0,
        onduty = onduty == true,
        isboss = gradeData.isboss == true,
        grade = { name = gradeData.name, level = grade },
    }
end

function Nova.BuildGang(name, grade)
    local gang = Nova.Gangs[name]
    if not gang then
        name, gang, grade = 'none', Nova.Gangs.none, 0
    end
    grade = tonumber(grade) or 0
    local gradeData = gang.grades[grade]
    if not gradeData then
        grade, gradeData = 0, gang.grades[0]
    end

    return {
        name = name,
        label = gang.label,
        isboss = gradeData.isboss == true,
        grade = { name = gradeData.name, level = grade },
    }
end

local function gradeLevel(grade)
    if type(grade) == 'table' then return grade.level end
    return grade
end

local function defaultCharinfo(charinfo)
    charinfo = charinfo or {}
    charinfo.firstname = charinfo.firstname or 'John'
    charinfo.lastname = charinfo.lastname or 'Doe'
    charinfo.birthdate = charinfo.birthdate or '1990-01-01'
    charinfo.gender = tonumber(charinfo.gender) or 0
    charinfo.nationality = charinfo.nationality or 'American'
    charinfo.phone = charinfo.phone or Nova.GeneratePhone()
    charinfo.account = charinfo.account or Nova.GenerateAccount()
    return charinfo
end

local function defaultMetadata(meta)
    meta = meta or {}
    local defaults = {
        hunger = 100, thirst = 100, stress = 0,
        isdead = false, inlaststand = false, armor = 0,
        ishandcuffed = false, tracker = false,
        injail = 0, jailitems = {},
        status = {}, phone = {}, jobrep = {}, commandbinds = {},
        callsign = 'NO CALLSIGN',
        criminalrecord = { hasRecord = false },
        licences = { driver = true, business = false, weapon = false },
        inside = { apartment = {} },
    }
    for key, value in pairs(defaults) do
        if meta[key] == nil then meta[key] = value end
    end
    meta.bloodtype = meta.bloodtype or ServerConfig.BloodTypes[math.random(#ServerConfig.BloodTypes)]
    meta.fingerprint = meta.fingerprint or Nova.GenerateFingerprint()
    meta.walletid = meta.walletid or Nova.GenerateWalletId()
    meta.phonedata = meta.phonedata or { SerialNumber = Nova.GenerateSerial(), InstalledApps = {} }
    return meta
end

local function checkPlayerData(source, data)
    data = data or {}
    local pd = {}

    pd.source = source
    pd.license = data.license or Nova.GetLicense(source)
    pd.name = GetPlayerName(source)
    pd.citizenid = data.citizenid or Nova.GenerateCitizenId()
    pd.cid = tonumber(data.cid) or 1

    pd.money = data.money or {}
    for account, start in pairs(Config.Money.types) do
        pd.money[account] = tonumber(pd.money[account]) or start
    end

    pd.charinfo = defaultCharinfo(data.charinfo)
    pd.charinfo.cid = pd.cid
    pd.metadata = defaultMetadata(data.metadata)

    local job = data.job or {}
    local onduty = job.onduty
    if Config.ForceDefaultDutyAtLogin then onduty = nil end
    pd.job = Nova.BuildJob(job.name or 'unemployed', gradeLevel(job.grade) or 0, onduty)

    local gang = data.gang or {}
    pd.gang = Nova.BuildGang(gang.name or 'none', gradeLevel(gang.grade) or 0)

    local pos = data.position
    if type(pos) == 'table' and pos.x and pos.y and pos.z then
        pd.position = { x = pos.x, y = pos.y, z = pos.z, w = pos.w or pos.h or 0.0 }
    else
        local d = Config.DefaultSpawn
        pd.position = { x = d.x, y = d.y, z = d.z, w = d.w }
    end

    pd.items = {} -- filled by ox_inventory
    pd.optin = true
    return pd
end

-- Player object ------------------------------------------------------------
-- Methods are closures over `self`, so they keep working when the object is
-- passed to other resources through exports or events.

function Nova.CreatePlayer(source, data, isNew)
    local self = {}
    self.PlayerData = checkPlayerData(source, data)
    self.Functions = {}
    self.Offline = false
    self.spawned = false
    self.isNew = isNew == true

    local src = source

    local function sync()
        TriggerClientEvent('nova:client:setPlayerData', src, self.PlayerData)
    end

    function self.Functions.UpdatePlayerData()
        sync()
    end

    function self.Functions.SetPlayerData(key, value)
        if type(key) ~= 'string' then return end
        self.PlayerData[key] = value
        sync()
    end

    -- Jobs / gangs ------------------------------------------------------------

    function self.Functions.SetJob(name, grade)
        name = tostring(name):lower()
        grade = tonumber(grade) or 0
        local job = Nova.Jobs[name]
        if not job or not job.grades[grade] then return false end

        self.PlayerData.job = Nova.BuildJob(name, grade, nil)
        sync()
        TriggerEvent('nova:server:onJobUpdate', src, self.PlayerData.job)
        TriggerClientEvent('nova:client:onJobUpdate', src, self.PlayerData.job)
        return true
    end

    function self.Functions.SetGang(name, grade)
        name = tostring(name):lower()
        grade = tonumber(grade) or 0
        local gang = Nova.Gangs[name]
        if not gang or not gang.grades[grade] then return false end

        self.PlayerData.gang = Nova.BuildGang(name, grade)
        sync()
        TriggerEvent('nova:server:onGangUpdate', src, self.PlayerData.gang)
        TriggerClientEvent('nova:client:onGangUpdate', src, self.PlayerData.gang)
        return true
    end

    function self.Functions.SetJobDuty(onDuty)
        self.PlayerData.job.onduty = onDuty == true
        sync()
        TriggerEvent('nova:server:onDutyUpdate', src, self.PlayerData.job.onduty)
        TriggerClientEvent('nova:client:onDutyUpdate', src, self.PlayerData.job.onduty)
        TriggerEvent('nova:server:onJobUpdate', src, self.PlayerData.job)
        TriggerClientEvent('nova:client:onJobUpdate', src, self.PlayerData.job)
    end

    -- Metadata ----------------------------------------------------------------

    function self.Functions.SetMetaData(key, value)
        if type(key) ~= 'string' then return end
        local md = self.PlayerData.metadata
        if key == 'hunger' or key == 'thirst' or key == 'stress' then
            value = Utils.Clamp(tonumber(value) or 0, 0, 100)
        end
        local old = md[key]
        md[key] = value
        sync()
        TriggerEvent('nova:server:onMetaDataChange', src, key, value, old)

        if key == 'hunger' or key == 'thirst' then
            TriggerClientEvent('hud:client:UpdateNeeds', src, md.hunger, md.thirst)
        elseif key == 'stress' then
            TriggerClientEvent('hud:client:UpdateStress', src, value)
        end
    end

    function self.Functions.GetMetaData(key)
        return self.PlayerData.metadata[key]
    end

    -- Money -------------------------------------------------------------------

    local function validAmount(amount)
        amount = tonumber(amount)
        if not amount or amount ~= amount or amount < 0 or amount == math.huge then return nil end
        return amount
    end

    local function moneyChanged(account, amount, action, reason)
        sync()
        TriggerEvent('nova:server:onMoneyChange', src, account, amount, action, reason or 'unknown')
        TriggerClientEvent('nova:client:onMoneyChange', src, account, amount, action, reason or 'unknown')
    end

    function self.Functions.AddMoney(account, amount, reason)
        account = tostring(account):lower()
        amount = validAmount(amount)
        local money = self.PlayerData.money
        if not amount or money[account] == nil then return false end

        money[account] = money[account] + amount
        moneyChanged(account, amount, 'add', reason)
        return true
    end

    function self.Functions.RemoveMoney(account, amount, reason)
        account = tostring(account):lower()
        amount = validAmount(amount)
        local money = self.PlayerData.money
        if not amount or money[account] == nil then return false end
        if Config.Money.dontAllowMinus[account] and money[account] - amount < 0 then return false end

        money[account] = money[account] - amount
        moneyChanged(account, amount, 'remove', reason)
        return true
    end

    function self.Functions.SetMoney(account, amount, reason)
        account = tostring(account):lower()
        amount = validAmount(amount)
        local money = self.PlayerData.money
        if not amount or money[account] == nil then return false end

        money[account] = amount
        moneyChanged(account, amount, 'set', reason)
        return true
    end

    function self.Functions.GetMoney(account)
        local value = self.PlayerData.money[tostring(account):lower()]
        if value == nil then return false end
        return value
    end

    -- Inventory (via server/inventory.lua) ------------------------------------
    -- ox_inventory's qb bridge replaces these with its own versions on login.

    function self.Functions.AddItem(item, amount, slot, info)
        return Inventory.AddItem(src, item, amount or 1, info, slot)
    end

    function self.Functions.RemoveItem(item, amount, slot)
        return Inventory.RemoveItem(src, item, amount or 1, nil, slot)
    end

    function self.Functions.GetItemByName(item)
        return Inventory.GetSlotWithItem(src, item)
    end

    function self.Functions.GetItemsByName(item)
        return Inventory.GetSlotsWithItem(src, item)
    end

    function self.Functions.HasItem(item, amount)
        return Inventory.HasItem(src, item, amount)
    end

    function self.Functions.ClearInventory()
        Inventory.ClearInventory(src)
    end

    -- Lifecycle / extension ---------------------------------------------------

    function self.Functions.Save()
        return Nova.SavePlayer(src)
    end

    function self.Functions.Logout()
        return Nova.Logout(src)
    end

    function self.Functions.AddMethod(name, fn)
        self.Functions[name] = fn
    end

    function self.Functions.AddField(key, value)
        self[key] = value
    end

    Nova.Players[src] = self
    Nova.CitizenIndex[self.PlayerData.citizenid] = src
    return self
end

-- Save / login / logout ----------------------------------------------------

function Nova.SavePlayer(source)
    local player = Nova.Players[source]
    if not player then return false end
    local pd = player.PlayerData

    -- Only record position once the player has actually spawned, so the
    -- character-select scene never becomes their saved location.
    if player.spawned then
        local ped = GetPlayerPed(source)
        if ped and ped ~= 0 then
            local coords = GetEntityCoords(ped)
            pd.position = { x = coords.x, y = coords.y, z = coords.z, w = GetEntityHeading(ped) }
            pd.metadata.armor = GetPedArmour(ped)
        end
    end

    Storage.SavePlayer(pd)
    return true
end

function Nova.Login(source, citizenid, newData)
    source = tonumber(source)
    if not source or not GetPlayerName(source) then return false, 'invalid_source' end
    if Nova.Players[source] then return false, 'already_logged_in' end

    local license = Nova.GetLicense(source)
    if not license then return false, 'no_license' end

    local data, isNew
    if citizenid then
        if Nova.CitizenIndex[citizenid] then return false, 'character_in_use' end
        data = Storage.FetchCharacter(citizenid, license)
        if not data then return false, 'character_not_found' end
    else
        data = newData or {}
        data.license = license
        data.citizenid = nil
        isNew = true
    end

    local player = Nova.CreatePlayer(source, data, isNew)
    if isNew then Nova.SavePlayer(source) end

    TriggerClientEvent('nova:client:setPlayerData', source, player.PlayerData)
    TriggerEvent('nova:server:playerLoaded', source)

    print(('^2[nova_core]^7 %s (%s) loaded character %s %s [%s]'):format(
        GetPlayerName(source), source,
        player.PlayerData.charinfo.firstname, player.PlayerData.charinfo.lastname,
        player.PlayerData.citizenid))

    return true, player.PlayerData
end

-- Called (via net event) once the client has actually spawned in the world.
function Nova.OnPlayerSpawned(source)
    local player = Nova.Players[source]
    if not player or player.spawned then return end
    player.spawned = true

    local state = Player(source).state
    state:set('isLoggedIn', true, true)
    state:set('citizenid', player.PlayerData.citizenid, true)

    TriggerClientEvent('nova:client:onPlayerLoaded', source)
    TriggerEvent('nova:server:onPlayerSpawned', source, player.isNew)

    if player.isNew then
        player.isNew = false
        for _, item in ipairs(ServerConfig.StarterItems) do
            local ok, err = pcall(Inventory.AddItem, source, item.name, item.count or 1, item.metadata)
            if not ok then print(('^3[nova_core]^7 starter item %s failed: %s'):format(item.name, err)) end
        end
    end
end

-- Unload events fire while the player is still in Nova.Players so listeners
-- can read their data, then the player is removed.
function Nova.UnloadPlayer(source, dropped)
    local player = Nova.Players[source]
    if not player then return false end
    local citizenid = player.PlayerData.citizenid

    Nova.SavePlayer(source)
    Storage.SetLastLoggedOut(citizenid)

    TriggerEvent('nova:server:onPlayerUnload', source, citizenid, dropped == true)
    if not dropped then
        TriggerClientEvent('nova:client:onPlayerUnload', source)
        local state = Player(source).state
        state:set('isLoggedIn', false, true)
        state:set('citizenid', nil, true)
    end

    Nova.Players[source] = nil
    Nova.CitizenIndex[citizenid] = nil
    return true
end

function Nova.Logout(source)
    return Nova.UnloadPlayer(source, false)
end

-- Characters ---------------------------------------------------------------

local function validName(name)
    return type(name) == 'string' and #name >= 2 and #name <= 16
        and name:match("^%a[%a%-' ]*$") ~= nil
end

-- Pure-Lua days -> civil date (works for pre-1970 dates on every OS)
local function civilFromDays(z)
    z = z + 719468
    local era = (z >= 0 and z or z - 146096) // 146097
    local doe = z - era * 146097
    local yoe = (doe - doe // 1460 + doe // 36524 - doe // 146096) // 365
    local y = yoe + era * 400
    local doy = doe - (365 * yoe + yoe // 4 - yoe // 100)
    local mp = (5 * doy + 2) // 153
    local d = doy - (153 * mp + 2) // 5 + 1
    local m = mp < 10 and mp + 3 or mp - 9
    if m <= 2 then y = y + 1 end
    return y, m, d
end

local function normaliseBirthdate(value)
    local y, m, d
    if type(value) == 'number' then
        local seconds = value
        if math.abs(seconds) > 1e11 then seconds = seconds / 1000 end -- ms timestamp from ox_lib
        y, m, d = civilFromDays(math.floor((seconds + 43200) // 86400))
    elseif type(value) == 'string' then
        y, m, d = value:match('^(%d%d%d%d)%-(%d%d)%-(%d%d)$')
        y, m, d = tonumber(y), tonumber(m), tonumber(d)
    end
    if not y or y < 1900 or y > 2015 or not m or m < 1 or m > 12 or not d or d < 1 or d > 31 then
        return nil
    end
    return ('%04d-%02d-%02d'):format(y, m, d)
end

function Nova.GetMaxCharacters(source)
    local license = Nova.GetLicense(source)
    return (license and ServerConfig.CharacterSlots[license]) or Config.MaxCharacters
end

function Nova.GetCharacters(source)
    local license = Nova.GetLicense(source)
    if not license then return {} end
    return Storage.FetchCharacters(license)
end

function Nova.OwnsCharacter(source, citizenid)
    local license = Nova.GetLicense(source)
    return license ~= nil and type(citizenid) == 'string' and Storage.FetchCharacter(citizenid, license) ~= nil
end

function Nova.CreateCharacter(source, input)
    if Nova.Players[source] then return false, 'already_logged_in' end
    if type(input) ~= 'table' then return false, 'invalid_data' end

    local license = Nova.GetLicense(source)
    if not license then return false, 'no_license' end

    local firstname, lastname = Utils.Trim(input.firstname), Utils.Trim(input.lastname)
    if not validName(firstname) or not validName(lastname) then return false, 'invalid_name' end

    local birthdate = normaliseBirthdate(input.birthdate)
    if not birthdate then return false, 'invalid_birthdate' end

    local gender = tonumber(input.gender)
    if gender ~= 0 and gender ~= 1 then return false, 'invalid_gender' end

    local nationality = Utils.Trim(input.nationality)
    if type(nationality) ~= 'string' or #nationality == 0 or #nationality > 32 then
        nationality = 'American'
    end

    local existing = Storage.FetchCharacters(license)
    if #existing >= Nova.GetMaxCharacters(source) then return false, 'max_characters' end

    local used = {}
    for _, char in ipairs(existing) do used[tonumber(char.cid) or 0] = true end
    local cid = 1
    while used[cid] do cid = cid + 1 end

    return Nova.Login(source, nil, {
        cid = cid,
        charinfo = {
            firstname = Utils.FirstToUpper(firstname),
            lastname = Utils.FirstToUpper(lastname),
            birthdate = birthdate,
            gender = gender,
            nationality = nationality,
        },
    })
end

function Nova.DeleteCharacter(source, citizenid)
    if type(citizenid) ~= 'string' then return false, 'invalid_data' end
    if Nova.CitizenIndex[citizenid] then return false, 'character_in_use' end
    if not Nova.OwnsCharacter(source, citizenid) then return false, 'character_not_found' end

    Storage.DeleteCharacter(citizenid)
    TriggerEvent('nova:server:characterDeleted', source, citizenid)
    print(('^3[nova_core]^7 %s (%s) deleted character %s'):format(GetPlayerName(source), source, citizenid))
    return true
end

-- Exports ------------------------------------------------------------------

exports('Login', Nova.Login)
exports('Logout', Nova.Logout)
exports('SavePlayer', Nova.SavePlayer)
exports('CreateCharacter', Nova.CreateCharacter)
exports('DeleteCharacter', Nova.DeleteCharacter)
exports('GetCharacters', Nova.GetCharacters)
exports('GetMaxCharacters', Nova.GetMaxCharacters)
exports('OwnsCharacter', Nova.OwnsCharacter)

-- Direct helpers so other resources don't need to pull a whole player object
local function call(source, method, ...)
    local player = Nova.Players[source]
    if not player then return false end
    return player.Functions[method](...)
end

exports('GetPlayerData', function(source)
    local player = Nova.Players[source]
    return player and player.PlayerData or nil
end)
exports('AddMoney', function(source, ...) return call(source, 'AddMoney', ...) end)
exports('RemoveMoney', function(source, ...) return call(source, 'RemoveMoney', ...) end)
exports('SetMoney', function(source, ...) return call(source, 'SetMoney', ...) end)
exports('GetMoney', function(source, ...) return call(source, 'GetMoney', ...) end)
exports('SetJob', function(source, ...) return call(source, 'SetJob', ...) end)
exports('SetGang', function(source, ...) return call(source, 'SetGang', ...) end)
exports('SetJobDuty', function(source, ...) return call(source, 'SetJobDuty', ...) end)
exports('SetMetaData', function(source, ...) return call(source, 'SetMetaData', ...) end)
exports('GetMetaData', function(source, ...) return call(source, 'GetMetaData', ...) end)
