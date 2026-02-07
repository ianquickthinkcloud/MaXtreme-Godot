# MaXtreme -- Development Phases

## Porting M.A.X.R. (C++) to Godot 4.6 using GDExtension Hybrid Architecture

The C++ game engine (model, actions, turns, pathfinding, combat) stays as a GDExtension.
All rendering, UI, sound, and input are rebuilt natively in Godot.

---

## Completed

### Phase 1: Setup & Core Engine Compilation

- Initialized Godot 4.6 project structure
- Set up `godot-cpp` as a Git submodule (branch 4.5)
- Created GDExtension build system with SConstruct (C++20)
- Copied M.A.X.R. core C++ engine source files
- Created SDL2/SDL_mixer/SDL_net replacement stubs
- Got full core engine compiling as a GDExtension library
- Verified `cModel` instantiates successfully from GDScript

### Phase 2: Data Bridge

- Created `GameMap` GDExtension wrapper for `cMap`/`cStaticMap`
- Created `GamePlayer` GDExtension wrapper for `cPlayer`
- Created `GameUnit` GDExtension wrapper for `cUnit`/`cVehicle`/`cBuilding`
- Expanded `GameEngine` to provide access to all wrappers
- All core data structures accessible from GDScript

### Phase 3: Action System Bridge

- Created `GameActions` GDExtension class
- 24 methods wrapping the M.A.X.R. `cAction` system
- Covers: movement, combat, construction, production, logistics, special, turns

### Phase 4: Game Initialization

- Created `GameSetup` GDExtension class
- Programmatic WRL map generation (flat terrain)
- Test unit data definitions (8 vehicle types, 5 building types)
- Player creation and starting unit deployment
- `new_game_test()` and `new_game()` entry points

### Phase 5: Turn System & Game Loop

- Integrated M.A.X.R. turn system into `GameEngine`
- `advance_tick()`, `end_player_turn()`, turn state queries
- Signals for turn transitions (`turn_started`, `turn_ended`, `player_finished_turn`)
- Simultaneous turn-based mode working

### Phase 6: Minimal Visual Prototype

- Map rendered as colored tiles (`map_renderer.gd`)
- Units rendered as colored shapes with HP bars (`unit_renderer.gd`)
- Camera with pan (WASD/edge scroll) and zoom (`game_camera.gd`)
- Basic HUD with turn info, player info, unit info (`game_hud.gd`)
- Click to select, click to move, right-click to deselect
- Main game scene tying everything together (`main_game.gd`)

### Phase 7: Pathfinding & Movement Visualization

- Created `GamePathfinder` GDExtension class
  - A* pathfinding via `cPathCalculator`
  - Dijkstra flood-fill for reachable tile calculation
  - Movement cost queries and range checks
- Movement range overlay with cost gradient (`overlay_renderer.gd`)
- Path preview on hover (white line with waypoint dots)
- Smooth movement animation along paths (`move_animator.gd`)
- Proper pathfinding integrated into move commands
- Fixed missing terrain factors on Constructor/Surveyor/Engineer units

### Phase 8: Combat & Attack Visualization

- Exposed combat data to GDScript: `canAttack` bitfield, `muzzle_type`, `calc_damage_to()`, `is_in_range_of()`
- Attack range methods in GamePathfinder: `get_enemies_in_range()`, `get_attack_range_tiles()`, `preview_attack()`
- Attack range overlay (red tint on tiles in range, red highlight on enemies)
- Targeting reticle with damage preview on hover
- Full attack animation sequence (`combat_effects.gd`):
  - Muzzle flash (color varies by weapon type)
  - Projectile with trail (speed based on distance)
  - Impact/explosion effects with particle debris
  - Floating damage numbers (red for kills, yellow for hits)
- Updated HUD: shows attack stats (damage, range, shots, ammo)
- Combat flow: select unit, see enemies in range, hover for damage preview, click to attack
- Input blocked during attack animations for clean sequencing

