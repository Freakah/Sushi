# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Luau source for a Roblox incremental game ("Sushi Incremental"). There is no Rojo project, build step,
linter config or test suite: every file is copied into Roblox Studio by hand, and changes are tested by
running them in Studio. The user is the one doing that, so each file's header comment is the setup guide
for it — keep it accurate when changing where or how a file runs.

## File naming = how the file is used

- `*.command.luau` and the generators in `Mountain/` and `SakuraTree/` — pasted whole into Studio's
  **Command Bar** and run once at edit time. They must be fully self-contained (no `require`), run in edit
  mode, place their output where the camera is looking, set `ChangeHistoryService` waypoints so Ctrl+Z works,
  and select the result. Re-running replaces what the previous run created.
- `*.client.luau` — LocalScript; `*.server.luau` — Script; plain `*.luau` in `UpgradeShop/` — ModuleScript.
  The subfolder (`ReplicatedStorage/`, `ServerScriptService/`, `StarterPlayerScripts/`) is where it goes in
  Studio, and the instance name must match the file name (scripts `require`/`WaitForChild` each other by name).
- Most files start with a `CONFIG` table of user-tweakable values; put new knobs there rather than inline.

Because Command Bar scripts can't share modules, helpers such as `findOrigin`, `block`, `shaded`,
`mountainBlock` and `summit`, plus the pastel palette, are **copy-pasted** across the `Mountain/` generators.
A fix to one helper usually needs to be applied to the others. `Sky/SkySetup.command.luau` likewise embeds a
LocalScript's source as a string and writes it to `StarterPlayerScripts`.

## UpgradeShop architecture

See `UpgradeShop/README.md` for Studio setup and the integration API.

- `UpgradeConfig` (ReplicatedStorage) is the single source of truth shared by server and client: currencies,
  upgrades (`BaseCost`, `CostGrowth`, `Value(level)`, `Currency`), which board shows which upgrade, rebirth
  rules, `FormatNumber`, and derived stats (`GetStats`). Upgrade levels live in player attributes
  `Upg_<UpgradeId>` and `RebirthCount`, so the client reads them without extra networking.
- `UpgradeService` (server) owns currencies (`leaderstats.Cash`/`Rebirths`, reused if the game already
  creates them), validates purchases and rebirths, and saves via DataStore (`DataStoreName`; bump the
  version suffix if the save format changes). It creates a single RemoteEvent `UpgradeShopRemote` in
  ReplicatedStorage taking `("Buy", upgradeId, buyMax)` or `("Rebirth")`, rate-limited per player.
  Other server scripts use `AwardCash` and `GetStats`.
- `UpgradeBoards` (client) draws SurfaceGui boards onto the parts in `Workspace.UpgradeBoards`
  (created by `CreateBoards.command.luau`; part sizes match the UI canvas aspect ratios) and only sends
  requests — never trust it for game state.
- `Config.StudioTestIncome` gives free cash only when `RunService:IsStudio()`.

## Other pieces

- `LoadingScreen/` — LocalScript for ReplicatedFirst; prints `[LoadingScreen] ...` status lines to Output for
  troubleshooting.
- `Squishies/` — `MakiBuilder` builds a model tagged `SquishySushi`; `SquishyAnimator` (client) animates every
  model with that CollectionService tag, so spawned clones animate automatically.
- Visual style across the repo is soft pastel / kawaii with the `FredokaOne` font; match it in new UI or models.
