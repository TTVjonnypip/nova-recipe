# qbx_charcreate (Nova)

Character selection & creation for the **Nova framework**: cinematic preview scene, NUI slot list, creation form with server-side validation, delete confirmation, and illenium-appearance support.

This replaces `nova_multicharacter`. **Don't run both.**

## Requirements
- nova_core, ox_lib, oxmysql
- nova_spawn *(optional: location picker for returning characters)*
- illenium-appearance *(optional: skin previews and the first-character clothing menu)*

## Install
Add to `server.cfg` after nova_core, ox_lib, oxmysql and illenium-appearance:
```
ensure qbx_charcreate
```

## Where settings live
| Setting | File |
|---|---|
| Character slots | `nova_core/config/shared.lua` → `Config.MaxCharacters`, and `nova_core/config/server.lua` → `ServerConfig.CharacterSlots` |
| Starter items | `nova_core/config/server.lua` → `ServerConfig.StarterItems` |
| `/logout` | built into nova_core (admin only) |
| Everything else (scene, spawn mode, delete button, age limits, name rules, nationalities) | this resource's `config.lua` |

## Spawning
- `Config.SpawnMode = 'auto'`: returning characters get nova_spawn's location picker if it's running, otherwise their last location. Jailed or dead characters always go to their last location.
- New characters spawn at `Config.NewCharacterSpawn` and the clothing menu opens (`Config.FirstCharacterEvent`).

## Troubleshooting
- **Stuck on the loading screen:** make sure `nova_multicharacter` is not started and nova_core started without errors.
- **Clothing menu doesn't open:** check illenium-appearance is started and `Config.FirstCharacterEvent` matches it.