### Phase 9: Real Data Loading

- Replaced all hardcoded test data with the original M.A.X.R. JSON data loading system
- Copied full `data/` directory from maxr-release-0.2.17 (vehicles, buildings, clans, maps, assets)
- Created adapted `loaddata.cpp` for GDExtension (JSON loading only, no graphics/sound)
  - `LoadVehicles()` -- reads `vehicles.json` + 37 `data.json` files
  - `LoadBuildings()` -- reads `buildings.json` + 42 `data.json` files, sets special building IDs
  - `LoadClans()` -- reads `clans.json` with 8 clans and unit stat modifications
- Added stub UI data types for JSON deserialization compatibility
- Added `cSettings::setDataDir()` for configurable data directory paths
- Rewrote `GameSetup` to use `LoadData(false)` instead of `create_test_units_data()`
  - Loads real maps from `data/maps/` (5 WRL maps: Delta, Three Isles, Mushroom, Lava, Donuts)
  - Falls back to generated flat map if no real maps available
  - Supports per-player clan selection via `player->setClan()`
- New GDScript API: `load_game_data()`, `get_available_maps()`, `get_available_clans()`, `get_unit_data_info()`, updated `new_game()` signature
- Data loaded: 35 vehicles, 33 buildings, 8 clans, 5 real maps

### Phase 10: PCX to PNG Asset Conversion

- Created `tools/convert_pcx_to_png.py` -- Python + Pillow batch converter
- Recursively converts all 1,113 PCX files under `data/` to PNG format
  - 816 vehicle sprites, 171 building sprites, 95 UI graphics, 15 effects, 15 fonts, 1 init screen
- Handles M.A.X.R. transparency: palette index 0 converted to alpha channel (RGBA output)
- Output PNGs placed alongside originals (e.g. `data/vehicles/tank/img0.png` next to `img0.pcx`)
- Smart skip logic: re-running only converts files where the PCX is newer than the PNG
- CLI options: `--force`, `--no-transparency`, `--dry-run`, `--data-dir`
- Zero failures across all 1,113 files; completes in ~6 seconds

### Phase 11: Building & Economy

- Extended `GameUnit` C++ wrapper with ~25 new building/economy methods:
  - Construction: `get_can_build()`, `is_constructor()`, `get_buildable_types()`, `is_building_a_building()`, `get_build_turns_remaining()`, `get_build_costs_remaining()`
  - Production: `is_working()`, `can_start_work()`, `get_build_list()`, `get_build_list_size()`, `get_producible_types()`, `get_build_speed()`, `get_metal_per_round()`, `get_repeat_build()`
  - Mining: `get_mining_production()`, `get_mining_max()`
  - Research: `get_research_area()`
  - Misc: `can_be_upgraded()`, `connects_to_base()`, `get_energy_production()`, `get_energy_need()`, `get_description()`, `get_build_cost()`
- Extended `GamePlayer` C++ wrapper with ~10 new economy methods:
  - Resources: `get_resource_storage()`, `get_resource_production()`, `get_resource_needed()`
  - Energy: `get_energy_balance()`
  - Humans: `get_human_balance()`
  - Research: `get_research_levels()`, `get_research_centers_per_area()`
  - Summary: `get_economy_summary()`
- Resource display bar in HUD with Metal/Oil/Gold storage and net rates, Energy, Credits
- Building placement system:
  - `build_panel.gd` -- constructor building selection panel
  - Build mode state machine in `main_game.gd`
  - Green/red placement overlay preview
  - Position validation for 1x1 and 2x2 buildings
- Factory production queue:
  - `production_panel.gd` -- queue management, progress bar, speed cycling, repeat, start/stop
- Construction progress visualization: progress bars, working indicators, construction icons

### Phase 12: Sprite Loading

