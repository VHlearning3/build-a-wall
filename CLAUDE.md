# Build a Wall: "Winning Is Just The Beginning!"

A Roblox game that looks like a cute top-down maze builder and flips into first-person survival horror.

## Working rules

- Vili said to stop asking before each plan step: build the step, playtest it, then commit it to `main` and push.
- Vili writes in Finnish; reply in Finnish. All in-game text, UI and console output must be in English.
- Write new code comments in English (older comments are still Finnish).
- Protect the twist: the main menu, how-to-play card, icon and description must read like a cheerful building game.

## Repo and sync

- Rojo 7.7 project managed with Rokit (`rokit.toml`). Mapping lives in `default.project.json`.
- Sync to Studio: `rojo serve`, then Connect in the Rojo plugin. Build a place file with `rojo build -o build-a-wall.rbxlx`.
- Scripts are plain `.luau` files. `RTSGui` is a text folder (`src/StarterGui/RTSGui/`). `Baseplate`, `EntitySpawn`, `EnemyCore` and `SpawnLocation` are `.model.json` files. `Hunter`, `Camera` and `Terrain` are still binary `.rbxm` files, so edit those in Studio. Every other screen is built in code by its script.
- The project uses the new input action system (`PlayerScriptsUseInputActionSystem`), so there is no `PlayerModule`; freezing the character relies on `WalkSpeed = 0`.

## Core loop

1. **Menu.** Cheerful main menu with a level picker over a slow camera sweep of the chosen level; orbs already bounce around behind it.
2. **RTS (build and route).** Top-down camera over a walled arena with a prebuilt maze. Cyan orbs fly out of the `EntitySpawn` pad every 2.5 s and bounce off walls like billiard balls. The player places pieces (budget per level) to steer them into the red core(s).
3. **Fake victory (the twist).** After the level's core hits: hard cut to first person in a dark concrete room with a ceiling and pulsing red alarms, a flashlight in hand, glitching "LEVEL CLEARED" and "- ERROR: BREACH DETECTED -", siren.
4. **Horror (survive and escape).** Thick fog, narrow flickering flashlight, heartbeat. The black `Hunter` with red eyes waits in its lair behind the core, creeps towards the player, then chases when it sees them. 3 lives. Reaching the green escape zone where the core was gives `TrueVictory`; losing all lives gives `GameOver`.
5. **End screens.** True victory: NEXT LEVEL (when there is one), PLAY AGAIN (build a new maze) or MAIN MENU. Game over: TRY AGAIN (same maze, escape again) or MAIN MENU. All restarts happen in place (no teleport), so they work in Studio too.

## Levels

Defined in `src/ReplicatedStorage/Levels.luau`: 1 The Grid, 2 Bumper Hall (spinning bumper bars, 20 pieces), 3 Twin Cores (two cores, 3 hits each, escape at the far one), 4 The Long Corridor (64x300, Hunter chases right away), 5 Blackout (flashlight battery drains in 40 s, 6 battery pickups refill it, thicker fog), 6 Two Hunters (a chaser plus a guard that patrols the escape zone). Each level has its size, spawn, cores (position and hits), escape position, budget, maze rectangles, bumpers and Hunter settings (`HUNTER_LAIR_WAIT`, `HUNTER_STALKS`), and optionally `HUNTERS` (roles), `BATTERY` and `HORROR_FOG`.

The server picks the level with the workspace attribute `Level` (`Remotes.SelectLevel` from the menu, or NEXT LEVEL). `ArenaLayout` reads every field of the current level (`ArenaLayout.HALF_X`, `.MAZE`, `.BUDGET`, ...), so code always gets the current level. `ArenaService` rebuilds the arena, moves the spawn pad and `EnemyCore`, and adds extra cores as `EnemyCore2`... inside the `Arena` folder. Winning a level unlocks the next (saved; every level is open in Studio). When adding a level, check the Output: the server warns if the prebuilt maze has no route from the spawn to the escape.

## How the code is organised

The client runs the game flow; the server owns the arena, the maze pieces, the Hunter, records and badges.

