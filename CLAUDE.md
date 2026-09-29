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

1. **RTS phase (build and route).** Top-down camera. The player builds neon blocks on a 2-stud grid. Cyan `EnergyOrb`s spawn at `EntitySpawn` every 3 seconds and bounce off walls (custom raycast reflection, like billiard balls) toward the red `EnemyCore`.
2. **The twist.** After 5 core hits the game shows a fake victory, the world goes dark, and the player is teleported to `EntitySpawn` in first person with a flashlight.
3. **Horror phase (survive and escape).** Neon walls turn to dark concrete. The `Hunter` chases the player with `PathfindingService` and kills on touch. Reaching the green escape zone at the core's location gives True Victory.

## What exists today

All gameplay code is client-side. There are no server scripts. The phase lives in the `GameState` ModuleScript (`src/ReplicatedStorage/GameState.luau`): `RTS` -> `FakeVictory` -> `Horror` -> `TrueVictory`. Scripts use `GameState.Is(phase)`, `GameState.OnPhase(phase, fn)` and `GameState.Changed`; only `GameManager` calls `GameState.Set`.

| Script | Location | Does |
|---|---|---|
| `CameraManager` | `src/StarterPlayer/StarterPlayerScripts/CameraManager.client.luau` | Scriptable top-down camera with WASD, character frozen. On `FakeVictory`: `LockFirstPerson`, `CameraType.Custom`, still frozen. On `Horror`: walking restored. Reapplies the phase rules on respawn. |
| `EntitySpawner` | `src/StarterPlayer/StarterPlayerScripts/EntitySpawner.client.luau` | Spawns orbs every 3 s into the `EnergyOrbs` folder, raycast bounce (ignores other orbs and the build preview), destroys orbs more than 250 studs from the spawn or older than 60 s, fires `CoreHitEvent` on core hit. When the phase leaves `RTS`: stops spawning and destroys all orbs. |
| `GameManager` | `src/StarterPlayer/StarterPlayerScripts/GameManager.client.luau` | Counts core hits (goal 5), then sets `FakeVictory`: teleports the player to `EntitySpawn` and after 4 s sets `Horror`. On `Horror`: darkness (`Ambient`/`OutdoorAmbient` 0, `Brightness` 0, `ClockTime` 0), reshapes `EnemyCore` into a flat lime-green neon pad with a green PointLight, adds a SpotLight flashlight on the head. Keeps the flashlight and spawn pad on respawn. `EnemyCore.Touched` during `Horror` sets `TrueVictory`, which freezes the player and enables `VictoryGui`. |
| `ArenaGrid` | `src/StarterPlayer/StarterPlayerScripts/ArenaGrid.client.luau` | Builds the glowing light-blue floor grid (neon strips every 8 studs, `CanQuery = false`) in an `ArenaGrid` folder. On `FakeVictory`: removes it. |
| `MonsterAI` | `src/StarterPlayer/StarterPlayerScripts/MonsterAI.client.luau` | Uses the existing `workspace.Hunter` rig. On `Horror`: recomputes a path to the player every 0.2 s, kills on touch. On `TrueVictory`: stops. |
| `BuilderScript` | `src/StarterGui/RTSGui/BuilderScript.client.luau` | Build mode toggle button, 2-stud grid snap, `GhostPreview` part (`CanQuery = false`), R rotates 90°, keys 1/2/3 pick Wall (orange) / Tower (cyan) / Floor Obstacle (magenta). Creates the `RTSWalls` folder at runtime and uses it as the mouse `TargetFilter`. On `FakeVictory`: hides the GUI and turns walls into dark grey concrete. |

Other instances:
- `ReplicatedStorage`: `GameState` ModuleScript and the `CoreHitEvent` BindableEvent.
- `Workspace`: `Baseplate` (dark blue), `EntitySpawn` (flat blue neon pad with an "S" SurfaceGui), `EnemyCore` (16-stud red neon sphere with a red PointLight), `Hunter` (rig), `SpawnLocation` (invisible, out of view at z = 120 so the frozen character is off camera during RTS).
- `StarterGui`: `RTSGui` (`ResetOnSpawn = false`), `VictoryGui` ("TRUE VICTORY" text, disabled until escape).
- `Lighting`: one `Sky`, one `Atmosphere`, and the post effects (Bloom, Blur, ColorCorrection, SunRays, DepthOfField).

## Target design (not built yet)

- **Fake victory:** a `FakeVictoryGui` with a glitchy "LEVEL CLEARED" and red "- ERROR: BREACH DETECTED -", red ceiling alarm lights, and a short pause before the horror phase starts.
- **Separate `EscapeZone`:** an anchored, huge, glowing green part on the ground at the core's position, shown only in the horror phase. Use it instead of reshaping the spherical `EnemyCore`.
- **Horror atmosphere:** thick fog, a narrow and dim flashlight, black Hunter with glowing red eyes. Fog clears near the escape zone.
- **True victory:** lights and fog lift, "TRUE VICTORY: YOU SURVIVED".
- **Hunter rules:** hidden and idle during the RTS phase, stops chasing after victory.
- **GUIs:** `ResetOnSpawn = false` on `VictoryGui` too (done for `RTSGui`).
- Optional later: move authority to server scripts.

## Testing

Play in Studio: build walls, check that orbs route into the core, check the switch to the horror phase after 5 hits (darkness, FPS, flashlight, Hunter chasing), die once to check respawn keeps FPS and flashlight, then reach the escape pad and check True Victory.
