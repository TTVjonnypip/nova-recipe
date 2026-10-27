# qbx_pregnancy

Roleplay pregnancy system for QBox (`nova_core`, `ox_lib`, `ox_inventory`).

## Install
1. Drop the `qbx_pregnancy` folder into your resources and add `ensure qbx_pregnancy` after `nova_core`, `ox_lib` and `ox_inventory`.
2. Add the items below to `custom_inventory/shared/items.lua (or ox_inventory/data/items.lua)`.
3. Tweak `config.lua` (set `Config.DayLengthSeconds = 60` while testing).

```lua
['pregnancy_test'] = {
    label = 'Pregnancy Test',
    weight = 50,
    stack = true,
    close = true,
    description = 'A home pregnancy test.',
    server = { export = false },
},

['birth_certificate'] = {
    label = 'Birth Certificate',
    weight = 10,
    stack = false,
    close = true,
},
```

The test is registered as usable with `exports.nova_core:CreateUseableItem`, which QBox bridges to ox_inventory, so no extra item hooks are needed.

## How it works
- Progress is stored in the character's `metadata.pregnancy` and uses real time, so it keeps advancing while offline.
- 40 in-game "weeks" are spread across `Config.PregnancyDays`. Trimesters: weeks 0–12, 13–26, 27–40.
- Trimester 1: nausea. Trimester 2: cravings. Trimester 3: cravings stop, back pain, slow walkstyle, no sprint/jump.

## Commands
| Command | Who | What |
|---|---|---|
| `/startpregnancy [id]` | On-duty medic | Asks the patient for consent, then starts a pregnancy |
| `/ultrasound [id]` | On-duty medic | Shows week, trimester and due status to medic and patient |
| `/deliver [id]` | On-duty medic | Delivers the baby (only when due, unless `AllowEarlyDelivery`) and gives a birth certificate |
| `/pregnancy` | Patient | Checks progress (after an ultrasound has confirmed it) |
| `/setpregnancy [id] [days]` | Admin | Sets elapsed days, useful for testing |
| `/endpregnancy [id]` | Admin | Clears a pregnancy |

Medics must be within `Config.MaxDistance` of the patient. Nothing starts without the patient clicking **Accept**.
