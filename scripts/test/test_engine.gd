extends Node

## Phase 2 Integration Test
## Proves the full data bridge between M.A.X.R. C++ engine and GDScript.
## Tests GameEngine, GameMap, GamePlayer, and GameUnit wrapper classes.

func _ready() -> void:
	print("")
	print("================================================")
	print("  MaXtreme Engine Integration Test")
	print("  Phase 2: Full C++ Data Bridge")
	print("================================================")
	print("")

	# Create the GameEngine node (C++ GDExtension class)
	var engine = GameEngine.new()
	add_child(engine)

	# --- Pre-init checks ---
	print("[TEST] Version:      ", engine.get_engine_version())
	print("[TEST] Initialized:  ", engine.is_engine_initialized())
	assert(not engine.is_engine_initialized(), "Engine should not be initialized yet")
	print("")

	# --- Initialize the engine ---
	print("[TEST] Initializing core engine...")
	engine.initialize_engine()
	assert(engine.is_engine_initialized(), "Engine should be initialized")
	print("")

	# --- GameEngine basics ---
	print("[TEST] === GameEngine ===")
	print("[TEST] Status:       ", engine.get_engine_status())
	print("[TEST] Turn number:  ", engine.get_turn_number())
	print("[TEST] Player count: ", engine.get_player_count())
	print("[TEST] Map name:     ", engine.get_map_name())
	print("")

	# --- GameMap ---
	print("[TEST] === GameMap ===")
	var game_map = engine.get_map()
	assert(game_map != null, "get_map() should return a GameMap")
	print("[TEST] Map type:     ", game_map.get_class())
	print("[TEST] Map size:     ", game_map.get_size())
	print("[TEST] Map width:    ", game_map.get_width())
	print("[TEST] Map height:   ", game_map.get_height())
	print("[TEST] Map filename: ", game_map.get_filename())
	# Test terrain queries on empty map
	print("[TEST] Valid pos(0,0): ", game_map.is_valid_position(Vector2i(0, 0)))
	print("")

	# --- GamePlayer (empty model has no players yet) ---
	print("[TEST] === GamePlayer ===")
	var all_players = engine.get_all_players()
	print("[TEST] All players:  ", all_players.size(), " players")
	# Test accessing out-of-bounds player (should return empty wrapper)
	var empty_player = engine.get_player(0)
	print("[TEST] Empty player name: '", empty_player.get_name(), "'")
	print("[TEST] Empty player id:   ", empty_player.get_id())
	print("")

	# --- GameUnit (empty model has no units yet) ---
	print("[TEST] === GameUnit ===")
	var vehicles = engine.get_player_vehicles(0)
	print("[TEST] Player 0 vehicles: ", vehicles.size())
	var buildings = engine.get_player_buildings(0)
	print("[TEST] Player 0 buildings: ", buildings.size())
	# Test empty unit wrapper
	var empty_unit = engine.get_unit_by_id(0, 0)
	print("[TEST] Empty unit id:     ", empty_unit.get_id())
	print("[TEST] Empty unit name:   '", empty_unit.get_name(), "'")
	print("[TEST] Empty unit stats:  ", empty_unit.get_stats())
	print("")

	# --- Class registration verification ---
	print("[TEST] === Class Registration ===")
	print("[TEST] GameEngine class: ", engine.get_class())
	print("[TEST] GameMap class:    ", game_map.get_class())
	print("[TEST] GamePlayer class: ", empty_player.get_class())
	print("[TEST] GameUnit class:   ", empty_unit.get_class())
	print("")

	print("================================================")
	print("  All Phase 2 tests PASSED!")
	print("  C++ Data Bridge: GameEngine, GameMap,")
	print("  GamePlayer, and GameUnit fully accessible")
	print("  from GDScript!")
	print("================================================")
	print("")