- Created `scripts/game/sprite_cache.gd` -- texture loading and caching system
  - `get_vehicle_texture(type_name, direction)` -- loads `data/vehicles/{name}/img{dir}.png`
  - `get_building_texture(type_name)` -- loads `data/buildings/{name}/img.png`
  - `get_unit_icon(type_name, is_vehicle)` -- loads store/info icons
  - Lazy loading with dictionary cache; graceful null fallback for missing files
- Updated `unit_renderer.gd` to use real PNG sprites:
  - Vehicles: sprite texture centered on tile, with 40% player color tint
  - Buildings: sprite scaled to fit tile footprint (1x1 or 2x2)
  - Falls back to colored shapes when sprite is missing
- Sprite cache instantiated in `main_game.gd` and passed to `unit_renderer`

---

## Up Next

### Phase 13: Menus & Game Flow [COMPLETE]

- `GameManager` autoload singleton (`scripts/autoloads/game_manager.gd`):
  - Persists across scene changes; holds game config, settings, scene transitions
  - Settings saved to `user://settings.cfg` (display, audio, controls)
  - `go_to_main_menu()`, `go_to_new_game_setup()`, `start_game(config)`, `quit_game()`
- Main menu scene (`scenes/menus/main_menu.tscn` + `scripts/ui/main_menu.gd`):
  - New Game, Load Game (disabled until saves exist), Settings, Exit buttons
  - Inline settings panel with fullscreen, vsync, volume sliders
  - Now the project's main scene (was previously the game scene directly)
- New game setup screen (`scenes/menus/new_game_setup.tscn` + `scripts/ui/new_game_setup.gd`):
  - Map selection (lists all 5 WRL maps from engine data)
  - Up to 4 players: enable/disable, custom names, colors, clan selection
  - Starting credits spinner (50-9999, step 50)
  - Loads game data via temporary GameEngine, passes config to GameManager
- Save/Load C++ API added to `GameEngine`:
  - `save_game(slot, name)` -- saves current game state to JSON via `cSavegame`
  - `load_game(slot)` -- loads game state from slot, reconnects all model signals
  - `get_save_game_list()` -- lists all save slots (1-100) with metadata
  - `get_save_game_info(slot)` -- returns slot details (name, date, turn, map, players)
- In-game pause menu (ESC key):
  - Dimmed overlay with Resume, Settings, Quit to Menu buttons
  - Settings panel reusable component (`settings_panel.gd`)
  - Pauses game tick processing and blocks all game input
- Victory/defeat screens (`game_over_screen.gd`):
  - Triggered by `player_won` / `player_lost` engine signals
  - Shows result with player name, Continue Playing or Return to Menu buttons
- Full game flow wired:
  - Main Menu -> New Game Setup -> Game -> (ESC: Pause) -> (Victory/Defeat) -> Main Menu
  - Game scene supports both configured launch (via GameManager) and direct test launch (fallback)

### Phase 14: Fog of War [COMPLETE]

- Extended `GamePlayer` C++ wrapper with visibility methods:
  - `can_see_at(Vector2i pos)` -- checks if tile is in player's scan range
  - `get_scan_map_data()` -- returns full scan map as PackedInt32Array (bulk data for performance)
  - `get_scan_map_size()` -- returns scan map dimensions
  - Wraps M.A.X.R.'s `cRangeMap` scan system (`cPlayer::scanMap`)
- Created `scripts/game/fog_renderer.gd` -- fog of war overlay:
  - Three tile states: visible (clear), explored (semi-dark), unexplored (full dark)
  - Reads bulk scan map data from engine each refresh (avoids per-tile C++ calls)
  - Maintains persistent `_explored_tiles` dictionary tracking tiles ever seen
  - Draws fog rectangles only for non-visible tiles (optimized skip for visible)
  - `fog_enabled` toggle for disabling fog
- Updated `unit_renderer.gd` to hide enemy units in fog:
  - Added `fog_renderer` and `current_player` references
  - Enemy units on non-visible tiles are skipped during `_draw()`
  - Own units always visible regardless of fog
