--[[
    qb-core compatibility bridge (server)

    Exposes exports['qb-core']:GetCoreObject() with the QBCore API that
    common qb scripts (and ox_inventory's qb bridge) expect, and re-emits
    Nova's events under their QBCore names.
]]

local QBCore = {}

-- Shared data in qb format ---------------------------------------------------

local function toQbGroups(groups)
    local out = {}
    for name, data in pairs(groups) do
        local copy = Utils.DeepCopy(data)
        local grades = {}
        for level, grade in pairs(data.grades or {}) do
            grades[tostring(level)] = Utils.DeepCopy(grade)
        end
        copy.grades = grades
        out[name] = copy
    end
    return out
end

local itemsCache
local function getItems()
    if itemsCache and next(itemsCache) then return itemsCache end
    itemsCache = {}

    local ok, defs = pcall(Inventory.GetItems)
    if not ok or type(defs) ~= 'table' then return itemsCache end

    for name, item in pairs(defs) do
        itemsCache[name] = {
            name = name,
            label = item.label,
            weight = item.weight or 0,
            type = item.weapon and 'weapon' or 'item',
            image = item.image or (name .. '.png'),
            unique = item.stack == false,
            useable = true,
            shouldClose = item.close ~= false,
            description = item.description,
        }
    end
    return itemsCache
end

AddEventHandler('onResourceStart', function(resource)
    if resource == 'ox_inventory' or resource == 'custom_inventory' then itemsCache = nil end
end)

local dontAllowMinus = {}
for account in pairs(Config.Money.dontAllowMinus) do dontAllowMinus[#dontAllowMinus + 1] = account end

QBCore.Config = {
    Server = { Name = Config.ServerName, MaxPlayers = GetConvarInt('sv_maxclients', 48) },
    Money = { MoneyTypes = Config.Money.types, DontAllowMinus = dontAllowMinus },
    Player = { Bloodtypes = ServerConfig.BloodTypes },
    DefaultSpawn = Config.DefaultSpawn,
    Notify = {},
}

QBCore.Shared = {
    Round = Utils.Round,
    RandomStr = Utils.RandomLetters,
    RandomInt = Utils.RandomNumbers,
    SplitStr = Utils.SplitStr,
    Trim = Utils.Trim,
    FirstToUpper = Utils.FirstToUpper,
    ForceJobDefaultDutyAtLogin = Config.ForceDefaultDutyAtLogin,
    StarterItems = {},
}

QBCore.Functions = {}
QBCore.Commands = { List = {} }
QBCore.Player = {}
QBCore.ServerCallbacks = {}

-- Players -------------------------------------------------------------------

function QBCore.Functions.GetPlayer(source) return Nova.GetPlayer(source) end
function QBCore.Functions.GetPlayerByCitizenId(citizenid) return Nova.GetPlayerByCitizenId(citizenid) end
function QBCore.Functions.GetPlayerByPhone(phone) return Nova.GetPlayerByPhone(phone) end
function QBCore.Functions.GetPlayers() return Nova.GetPlayerSources() end
function QBCore.Functions.GetQBPlayers() return Nova.Players end

-- Read-only snapshot of an offline character. No Functions: change data while they're online.
function QBCore.Functions.GetOfflinePlayerByCitizenId(citizenid)
    local online = Nova.GetPlayerByCitizenId(citizenid)
    if online then return online end
    local row = Storage.FetchCharacterByCitizenId(citizenid)
    if not row then return nil end
    return { PlayerData = row, Offline = true, Functions = {} }
end

function QBCore.Functions.GetIdentifier(source, idType)
    return GetPlayerIdentifierByType(source, idType or 'license')
end

function QBCore.Functions.GetSource(identifier) return Nova.GetSourceByIdentifier(identifier) end

function QBCore.Functions.GetDutyCount(job)
    local count = Nova.GetDutyCount(job)
    return count
end

function QBCore.Functions.GetPlayersOnDuty(job)
    local count, sources = Nova.GetDutyCount(job)
    return sources, count
end

function QBCore.Functions.AddPlayerMethod(ids, name, handler)
    if ids == -1 then
        for _, player in pairs(Nova.Players) do player.Functions.AddMethod(name, handler) end
    elseif type(ids) == 'table' then
        for _, id in ipairs(ids) do
            local player = Nova.Players[id]
            if player then player.Functions.AddMethod(name, handler) end
        end
    else
        local player = Nova.Players[ids]
        if player then player.Functions.AddMethod(name, handler) end
    end
end

function QBCore.Functions.AddPlayerField(ids, name, data)
    if ids == -1 then
        for _, player in pairs(Nova.Players) do player.Functions.AddField(name, data) end
    elseif type(ids) == 'table' then
        for _, id in ipairs(ids) do
            local player = Nova.Players[id]
            if player then player.Functions.AddField(name, data) end
        end
    else
        local player = Nova.Players[ids]
        if player then player.Functions.AddField(name, data) end
    end
end

-- Permissions / moderation --------------------------------------------------

function QBCore.Functions.HasPermission(source, permission) return Nova.HasPermission(source, permission) end
function QBCore.Functions.GetPermission(source) return Nova.GetPermission(source) end
function QBCore.Functions.IsOptin() return true end
function QBCore.Functions.Kick(source, reason) Nova.Kick(source, reason) end

function QBCore.Functions.IsPlayerBanned(source)
    local ban = Storage.FetchActiveBan(Nova.GetLicense(source),
        GetPlayerIdentifierByType(source, 'discord'), GetPlayerIdentifierByType(source, 'ip'))
    if not ban then return false end
    return true, ('You are banned. Reason: %s'):format(ban.reason or 'n/a')
end

-- Notify / misc ---------------------------------------------------------------

function QBCore.Functions.Notify(source, text, notifType, length)
    local title, description = nil, text
    if type(text) == 'table' then title, description = text.caption, text.text end
    Nova.Notify(source, description, notifType, length, title)
end

function QBCore.Functions.GetCoords(entity)
    local coords = GetEntityCoords(entity)
    return vec4(coords.x, coords.y, coords.z, GetEntityHeading(entity))
end

function QBCore.Functions.SetPlayerBucket(source, bucket)
    if not source or not bucket then return false end
    SetPlayerRoutingBucket(source, bucket)
    return true
end

function QBCore.Functions.SetEntityBucket(entity, bucket)
    if not entity or not bucket then return false end
    SetEntityRoutingBucket(entity, bucket)
    return true
end

-- Server-side vehicle spawn (OneSync). Returns the network id.
function QBCore.Functions.SpawnVehicle(source, model, coords, warp)
    local ped = GetPlayerPed(source)
    model = type(model) == 'string' and GetHashKey(model) or model
    if not coords then coords = GetEntityCoords(ped) end
    local heading = (type(coords) == 'vector4' and coords.w)
        or (type(coords) == 'table' and (coords.w or coords.h))
        or GetEntityHeading(ped)
    local vehicle = CreateVehicle(model, coords.x, coords.y, coords.z, heading, true, true)
    local timeout = GetGameTimer() + 5000
    while not DoesEntityExist(vehicle) and GetGameTimer() < timeout do Wait(0) end
    if not DoesEntityExist(vehicle) then return nil end
    if warp then
        while GetVehiclePedIsIn(ped, false) ~= vehicle and GetGameTimer() < timeout do
            TaskWarpPedIntoVehicle(ped, vehicle, -1)
            Wait(50)
        end
    end
    return NetworkGetNetworkIdFromEntity(vehicle)
end
QBCore.Functions.CreateVehicle = QBCore.Functions.SpawnVehicle

-- Items -------------------------------------------------------------------------

function QBCore.Functions.CreateUseableItem(item, cb) Nova.CreateUseableItem(item, cb) end
function QBCore.Functions.CanUseItem(item) return Nova.CanUseItem(item) end

function QBCore.Functions.UseItem(source, item)
    local name = type(item) == 'table' and item.name or item
    local cb = Nova.CanUseItem(name)
    if cb then cb(source, item) end
end

function QBCore.Functions.HasItem(source, items, amount)
    return Inventory.HasItem(source, items, amount)
end

-- Jobs / gangs ------------------------------------------------------------------

function QBCore.Functions.AddJob(name, job) return Nova.AddJob(name, job) end
function QBCore.Functions.AddGang(name, gang) return Nova.AddGang(name, gang) end

function QBCore.Functions.AddJobs(jobs)
    for name, job in pairs(jobs) do
        local ok, err = Nova.AddJob(name, job)
        if not ok then return false, err, name end
    end
    return true, 'success'
end

function QBCore.Functions.AddGangs(gangs)
    for name, gang in pairs(gangs) do
        local ok, err = Nova.AddGang(name, gang)
        if not ok then return false, err, name end
    end
    return true, 'success'
end

-- Callbacks (qb protocol) ---------------------------------------------------------

function QBCore.Functions.CreateCallback(name, cb)
    QBCore.ServerCallbacks[name] = cb
end

RegisterNetEvent('QBCore:Server:TriggerCallback', function(name, ...)
    local src = source
    local cb = QBCore.ServerCallbacks[name]
    if not cb then return end
    cb(src, function(...)
        TriggerClientEvent('QBCore:Client:TriggerCallback', src, name, ...)
    end, ...)
end)

-- Commands ------------------------------------------------------------------------

function QBCore.Commands.Add(name, help, arguments, argsrequired, callback, permission)
    local restricted
    if type(permission) == 'table' then
        restricted = {}
        for i, perm in ipairs(permission) do restricted[i] = 'group.' .. perm end
    elseif permission and permission ~= 'user' then
        restricted = 'group.' .. permission
    end

    arguments = arguments or {}
    QBCore.Commands.List[name:lower()] = {
        name = name:lower(), help = help, arguments = arguments,
        argsrequired = argsrequired, permission = permission,
    }

    lib.addCommand(name, { help = help, restricted = restricted }, function(source, args, raw)
        if argsrequired and #args < #arguments then
            return Nova.Notify(source, 'All arguments must be filled out.', 'error')
        end
        callback(source, args, raw)
    end)
end

function QBCore.Commands.Refresh() end

-- Player lifecycle ------------------------------------------------------------------

function QBCore.Player.Login(source, citizenid, newData) return Nova.Login(source, citizenid, newData) end
function QBCore.Player.Logout(source) return Nova.Logout(source) end
function QBCore.Player.Save(source) return Nova.SavePlayer(source) end

-- Core object -----------------------------------------------------------------------

local function buildCore()
    QBCore.Players = Nova.Players
    QBCore.UsableItems = Nova.UsableItems
    QBCore.Shared.Jobs = toQbGroups(Nova.Jobs)
    QBCore.Shared.Gangs = toQbGroups(Nova.Gangs)
    QBCore.Shared.Vehicles = Shared.Vehicles
    QBCore.Shared.Items = getItems()
    return QBCore
end

exports('GetCoreObject', buildCore)
AddEventHandler('QBCore:GetObject', function(cb) cb(buildCore()) end)

-- Event translation (Nova -> QBCore names) ------------------------------------------

AddEventHandler('nova:server:playerLoaded', function(src)
    local player = Nova.Players[src]
    if player then TriggerEvent('QBCore:Server:PlayerLoaded', player) end
end)

AddEventHandler('nova:server:onPlayerUnload', function(src)
    TriggerEvent('QBCore:Server:OnPlayerUnload', src)
end)

AddEventHandler('nova:server:onJobUpdate', function(src, job)
    TriggerEvent('QBCore:Server:OnJobUpdate', src, job)
end)

AddEventHandler('nova:server:onGangUpdate', function(src, gang)
    TriggerEvent('QBCore:Server:OnGangUpdate', src, gang)
end)

AddEventHandler('nova:server:onDutyUpdate', function(src, onDuty)
    TriggerEvent('QBCore:Server:SetDuty', src, onDuty)
end)

AddEventHandler('nova:server:onMoneyChange', function(src, account, amount, action, reason)
    TriggerEvent('QBCore:Server:OnMoneyChange', src, account, amount, action, reason)
end)

AddEventHandler('nova:server:onMetaDataChange', function(src, key, value, old)
    TriggerEvent('QBCore:Server:OnMetaDataChange', src, key, value, old)
end)

-- Legacy net events that qb scripts fire -----------------------------------------------

RegisterNetEvent('QBCore:ToggleDuty', function()
    local player = Nova.Players[source]
    if player then player.Functions.SetJobDuty(not player.PlayerData.job.onduty) end
end)

-- Used by ox_inventory (qb mode) when eating / drinking. These events are
-- client-triggered, as in qb-smallresources, so values are clamped to 0-100.
RegisterNetEvent('consumables:server:addHunger', function(amount)
    local player = Nova.Players[source]
    if player then player.Functions.SetMetaData('hunger', amount) end
end)

RegisterNetEvent('consumables:server:addThirst', function(amount)
    local player = Nova.Players[source]
    if player then player.Functions.SetMetaData('thirst', amount) end
end)

RegisterNetEvent('hud:server:GainStress', function(amount)
    local player = Nova.Players[source]
    amount = tonumber(amount)
    if not player or not amount or amount <= 0 then return end
    player.Functions.SetMetaData('stress', (player.PlayerData.metadata.stress or 0) + math.min(amount, 20))
end)

RegisterNetEvent('hud:server:RelieveStress', function(amount)
    local player = Nova.Players[source]
    amount = tonumber(amount)
    if not player or not amount or amount <= 0 then return end
    player.Functions.SetMetaData('stress', (player.PlayerData.metadata.stress or 0) - amount)
end)
