# Nova txAdmin Recipe

One-click deploy of the Nova framework and its scripts on any host running txAdmin (RocketNode included).

## What's in this repo

| Path | What it is |
|---|---|
| `nova.yaml` | The txAdmin recipe |
| `server.cfg` | Server config template (txAdmin fills in license, database, slots, admin) |
| `nova.sql` | Every table Nova and the scripts need |
| `[nova]/` | nova_core, nova_spawn, custom_inventory, qbx_charcreate, the loading screen and all scripts |
| `FRAMEWORK.md` | Full framework docs (API, commands, configuration) |

The recipe also downloads chat/sessionmanager/hardcap, oxmysql, ox_lib, ox_target and pma-voice.

## Step 1: Put this on GitHub (once)

1. Create a free account at github.com if you don't have one.
2. Create a new **public** repository named exactly `nova-recipe`.
3. Upload everything in this folder to it (Add file → Upload files, drag the whole folder contents in, Commit). The `[nova]` folder must stay at the top level of the repo.
4. Edit `nova.yaml` in the repo and replace `YOUR_GITHUB_USERNAME` with your GitHub username. Commit.
5. Open `nova.yaml` in the repo and click **Raw**. Copy that URL. It looks like:
   `https://raw.githubusercontent.com/YOUR_GITHUB_USERNAME/nova-recipe/main/nova.yaml`

## Step 2: Deploy on RocketNode

1. In the RocketNode panel, create a MySQL database for the server if you don't have one, and note its host, port, username, password and database name.
2. Open txAdmin for your server.
   - **New server:** the setup wizard starts automatically.
   - **Existing server:** in txAdmin go to **Settings → FXServer** (or **Master Actions → Reset FXServer Settings**) to re-run setup. This replaces the server's files and config, so back up anything you want to keep first.
3. In the setup wizard choose **Remote URL Template** and paste the Raw URL from Step 1.
4. When asked for the database, enter the RocketNode database details. Leave "delete existing database" off unless you want a clean wipe.
5. Let the deployer finish, then click **Save & Run Server**.

## Step 3: First boot

1. Watch the txAdmin live console. You should see `[nova_core] Nova RP framework started`.
2. Join, create a character, and test TAB (inventory) and M (phone).
3. To give yourself god: copy your `license:` identifier from txAdmin's **Players** page, add
   `add_principal identifier.license:YOUR_LICENSE group.god`
   to the bottom of server.cfg (txAdmin → **CFG Editor**), and restart.

## Updating later

Recipes only run on first deploy. To push script changes to a running server, upload the changed resource folders over FTP / the RocketNode file manager and restart, or re-deploy the recipe on a fresh server.

## Troubleshooting

- **Deploy fails on the Nova download step:** the repo isn't public, isn't named `nova-recipe`, or `YOUR_GITHUB_USERNAME` wasn't replaced.
- **Deploy fails on query_database:** the database details were wrong. Check them in the RocketNode panel and re-run.
- **ox_lib errors about a missing web build:** something replaced the release zip with source code. Re-download `ox_lib.zip` from the ox_lib Releases page.
- **Stuck on the loading screen:** check the console for red errors from `nova_core` or `qbx_charcreate`.