- Integrated into game flow:
  - FogRenderer node added to `main_game.tscn` (draws above terrain, below units)
  - Fog refreshed after: movement, attacks, building, turn changes
  - `_refresh_fog()` helper in `main_game.gd` called at all state change points

### Phase 15: Audio [COMPLETE]

- Created `AudioManager` autoload singleton (`scripts/autoloads/audio_manager.gd`):
  - Manages SFX playback via round-robin pool of 8 AudioStreamPlayers
  - Music playback with auto-advance to next track on finish
  - Lazy `.ogg` file loading with dictionary cache (sentinel for missing files)
  - Programmatic audio bus setup: Master -> Music bus, Master -> SFX bus
  - `play_sound(name)` -- play global SFX by logical name (click, arm, absorb, etc.)
  - `play_unit_sound(type_name, action, is_water)` -- play per-unit sound from `data/vehicles/{type}/`
  - `play_music()` / `stop_music()` -- background music with auto-advance playlist
  - Volume control: `set_master_volume()`, `set_music_volume()`, `set_sfx_volume()` (0-100 scale)
- 21 existing `.ogg` assets used (all Godot-native, no conversion needed):
  - `data/sounds/` -- 4 global SFX (absorb, arm, Chat, dummy)
  - `data/vehicles/awac/` -- 4 sounds (start, stop, drive, wait)
  - `data/vehicles/surveyor/` -- 8 sounds (land + water variants)
  - `data/vehicles/sub/` -- 5 sounds (water variants + attack)
- Music system framework ready (reads `data/music/musics.json` playlist):
  - References 13 background tracks (not yet present -- will work once files are dropped in)
  - Main menu starts `main.ogg`; game scene plays random background track
- Unit movement sounds wired into `move_animator.gd`:
  - `start.ogg` + `drive.ogg` on move begin; `stop.ogg` on move end
  - Per-vehicle type from `data/vehicles/{type_name}/`; water variants supported
- Combat sounds wired into `combat_effects.gd`:
  - Plays per-unit `attack.ogg` (falls back to generic `arm.ogg`)
- UI sounds wired into menus and game:
  - Menu button clicks (main menu, pause menu)
  - Build placement, turn end
- Volume settings connected bidirectionally:
  - `GameManager._apply_settings()` pushes to `AudioManager`
  - `AudioManager._ready()` reads initial settings from `GameManager`
  - Settings panel sliders -> `GameManager` -> `AudioManager` in real-time

### Phase 16: Networking & Multiplayer [COMPLETE]

- **SDL_net replacement** (`stubs/SDL/SDL_net.h`):
  - Replaced all 15 stubbed SDL_net functions with real POSIX BSD socket implementations (~270 lines)
  - `SDLNet_ResolveHost` via `getaddrinfo()`, `SDLNet_TCP_Open` via `socket()`+`bind()`+`listen()` (server) or `connect()` (client)
  - `SDLNet_TCP_Accept`, `SDLNet_TCP_Close`, `SDLNet_TCP_Send` (loop send), `SDLNet_TCP_Recv`
  - Socket set polling via `select()`: `SDLNet_AllocSocketSet`, `SDLNet_CheckSockets`, `SDLNet_SocketReady`
  - `TCP_NODELAY` enabled for low-latency game traffic; `SO_REUSEADDR` for quick restarts
- **SDL_AddTimer replacement** (`stubs/SDL/SDL.h`):
  - Real `std::thread`-based periodic timer with `std::atomic<bool>` stop flag
  - Timer registry with mutex-protected `std::map<SDL_TimerID, TimerState>`
  - Supports both one-shot (callback returns 0) and repeating (returns interval) timers
  - Powers M.A.X.R.'s 10ms lockstep game timer and handshake timeouts
