Utils = {}

local letters, alnum = {}, {}
for i = 65, 90 do letters[#letters + 1] = string.char(i) end
for i = 48, 57 do alnum[#alnum + 1] = string.char(i) end
for i = 65, 90 do alnum[#alnum + 1] = string.char(i) end

function Utils.RandomLetters(length)
    local out = {}
    for i = 1, length do out[i] = letters[math.random(#letters)] end
    return table.concat(out)
end

function Utils.RandomNumbers(length)
    local out = {}
    for i = 1, length do out[i] = tostring(math.random(0, 9)) end
    return table.concat(out)
end

function Utils.RandomAlnum(length)
    local out = {}
    for i = 1, length do out[i] = alnum[math.random(#alnum)] end
    return table.concat(out)
end

function Utils.Trim(value)
    if type(value) ~= 'string' then return value end
    return (value:gsub('^%s*(.-)%s*$', '%1'))
end

function Utils.Round(value, decimals)
    local mult = 10 ^ (decimals or 0)
    return math.floor(value * mult + 0.5) / mult
end

function Utils.FirstToUpper(value)
    if type(value) ~= 'string' then return value end
    return (value:gsub('^%l', string.upper))
end

function Utils.SplitStr(str, delimiter)
    local result = {}
    local escaped = delimiter:gsub('%p', '%%%0')
    for part in (str .. delimiter):gmatch('(.-)' .. escaped) do
        result[#result + 1] = part
    end
    return result
end

function Utils.Clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

function Utils.DeepCopy(value)
    if type(value) ~= 'table' then return value end
    local copy = {}
    for k, v in pairs(value) do copy[k] = Utils.DeepCopy(v) end
    return copy
end

-- Maps qb-style notification types onto ox_lib types
local notifyTypes = {
    primary = 'inform', info = 'inform', inform = 'inform', police = 'inform', ambulance = 'inform',
    success = 'success', error = 'error', warning = 'warning',
}

function Utils.NotifyType(value)
    return notifyTypes[value or 'inform'] or 'inform'
end
