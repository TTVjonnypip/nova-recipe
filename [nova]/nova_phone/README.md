# Nova Phone (Nova)

A smartphone resource for the **Qbox** framework with 12 apps:

| App | What it does |
|---|---|
| Phone | Dialer + recent calls. Real voice calls through pma-voice call channels |
| Messages | SMS threads with unread badges, live delivery |
| Contacts | Add / search / delete, call or text from a contact |
| Fleeca (Bank) | Balance, transfers by phone number, transaction history |
| Chirp | Social feed: post, like/unlike, delete own posts |
| Yellow Pages | Classified ads with price, call/text the seller (optional posting fee) |
| Mail | Inbox other scripts can send to via export |
| Notes | Persistent notes |
| Calculator | Fully client-side |
| Garage | Lists your `player_vehicles` with status, fuel, engine and body |
| Services | Alert on-duty Police / EMS / Mechanic / Taxi, optional location blip |
| Settings | 6 wallpapers, do-not-disturb |

## Requirements
- `nova_core`, `ox_lib`, `oxmysql`
- `pma-voice` (for call audio; optional)
- An inventory: custom_inventory or ox_inventory (only if `Config.RequireItem = true`)

## Install
1. Drop the `nova_phone` folder into your `resources` directory.
2. Run `sql/install.sql` on your database.
3. Add to `server.cfg` **after** nova_core / ox_lib / oxmysql / pma-voice:
   ```
   ensure nova_phone
   ```
4. Make sure a `phone` item exists in `custom_inventory/shared/items.lua (or ox_inventory/data/items.lua)` (Qbox ships with one). To let players use the item to open the phone, add to the item:
   ```lua
   ['phone'] = {
       label = 'Phone', weight = 190, stack = false, consume = 0,
       client = { export = 'nova_phone.OpenPhone' },
   },
   ```
5. If you run another phone (qb-phone, npwd, lb-phone, etc.), stop it — two phones will fight over keybinds and pma-voice call channels.

## Usage
- **M** (rebindable in Settings > Key Bindings > FiveM) or `/phone` to open. **Esc** closes.
- Click the bar at the bottom of the screen to go home.

## Exports
```lua
-- server: send an email to a character (online or offline)
exports.nova_phone:SendMail(citizenid, 'Los Santos DMV', 'Subject', 'Body text')

-- client
exports.nova_phone:OpenPhone()
exports.nova_phone:ClosePhone()
exports.nova_phone:IsOpen()
```

## Notes
- Bank transfers go to players who are **online**. Offline transfers are intentionally not supported to avoid editing JSON money columns directly.
- Icons and font load from cdnjs / Google Fonts. For a fully offline server, download Font Awesome 6 into `html/` and change the `<link>` in `index.html`.
- Open `html/index.html` in a normal browser to preview the UI with mock data.
- Everything tunable (keys, fees, services, ring time, ad cost) lives in `config.lua`.

## Troubleshooting: phone won't open
1. Type `/phone` in chat. If that works, the problem is the keybind: rebind "Open phone" in Settings > Key Bindings > FiveM.
2. Type `/phonedebug`, open F8, and read the `[nova_phone]` lines. Any `false`, `0`, `ERROR`, or `NO RESPONSE` points to the cause.
3. Check the server console at startup for `[nova_phone] Database OK`. If it says tables are missing, import `sql/install.sql`.
4. Make sure the folder is named exactly `nova_phone` and that `ensure nova_phone` comes after nova_core, ox_lib and oxmysql.