- **GameEngine multiplayer mode** (`game_engine.h/cpp`):
  - `NetworkMode` enum: `SINGLE_PLAYER`, `HOST`, `CLIENT`
  - `get_active_model()` accessor transparently returns the right `cModel*` for current mode
  - `accept_lobby_handoff()` receives `cConnectionManager`/`cServer`/`cClient` from lobby
  - In multiplayer, `advance_tick()` and `advance_ticks()` are no-ops (lockstep timer handles ticks)
  - New signals: `freeze_mode_changed`, `connection_lost`
  - All 20+ model-accessing methods updated to use `get_active_model()` instead of direct `model` member
- **GameActions multiplayer routing** (`game_actions.h/cpp`):
  - Added `cClient*` member with `set_internal_client()` method
  - All 24 action methods route through `cClient` when set (multiplayer), fall back to direct `cAction::execute()` (single-player)
  - Transparent to GDScript -- the API doesn't change
- **GameLobby GDExtension class** (`game_lobby.h/cpp`):
  - Wraps `cLobbyServer` and `cLobbyClient` with Godot signals and methods
  - Host: `host_game(port, name, color)`, `select_map()`, `start_game()`
  - Client: `join_game(host, port, name, color)`, `set_ready()`, `change_player_info()`
  - Shared: `send_chat()`, `get_player_list()`, `poll()`, `handoff_to_engine()`
  - 11 Godot signals: `player_joined`, `player_left`, `chat_received`, `map_changed`, `game_starting`, etc.
  - Registered in GDExtension module alongside other classes
- **Host Game screen** (`host_game.tscn` + `host_game.gd`):
  - Player name, port (default 58600), color picker
  - Creates GameLobby, calls `host_game()`, reparents lobby to GameManager, transitions to lobby
- **Join Game screen** (`join_game.tscn` + `join_game.gd`):
  - Player name, host IP, port, color picker
  - Creates GameLobby, calls `join_game()`, handles connection success/failure
  - Transitions to lobby on successful connection
- **Lobby screen** (`lobby.tscn` + `lobby.gd`):
  - Player list (names, colors, ready status)
  - Map selection dropdown (host only, loaded from engine data)
  - Chat history with BBCode formatting + input field
  - Map download progress bar (for clients receiving maps)
  - Ready toggle (client), Start Game button (host, enabled when all ready)
  - Calls `GameLobby.poll()` in `_process()` for message handling
- **GameManager updates** (`game_manager.gd`):
  - New scene constants: `SCENE_HOST_GAME`, `SCENE_JOIN_GAME`, `SCENE_LOBBY`
  - New state: `lobby` (GameLobby reference), `lobby_role` ("host"/"client")
  - New methods: `go_to_host_game()`, `go_to_join_game()`, `go_to_lobby()`
- **Main menu updates** (`main_menu.gd` + `main_menu.tscn`):
  - "New Game" renamed to "SINGLE PLAYER"
  - Added "HOST GAME" and "JOIN GAME" buttons
- **In-game multiplayer** (`main_game.gd`):
  - Detects multiplayer from `game_config["multiplayer"]`
  - Lobby handoff to engine on game start
  - Skips auto-ending other players' turns in multiplayer
  - Network status overlay for freeze modes
  - Connection lost handling with auto-return to menu
- **Network status overlay** (`network_status.gd`):
  - Semi-transparent fullscreen overlay for freeze mode display
  - "Waiting for network..." message during freezes
  - "Connection Lost!" message with auto-redirect
- **In-game chat overlay** (`chat_overlay.gd`):
  - Semi-transparent chat history (bottom-left), fades after 8s inactivity
  - Activated by Enter/T key, dismissed by Escape
  - Routes messages through GameLobby
  - BBCode formatted player names + system messages

### Phase 17: Advanced Graphics & Polish [COMPLETE]

