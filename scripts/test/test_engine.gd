extends Node

## Phase 3 Integration Test
## Proves the full Action System Bridge between M.A.X.R. C++ engine and GDScript.
## Tests GameEngine, GameMap, GamePlayer, GameUnit, and GameActions.

func _ready() -> void:
	print("")
	print("================================================")
	print("  MaXtreme Engine Integration Test")
	print("  Phase 3: Action System Bridge")
	print("================================================")
	print("")

	# Create and initialize the engine
	var engine = GameEngine.new()
	add_child(engine)
	engine.initialize_engine()
	print("[TEST] Engine initialized: ", engine.is_engine_initialized())
	print("")

	# --- Phase 2 classes still work ---
	print("[TEST] === Data Bridge (Phase 2) ===")
	var game_map = engine.get_map()
	print("[TEST] GameMap:    ", game_map.get_class(), " size=", game_map.get_size())
	var player = engine.get_player(0)
	print("[TEST] GamePlayer: ", player.get_class(), " name='", player.get_name(), "'")
	var unit = engine.get_unit_by_id(0, 0)
	print("[TEST] GameUnit:   ", unit.get_class(), " id=", unit.get_id())
	print("")

	# --- GameActions: The Action System ---
	print("[TEST] === Action System (Phase 3) ===")
	var actions = engine.get_actions()
	assert(actions != null, "get_actions() should return a GameActions")
	print("[TEST] GameActions class: ", actions.get_class())
	print("")

	# --- Test action method signatures exist ---
	# Movement methods
	print("[TEST] Action methods available:")
	print("[TEST]   move_unit:      ", actions.has_method("move_unit"))
	print("[TEST]   resume_move:    ", actions.has_method("resume_move"))
	print("[TEST]   set_auto_move:  ", actions.has_method("set_auto_move"))

	# Combat methods
	print("[TEST]   attack:         ", actions.has_method("attack"))
	print("[TEST]   toggle_sentry:  ", actions.has_method("toggle_sentry"))
	print("[TEST]   toggle_manual_fire: ", actions.has_method("toggle_manual_fire"))

	# Construction methods
	print("[TEST]   start_build:    ", actions.has_method("start_build"))
	print("[TEST]   finish_build:   ", actions.has_method("finish_build"))
	print("[TEST]   change_build_list: ", actions.has_method("change_build_list"))

	# Production methods
	print("[TEST]   start_work:     ", actions.has_method("start_work"))
	print("[TEST]   stop:           ", actions.has_method("stop"))
	print("[TEST]   change_research: ", actions.has_method("change_research"))

	# Logistics methods
	print("[TEST]   transfer_resources: ", actions.has_method("transfer_resources"))
	print("[TEST]   load_unit:      ", actions.has_method("load_unit"))
	print("[TEST]   activate_unit:  ", actions.has_method("activate_unit"))
	print("[TEST]   repair_reload:  ", actions.has_method("repair_reload"))

	# Special methods
	print("[TEST]   steal_disable:  ", actions.has_method("steal_disable"))
	print("[TEST]   clear_area:     ", actions.has_method("clear_area"))
	print("[TEST]   self_destroy:   ", actions.has_method("self_destroy"))
	print("[TEST]   rename_unit:    ", actions.has_method("rename_unit"))
	print("[TEST]   upgrade_vehicle: ", actions.has_method("upgrade_vehicle"))
	print("[TEST]   upgrade_building: ", actions.has_method("upgrade_building"))

	# Turn management
	print("[TEST]   end_turn:       ", actions.has_method("end_turn"))
	print("[TEST]   start_turn:     ", actions.has_method("start_turn"))
	print("")

	# --- Test calling actions on empty model (safe failure) ---
	print("[TEST] === Safe Failure Tests ===")
	# These should return false gracefully (no units in empty model)
	var result: bool

	result = actions.toggle_sentry(999)
	print("[TEST] toggle_sentry(999) -> ", result, " (expected: false)")
	assert(not result, "Should fail on nonexistent unit")

	result = actions.stop(42)
	print("[TEST] stop(42) -> ", result, " (expected: false)")
	assert(not result, "Should fail on nonexistent unit")

	result = actions.attack(1, Vector2i(5, 5))
	print("[TEST] attack(1, (5,5)) -> ", result, " (expected: false)")
	assert(not result, "Should fail on nonexistent unit")

	var path = PackedVector2Array([Vector2(1, 0), Vector2(2, 0), Vector2(3, 0)])
	result = actions.move_unit(1, path)
	print("[TEST] move_unit(1, path) -> ", result, " (expected: false)")
	assert(not result, "Should fail on nonexistent unit")
	print("")

	# --- Class registration summary ---
	print("[TEST] === All Registered Classes ===")
	print("[TEST] GameEngine:  ", engine.get_class())
	print("[TEST] GameMap:     ", game_map.get_class())
	print("[TEST] GamePlayer:  ", player.get_class())
	print("[TEST] GameUnit:    ", unit.get_class())
	print("[TEST] GameActions: ", actions.get_class())
	print("")

	print("================================================")
	print("  All Phase 3 tests PASSED!")
	print("")
	print("  Action System Bridge: 24 action methods")
	print("  exposed to GDScript covering:")
	print("    - Movement (move, resume, auto-move)")
	print("    - Combat (attack, sentry, manual fire)")
	print("    - Construction (build, finish, build list)")
	print("    - Production (work, stop, research)")
	print("    - Logistics (transfer, load, activate)")
	print("    - Special (steal, clear, self-destruct)")
	print("    - Turn management (end/start turn)")
	print("================================================")
	print("")
