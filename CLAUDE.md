# Build a Wall: "Winning Is Just The Beginning!"

A Roblox game that starts as a top-down RTS maze puzzle and flips into first-person survival horror.

## Working rules

- Vili said to stop asking before each plan step: build the step, playtest it, then commit it to `main` and push.
- Vili writes in Finnish; reply in Finnish. All in-game text, UI and console output must be in English.
- Write new code comments in English (older comments are still Finnish).

## Repo and sync

- Rojo 7.7 project managed with Rokit (`rokit.toml`). Mapping lives in `default.project.json`.
- Sync to Studio: `rojo serve`, then Connect in the Rojo plugin. Build a place file with `rojo build -o build-a-wall.rbxlx`.
- Scripts are plain `.luau` files. `RTSGui` is a text folder (`src/StarterGui/RTSGui/`). `Baseplate`, `EntitySpawn`, `EnemyCore` and `SpawnLocation` are `.model.json` files. `VictoryGui`, `Hunter`, `Camera` and `Terrain` are still binary `.rbxm` files, so edit those in Studio.

## Core loop

1. **RTS phase (build and route).** Top-down camera. The player builds neon blocks on a 2-stud grid. Cyan `EnergyOrb's spawn at `EntitySpawn` every 3 seconds and bounce off walls (custom raycast reflection, like billiard balls) toward the red `EnemyCore`.
2. **The twist.** After 5 core hits the game shows a fake victory, the world goes dark, and the player is teleported to `EntitySpawn` in first person with a flashlight.
3. **Horror phase (survive and escape).** Neon walls turn to dark concrete. The `Hunter` chases the player with `PathfindingService` and kills on touch. Reaching the green escape zone at the core's location gives True Victory.

## What exists today

The client runs the game; the server owns the maze walls and the Hunter so pathfinding and physics work. The client phase lives in the `GameState` ModuleScript (`src/ReplicatedStorage/GameState.luau`): `RTS` -> `FakeVictory` -> `Horror` -> `TrueVictory`. Scripts use `GameState.Is(phase)`, `GameState.OnPhase(phase, fn)` and `GameState.Changed`; only `GameManager` calls `GameState.Set`, and it reports every change to the server through the `Remotes.PhaseReport` RemoteEvent. The server keeps its copy in the `ServerPhase` ModuleScript (`src/ServerScriptService/ServerPhase.luau`), which only accepts forward moves.

| Script | Location | Does |
|---|---|---|
| `CameraManager` | `src/StarterPlayer/StarterPlayerScripts/CameraManager.client.luau` | Scriptable top-down camera with WASD, character frozen. On `FakeVictory`: `LockFirstPerson`, `CameraType.Custom`, still frozen. On `Horror`: walking restored. Reapplies the phase rules on respawn. |
| `EntitySpawner` | `src/StarterPlayer/StarterPlayerScripts/EntitySpawner.client.luau` | Spawns orbs every 3 s into the `EnergyOrbs` folder, raycast bounce (ignores other orbs and the build preview), destroys orbs more than 250 studs from the spawn or older than 60 s, fires `CoreHitEvent` on core hit. When the phase leaves `RTS`: stops spawning and destroys all orbs. |
| `GameManager` | `src/StarterPlayer/StarterPlayerScripts/GameManager.client.luau` | Counts core hits (goal 5), then sets `FakeVictory`: hides the core, teleports the player onto `EntitySpawn` facing the maze, and after 5 s sets `Horror`. On `Horror`: reshapes `EnemyCore` into a flat lime-green neon pad with a green PointLight. Respawns during `Horror` start on the spawn pad. `EnemyCore.Touched` during `Horror` sets `TrueVictory`, which freezes the player and enables `VictoryGui`. |
| `ArenaGrid` | `src/StarterPlayer/StarterPlayerScripts/ArenaGrid.client.luau` | Builds the glowing light-blue floor grid (neon strips every 8 studs, `CanQuery = false`) in an `ArenaGrid` folder. On `FakeVictory`: removes it. |
| `PhaseEffects` | `src/StarterPlayer/StarterPlayerScripts/PhaseEffects.client.luau` | On `FakeVictory`: night lighting, concrete floor, dimmed spawn pad, a concrete ceiling on top of the walls (`ConcreteRoom` folder) with a grid of pulsing red alarm lights. On `Horror`: alarms go dark and the `Atmosphere` turns into thick dark fog. |
| `Flashlight` | `src/StarterPlayer/StarterPlayerScripts/Flashlight.client.luau` | From `FakeVictory` on: a first-person hand holding a flashlight (`FlashlightViewmodel` model in Workspace, follows the camera, bobs when walking). The beam is wide in `FakeVictory`, narrow and dim in `Horror`. |
| `FakeVictoryGui` | `src/StarterPlayer/StarterPlayerScripts/FakeVictoryGui.client.luau` | During `FakeVictory`: black cut-in, glitching "LEVEL CLEARED" (red/cyan split, corrupted letters, getting worse), then a blinking red "- ERROR: BREACH DETECTED -". Removed when the phase ends. |
| `WallService` (server) | `src/ServerScriptService/WallService.server.luau` | Owns the `RTSWalls` folder. Handles `Remotes.PlacePiece` (piece index, position, rotation): validates the piece, arena bounds, 90° rotation, rate limit, the 150-piece cap and the keep-clear radius around the spawn pad and core, then snaps to the grid and creates the neon part. On `FakeVictory`: turns every piece into dark grey concrete. |
| `HunterAI` (server) | `src/ServerScriptService/HunterAI.server.luau` | Paints the `Hunter` rig black with glowing red eyes, plays its walk/idle animations from the server (the rig's Animate LocalScript never ran), and hides it in ServerStorage. On `Horror`: puts it in a free spot 14 studs behind the core, walks at 13 (player 16), goes straight at the player with line of sight and otherwise follows `PathfindingService` waypoints, kills on touch. After a player respawn it returns to its lair and waits 3 s. On `TrueVictory`: stops. |
| `BuilderScript` | `src/StarterGui/RTSGui/BuilderScript.client.luau` | Builds the neon build menu in code (bottom `BuildBar` with a BUILD toggle and Wall/Tower/Floor Obstacle slots, controls hint, top `CoreHud` with core-hit pips read from `EnemyCore` attributes `Hits`/`HitsRequired`). B toggles build mode, clicks on the menu never place pieces, 2-stud grid snap, `GhostPreview` part (`CanQuery = false`), R rotates 90°, keys 1/2/3 pick the pieces from `BuildPieces`. The preview turns red where the server would refuse the piece; a click fires `Remotes.PlacePiece`. Uses the server's `RTSWalls` folder as the mouse `TargetFilter`. On `FakeVictory`: hides the GUI. |

Other instances:
- `ReplicatedStorage`: `GameState` and `BuildPieces` (piece sizes/colours/keys and placement limits, shared by client and server) ModuleScripts, the `CoreHitEvent` BindableEvent, and the `Remotes` folder (`PlacePiece`, `PhaseReport` RemoteEvents).
- `Workspace`: `Baseplate` (dark blue), `EntitySpawn` (flat blue neon pad with an "S" SurfaceGui), `EnemyCore` (16-stud red neon sphere with a red PointLight), `Hunter` (R15 rig, moved to ServerStorage by `HunterAI` until the horror), `SpawnLocation` (invisible, out of view at z = 120 so the frozen character is off camera during RTS).
- `StarterGui`: `RTSGui` (`ResetOnSpawn = false`), `VictoryGui` ("TRUE VICTORY" text, disabled until escape).
- `Lighting`: one `Sky`, one `Atmosphere`, and the post effects (Bloom, Blur, ColorCorrection, SunRays, DepthOfField).

## Target design (not built yet)

- **Separate `EscapeZone`:** an anchored, huge, glowing green part on the ground at the core's position, shown only in the horror phase. Use it instead of reshaping the spherical `EnemyCore`.
- **Horror atmosphere:** fog clears near the escape zone.
- **True victory:** lights and fog lift, "TRUE VICTORY: YOU SURVIVED".
- **GUIs:** `ResetOnSpawn = false` on `VictoryGui` too (done for `RTSGui`).
- Optional later: move the rest of the game logic (orbs, core hits, phases) to the server.

## Testing

Play in Studio: build walls, check that orbs route into the core, check the switch to the horror phase after 5 hits (darkness, FPS, flashlight, Hunter chasing), die once to check respawn keeps FPS and flashlight, then reach the escape pad and check True Victory.