- **Global UI Theme** (`scripts/autoloads/theme_setup.gd`):
  - Dark sci-fi/military aesthetic applied project-wide via `get_tree().root.theme`
  - Styled: Button (normal/hover/pressed/disabled/focus), PanelContainer, LineEdit, SpinBox
  - Styled: CheckBox, OptionButton, ItemList, ScrollBar, ProgressBar, HSlider, HSeparator
  - Styled: PopupMenu, RichTextLabel, TooltipPanel
  - Color scheme: deep blue-gray backgrounds, cyan accent highlights, high-contrast text
  - Consistent corner radii, border widths, content margins, shadow effects
- **Enhanced Sprite Cache** (`scripts/game/sprite_cache.gd`):
  - Vehicle directional sprites: `get_vehicle_texture(type, dir)` loads `img0-7.png` (8 directions)
  - Vehicle shadows: `get_vehicle_shadow(type, dir)` loads `shw0-7.png`
  - Animation frames: `get_vehicle_anim_frame(type, dir, frame)` for infantry/commando (`img0-7_00-12.png`)
  - Animation detection: `has_animation_frames()`, `get_animation_frame_count()`
  - Building sprites: main (`img.png`), shadow (`shw.png`), effect overlay (`effect.png`), video (`video.png`)
  - Unit icons: `get_unit_icon()` loads `store.png` (vehicles) / `info.png` (buildings)
  - FX sprites: `get_fx_texture()` loads from `data/fx/` (explosions, muzzle, projectiles, smoke, corpse)
  - GFX assets: `get_gfx_texture()` loads from `data/gfx/` (logo, HUD elements)
  - Preloading: `preload_vehicle()` / `preload_building()` for batch loading
- **Terrain Renderer Overhaul** (`scripts/game/map_renderer.gd`):
  - Procedural terrain with `FastNoiseLite` (Simplex FBM, 3 octaves) for natural variation
  - Rich terrain palette: 3 ground shades, 3 water depths, 3 coast variants, 3 rock tones
  - Animated water with shimmer effects (moving light reflections, subtle wave patterns)
  - Coastal transitions: water-edge blending on land tiles adjacent to water (foam lines)
  - Adaptive grid: thicker lines every 8 tiles, alpha fades based on zoom level
  - Viewport-culled rendering: only draws tiles visible on screen
  - Pre-computed terrain and neighbor caches for fast rendering
  - `get_terrain_color_at()` utility for minimap
- **Unit Renderer Overhaul** (`scripts/game/unit_renderer.gd`):
  - Directional sprites: units face based on last movement direction (8 directions, 0-7)
  - Shadow rendering: shadow sprites drawn in a separate pass beneath all units
  - Animated units: infantry/commando frame cycling at 8 FPS during movement
  - Player color tinting: 35% strength on vehicles, 21% on buildings
  - Pulsing selection indicators: cyan ring for vehicles, bracket corners for buildings
  - HP bars: only shown on damaged units, green->yellow->red gradient
  - Building effects: `effect.png` overlay on working buildings with pulse animation
  - Construction badges: gear icon on constructing vehicles
  - Build progress bars: blue->cyan gradient
  - Damage effects: crack lines and sparks on heavily damaged units (<40% HP)
  - Procedural fallbacks: colored shapes with direction indicators when sprites missing
  - Viewport-culled: only draws units visible on screen
  - Two-pass rendering: shadows first, then units on top
- **Combat Effects Overhaul** (`scripts/game/combat_effects.gd`):
  - Real FX sprites: muzzle flashes (`muzzle_big/med/small.png`), explosions (`explo_big/small/air/water.png`)
  - Projectile sprites: `rocket.png`, `torpedo.png` with rotation toward target
  - Weapon-specific FX configs: Big, Rocket, RocketCluster, Small, Med, Torpedo, Sniper
  - Trail effects on projectiles (fading line behind moving projectile)
  - Procedural tracers for instant-hit weapons
  - Smoke effects (`dark_smoke.png`) rising from destroyed units
  - Corpse wreckage (`corpse.png`) that lingers and fades
  - Debris particles on kills (8 particles radiating outward)
  - "DESTROYED" text label on kill shots
  - All sprites lazy-loaded from shared sprite cache