- **Client phase:** `GameState` ModuleScript (`src/ReplicatedStorage/GameState.luau`): `Menu` -> `RTS` -> `FakeVictory` -> `Horror` -> `TrueVictory` or `GameOver`. Scripts use `GameState.Is`, `GameState.OnPhase(phase, fn)` and `GameState.Changed` (listeners run in their own thread, in connect order). `MainMenu` sets `RTS`; `GameManager` sets the rest and reports every change to the server with `Remotes.PhaseReport`.
- **Round resets:** the end screens fire `Remotes.RestartRequest` (`Retry`, `PlayAgain`, `MainMenu`). `RestartService` resets the server (`ServerPhase.Reset`), tells the client with `Remotes.RoundReset`, then reloads the character. The client calls `GameState.Reset(target)`: `GameState.Resetting` listeners clean up first (must not wait), then `Changed` fires. `GameState.IsFullReset(target)` is true for `Menu` and `RTS` (new maze); `Horror` is the retry. Every script that changes the world handles `Resetting`.
- **Server phase:** `ServerPhase` ModuleScript (`src/ServerScriptService/ServerPhase.luau`) follows the client reports (forward only) and `Changed` fires with `(phase, player, isReset)`.

### Client scripts (`src/StarterPlayer/StarterPlayerScripts/` unless noted)

| Script | Does |
|---|---|
| `MainMenu` | Main menu (FredokaOne title, PLAY, HOW TO PLAY, flashing lights notice), the how-to-play card that also opens for 9 s at the start of every round, and floating "ENEMY CORE" / "ORBS START HERE" labels during `RTS`. |
| `CameraManager` | Menu: slow sweep. RTS: top-down, WASD or one-finger drag, wheel or pinch zoom (height 30 to 140), kept inside the arena. FakeVictory/Horror: `LockFirstPerson`, facing the maze; walking only in `Horror`. TrueVictory/GameOver: holds the last view and frees the mouse for the end screen buttons. |
| `GameManager` | Counts core hits (5) with flash, shake and sound. FakeVictory: hides the core, teleports the player onto the spawn pad facing the maze, `Horror` after 5 s. Horror: builds the `EscapeZone` folder (flat green pad, strong light, broken pillars) and sets `TrueVictory` when the player stands within 8 studs of its centre. 3 lives (`LivesLeft` attribute). Listens for `RoundReset`. |
| `EntitySpawner` | Orbs in `Menu` and `RTS` (`EnergyOrbs` folder), raycast bounce against `RTSWalls`, `Arena` and `EnemyCore` only, spark and ping on each bounce, `CoreHitEvent` on a core hit, never expire (only removed if outside the arena); at most 40 fly at once. Every round starts with an empty arena; the menu shows at most 6 orbs. |
| `ArenaGrid` | Glowing floor grid inside the arena (`CanQuery = false`), removed at `FakeVictory`, rebuilt on a new round. |
| `PhaseEffects` | Lighting and fog. FakeVictory: night, concrete floor, dimmed spawn pad, `ConcreteRoom` ceiling with pulsing red alarms. Horror: alarms off, thick dark `Atmosphere` fog that thins near the escape zone. TrueVictory: fog lifts. A new round restores the start look. |
| `Flashlight` | On `BATTERY` levels: battery bar, drain, spinning battery pickups (`BatteryPickups` folder, keep-clear spots for building). First-person hand with a flashlight (`FlashlightViewmodel` in Workspace; lights under the Camera do not render). Wide beam in `FakeVictory`, narrow and dim in `Horror`, flickers now and then and a lot when the Hunter is within 35 studs. |
| `FakeVictoryGui` | Black cut-in, glitching "LEVEL CLEARED" that gets worse, blinking red "- ERROR: BREACH DETECTED -". |
| `EndScreens` | Lives counter in `Horror`; victory and game over screens with escape time, best time, deaths, new-record line and the two buttons. |
| `BumperSpin` | Spins the bumper bars locally while building; snaps them back to the server position at the fake victory. |
| `AudioDirector` | Music and ambience per phase (see `SoundFx`): building music, hard cut + glitch + siren at the twist, drone music and a heartbeat that speeds up as the Hunter gets close, growl at game over. |
| `RTSGui/BuilderScript` (`src/StarterGui/RTSGui/`) | Neon build bar (BUILD toggle, Wall/Tower/Booster, ROTATE, REMOVE, piece budget, hints, refusal message) and the top core-hit HUD. B build mode, X remove mode, R rotate 45°, 1/2/3 pieces, right-click removes, touch tap places/removes. Red preview where placing is refused; pieces pop in with a sound. Only visible in `RTS`. |

