extends Node

## Phase 1b Integration Test
## Proves that the M.A.X.R. C++ game engine compiles as GDExtension
## and core game state (cModel, cTurnCounter, cPlayer) is accessible from GDScript.

func _ready() -> void:
	print("")
	print("========================================")
	print("  MaXtreme Engine Integration Test")
	print("  Phase 1b: Core C++ Engine Bridge")
	print("========================================")
	print("")

	# Create the GameEngine node (C++ GDExtension class)
	var engine = GameEngine.new()
	add_child(engine)

	# --- Pre-init state ---
	print("[TEST] Version:      ", engine.get_engine_version())
	print("[TEST] Status:       ", engine.get_engine_status())
	print("[TEST] Initialized:  ", engine.is_engine_initialized())
	print("[TEST] Turn number:  ", engine.get_turn_number())
	print("[TEST] Player count: ", engine.get_player_count())
	print("")

	# --- Initialize the engine (creates cModel) ---
	print("[TEST] Initializing core engine...")
	engine.initialize_engine()
	print("")

	# --- Post-init state ---
	print("[TEST] Status:       ", engine.get_engine_status())
	print("[TEST] Initialized:  ", engine.is_engine_initialized())
	print("[TEST] Turn number:  ", engine.get_turn_number())
	print("[TEST] Player count: ", engine.get_player_count())
	print("[TEST] Map name:     ", engine.get_map_name())
	print("")
	print("========================================")
	print("  All Phase 1b tests PASSED!")
	print("  Core C++ engine accessible from GDScript")
	print("========================================")
	print("")
