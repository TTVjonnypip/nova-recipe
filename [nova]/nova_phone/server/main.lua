-- Nova Phone - server
local Calls = {}   -- callId -> { caller = src, target = src, answered = bool }
local InCall = {}  -- src -> callId

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local core = exports.nova_core

-- Full player object (PlayerData + Functions). Use only when changing money etc.
local function getPlayer(src)
    return core:GetPlayer(src)
end

-- PlayerData only: much cheaper, used for read-only lookups
local function getData(src)
    return core:GetPlayerData(src)
end

local function getNumber(src)
    local pd = getData(src)
    return pd and pd.charinfo.phone
end

local function getCid(src)
    local pd = getData(src)
    return pd and pd.citizenid
end

local function getName(src)
    local pd = getData(src)
    if not pd then return 'Unknown' end
    local c = pd.charinfo
    return ('%s %s'):format(c.firstname, c.lastname)
end

local function getSrcByNumber(number)
    if not number then return nil end
    local p = core:GetPlayerByPhone(number)
    return p and p.PlayerData.source
end

local function getSrcByCid(cid)
    local p = core:GetPlayerByCitizenId(cid)
    return p and p.PlayerData.source
end

-- trims and length-limits any string coming from the UI
local function clean(str, max)
    if type(str) ~= 'string' and type(str) ~= 'number' then return nil end
    str = tostring(str):gsub('^%s+', ''):gsub('%s+$', '')
    if str == '' then return nil end
    if max and #str > max then str = str:sub(1, max) end
    return str
end

local function push(src, kind, data)
    TriggerClientEvent('nova_phone:client:push', src, kind, data)
end

local function bankLog(cid, label, amount)
    MySQL.insert('INSERT INTO phone_bank_log (citizenid, label, amount) VALUES (?, ?, ?)', { cid, label, amount })
end

-- tiny per-player rate limit for spammy actions
local lastAction = {}
local function throttled(src, key, ms)
    local now = GetGameTimer()
    lastAction[src] = lastAction[src] or {}
    if lastAction[src][key] and now - lastAction[src][key] < ms then return true end
    lastAction[src][key] = now
    return false
end

local function cb(name, fn)
    lib.callback.register('nova_phone:server:' .. name, function(src, data)
        if not core:IsPlayerLoaded(src) then return { ok = false, msg = 'Character not loaded on server' } end
        local ok, result = pcall(fn, src, type(data) == 'table' and data or {})
        if not ok then
            print(('^1[nova_phone] %s failed: %s^7'):format(name, tostring(result)))
            return { ok = false, msg = 'Server error in ' .. name .. ' (see server console)' }
        end
        return result
    end)
end

