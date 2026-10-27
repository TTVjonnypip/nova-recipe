# Nova Framework

A lean FiveM roleplay framework that takes the structure of **Qbox** (ox_lib-first, exports-based, OneSync) and keeps the **QBCore** player format and API, so most existing qb scripts run on it unchanged.

| Resource | What it does |
|---|---|
| `nova_core` | Players, characters, money, jobs, gangs, metadata, permissions, bans, commands, autosave, paychecks, hunger/thirst, plus the `qb-core` bridge |
| `nova_multicharacter` | Character select, create, and delete using ox_lib menus, with a ped preview (and illenium-appearance skins if you have it) |
| `nova_spawn` | Spawn picker: last location or configured spots. New characters go straight to the default spawn and the clothing editor |

The `scripts/` folder has your scripts, already ported to Nova:

| Script | Notes |
|---|---|
| `custom_inventory` | The inventory. Per-character, cash synced with Nova, food/drink feed hunger/thirst, job-locked stashes |
| `qbx_charcreate` | Character select/create. **Use this instead of `nova_multicharacter`** (don't run both) |
| `familylegacy_loadscreen` | Loading screen. Now stays up until character select is ready |
| `fp-dealership` | Buys go to `player_vehicles`, default garage `legion` |
| `qbx_easygarage` | Reads/writes `player_vehicles`; accepts any spawn name |
| `qbx_starterpack` | Gives once on a new character's first spawn; car goes straight into `player_vehicles` |
| `nova_phone` | Using the phone item opens it; bank shows Nova balances |
| `qbx_marriage` | Needs `ox_target` |
| `qbx_pregnancy` | Pregnancy test is a usable item |

The resource names are unchanged (`qbx_charcreate` etc.) so their events, exports and NUI keep working. They no longer need qbx_core.

"Nova" is a placeholder name. To rename it, rename the folders and find/replace `nova_` / `nova:` across the files.

---

## Requirements

- FiveM server with **OneSync** enabled
- [oxmysql](https://github.com/overextended/oxmysql)
- [ox_lib](https://github.com/overextended/ox_lib)
- An inventory: **custom_inventory** (included) *or* [ox_inventory](https://github.com/overextended/ox_inventory) in its `qb` mode. Not both.
- Optional: illenium-appearance (clothing and skin preview), ox_target (needed by qbx_marriage), pma-voice (phone calls), a vehicle keys script

**Do not run** `qb-core`, `qbx_core`, `es_extended`, `spawnmanager` or `basic-gamemode` alongside Nova. `nova_core` *provides* `qb-core` itself.

## Install

1. Copy `nova_core`, `nova_spawn` and everything in `scripts/` into your `resources` folder (e.g. `resources/[nova]/`). Keep `nova_multicharacter` only as a spare; don't start it alongside `qbx_charcreate`.
2. Import these into your database (all use `CREATE TABLE IF NOT EXISTS`, and the layouts match qb-core / Qbox):
   - `nova_core/sql/nova.sql` (players, bans)
   - `nova_core/sql/player_vehicles.sql`
   - `custom_inventory/sql/install.sql`
   - `nova_phone/sql/install.sql`
   - `qbx_marriage/marriage.sql` (optional; the script creates it too)
   - fp-dealership creates its own table on first start.
3. Add this to `server.cfg`:

```cfg
set mysql_connection_string "mysql://user:password@localhost/nova?charset=utf8mb4"
set onesync on

ensure oxmysql
ensure ox_lib
ensure ox_target              # needed by qbx_marriage
ensure pma-voice              # phone calls (optional)

ensure familylegacy_loadscreen
ensure nova_core
ensure custom_inventory       # must start before scripts that give items
ensure nova_spawn
ensure qbx_charcreate
# ensure illenium-appearance  (optional)

ensure fp-dealership
ensure qbx_easygarage
ensure qbx_starterpack
ensure nova_phone
ensure qbx_marriage
ensure qbx_pregnancy
# ... any qb scripts after this

# Let resources register admin-only commands (ox_lib lib.addCommand needs this per resource)
add_ace resource.nova_core command.add_ace allow
add_ace resource.nova_core command.remove_ace allow
add_ace resource.nova_core command.add_principal allow
add_ace resource.nova_core command.remove_principal allow
add_ace resource.fp-dealership command.add_ace allow
add_ace resource.fp-dealership command.remove_ace allow
add_ace resource.fp-dealership command.add_principal allow
add_ace resource.fp-dealership command.remove_principal allow
add_ace resource.qbx_easygarage command.add_ace allow
add_ace resource.qbx_easygarage command.remove_ace allow
add_ace resource.qbx_easygarage command.add_principal allow
add_ace resource.qbx_easygarage command.remove_principal allow
add_ace resource.qbx_starterpack command.add_ace allow
add_ace resource.qbx_starterpack command.remove_ace allow
add_ace resource.qbx_starterpack command.add_principal allow
add_ace resource.qbx_starterpack command.remove_principal allow
add_ace resource.qbx_pregnancy command.add_ace allow
add_ace resource.qbx_pregnancy command.remove_ace allow
add_ace resource.qbx_pregnancy command.add_principal allow
add_ace resource.qbx_pregnancy command.remove_principal allow

# Permission levels (god > admin > mod)
add_ace group.god god allow
add_ace group.admin admin allow
add_ace group.mod mod allow
add_principal group.god group.admin
add_principal group.admin group.mod

# custom_inventory admin commands
add_ace group.admin command.giveitem allow
add_ace group.admin command.clearinv allow

# Make yourself god
add_principal identifier.license:YOUR_LICENSE_HERE group.god
```

**Using ox_inventory instead of custom_inventory:** replace `ensure custom_inventory` with `ensure ox_inventory`, add `setr inventory:framework "qb"`, and add `pregnancy_test`, `birth_certificate`, `engagement_ring` and `wedding_ring` to `ox_inventory/data/items.lua`. Every script works with either inventory because they all go through nova_core.

Start order matters: **nova_core starts before the inventory**, and the inventory before anything that gives items.

## Configuration

- `nova_core/config/shared.lua`: server name, character slots, starting money, default spawn, duty behaviour, hunger/thirst rates, wanted level/dispatch
- `nova_core/config/server.lua`: save/paycheck/status intervals, whitelist, permission levels, per-license extra slots, starter items, tables cleaned on character delete
- `nova_core/shared/jobs.lua` / `gangs.lua` / `vehicles.lua`: your jobs, gangs and vehicle list
- `nova_multicharacter/config.lua`: preview ped and camera position, birthdate limits
- `nova_spawn/config.lua`: spawn locations, new-character spawn, menu camera

Job grades use numeric keys (`[0]`, `[1]`, …). Legacy scripts that read `QBCore.Shared.Jobs[job].grades['0']` still work because the bridge converts them.

## Commands

| Command | Who | Description |
|---|---|---|
| `/car [model]` | admin | Spawn a vehicle and get in |
| `/dv [radius]` | admin | Delete current or nearby vehicles |
| `/tp [id or x] [y] [z]` | admin | Teleport to a player or coords |
| `/tpm` | admin | Teleport to waypoint |
| `/coords` | mod | Copy `vec4(...)` to clipboard |
| `/givemoney [id] [account] [amount]` | admin | Add money |
| `/setmoney [id] [account] [amount]` | admin | Set balance |
| `/setjob [id] [job] [grade]` | admin | Set job |
| `/setgang [id] [gang] [grade]` | admin | Set gang |
| `/logout` | admin | Back to character select |
| `/kick [id] [reason]` | mod | Kick |
| `/ban [id] [hours] [reason]` | admin | Ban (0 hours = permanent) |
| `/unban [banid]` | admin | Remove a ban |
| `/id`, `/job`, `/gang`, `/cash`, `/bank` | everyone | Info |

---

## Using Nova in your own scripts

### Server exports (preferred: no object copying)

```lua
local core = exports.nova_core

local pd = core:GetPlayerData(source)          -- PlayerData table or nil
core:AddMoney(source, 'bank', 500, 'job payout')
core:RemoveMoney(source, 'cash', 50, 'store')  -- false if not enough cash
core:SetJob(source, 'police', 2)
core:SetGang(source, 'ballas', 0)
core:SetJobDuty(source, true)
core:SetMetaData(source, 'stress', 0)
core:HasPermission(source, 'admin')
core:Notify(source, 'Hello', 'success')
core:GetDutyCount('police')                     -- count, sources
core:AddJob('burgershot', { label = 'Burger Shot', grades = { [0] = { name = 'Cook', payment = 40 } } })
core:CreateUseableItem('lockpick', function(source, item) ... end)
```

Also available: `GetPlayer`, `GetPlayerByCitizenId`, `GetPlayerByPhone`, `GetPlayerSources`, `GetJobs`, `GetJob`, `GetGangs`, `GetGang`, `AddGang`, `Kick`, `Ban`, `IsPlayerLoaded`, `Login`, `Logout`, `SavePlayer`, `GetCharacters`, `CreateCharacter`, `DeleteCharacter`, `OwnsCharacter`, `GetMaxCharacters`, `GetMoney`, `GetMetaData`.

`GetPlayer(source)` returns the full qb-style player object (`PlayerData` + `Functions`). As with qb-core, the `PlayerData` you get back is a snapshot; call its `Functions` to make changes.

### Inventory (works with custom_inventory or ox_inventory)

```lua
-- server
core:AddItem(source, 'water', 2, metadata?, slot?)   -- ok, reason
core:RemoveItem(source, 'water', 1, metadata?, slot?)
core:GetItemCount(source, 'water')
core:CanCarryItem(source, 'water', 2)
core:HasItem(source, 'phone')                         -- or { 'a', 'b' } or { a = 2 }
core:ItemExists('wedding_ring')
core:GetItems()                                       -- all item definitions
core:CreateUseableItem('lockpick', function(source, item) ... end) -- item.slot is set

-- client
exports.nova_core:HasItem('phone')
exports.nova_core:GetItemCount('money')
```

`Config.Inventory` in `nova_core/config/shared.lua` picks the inventory (`'auto'` by default).

### Client exports

```lua
local pd = exports.nova_core:GetPlayerData()
local loggedIn = exports.nova_core:IsLoggedIn()     -- or LocalPlayer.state.isLoggedIn
exports.nova_core:Notify('Text', 'error')
```

### Events

| Server event | Args | When |
|---|---|---|
| `nova:server:playerLoaded` | source | Character loaded (before spawn) |
| `nova:server:onPlayerSpawned` | source, isNew | Player is in the world |
| `nova:server:onPlayerUnload` | source, citizenid, dropped | Logout or disconnect |
| `nova:server:onJobUpdate` | source, job | Job or duty changed |
| `nova:server:onGangUpdate` | source, gang | Gang changed |
| `nova:server:onDutyUpdate` | source, onDuty | Duty toggled |
| `nova:server:onMoneyChange` | source, account, amount, action, reason | `add` / `remove` / `set` |
| `nova:server:onMetaDataChange` | source, key, value, old | Metadata set |
| `nova:server:characterDeleted` | source, citizenid | Character deleted |

| Client event | Args | When |
|---|---|---|
| `nova:client:onPlayerLoaded` | (none) | Spawned and logged in |
| `nova:client:onPlayerUnload` | (none) | Logged out |
| `nova:client:playerDataUpdated` | data, old | Any PlayerData change |
| `nova:client:onJobUpdate` / `onGangUpdate` / `onDutyUpdate` | job / gang / bool | Changes |
| `nova:client:onMoneyChange` | account, amount, action, reason | Money change |

Net event `nova:server:toggleDuty` toggles the caller's duty.

---

## qb-core compatibility

`exports['qb-core']:GetCoreObject()` returns a QBCore object backed by Nova:

- **Server:** `Functions.GetPlayer/GetPlayerByCitizenId/GetPlayerByPhone/GetPlayers/GetQBPlayers/GetOfflinePlayerByCitizenId/GetIdentifier/GetSource/GetDutyCount/GetPlayersOnDuty/HasPermission/GetPermission/Kick/IsPlayerBanned/Notify/CreateCallback/CreateUseableItem/CanUseItem/UseItem/HasItem/AddJob(s)/AddGang(s)/AddPlayerMethod/AddPlayerField/SpawnVehicle/SetPlayerBucket/SetEntityBucket/GetCoords`, `Commands.Add`, `Player.Login/Logout/Save`, `Shared.Jobs/Gangs/Vehicles/Items` (items come from ox_inventory)
- **Player object:** `SetJob, SetGang, SetJobDuty, SetPlayerData, SetMetaData, GetMetaData, AddMoney, RemoveMoney, SetMoney, GetMoney, Save, Logout, AddMethod, AddField, UpdatePlayerData`, and item functions that go through ox_inventory
- **Client:** `Functions.GetPlayerData, TriggerCallback, Notify, Progressbar (→ lib.progressBar), HasItem, GetClosestPlayer, GetPlayersFromCoords, GetClosestVehicle, Get/SetVehicleProperties, SpawnVehicle, DeleteVehicle, GetPlate, DrawText3D, DrawText, RequestAnimDict, LoadModel, PlayAnim, GetCoords`
- **Events re-emitted:** `QBCore:Server:PlayerLoaded`, `QBCore:Server:OnPlayerUnload`, `QBCore:Server:OnJobUpdate`, `QBCore:Server:OnGangUpdate`, `QBCore:Server:SetDuty`, `QBCore:Server:OnMoneyChange`, `QBCore:Client:OnPlayerLoaded`, `QBCore:Client:OnPlayerUnload`, `QBCore:Player:SetPlayerData`, `QBCore:Client:OnJobUpdate`, `QBCore:Client:OnGangUpdate`, `QBCore:Client:SetDuty`, `hud:client:OnMoneyChange`, `hud:client:UpdateNeeds`
- **Legacy net events handled:** `QBCore:Server:TriggerCallback`, `QBCore:ToggleDuty`, `QBCore:Notify`, `consumables:server:addHunger/addThirst`, `hud:server:GainStress/RelieveStress`

Anything not listed (e.g. `QBCore.Functions.TriggerClientCallback`, qb's built-in inventory functions) isn't there. A qb script that needs one will error with "attempt to call a nil value" naming it, which tells you what to add to `bridge/qb/*.lua`.

## Not included (pair with existing resources)

HUD, death/ambulance system, vehicle keys, banking UI, housing/apartments, admin menu. The qb or Qbox versions of these generally work through the bridge. `/car` fires `vehiclekeys:client:SetOwner`.

## Known limitations and things to test

- **Test on a dev server first.** None of this has been run on a live FiveM server yet. Everything passes a syntax check and the inventory's cash sync was tested against a simulated Nova, but in-game behaviour (cameras, NUI, spawn hand-off) still needs a real run. Parts that depend on outside resources (ox_inventory's qb mode, illenium-appearance detecting `qb-core` through `provide`) match their public APIs as best known.
- Existing custom_inventory data from before the port was stored per license (`player:license:...`). Characters now use `player:<citizenid>`, so old pockets won't carry over. Stashes, trunks and gloveboxes are unaffected.
- The hunger/thirst/stress net events are client-triggered, as in qb. Values are clamped, but a cheater could still set their own hunger to 100.
- Don't restart `nova_core` while players are online. Restart the whole server instead (players are saved on txAdmin shutdown).
- The duplicate-license check at connect can briefly block a player who crashes and rejoins before their old session times out.
