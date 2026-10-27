--[[
    qb-core compatibility bridge (client)
]]

local QBCore = {}

local function toQbGroups(groups)
    local out = {}
    for name, data in pairs(groups) do
        local copy = Utils.DeepCopy(data)
        local grades = {}
        for level, grade in pairs(data.grades or {}) do grades[tostring(level)] = Utils.DeepCopy(grade) end
        copy.grades = grades
        out[name] = copy
    end
    return out
end

local function getItems()
    local items = {}
    local ok, defs = pcall(Nova.GetItems)
    if not ok or type(defs) ~= 'table' then return items end
    for name, item in pairs(defs) do
        items[name] = {
            name = name,
            label = item.label,
            weight = item.weight or 0,
            type = item.weapon and 'weapon' or 'item',
            image = item.image or (name .. '.png'),
            unique = item.stack == false,
            useable = true,
            shouldClose = true,
            description = item.description,
        }
    end
    return items
end

QBCore.Config = {
    Server = { Name = Config.ServerName },
    Money = { MoneyTypes = Config.Money.types },
    DefaultSpawn = Config.DefaultSpawn,
}

QBCore.Shared = {
    Round = Utils.Round,
    RandomStr = Utils.RandomLetters,
    RandomInt = Utils.RandomNumbers,
    SplitStr = Utils.SplitStr,
    Trim = Utils.Trim,
    FirstToUpper = Utils.FirstToUpper,
}

QBCore.Functions = {}
QBCore.ServerCallbacks = {}

-- Player data ---------------------------------------------------------------

function QBCore.Functions.GetPlayerData(cb)
    if cb then return cb(Nova.PlayerData) end
    return Nova.PlayerData
end

function QBCore.Functions.HasItem(items, amount)
    return Nova.HasItem(items, amount)
end

-- Callbacks -------------------------------------------------------------------

function QBCore.Functions.TriggerCallback(name, cb, ...)
    QBCore.ServerCallbacks[name] = cb
    TriggerServerEvent('QBCore:Server:TriggerCallback', name, ...)
end

RegisterNetEvent('QBCore:Client:TriggerCallback', function(name, ...)
    local cb = QBCore.ServerCallbacks[name]
    if cb then
        QBCore.ServerCallbacks[name] = nil
        cb(...)
    end
end)

-- UI ----------------------------------------------------------------------------

function QBCore.Functions.Notify(text, notifType, length)
    local title, description = nil, text
    if type(text) == 'table' then title, description = text.caption, text.text end
    Nova.Notify(description, notifType, length, title)
end

