-- All database access lives here so the rest of the core never writes SQL.
Storage = {}

local function decode(value, fallback)
    if type(value) ~= 'string' or value == '' then return fallback end
    local ok, result = pcall(json.decode, value)
    if ok and result ~= nil then return result end
    return fallback
end
Storage.Decode = decode

local jsonColumns = { 'money', 'charinfo', 'job', 'gang', 'position', 'metadata' }

local function decodeRow(row)
    if not row then return nil end
    for i = 1, #jsonColumns do
        local column = jsonColumns[i]
        if row[column] ~= nil then row[column] = decode(row[column], nil) end
    end
    return row
end

-- Characters ---------------------------------------------------------------

function Storage.FetchCharacters(license)
    local rows = MySQL.query.await(
        'SELECT citizenid, cid, charinfo, money, job, gang FROM players WHERE license = ? ORDER BY cid ASC',
        { license }) or {}
    for i = 1, #rows do decodeRow(rows[i]) end
    return rows
end

function Storage.FetchCharacter(citizenid, license)
    return decodeRow(MySQL.single.await(
        'SELECT citizenid, cid, license, money, charinfo, job, gang, position, metadata FROM players WHERE citizenid = ? AND license = ? LIMIT 1',
        { citizenid, license }))
end

function Storage.FetchCharacterByCitizenId(citizenid)
    return decodeRow(MySQL.single.await(
        'SELECT citizenid, cid, license, name, money, charinfo, job, gang, position, metadata FROM players WHERE citizenid = ? LIMIT 1',
        { citizenid }))
end

function Storage.CitizenIdExists(citizenid)
    return MySQL.scalar.await('SELECT 1 FROM players WHERE citizenid = ? LIMIT 1', { citizenid }) ~= nil
end

function Storage.PhoneExists(phone)
    return MySQL.scalar.await(
        "SELECT 1 FROM players WHERE JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.phone')) = ? LIMIT 1",
        { phone }) ~= nil
end

local SAVE_QUERY = [[
INSERT INTO players (citizenid, cid, license, name, money, charinfo, job, gang, position, metadata)
VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
ON DUPLICATE KEY UPDATE
    cid = VALUES(cid),
    name = VALUES(name),
    money = VALUES(money),
    charinfo = VALUES(charinfo),
    job = VALUES(job),
    gang = VALUES(gang),
    position = VALUES(position),
    metadata = VALUES(metadata)
]]

-- Inventory is intentionally not saved here: ox_inventory owns players.inventory.
function Storage.SavePlayer(pd)
    MySQL.query.await(SAVE_QUERY, {
        pd.citizenid, pd.cid, pd.license, pd.name,
        json.encode(pd.money), json.encode(pd.charinfo),
        json.encode(pd.job), json.encode(pd.gang),
        json.encode(pd.position), json.encode(pd.metadata),
    })
end

function Storage.SetLastLoggedOut(citizenid)
    MySQL.update('UPDATE players SET last_logged_out = NOW() WHERE citizenid = ?', { citizenid })
end

local tableExistsCache = {}
local function tableExists(name)
    if tableExistsCache[name] == nil then
        tableExistsCache[name] = MySQL.scalar.await(
            'SELECT 1 FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = ? LIMIT 1',
            { name }) ~= nil
    end
    return tableExistsCache[name]
end

function Storage.DeleteCharacter(citizenid)
    for _, entry in ipairs(ServerConfig.DeleteTables) do
        if tableExists(entry.table) then
            MySQL.query.await(('DELETE FROM `%s` WHERE `%s` = ?'):format(entry.table, entry.column), { citizenid })
        end
    end
    MySQL.query.await('DELETE FROM players WHERE citizenid = ?', { citizenid })
end

-- Bans ---------------------------------------------------------------------

function Storage.FetchActiveBan(license, discord, ip)
    return MySQL.single.await([[
        SELECT * FROM bans
        WHERE (license = ? OR (discord IS NOT NULL AND discord = ?) OR (ip IS NOT NULL AND ip = ?))
          AND expire > ?
        ORDER BY expire DESC LIMIT 1
    ]], { license or '', discord or '', ip or '', os.time() })
end

function Storage.InsertBan(ban)
    return MySQL.insert.await(
        'INSERT INTO bans (name, license, discord, ip, reason, expire, bannedby) VALUES (?, ?, ?, ?, ?, ?, ?)',
        { ban.name, ban.license, ban.discord, ban.ip, ban.reason, ban.expire, ban.bannedby })
end

function Storage.DeleteBan(id)
    return (MySQL.update.await('DELETE FROM bans WHERE id = ?', { id }) or 0) > 0
end
