# fp-dealership (Nova)

A vehicle dealership where players browse, preview and buy cars, and admins add or
remove stock from inside the game. Built for the Nova framework.

## Requirements
- nova_core
- ox_lib
- oxmysql
- A garage that uses the `player_vehicles` table (qbx_easygarage; run `nova_core/sql/player_vehicles.sql`)
- Optional: a keys script (qbx_vehiclekeys export, or the qb-vehiclekeys `vehiclekeys:client:SetOwner` event)

## Install
1. Drop the `fp-dealership` folder into your `resources` folder.
2. Add to `server.cfg` after nova_core, ox_lib and oxmysql:
   ```
   ensure fp-dealership
   ```
3. Start the server. The `dealership_vehicles` table is created automatically and filled
   with the starter cars from `config.lua` (first run only).

## Using it
- Walk up to the salesman and press **E**.
- Click a car to preview it. Drag the showroom area with the mouse to rotate it.
- Pay with cash or bank (click twice: once to arm, once to confirm).
- The car is saved to the buyer's garage and spawns outside with the keys.

## Adding and removing cars (admins)
Anyone with the Nova permission level in `Config.AdminPermission` (default `admin`, so god also qualifies) sees a
**Manage stock** tab. Enter the spawn name, display name, price and category to add a car.
Click an existing row to edit it, or press Remove (twice) to take it off sale.

Commands do the same thing and also work from the server console:
```
/adddealercar sultan 45000 Sedans Sultan Classic
/removedealercar sultan
```
Make yourself admin in `server.cfg` if you haven't:
```
add_principal identifier.license:YOUR_LICENSE group.admin
```

## Configuring
Everything lives in `config.lua`: location, blip, ped, delivery spot, camera, garage name,
starter stock, and two hooks:
- `Config.GiveKeys` (server): uses qbx_vehiclekeys if running, else the qb-vehiclekeys event. Swap for your keys script.
- `Config.OnVehicleSpawned` (client): sets fuel to 100 through the `fuel` state bag.

Default coordinates are around Premium Deluxe Motorsport. If the preview car or camera
sits in the wrong spot, adjust `Config.Preview.coords` and `camOffset`.

## Security notes
Prices are read from the database on the server, add/remove is permission-checked on the
server, and keys are only handed out for the car the player just bought.
