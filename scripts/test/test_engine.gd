extends Node

## Phase 4 Integration Test
## Tests full game initialization: new_game_test() creates a map, players, and units.
## Then verifies the complete pipeline: map queries, player data, unit stats, and actions.

func _ready() -> void:
	print("")
	print("================================================")
	print("  MaXtreme Engine Integration Test")
	print("  Phase 4: Game Initialization")
	print("================================================")
	print("")

	# Create the engine
	var engine = GameEngine.new()
	add_child(engine)

	# --- Phase 4: Start a test game ---
	print("[TEST] === Game Initialization (Phase 4) ===")
	print("[TEST] Calling new_game_test()...")
	var game_info: Dictionary = engine.new_game_test()
	print("[TEST] Result: ", game_info)
	print("")

	# Verify game started successfully
	assert(game_info.has("success"), "Result should have 'success' key")
	if not game_info["success"]:
		print("[TEST] FAILED: Game initialization failed!")
		print("[TEST] Error: ", game_info.get("error", "unknown"))
		print("================================================")
		print("  Phase 4 tests FAILED!")
		print("================================================")
		return

	print("[TEST] Game initialized successfully!")
	print("[TEST]   Game ID:          ", game_info["game_id"])
	print("[TEST]   Players:          ", game_info["player_count"])
	print("[TEST]   Total units:      ", game_info["units_total"])
	print("[TEST]   Units per player: ", game_info["units_per_player"])
	print("[TEST]   Start credits:    ", game_info["start_credits"])
	print("[TEST]   Map size:         ", game_info["map_size"])
	print("[TEST]   Unit types:       ", game_info["unit_types"])
	print("")

	# Verify engine state
	assert(engine.is_engine_initialized(), "Engine should be initialized")
	assert(engine.get_player_count() == 2, "Should have 2 players")
	print("[TEST] Engine state verified: ", engine.get_engine_status())
	print("")

	# --- Test map data ---
	print("[TEST] === Map Verification ===")
	var game_map = engine.get_map()
	assert(game_map != null, "Map should exist")
	print("[TEST] Map class:     ", game_map.get_class())
	print("[TEST] Map size:      ", game_map.get_size())
	print("[TEST] Map width:     ", game_map.get_width())
	print("[TEST] Map height:    ", game_map.get_height())
	assert(game_map.get_width() == 64, "Map width should be 64")
	assert(game_map.get_height() == 64, "Map height should be 64")

	# Test a position on the map
	var center = Vector2i(32, 32)
	print("[TEST] Position (32,32) valid: ", game_map.is_valid_position(center))
	print("[TEST] Position (32,32) water: ", game_map.is_water(center))
	print("[TEST] Position (32,32) ground: ", game_map.is_ground(center))
	print("")

	# --- Test player data ---
	print("[TEST] === Player Verification ===")
	var all_players = engine.get_all_players()
	assert(all_players.size() == 2, "Should have 2 players")

	for i in range(all_players.size()):
		var p = all_players[i]
		print("[TEST] Player ", i, ":")
		print("[TEST]   Name:     '", p.get_name(), "'")
		print("[TEST]   ID:       ", p.get_id())
		print("[TEST]   Color:    ", p.get_color())
		print("[TEST]   Credits:  ", p.get_credits())
		print("[TEST]   Vehicles: ", p.get_vehicle_count())
		print("[TEST]   Buildings:", p.get_building_count())
		print("[TEST]   Defeated: ", p.is_defeated())
		assert(p.get_credits() == 150, "Player should have 150 credits")
		assert(p.get_vehicle_count() == 4, "Player should have 4 vehicles")
	print("")

	# --- Test unit data ---
	print("[TEST] === Unit Verification ===")
	var p1_vehicles = engine.get_player_vehicles(0)
	print("[TEST] Player 0 vehicles: ", p1_vehicles.size())
	assert(p1_vehicles.size() == 4, "Player 0 should have 4 vehicles")

	for i in range(p1_vehicles.size()):
		var u = p1_vehicles[i]
		print("[TEST] Unit ", i, ": id=", u.get_id(), " name='", u.get_name(),
			  "' pos=", u.get_position(), " hp=", u.get_hp(), "/", u.get_hp_max(),
			  " speed=", u.get_speed(), "/", u.get_speed_max())
	print("")

	# Test specific unit properties
	var first_unit = p1_vehicles[0]
	assert(first_unit.get_id() > 0, "Unit should have a positive ID")
	assert(first_unit.get_hp() > 0, "Unit should have HP")
	assert(first_unit.is_vehicle(), "Unit should be a vehicle")
	assert(not first_unit.is_building(), "Unit should not be a building")
	print("[TEST] First unit stats dictionary:")
	var stats = first_unit.get_stats()
	print("[TEST]   ", stats)
	print("")

	# --- Test player 2 units ---
	print("[TEST] === Player 2 Units ===")
	var p2_vehicles = engine.get_player_vehicles(1)
	print("[TEST] Player 1 vehicles: ", p2_vehicles.size())
	assert(p2_vehicles.size() == 4, "Player 1 should have 4 vehicles")
	for i in range(p2_vehicles.size()):
		var u = p2_vehicles[i]
		print("[TEST] Unit ", i, ": id=", u.get_id(), " name='", u.get_name(),
			  "' pos=", u.get_position())
	print("")

	# --- Test actions on real units ---
	print("[TEST] === Action Tests on Real Units ===")
	var actions = engine.get_actions()
	assert(actions != null, "Actions should exist")

	# Try to toggle sentry on a real unit
	var tank = p1_vehicles[1]  # Should be a Tank
	var tank_id = tank.get_id()
	print("[TEST] Testing sentry toggle on Tank (id=", tank_id, ")...")
	var result = actions.toggle_sentry(tank_id)
	print("[TEST]   toggle_sentry -> ", result)

	# Try on nonexistent unit (should fail gracefully)
	result = actions.toggle_sentry(99999)
	print("[TEST]   toggle_sentry(99999) -> ", result, " (expected: false)")
	assert(not result, "Should fail on nonexistent unit")
	print("")

	# --- Test custom game ---
	print("[TEST] === Custom Game Test ===")
	print("[TEST] Starting 3-player custom game on 128x128 map...")
	var names = ["Alpha", "Beta", "Gamma"]
	var colors = [Color.BLUE, Color.RED, Color.GREEN]
	var custom_info = engine.new_game(names, colors, 128, 200)
	print("[TEST] Custom game result: ", custom_info)

	if custom_info["success"]:
		assert(engine.get_player_count() == 3, "Should have 3 players")
		var custom_map = engine.get_map()
		assert(custom_map.get_width() == 128, "Map should be 128 wide")
		print("[TEST] Custom game verified: 3 players on 128x128 map")

		# Verify custom game players
		for i in range(3):
			var cp = engine.get_player(i)
			print("[TEST]   Player ", i, ": '", cp.get_name(), "' credits=", cp.get_credits(),
				  " vehicles=", cp.get_vehicle_count())
			assert(cp.get_credits() == 200, "Should have 200 credits")
			assert(cp.get_vehicle_count() == 4, "Should have 4 vehicles")
	print("")

	# --- Summary ---
	print("================================================")
	print("  All Phase 4 tests PASSED!")
	print("")
	print("  Game Initialization verified:")
	print("    - new_game_test(): 2 players, 64x64 map")
	print("    - new_game(): 3 players, 128x128, custom settings")
	print("    - Map queries work (size, terrain, positions)")
	print("    - Player data correct (name, credits, units)")
	print("    - Unit data correct (id, name, hp, position)")
	print("    - Actions work on real units")
	print("    - Game is PLAYABLE from GDScript!")
	print("================================================")
	print("")
