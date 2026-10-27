# qbx_marriage

Proposals, weddings and divorces for Nova (nova_core + ox_lib + ox_target + ox_inventory + oxmysql).

## Features
- **Propose** – use an `engagement_ring` next to someone. You kneel, they get a Yes/No prompt. On yes the ring is consumed and you're engaged.
- **Wedding** – both partners go to the chapel officiant; one selects *Hold wedding ceremony*, the other says "I do". Both play the vows, then get a `wedding_ring` engraved with partner name + date. Optional server-wide announcement.
- **Divorce / call off engagement** – courthouse clerk, with confirmation dialog and fee.
- `/spouse` – shows your status and whether your partner is in the city.
- Status is mirrored into `PlayerData.metadata.marriage` (`{ id, status, partner, partnerName }` or `false`) so ID cards, phones and HUDs can read it.
- Spouse gets notified when their partner logs in.

## Install
1. Drop `qbx_marriage` into your resources and add `ensure qbx_marriage` **after** nova_core, ox_lib, ox_target, ox_inventory and oxmysql.
2. Run `marriage.sql` on your database.
3. Add the items to `custom_inventory/shared/items.lua (or ox_inventory/data/items.lua)`:

```lua
['engagement_ring'] = {
    label = 'Engagement Ring',
    weight = 50,
    stack = false,
    close = true,
    description = 'Use it near someone special to propose.',
},

['wedding_ring'] = {
    label = 'Wedding Ring',
    weight = 50,
    stack = false,
    close = true,
},
```

4. Add images `engagement_ring.png` and `wedding_ring.png` to `ox_inventory/web/images/`, and put the engagement ring in a shop (e.g. a jeweler).
5. Move `Config.Chapel` / `Config.Courthouse` coords to your MLOs.

## Exports (server)
```lua
exports.qbx_marriage:IsMarried(citizenid)       -- boolean
exports.qbx_marriage:GetSpouse(citizenid)       -- { citizenid, name } or nil
exports.qbx_marriage:GetRelationship(citizenid) -- full DB row or nil
```

Client side, just read `QBX.PlayerData.metadata.marriage`.
