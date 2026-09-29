# Build a Wall: "Winning Is Just The Beginning!"

A Roblox game that starts as a top-down RTS maze puzzle and flips into first-person survival horror.

## Working rules

- Vili said to stop asking before each plan step: build the step, playtest it, then commit it to `main` and push.
- Vili writes in Finnish; reply in Finnish. All in-game text, UI and console output must be in English.
- Write new code comments in English (older comments are still Finnish).

## Repo and sync

- Rojo 7.7 project managed with Rokit (`rokit.toml`). Mapping lives in `default.project.json`.
- Sync to Studio: `rojo serve`, then Connect in the Rojo plugin. Build a place file with `rojo build -o build-a-wall.rbxlx`.
- Scripts are plain `.luau` files. `RTSGui` is a text folder (`src/StarterGui/RTSGui/`). `Baseplate`, `EntitySpawn`, `EnemyCore` and `SpawnLocation` are `.model.json` files. `Hunter`, `Camera` and `Terrain` are still binary `.rbxm` files, so edit those in Studio.

## Core loop

1. **RTS phase (build and route).** Top-down camera. The player builds neon blocks on a 2-stud grid. Cyan `EnergyOrb's spawn at `EntitySpawn` every 3 seconds and bounce off walls (custom raycast reflection, like billiard balls) toward the red `EnemyCore`.
2. **The twist.** After 5 core hits the game shows a fake victory, the world goes dark, and the player is teleported to `EntitySpawn` in first person with a flashlight.
3. **Horror phase (survive and escape).** Neon walls turn to dark concrete. The `Hunter` chases the player with `PathfindingService` and kills on touch. Reaching the green escape zone at the core's location gives True Victory.

## What exists today

The client runs the game; the server owns the maze walls and the Hunter so pathfinding and physics work. The client phase lives in the `GameState` ModuleScript (`src/ReplicatedStorage/GameState.luau`): `RTS` -> `FakeVictory` -> `Horror` -> `TrueVictory` (or `GameOver` when out of lives). Scripts use `GameState.Is(phase)`, `GameState.OnPhase(phase, fn)` and `GameState.Changed`; only `GameManager` calls `GameState.Set`, and it reports every change to the server through the `Remotes.PhaseReport` RemoteEvent. The server keeps its copy in the `ServerPhase` ModuleScript (`src/ServerScriptService/ServerPhase.luau`), which only accepts forward moves.

| Script | Location | Does |
|---|---|---|
| `CameraManager` | `src/StarterPlayer/StarterPlayerScripts/CameraManager.client.luau` | Scriptable top-down camera: WASD or one-finger drag to move, mouse wheel or pinch to zoom (height 30 to 140), kept inside the arena. The default movement controls (keyboard and mobile thumbstick) are disabled except in `Horror`; character frozen. On `FakeVictory`: `LockFirstPerson`, `CameraType.Custom`, still frozen. On `Horror`: walking restored. Reapplies the phase rules on respawn. |
| `EntitySpawner` | `src/StarterPlayer/StarterPlayerScripts/EntitySpawner.client.luau` | Spawns orbs every 3 s into the `EnergyOrbs` folder, raycast bounce (ignores other orbs and the build preview), destroys orbs more than 250 studs from the spawn or older than 60 s, fires `CoreHitEvent` on core hit. Raycasts only include `RTSWalls`, `Arena` and `EnemyCore`. When the phase leaves `RTS`: stops spawning and destroys all orbs. |
| `GameManager` | `src/StarterPlayer/StarterPlayerScripts/GameManager.client.luau` | Counts core hits (goal 5), then sets `FakeVictory`: hides the core, teleports the player onto `EntitySpawn` facing the maze, and after 5 s sets `Horror`. On `Horror`: builds the `EscapeZone` folder (flat 16x16 green neon pad with a strong green PointLight and broken concrete pillars) where the core was, and sets `TrueVictory` when the living player stands within 8 studs of its centre. 3 lives (`LivesLeft` player attribute): each death in `Horror` costs one, the last sets `GameOver`. Respawns during `Horror` start on the spawn pad. `TrueVictory` freezes the player. |
| `ArenaGrid` | `src/StarterPlayer/StarterPlayerScripts/ArenaGrid.client.luau` | Builds the glowing light-blue floor grid (neon strips every 8 studs, `CanQuery = false`) in an `ArenaGrid` folder. On `FakeVictory`: removes it. |
| `PhaseEffects` | `src/StarterPlayer/StarterPlayerScripts/PhaseEffects.client.luau` | Owns lighting and fog. On `FakeVictory`: night lighting, concrete floor, dimmed spawn pad, a concrete ceiling on top of the walls (`ConcreteRoom` folder) with a grid of pulsing red alarm lights. On `Horror`: alarms go dark and the `Atmosphere` turns into thick dark fog that thins to about half within 45 studs of the escape zone. On `TrueVictory`: fog lifts and a cold dawn light fades in. |
| `EndScreens` | `src/StarterPlayer/StarterPlayerScripts/EndScreens.client.luau` | Lives counter during `Horror`. On `TrueVictory` ("TRUE VICTORY: YOU SURVIVED") or `GameOver` ("THE HUNTER GOT YOU"): calm fade-in screen with time in the dark, deaths and a PLAY AGAIN button that fires `Remotes.PlayAgain`. |
| `Flashlight` | `src/StarterPlayer/StarterPlayerScripts/Flashlight.client.luau` | From `FakeVictory` on: a first-person hand holding a flashlight (`FlashlightViewmodel` model in Workspace, follows the camera, bobs when walking). The beam is wide in `FakeVictory`, narrow and dim in `Horror`. |
| `FakeVictoryGui` | `src/StarterPlayer/StarterPlayerScripts/FakeVictoryGui.client.luau` | During `FakeVictory`: black cut-in, glitching "LEVEL CLEARED" (red/cyan split, corrupted letters, getting worse), then a blinking red "- ERROR: BREACH DETECTED -". Removed when the phase ends. |
| `ArenaService` (server) | `src/ServerScriptService/ArenaService.server.luau` | Builds the `Arena` folder from `ArenaLayout`: `Border` walls around the 128x192 play area and the prebuilt `Maze` (dark steel walls with a thin pale neon line on top). On `FakeVictory`: turns them into concrete. |
| `WallService` (server) | `src/ServerScriptService/WallService.server.luau` | Owns the `RTSWalls` folder. Handles `Remotes.PlacePiece` (piece index, position, rotation) and `Remotes.RemovePiece` (part). Placement rules: RTS phase only, rate limit, 30-piece budget, inside the arena, 90° rotations, no overlap with pieces or arena walls, keep-clear radius around the spawn pad and core, and a flood fill on a 2-stud grid that refuses any Wall/Tower that would cut the walking route from the spawn to the core (Floor Obstacles can be jumped). Refusals go back to the client as a message on `PlacePiece`. On `FakeVictory`: turns every piece into dark grey concrete. |
| `HunterAI` (server) | `src/ServerScriptService/HunterAI.server.luau` | Paints the `Hunter` rig black with glowing red eyes, plays its walk/idle animations from the server (the rig's Animate LocalScript never ran), and hides it in ServerStorage. On `Horror`: puts it in a free spot 14 studs behind the core, walks at 13 (player 16), goes straight at the player with line of sight and otherwise follows `PathfindingService` waypoints, kills on touch. After a player respawn it returns to its lair and waits 3 s. On `TrueVictory`: stops. |
| `RestartService` (server) | `src/ServerScriptService/RestartService.server.luau` | Handles `Remotes.PlayAgain` after the game ended: teleports the player to a fresh reserved server of this place. Teleports fail in Studio, so the client then says to stop and press Play. |
| `BuilderScript` | `src/StarterGui/RTSGui/BuilderScript.client.luau` | Builds the neon build menu in code (bottom `BuildBar` with a BUILD toggle, Wall/Tower/Floor Obstacle slots, ROTATE and REMOVE buttons, piece budget, controls hint, refusal message, top `CoreHud` with core-hit pips read from `EnemyCore` attributes `Hits`/`HitsRequired`). B toggles build mode, X toggles remove mode (highlights the piece under the pointer), right-click removes a piece, on touch a short tap places or removes, new pieces pop in, clicks on the menu never place pieces, 2-stud grid snap, `GhostPreview` part (`CanQuery = false`), R rotates 90°, keys 1/2/3 pick the pieces from `BuildPieces`. The preview turns red where the server would refuse the piece (except the route check, which only the server does); a click fires `Remotes.PlacePiece`. Uses the server's `RTSWalls` folder as the mouse `TargetFilter`. On `FakeVictory`: hides the GUI. |

Other instances:
- `ReplicatedStorage`: `GameState`, `BuildPieces` (pieces, budget and placement limits) and `ArenaLayout` (arena size, maze rectangles, spawn and core positions) ModuleScripts shared by client and server, the `CoreHitEvent` BindableEvent, and the `Remotes` folder (`PlacePiece`, `RemovePiece`, `PhaseReport`, `PlayAgain` RemoteEvents).
- `Workspace`: `Baseplate` (dark blue), `EntitySpawn` (flat blue neon pad with an "S" SurfaceGui, at z = 70), `EnemyCore` (16-stud red neon sphere with a red PointLight, at z = -70; `ArenaLayout` must match both), `Hunter` (R15 rig, moved to ServerStorage by `HunterAI` until the horror), `SpawnLocation` (invisible, out of view at z = 120 so the frozen character is off camera during RTS).
- `StarterGui`: `RTSGui` (`ResetOnSpawn = false`). The phase screens are built in code by their scripts.
- `Lighting`: one `Sky`, one `Atmosphere`, and the post effects (Bloom, Blur, ColorCorrection, SunRays, DepthOfField).

## Target design (not built yet)

- Optional later: move the rest of the game logic (orbs, core hits, phases) to the server.

## Testing

Play in Studio: build walls, check that orbs route into the core, check the switch to the horror phase after 5 hits (darkness, FPS, flashlight, Hunter chasing), die once to check respawn keeps FPS and flashlight, then reach the escape pad and check True Victory.
