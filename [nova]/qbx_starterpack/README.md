# qbx_starterpack

One-time starter pack for Nova characters:
- $100,000 (bank)
- Karin Sultan (`sultan`) stored in a garage
- 5x water, 5x burger

## Install
1. Drop the `qbx_starterpack` folder into your `resources` folder.
2. Make sure `player_vehicles` exists (`nova_core/sql/player_vehicles.sql`) and add to `server.cfg` **after** nova_core and your inventory:
   ```
   ensure qbx_starterpack
   ```
3. Check `config.lua`, especially `Config.Vehicle.garage`, which must match a garage key in `qbx_easygarage/config.lua`.

## Usage
- With `Config.AutoGive = true`, new characters get the pack ~3 seconds after spawning in.
- Players can also run `/starterpack`.
- Each character can only claim once (stored in player metadata).
- Admins: `/resetstarterpack [id]` to let someone claim again.

## Notes
- `water` and `burger` exist in custom_inventory and ox_inventory by default; rename them in config if you use different names.
- If inventory is full, nothing is given and the player can retry with `/starterpack`.
