# Sushi Upgrade Boards

Clickable incremental-game upgrade boards: a **Cash Upgrades** board, a **Rebirth** board and a
**Rebirth Upgrades** board, drawn on invisible parts in the world.

## Setup in Roblox Studio

Create these scripts, each with the exact name shown, and paste in the matching file's contents:

| Where in Studio | Type | Name | File |
|---|---|---|---|
| ReplicatedStorage | ModuleScript | `UpgradeConfig` | `ReplicatedStorage/UpgradeConfig.luau` |
| ServerScriptService | ModuleScript | `UpgradeService` | `ServerScriptService/UpgradeService.luau` |
| ServerScriptService | Script | `UpgradeServer` | `ServerScriptService/UpgradeServer.server.luau` |
| StarterPlayer > StarterPlayerScripts | LocalScript | `UpgradeBoards` | `StarterPlayerScripts/UpgradeBoards.client.luau` |

Then point the camera where you want the boards, paste `CreateBoards.command.luau` into the
Command Bar and press Enter. Press Play.

While testing in Studio you get 50 free Cash per second (`StudioTestIncome` in `UpgradeConfig`).
It never runs in the published game.

To save progress in Studio, turn on Game Settings > Security > Enable Studio Access to API Services.

## Connecting it to your sushi

Currencies are `leaderstats.Cash` and `leaderstats.Rebirths`. If your game already makes these, they
are reused.

In the server script where a player collects sushi:

```lua
local UpgradeService = require(game.ServerScriptService.UpgradeService)
UpgradeService.AwardCash(player, sushiValue) -- applies Sushi Value x More Cash
```

In your sushi spawner:

```lua
local stats = UpgradeService.GetStats(player)
stats.SushiCapacity -- max sushi on the pad (Sushi Capacity x More Sushi)
stats.SpawnInterval -- seconds between spawns (Spawn Speed)
```

## Changing upgrades

Everything is in `UpgradeConfig`: titles, icons, max levels, costs (`BaseCost`, `CostGrowth`),
values, which board each upgrade is on, and the rebirth requirement and reward.
