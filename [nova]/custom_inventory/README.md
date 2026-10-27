# custom_inventory

A slot-based inventory for the **Nova framework** (nova_core + oxmysql).

**Features:** drag & drop UI · 5-slot hotbar (keys 1–5) · weight limits · stashes (shared, personal, or ACE-locked) · vehicle trunks & gloveboxes (saved by plate) · ground drops · give to nearest player · usable items with animations · NPC shops · server-authoritative (clients can only *request* moves; every action is validated for access, distance, weight and space).

## Install

1. Drop the `custom_inventory` folder into your `resources` folder.
2. Run `sql/install.sql` on your database.
3. Add to `server.cfg` **after** nova_core and **before** scripts that give items:
   ```
   ensure oxmysql
   ensure nova_core
   ensure custom_inventory
   ```
   Don't run ox_inventory at the same time.
4. (Optional) Admin commands — give your admin group access:
   ```
   add_ace group.admin command.giveitem allow
   add_ace group.admin command.clearinv allow
   ```
5. (Optional) Lock a stash to a Nova job with `job = 'police'` (or `job = { police = 2 }` for a minimum grade), or to an ACE with `ace = '...'`.

## Controls

| Key | Action |
|---|---|
| TAB | Open inventory (opens glovebox in a vehicle, trunk when standing behind one, ground loot when near a drop) |
| 1–5 | Use hotbar slot |
| Z | Peek at hotbar |
| E | Open stash / shop when standing at one |
| X | Cancel an item being used |

In the UI: drag to move · **Shift**-drag moves half · **Ctrl**-drag moves one · the Amount box sets an exact amount · right-click uses · double-click quick-moves to the other side · drag onto Use / Give / Drop · Esc or Tab closes. All keys are rebindable in GTA Settings → Key Bindings → FiveM.

## Adding items

Add an entry to `shared/items.lua` and an image at `html/images/<name>.png` (100×100 PNG). Items without an image show a letter badge.

```lua
lockpick = { label = 'Lockpick', weight = 160, stack = true, description = '...' },
```

Built-in `use` effects: `eat`, `drink`, `heal`, `armour`. For anything else, register a callback from another resource:

```lua
exports.custom_inventory:RegisterUsableItem('lockpick', function(source, item, slot)
    -- your logic; remove it yourself if it should be consumed:
    exports.custom_inventory:RemoveItem(source, 'lockpick', 1, nil, slot)
end)
```

Hunger/thirst HUDs can listen for `custom_inventory:client:itemUsed` (client, `name, useDef`) or `custom_inventory:itemUsed` (server, `source, name`).

## Server exports

`target` is a player server id or an inventory id string (`'stash:legion_locker'`, `'trunk:ABC123'`, ...).

```lua
exports.custom_inventory:AddItem(target, name, count, metadata?, slot?)   -- → ok, reason
exports.custom_inventory:RemoveItem(target, name, count, metadata?, slot?) -- → ok
exports.custom_inventory:GetItemCount(target, name, metadata?)
exports.custom_inventory:CanCarryItem(target, name, count, metadata?)     -- → ok, reason
exports.custom_inventory:GetInventory(target)
exports.custom_inventory:ClearInventory(target)
exports.custom_inventory:RegisterUsableItem(name, function(source, item, slot) end)
exports.custom_inventory:RegisterStash({ id, label, coords = vector3(...), slots, weight, personal?, ace? })
```

Client exports: `IsOpen()`, `CloseInventory()`, `GetPlayerItems()`, `OpenStash(id)`.

## Config

Everything lives in `config.lua`: slot counts and weights, starting items, interaction distances, save interval, drop despawn time, trunk sizes per vehicle class, stash and shop locations (the coordinates included are examples — move them to suit your map).

## Notes

- Each **character** has their own inventory (keyed by Nova citizenid). It loads when a character is selected and saves on logout or disconnect.
- The `money` item mirrors the character's Nova cash. Shops, drops and giving change Nova cash; paychecks and scripts that change cash update the item. If pockets are full the item waits until there's space, and cash is never lost.
- `eat` / `drink` items fill Nova hunger / thirst by their `amount` (default 25).
- Items registered with `exports.nova_core:CreateUseableItem` (or QBCore's) work here too.
- Inventories save every 5 minutes, when a player leaves, and when the resource stops.
- Ground drops are not saved across restarts and despawn after 30 minutes.
- Weapons aren't wired in yet — weapons as items (equip on use, ammo as metadata) would be the natural next addition.