- **Build & Production Panel Icons** (`scripts/ui/build_panel.gd`, `scripts/ui/production_panel.gd`):
  - Building entries show `info.png` icons alongside name and cost
  - Production queue shows `store.png` icons for queued units
  - "Add Unit" list shows icons for available production options
  - Icons loaded via shared sprite cache
- **Minimap** (`scripts/game/minimap.gd`):
  - 180x180 pixel overview map in bottom-right corner of HUD
  - Terrain rendered as pre-generated `ImageTexture` from map data
  - Unit dots: color-coded by player, vehicles (small) and buildings (larger, lighter)
  - Fog of war overlay: dark for unexplored, semi-dark for explored-but-not-visible
  - Enemy units hidden by fog not shown on minimap
  - Camera viewport rectangle showing current view area
  - Click-to-pan: click anywhere on minimap to pan camera to that location
  - Draggable: hold and drag to continuously pan
  - Auto-refresh with fog/unit updates
- **HUD Overhaul** (`scripts/game/game_hud.gd` + `main_game.tscn`):
  - Compact top bar: turn number, player info, active/waiting status
  - Resource bar: metal/oil/gold with storage, net production, color-coded deficits
  - Energy display with production vs. need, color-coded surplus/deficit
  - Credits display in gold
  - Unit panel with icon (store.png/info.png), name, ID, full stats
  - Combat stats line (damage, range, shots, ammo) - only shown for armed units
  - HP color coding: green (>60%), yellow (30-60%), red (<30%)
  - Extra info for buildings (production status, mining output) and constructors
  - Bottom bar with tile coordinates and END TURN button
  - Minimap container in bottom-right
  - Semi-transparent backgrounds for readability without obscuring game
- **Overlay Renderer Polish** (`scripts/game/overlay_renderer.gd`):
  - Movement range: 4-color gradient (blue->teal->orange->red) based on movement cost
  - Range border: edge detection drawing borders only at reachable area boundary
  - Path preview: dual-width line (glow + bright), waypoint dots, pulsing destination marker, direction arrow
  - Attack range: red tint with edge borders, pulsing enemy highlight rectangles
  - Targeting reticle: animated crosshair with inner circle, damage prediction text, "KILL" indicator
  - Build preview: pulsing valid (green) / invalid (red) overlay with grid lines and label
- **Fog of War Polish** (`scripts/game/fog_renderer.gd`):
  - Viewport-culled rendering (only draws fog for visible tiles)
  - Edge softening: subtle gradient at boundary between unexplored and explored fog
  - Cleaner colors: deeper unexplored fog, subtle explored overlay
- **Menu Polish** (`scripts/ui/main_menu.gd` + `main_menu.tscn`):
  - Logo image loaded from `data/gfx/logo.png`
  - Animated background with subtle color shifting
  - Cyan accent on title text
  - Larger, more spacious button layout (300px wide, 50px tall)
  - Version label updated to v0.5.0
  - Fixed Join Game button (was calling `go_to_host_game()`, now calls `go_to_join_game()`)
- **Move Animator Direction Tracking** (`scripts/game/move_animator.gd`):
  - New `direction_changed` signal emitted when unit changes movement segment
  - `_calc_direction()` converts tile delta to 8-direction index
  - Initial direction emitted at animation start
  - Wired to `unit_renderer._unit_directions` in `main_game.gd`

---

## Future / Post-Release

- AI Opponent -- computer player logic, threat assessment, difficulty levels
- New visual assets -- replace M.A.X.R. sprites with modern artwork
- Map editor -- built in Godot with TileMap editing tools
- Replay system -- record and playback action sequences
- Mobile port -- Godot exports to Android/iOS
- Web port -- Godot exports to HTML5/WebAssembly
- Steam integration -- Steamworks via GDExtension