function QBCore.Functions.Progressbar(_, label, duration, useWhileDead, canCancel, disableControls,
                                     animation, prop, propTwo, onFinish, onCancel)
    disableControls = disableControls or {}

    local anim
    if animation then
        if animation.task then
            anim = { scenario = animation.task }
        elseif animation.animDict then
            anim = { dict = animation.animDict, clip = animation.anim, flag = animation.flags or 49 }
        end
    end

    local function toProp(p)
        if not p or not p.model then return nil end
        local c, r = p.coords or {}, p.rotation or {}
        return {
            model = p.model,
            bone = p.bone,
            pos = vec3(c.x or 0.0, c.y or 0.0, c.z or 0.0),
            rot = vec3(r.x or 0.0, r.y or 0.0, r.z or 0.0),
        }
    end

    local props = {}
    props[#props + 1] = toProp(prop)
    props[#props + 1] = toProp(propTwo)

    CreateThread(function()
        local completed = lib.progressBar({
            duration = duration,
            label = label,
            useWhileDead = useWhileDead,
            canCancel = canCancel,
            disable = {
                move = disableControls.disableMovement,
                car = disableControls.disableCarMovement,
                combat = disableControls.disableCombat,
                mouse = disableControls.disableMouse,
            },
            anim = anim,
            prop = #props > 0 and props or nil,
        })
        if completed then
            if onFinish then onFinish() end
        elseif onCancel then
            onCancel()
        end
    end)
end

function QBCore.Functions.DrawText3D(x, y, z, text)
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(true)
    SetTextColour(255, 255, 255, 215)
    BeginTextCommandDisplayText('STRING')
    SetTextCentre(true)
    AddTextComponentSubstringPlayerName(text)
    SetDrawOrigin(x, y, z, 0)
    EndTextCommandDisplayText(0.0, 0.0)
    local factor = #text / 370
    DrawRect(0.0, 0.0125, 0.017 + factor, 0.03, 0, 0, 0, 75)
    ClearDrawOrigin()
end

function QBCore.Functions.DrawText(x, y, width, height, scale, r, g, b, a, text)
    SetTextFont(4)
    SetTextScale(scale, scale)
    SetTextColour(r, g, b, a)
    SetTextDropshadow(0, 0, 0, 0, 255)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(x - width / 2, y - height / 2 + 0.005)
end

-- World helpers -------------------------------------------------------------------

local function toVec3(coords)
    if not coords then return GetEntityCoords(cache.ped) end
    return vec3(coords.x, coords.y, coords.z)
end

function QBCore.Functions.GetCoords(entity)
    local c = GetEntityCoords(entity)
    return vec4(c.x, c.y, c.z, GetEntityHeading(entity))
end

function QBCore.Functions.GetClosestPlayer(coords)
    coords = toVec3(coords)
    local player, _, playerCoords = lib.getClosestPlayer(coords, 50.0, false)
    if not player then return -1, -1 end
    return player, #(coords - playerCoords)
end

function QBCore.Functions.GetPlayersFromCoords(coords, distance)
    local list = {}
    for _, entry in ipairs(lib.getNearbyPlayers(toVec3(coords), distance or 5.0, true)) do
        list[#list + 1] = entry.id
    end
    return list
end

function QBCore.Functions.GetClosestVehicle(coords)
    coords = toVec3(coords)
    local vehicle, vehicleCoords = lib.getClosestVehicle(coords, 50.0, true)
    if not vehicle then return -1, -1 end
    return vehicle, #(coords - vehicleCoords)
end

function QBCore.Functions.GetVehicleProperties(vehicle) return lib.getVehicleProperties(vehicle) end
function QBCore.Functions.SetVehicleProperties(vehicle, props) return lib.setVehicleProperties(vehicle, props) end
function QBCore.Functions.GetPlate(vehicle) return Nova.GetPlate(vehicle) end
function QBCore.Functions.DeleteVehicle(vehicle) Nova.DeleteVehicle(vehicle) end

function QBCore.Functions.SpawnVehicle(model, cb, coords, isNetworked, teleportInto)
    local ped = cache.ped
    local heading
    if type(coords) == 'vector4' then
        heading = coords.w
    elseif type(coords) == 'table' then
        heading = coords.w or coords.h
    end
    coords = toVec3(coords)
    heading = heading or GetEntityHeading(ped)

    local vehicle = Nova.SpawnVehicle(model, coords, heading, isNetworked ~= false)
    if not vehicle then return end
    SetVehicleFuelLevel(vehicle, 100.0)
    if teleportInto then TaskWarpPedIntoVehicle(ped, vehicle, -1) end
    if cb then cb(vehicle) end
end

function QBCore.Functions.RequestAnimDict(dict) return lib.requestAnimDict(dict) end
function QBCore.Functions.LoadModel(model) return lib.requestModel(model) end

function QBCore.Functions.PlayAnim(dict, anim, blendIn, flag)
    lib.requestAnimDict(dict)
    TaskPlayAnim(cache.ped, dict, anim, blendIn or 8.0, 8.0, -1, flag or 0, 0.0, false, false, false)
    RemoveAnimDict(dict)
end

function QBCore.Functions.Debug(...) print(json.encode({ ... }, { indent = true })) end

-- Core object -----------------------------------------------------------------------

local function buildCore()
    QBCore.PlayerData = Nova.PlayerData
    QBCore.Shared.Jobs = toQbGroups(Shared.Jobs)
    QBCore.Shared.Gangs = toQbGroups(Shared.Gangs)
    QBCore.Shared.Vehicles = Shared.Vehicles
    QBCore.Shared.Items = getItems()
    return QBCore
end

exports('GetCoreObject', buildCore)
AddEventHandler('QBCore:GetObject', function(cb) cb(buildCore()) end)

-- Event translation (Nova -> QBCore names) --------------------------------------------

RegisterNetEvent('nova:client:onPlayerLoaded', function()
    TriggerEvent('QBCore:Client:OnPlayerLoaded')
end)

RegisterNetEvent('nova:client:onPlayerUnload', function()
    TriggerEvent('QBCore:Client:OnPlayerUnload')
end)

AddEventHandler('nova:client:playerDataUpdated', function(data)
    TriggerEvent('QBCore:Player:SetPlayerData', data)
end)

RegisterNetEvent('nova:client:onJobUpdate', function(job)
    TriggerEvent('QBCore:Client:OnJobUpdate', job)
end)

RegisterNetEvent('nova:client:onGangUpdate', function(gang)
    TriggerEvent('QBCore:Client:OnGangUpdate', gang)
end)

RegisterNetEvent('nova:client:onDutyUpdate', function(onDuty)
    TriggerEvent('QBCore:Client:SetDuty', onDuty)
end)

RegisterNetEvent('nova:client:onMoneyChange', function(account, amount, action, reason)
    TriggerEvent('hud:client:OnMoneyChange', account, amount, action == 'remove', reason)
end)

-- Many qb server scripts send this directly
RegisterNetEvent('QBCore:Notify', function(text, notifType, length)
    QBCore.Functions.Notify(text, notifType, length)
end)
