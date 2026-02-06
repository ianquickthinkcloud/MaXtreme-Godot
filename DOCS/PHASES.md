# MaXtreme - Development Phases

## Porting M.A.X.R. (C++) to Godot Engine

---

### Phase 1: Setup & Core Engine Compilation [COMPLETE]
- Initialized Godot 4 project structure
- Set up `godot-cpp` as a Git submodule (branch 4.5)
- Created minimal GDExtension with SConstruct (C++20)
- Copied M.A.X.R. core C++ engine source files
- Created SDL2/SDL_mixer/SDL_net replacement stubs
- Got full core engine compiling as a GDExtension library
- Verified `cModel` instantiates successfully from GDScript

### Phase 2: Data Bridge [COMPLETE]
- Created `GameMap` GDExtension wrapper for `cMap`/`cStaticMap`
- Created `GamePlayer` GDExtension wrapper for `cPlayer`
- Created `GameUnit` GDExtension wrapper for `cUnit`/`cVehicle`/`cBuilding`
- Expanded `GameEngine` to provide access to all wrappers
- All core data structures accessible from GDScript

### Phase 3: Action System Bridge [COMPLETE]
- Created `GameActions` GDExtension class
- 24 methods wrapping the M.A.X.R. `cAction` system
- Covers: movement, combat, construction, production, logistics, special, turns

### Phase 4: Game Initialization [COMPLETE]
- Created `GameSetup` GDExtension class
- Programmatic WRL map generation (flat terrain)
- Test unit data definitions (8 vehicle types, 5 building types)
- Player creation and starting unit deployment
- `new_game_test()` and `new_game()` entry points

### Phase 5: Turn System & Game Loop [COMPLETE]
- Integrated M.A.X.R. turn system into `GameEngine`
- `advance_tick()`, `end_player_turn()`, turn state queries
- Signals for turn transitions (`turn_started`, `turn_ended`, `player_finished_turn`)
- Simultaneous turn-based mode working

### Phase 6: Minimal Visual Prototype [COMPLETE]
- Map rendered as colored tiles (`map_renderer.gd`)
- Units rendered as colored shapes with HP bars (`unit_renderer.gd`)
- Camera with pan (WASD/edge scroll) and zoom (`game_camera.gd`)
- Basic HUD with turn info, player info, unit info (`game_hud.gd`)
- Click to select, click to move, right-click to deselect
- Main game scene tying everything together (`main_game.gd`)

### Phase 7: Pathfinding & Movement Visualization [COMPLETE]
- Created `GamePathfinder` GDExtension class
  - A* pathfinding via `cPathCalculator`
  - Dijkstra flood-fill for reachable tile calculation
  - Movement cost queries and range checks
- Movement range overlay with cost gradient (`overlay_renderer.gd`)
- Path preview on hover (white line with waypoint dots)
- Smooth movement animation along paths (`move_animator.gd`)
- Proper pathfinding integrated into move commands
- Fixed missing terrain factors on Constructor/Surveyor/Engineer units

### Phase 8: Combat & Attack Visualization [COMPLETE]
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
- Combat flow: select unit -> see enemies in range -> hover for damage preview -> click to attack
- Input blocked during attack animations for clean sequencing

### Phase 9: Production & Construction (planned)
- Factory/building production queue
- Constructor building placement
- Build progress visualization
- Resource cost deduction

### Phase 10: Resource System (planned)
- Mining operations
- Resource display on map
- Surveyor resource scanning
- Resource economy HUD

### Phase 11: Fog of War (planned)
- Per-player visibility based on scan range
- Explored vs unexplored vs visible tiles
- Hidden enemy units

### Phase 12: Audio (planned)
- Sound effects for combat, movement, UI
- Music system
- Godot AudioStreamPlayer integration

### Phase 13: AI Opponent (planned)
- Basic computer player logic
- Unit command priorities
- Threat assessment