-- Startup check: warn loudly if the SQL file was never imported
CreateThread(function()
    local needed = { 'phone_contacts', 'phone_messages', 'phone_calls', 'phone_bank_log', 'phone_chirps',
        'phone_chirp_likes', 'phone_ads', 'phone_mail', 'phone_notes', 'phone_settings' }
    local rows = MySQL.query.await('SELECT table_name AS t FROM information_schema.tables WHERE table_schema = DATABASE()') or {}
    local have = {}
    for _, r in ipairs(rows) do have[(r.t or r.TABLE_NAME or ''):lower()] = true end
    local missing = {}
    for _, t in ipairs(needed) do if not have[t] then missing[#missing + 1] = t end end
    if #missing == 0 then return print('^2[nova_phone] Database OK^7') end

    -- Auto-install: run sql/install.sql (every statement is CREATE TABLE IF NOT EXISTS, so it's safe)
    print('^3[nova_phone] Creating missing tables: ' .. table.concat(missing, ', ') .. '^7')
    local sql = LoadResourceFile(GetCurrentResourceName(), 'sql/install.sql')
    if not sql then return print('^1[nova_phone] sql/install.sql not found - import it manually^7') end
    sql = sql:gsub('%-%-[^\n]*', '') -- strip comments
    local failed = false
    for statement in sql:gmatch('[^;]+') do
        if statement:find('%S') then
            local ok, err = pcall(MySQL.query.await, statement)
            if not ok then failed = true print('^1[nova_phone] Table creation failed: ' .. tostring(err) .. '^7') end
        end
    end
    if failed then
        print('^1[nova_phone] Some tables could not be created - import sql/install.sql manually^7')
    else
        print('^2[nova_phone] Database tables created - phone is ready^7')
    end
end)

---------------------------------------------------------------------------
-- Profile & settings
---------------------------------------------------------------------------
cb('getProfile', function(src)
    local p = getPlayer(src)
    local cid = p.PlayerData.citizenid
    local settings = MySQL.single.await('SELECT wallpaper, muted FROM phone_settings WHERE citizenid = ?', { cid })
        or { wallpaper = 'aurora', muted = 0 }
    local contacts = MySQL.query.await('SELECT id, name, number FROM phone_contacts WHERE citizenid = ? ORDER BY name', { cid })
    local unreadMsg = MySQL.scalar.await('SELECT COUNT(*) FROM phone_messages WHERE receiver = ? AND is_read = 0', { p.PlayerData.charinfo.phone })
    local unreadMail = MySQL.scalar.await('SELECT COUNT(*) FROM phone_mail WHERE citizenid = ? AND is_read = 0', { cid })

    local services = {}
    for i, s in ipairs(Config.Services) do services[i] = { job = s.job, label = s.label, icon = s.icon, color = s.color } end

    return {
        ok = true,
        name = getName(src),
        number = p.PlayerData.charinfo.phone,
        citizenid = cid,
        bank = p.PlayerData.money.bank,
        cash = p.PlayerData.money.cash,
        job = p.PlayerData.job.label,
        settings = { wallpaper = settings.wallpaper, muted = settings.muted == 1 or settings.muted == true },
        contacts = contacts,
        badges = { messages = unreadMsg, mail = unreadMail },
        services = services,
        chirpMax = Config.ChirpMaxLength,
        adCost = Config.AdCost,
    }
end)

cb('settingsSave', function(src, data)
    local wallpaper = clean(data.wallpaper, 20) or 'aurora'
    local muted = data.muted and 1 or 0
    MySQL.prepare.await([[INSERT INTO phone_settings (citizenid, wallpaper, muted) VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE wallpaper = VALUES(wallpaper), muted = VALUES(muted)]], { getCid(src), wallpaper, muted })
    return { ok = true }
end)

---------------------------------------------------------------------------
-- Contacts
---------------------------------------------------------------------------
cb('contactsGet', function(src)
    return { ok = true, list = MySQL.query.await('SELECT id, name, number FROM phone_contacts WHERE citizenid = ? ORDER BY name', { getCid(src) }) }
end)

cb('contactsAdd', function(src, data)
    local name, number = clean(data.name, 50), clean(data.number, 20)
    if not name or not number then return { ok = false, msg = 'Name and number required' } end
    local id = MySQL.insert.await('INSERT INTO phone_contacts (citizenid, name, number) VALUES (?, ?, ?)', { getCid(src), name, number })
    return { ok = true, id = id }
end)

cb('contactsDelete', function(src, data)
    MySQL.update.await('DELETE FROM phone_contacts WHERE id = ? AND citizenid = ?', { tonumber(data.id), getCid(src) })
    return { ok = true }
end)

---------------------------------------------------------------------------
-- Messages
---------------------------------------------------------------------------
cb('messagesThreads', function(src)
    local me = getNumber(src)
    local rows = MySQL.query.await([[
        SELECT m.id, m.sender, m.receiver, m.message, UNIX_TIMESTAMP(m.created) AS ts
        FROM phone_messages m
        JOIN (SELECT MAX(id) AS id FROM phone_messages WHERE sender = ? OR receiver = ?
              GROUP BY IF(sender = ?, receiver, sender)) t ON m.id = t.id
        ORDER BY m.id DESC LIMIT 60]], { me, me, me })
    local unread = {}
    for _, r in ipairs(MySQL.query.await('SELECT sender, COUNT(*) AS c FROM phone_messages WHERE receiver = ? AND is_read = 0 GROUP BY sender', { me })) do
        unread[r.sender] = r.c
    end
    local threads = {}
    for i, r in ipairs(rows) do
        local other = r.sender == me and r.receiver or r.sender
        threads[i] = { number = other, last = r.message, ts = r.ts, unread = unread[other] or 0 }
    end
    return { ok = true, list = threads }
end)

cb('messagesGet', function(src, data)
    local me, other = getNumber(src), clean(data.number, 20)
    if not other then return { ok = false } end
    local rows = MySQL.query.await([[
        SELECT id, sender, message, UNIX_TIMESTAMP(created) AS ts FROM phone_messages
        WHERE (sender = ? AND receiver = ?) OR (sender = ? AND receiver = ?)
        ORDER BY id DESC LIMIT 100]], { me, other, other, me })
    MySQL.update('UPDATE phone_messages SET is_read = 1 WHERE receiver = ? AND sender = ?', { me, other })
    local list = {}
    for i = #rows, 1, -1 do
        local r = rows[i]
        list[#list + 1] = { id = r.id, mine = r.sender == me, text = r.message, ts = r.ts }
    end
    return { ok = true, list = list }
end)

cb('messagesSend', function(src, data)
    if throttled(src, 'msg', 750) then return { ok = false, msg = 'Slow down' } end
    local me, to, text = getNumber(src), clean(data.number, 20), clean(data.text, 500)
    if not to or not text then return { ok = false, msg = 'Empty message' } end
    if to == me then return { ok = false, msg = "You can't text yourself" } end
    local id = MySQL.insert.await('INSERT INTO phone_messages (sender, receiver, message) VALUES (?, ?, ?)', { me, to, text })
    local target = getSrcByNumber(to)
    if target then
        push(target, 'message', { id = id, from = me, text = text, ts = os.time() })
    end
    return { ok = true, id = id, ts = os.time() }
end)

---------------------------------------------------------------------------
-- Calls (pma-voice call channels)
---------------------------------------------------------------------------
local function endCall(callId, reason)
    local call = Calls[callId]
    if not call then return end
    Calls[callId] = nil
    for _, s in ipairs({ call.caller, call.target }) do
        if InCall[s] == callId then InCall[s] = nil end
        push(s, 'callEnded', { reason = reason })
    end
end

cb('callStart', function(src, data)
    local me, to = getNumber(src), clean(data.number, 20)
    if not to then return { ok = false, msg = 'Enter a number' } end
    if to == me then return { ok = false, msg = "You can't call yourself" } end
    if InCall[src] then return { ok = false, msg = 'Already in a call' } end

    local target = getSrcByNumber(to)
    if not target then
        MySQL.insert('INSERT INTO phone_calls (caller, receiver, status) VALUES (?, ?, ?)', { me, to, 'missed' })
        return { ok = false, msg = 'The number you dialed is unavailable' }
    end
    if InCall[target] then return { ok = false, msg = 'Line is busy' } end

    local callId
    repeat callId = math.random(10000, 99999) until not Calls[callId]
    Calls[callId] = { caller = src, target = target, answered = false, from = me, to = to }
    InCall[src], InCall[target] = callId, callId

    push(target, 'incomingCall', { number = me })

    SetTimeout(Config.RingTime * 1000, function()
        local c = Calls[callId]
        if c and not c.answered then
            MySQL.insert('INSERT INTO phone_calls (caller, receiver, status) VALUES (?, ?, ?)', { me, to, 'missed' })
            endCall(callId, 'No answer')
        end
    end)
    return { ok = true }
end)

cb('callAccept', function(src)
    local callId = InCall[src]
    local call = callId and Calls[callId]
    if not call or call.target ~= src or call.answered then return { ok = false } end
    call.answered = true
    MySQL.insert('INSERT INTO phone_calls (caller, receiver, status) VALUES (?, ?, ?)', { call.from, call.to, 'answered' })
    for _, s in ipairs({ call.caller, call.target }) do
        TriggerClientEvent('nova_phone:client:joinCall', s, callId)
        push(s, 'callAccepted', {})
    end
    return { ok = true }
end)

cb('callEnd', function(src)
    local callId = InCall[src]
    local call = callId and Calls[callId]
    if call and not call.answered then
        MySQL.insert('INSERT INTO phone_calls (caller, receiver, status) VALUES (?, ?, ?)',
            { call.from, call.to, call.target == src and 'declined' or 'missed' })
    end
    if callId then endCall(callId, 'Call ended') end
    return { ok = true }
end)

cb('callHistory', function(src)
    local me = getNumber(src)
    local rows = MySQL.query.await([[SELECT caller, receiver, status, UNIX_TIMESTAMP(created) AS ts FROM phone_calls
        WHERE caller = ? OR receiver = ? ORDER BY id DESC LIMIT 40]], { me, me })
    local list = {}
    for i, r in ipairs(rows) do
        local outgoing = r.caller == me
        list[i] = { number = outgoing and r.receiver or r.caller, outgoing = outgoing, status = r.status, ts = r.ts }
    end
    return { ok = true, list = list }
end)

---------------------------------------------------------------------------
-- Bank
---------------------------------------------------------------------------
cb('bankGet', function(src)
    local p = getPlayer(src)
    local log = MySQL.query.await('SELECT label, amount, UNIX_TIMESTAMP(created) AS ts FROM phone_bank_log WHERE citizenid = ? ORDER BY id DESC LIMIT 25',
        { p.PlayerData.citizenid })
    return { ok = true, bank = p.PlayerData.money.bank, cash = p.PlayerData.money.cash, log = log }
end)

cb('bankTransfer', function(src, data)
    if throttled(src, 'bank', 2000) then return { ok = false, msg = 'Please wait a moment' } end
    local amount = math.floor(tonumber(data.amount) or 0)
    if amount <= 0 then return { ok = false, msg = 'Invalid amount' } end
    if amount > Config.MaxTransfer then return { ok = false, msg = 'Amount exceeds transfer limit' } end

    local target = getSrcByNumber(clean(data.number, 20))
    if not target then return { ok = false, msg = 'Recipient is not reachable right now' } end
    if target == src then return { ok = false, msg = "You can't send money to yourself" } end

    local sender, receiver = getPlayer(src), getPlayer(target)
    local fee = math.floor(amount * (Config.TransferFee / 100))
    if sender.PlayerData.money.bank < amount + fee then return { ok = false, msg = 'Insufficient funds' } end
    if not sender.Functions.RemoveMoney('bank', amount + fee, 'phone-transfer') then
        return { ok = false, msg = 'Transfer failed' }
    end
    receiver.Functions.AddMoney('bank', amount, 'phone-transfer')

    bankLog(sender.PlayerData.citizenid, 'Transfer to ' .. getName(target), -(amount + fee))
    bankLog(receiver.PlayerData.citizenid, 'Transfer from ' .. getName(src), amount)
    push(target, 'bank', { text = ('You received $%s from %s'):format(amount, getName(src)) })
    -- PlayerData from GetPlayer is a snapshot, so read the new balance fresh
    return { ok = true, bank = core:GetMoney(src, 'bank') }
end)

---------------------------------------------------------------------------
-- Chirp (social feed)
---------------------------------------------------------------------------
cb('chirpGet', function(src)
    local cid = getCid(src)
    local rows = MySQL.query.await([[
        SELECT c.id, c.author, c.handle, c.content, c.likes, UNIX_TIMESTAMP(c.created) AS ts,
               (l.citizenid IS NOT NULL) AS liked, (c.citizenid = ?) AS mine
        FROM phone_chirps c LEFT JOIN phone_chirp_likes l ON l.chirp_id = c.id AND l.citizenid = ?
        ORDER BY c.id DESC LIMIT ?]], { cid, cid, Config.ChirpFeedSize })
    return { ok = true, list = rows }
end)

cb('chirpPost', function(src, data)
    if throttled(src, 'chirp', 10000) then return { ok = false, msg = 'You can post again in a few seconds' } end
    local text = clean(data.text, Config.ChirpMaxLength)
    if not text then return { ok = false, msg = 'Write something first' } end
    local p = getPlayer(src)
    local c = p.PlayerData.charinfo
    local handle = ('@%s_%s'):format(c.firstname, c.lastname):lower():gsub('[^%w_@]', '')
    local id = MySQL.insert.await('INSERT INTO phone_chirps (citizenid, author, handle, content) VALUES (?, ?, ?, ?)',
        { p.PlayerData.citizenid, getName(src), handle, text })
    local post = { id = id, author = getName(src), handle = handle, content = text }
    for _, other in ipairs(GetPlayers()) do
        local o = tonumber(other)
        if o ~= src then push(o, 'chirp', post) end
    end
    return { ok = true }
end)

cb('chirpLike', function(src, data)
    local id, cid = tonumber(data.id), getCid(src)
    if not id then return { ok = false } end
    local inserted = MySQL.insert.await('INSERT IGNORE INTO phone_chirp_likes (chirp_id, citizenid) VALUES (?, ?)', { id, cid })
    local liked = true
    if not inserted or inserted == 0 then
        -- already liked -> unlike
        MySQL.update.await('DELETE FROM phone_chirp_likes WHERE chirp_id = ? AND citizenid = ?', { id, cid })
        liked = false
    end
    MySQL.update.await('UPDATE phone_chirps SET likes = (SELECT COUNT(*) FROM phone_chirp_likes WHERE chirp_id = ?) WHERE id = ?', { id, id })
    local likes = MySQL.scalar.await('SELECT likes FROM phone_chirps WHERE id = ?', { id })
    return { ok = true, liked = liked, likes = likes }
end)

cb('chirpDelete', function(src, data)
    MySQL.update.await('DELETE FROM phone_chirps WHERE id = ? AND citizenid = ?', { tonumber(data.id), getCid(src) })
    return { ok = true }
end)

---------------------------------------------------------------------------
-- Yellow Pages (ads)
---------------------------------------------------------------------------
cb('adsGet', function(src)
    local rows = MySQL.query.await([[SELECT id, author, number, title, body, price, UNIX_TIMESTAMP(created) AS ts, (citizenid = ?) AS mine
        FROM phone_ads WHERE created > NOW() - INTERVAL ? HOUR ORDER BY id DESC LIMIT 60]], { getCid(src), Config.AdLifetimeHours })
    return { ok = true, list = rows }
end)

cb('adsPost', function(src, data)
    if throttled(src, 'ad', 15000) then return { ok = false, msg = 'Wait before posting another ad' } end
    local title, body = clean(data.title, 80), clean(data.body, 500)
    if not title or not body then return { ok = false, msg = 'Title and description required' } end
    local price = tonumber(data.price)
    price = price and math.max(0, math.floor(price)) or nil
    local p = getPlayer(src)
    if Config.AdCost > 0 then
        if p.PlayerData.money.bank < Config.AdCost or not p.Functions.RemoveMoney('bank', Config.AdCost, 'phone-ad') then
            return { ok = false, msg = ('Posting costs $%s'):format(Config.AdCost) }
        end
        bankLog(p.PlayerData.citizenid, 'Yellow Pages ad', -Config.AdCost)
    end
    MySQL.insert.await('INSERT INTO phone_ads (citizenid, author, number, title, body, price) VALUES (?, ?, ?, ?, ?, ?)',
        { p.PlayerData.citizenid, getName(src), p.PlayerData.charinfo.phone, title, body, price })
    return { ok = true }
end)

cb('adsDelete', function(src, data)
    MySQL.update.await('DELETE FROM phone_ads WHERE id = ? AND citizenid = ?', { tonumber(data.id), getCid(src) })
    return { ok = true }
end)

---------------------------------------------------------------------------
-- Mail
---------------------------------------------------------------------------
cb('mailGet', function(src)
    return { ok = true, list = MySQL.query.await([[SELECT id, sender, subject, body, is_read, UNIX_TIMESTAMP(created) AS ts
        FROM phone_mail WHERE citizenid = ? ORDER BY id DESC LIMIT 50]], { getCid(src) }) }
end)

cb('mailRead', function(src, data)
    MySQL.update('UPDATE phone_mail SET is_read = 1 WHERE id = ? AND citizenid = ?', { tonumber(data.id), getCid(src) })
    return { ok = true }
end)

cb('mailDelete', function(src, data)
    MySQL.update.await('DELETE FROM phone_mail WHERE id = ? AND citizenid = ?', { tonumber(data.id), getCid(src) })
    return { ok = true }
end)

--- Send mail from any resource:
--- exports.nova_phone:SendMail(citizenid, 'Sender', 'Subject', 'Body text')
local function SendMail(cid, sender, subject, body)
    if not cid then return end
    MySQL.insert('INSERT INTO phone_mail (citizenid, sender, subject, body) VALUES (?, ?, ?, ?)',
        { cid, sender or 'Unknown', subject or '(no subject)', body or '' }, function(id)
            local src = getSrcByCid(cid)
            if src then push(src, 'mail', { id = id, sender = sender, subject = subject }) end
        end)
end
exports('SendMail', SendMail)

---------------------------------------------------------------------------
-- Notes
---------------------------------------------------------------------------
cb('notesGet', function(src)
    return { ok = true, list = MySQL.query.await('SELECT id, title, body, UNIX_TIMESTAMP(updated) AS ts FROM phone_notes WHERE citizenid = ? ORDER BY updated DESC', { getCid(src) }) }
end)

cb('notesSave', function(src, data)
    local title = clean(data.title, 80) or 'Untitled'
    local body = type(data.body) == 'string' and data.body:sub(1, 5000) or ''
    local id = tonumber(data.id)
    if id then
        MySQL.update.await('UPDATE phone_notes SET title = ?, body = ? WHERE id = ? AND citizenid = ?', { title, body, id, getCid(src) })
    else
        id = MySQL.insert.await('INSERT INTO phone_notes (citizenid, title, body) VALUES (?, ?, ?)', { getCid(src), title, body })
    end
    return { ok = true, id = id }
end)

cb('notesDelete', function(src, data)
    MySQL.update.await('DELETE FROM phone_notes WHERE id = ? AND citizenid = ?', { tonumber(data.id), getCid(src) })
    return { ok = true }
end)

---------------------------------------------------------------------------
-- Garage
---------------------------------------------------------------------------
cb('garageGet', function(src)
    local rows = MySQL.query.await('SELECT vehicle, plate, state, garage, fuel, engine, body FROM player_vehicles WHERE citizenid = ?', { getCid(src) })
    for _, v in ipairs(rows) do
        local st = Config.VehicleStates[tonumber(v.state) or 1] or { label = 'Unknown', color = '#8e8e93' }
        v.stateLabel, v.stateColor = st.label, st.color
    end
    return { ok = true, list = rows }
end)

---------------------------------------------------------------------------
-- Services / dispatch
---------------------------------------------------------------------------
cb('servicesSend', function(src, data)
    if throttled(src, 'service', 20000) then return { ok = false, msg = 'Please wait before sending another alert' } end
    local job, text = clean(data.job, 30), clean(data.text, 300)
    if not job or not text then return { ok = false, msg = 'Describe your situation' } end

    local service
    for _, s in ipairs(Config.Services) do if s.job == job then service = s break end end
    if not service then return { ok = false, msg = 'Unknown service' } end

    local coords = data.shareLocation and GetEntityCoords(GetPlayerPed(src)) or nil
    local alert = {
        service = service.label, text = text, number = getNumber(src), name = getName(src),
        coords = coords and { x = coords.x, y = coords.y, z = coords.z } or nil,
    }

    local count = 0
    for _, s in ipairs(core:GetPlayerSources()) do
        local pd = getData(s)
        if pd and pd.job.name == job and pd.job.onduty then
            push(s, 'dispatch', alert)
            count = count + 1
        end
    end
    if count == 0 then return { ok = false, msg = ('No %s units are available right now'):format(service.label) } end
    return { ok = true, msg = ('Alert sent to %d %s unit(s)'):format(count, service.label) }
end)

---------------------------------------------------------------------------
-- Cleanup
---------------------------------------------------------------------------
AddEventHandler('playerDropped', function()
    local src = source
    if InCall[src] then endCall(InCall[src], 'Call dropped') end
    lastAction[src] = nil
end)

---------------------------------------------------------------------------
-- Using the phone item from the inventory opens the phone
---------------------------------------------------------------------------
core:CreateUseableItem(Config.PhoneItem, function(source)
    TriggerClientEvent('nova_phone:client:usePhone', source)
end)