### Server scripts (`src/ServerScriptService/`)

| Script | Does |
|---|---|
| `ArenaService` | Builds the `Arena` folder (border walls and prebuilt maze from `ArenaLayout`, dark steel with a pale neon line). Concrete at `FakeVictory`; rebuilt (same folder) on a new round. |
| `WallService` | Owns `RTSWalls`. `PlacePiece` / `RemovePiece` with rate limit, 30-piece budget, arena bounds, 45° rotations, no overlaps, keep-clear radius around the spawn pad and core, and a flood fill that refuses any Wall/Tower that would cut the route from the spawn to the core. Refusal messages go back on `PlacePiece`. Concrete at `FakeVictory`; cleared on a new round. |
| `HunterAI` | Clones the Workspace `Hunter` rig (kept in ServerStorage as `HunterTemplate`) for each role in the level's `HUNTERS`: `chaser` (below) and `guard` (patrols 18 studs around the escape, chases players who come within reach, gives up beyond 45 studs from the escape). Models are named `Hunter`, `Hunter2`...; clients use `ArenaLayout.NearestHunter`. Black rig with red eyes, walk/idle animations from the server, hidden in ServerStorage outside the horror. Horror: lair 14 studs behind the core, waits 6 s, creeps at 55% speed towards a spot near the player, chases (growl) when it sees the player within 28 studs or is within 14, loses track after 5 s. Speed 11 + 0.8 per past escape (`Wins`), max 15 (player 16). Footstep sounds, kill on touch, back to the lair with 3 s grace after a death. Hunt loops use a generation counter so a retry never runs two. |
| `RestartService` | Handles `SelectLevel` (menu only, unlocked levels) and `RestartRequest` (`Retry`, `PlayAgain`, `NextLevel`, `MainMenu`). |
| `RecordService` | DataStore `EscapeRecords_v1`: best escape time per level, escape count and highest unlocked level per player (attributes `Wins`, `UnlockedLevel`, `BestEscape` for the current level, `LastEscape`, `NewRecord`). Awards badges. DataStores only work in a published place (Studio also needs API access enabled). |
| `BadgeIds` | Badge ids: `Levels[n]` (awarded for escaping level n) and `Flawless` (escaped without dying); 0 means not created yet and is skipped. |

### Shared modules (`src/ReplicatedStorage/`)

`GameState`, `BuildPieces` (pieces, keep-clear radius, footprint helper), `Levels` and `ArenaLayout` (see Levels), `SoundFx` (every sound id in one place plus `Play`/`Loop` helpers; only Roblox-licensed APM music, Pro Sound Effects and built-in `rbxasset://sounds`), the `CoreHitEvent` BindableEvent and the `Remotes` folder (`PlacePiece`, `RemovePiece`, `PhaseReport`, `RestartRequest`, `RoundReset`, `SelectLevel`).

## Publishing checklist (Vili, on the Creator Dashboard)

- Server size 1 (Places > Configure > Server Size), since the game is single-player.
- Maturity & Compliance questionnaire (horror, jump scare, flashing lights).
- Create the badges and paste their ids into `BadgeIds`.
- Enable Studio access to API services to test records in Studio.

## Testing

Play in Studio: menu, PLAY, build and route orbs into the core, fake victory, horror (fog, flashlight, Hunter creeping then chasing), die 3 times for game over and TRY AGAIN, escape for true victory, PLAY AGAIN and MAIN MENU. Studio's viewport capture sometimes shows white; UI still renders.
