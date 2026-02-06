extends Node2D
## Main Game Scene - ties together the engine, map, units, camera, and HUD.
## This is the primary gameplay scene for MaXtreme.

const TILE_SIZE := 64
const TICKS_PER_FRAME := 1  # How many engine ticks to process per visual frame

var engine = null         # GameEngine (GDExtension)
var actions = null        # GameActions (GDExtension)
var pathfinder = null     # GamePathfinder (GDExtension)
var map_renderer = null   # MapRenderer node
var unit_renderer = null  # UnitRenderer node
var overlay = null        # OverlayRenderer node
var combat_fx = null      # CombatEffects node
var camera = null         # Camera2D node
var hud = null            # GameHUD node
var move_animator = null  # MoveAnimator node

var selected_unit_id := -1
var current_player := 0  # Which player we're controlling (local player)
var game_running := false
var _last_hover_tile := Vector2i(-1, -1)
var _awaiting_attack := false  # True while an attack animation is playing


func _ready() -> void:
	# Get references to child nodes
	engine = $GameEngine
	map_renderer = $MapRenderer
	unit_renderer = $UnitRenderer
	overlay = $OverlayRenderer
	combat_fx = $CombatEffects
	move_animator = $MoveAnimator
	camera = $GameCamera
	hud = $GameHUD

	if engine == null:
		push_error("[Game] GameEngine node not found! Is the GDExtension loaded?")
		return

	# Connect signals
	engine.connect("turn_started", _on_turn_started)
	engine.connect("turn_ended", _on_turn_ended)
	engine.connect("player_finished_turn", _on_player_finished_turn)
	hud.connect("end_turn_pressed", _on_end_turn_pressed)
	move_animator.connect("animation_finished", _on_move_animation_finished)
	combat_fx.connect("effect_sequence_finished", _on_attack_animation_finished)

	# Give unit renderer access to the animator
	unit_renderer.move_animator = move_animator

	# Start a new test game
	_start_game()


func _start_game() -> void:
	print("[Game] Starting new game...")
	var result = engine.new_game_test()

	if not result.get("success", false):
		push_error("[Game] FAILED to start game: ", result.get("error", "unknown"))
		return

	game_running = true

	# Set up map
	var game_map = engine.get_map()
	map_renderer.setup(game_map)

	# Get subsystems
	actions = engine.get_actions()
	pathfinder = engine.get_pathfinder()

	# Set up units
	unit_renderer.setup(engine)

	# Center camera on Player 0's first unit
	var p0_vehicles = engine.get_player_vehicles(0)
	if p0_vehicles.size() > 0:
		var first_pos = p0_vehicles[0].get_position()
		camera.center_on_tile(first_pos, TILE_SIZE)
	else:
		camera.position = Vector2(32 * TILE_SIZE, 32 * TILE_SIZE)

	# Update HUD
	_update_hud()

	var map_w = game_map.get_width() if game_map else 0
	var map_h = game_map.get_height() if game_map else 0
	print("[Game] Ready! Turn ", engine.get_turn_number(), " | Map: ", map_w, "x", map_h, " | Units: ", result.get("units_total", 0))
	print("[Game] Controls: Left-click=Select/Move/Attack, Right-click=Deselect, WASD=Pan, Scroll=Zoom")

	# Auto-select the first vehicle so movement range is visible immediately
	if p0_vehicles.size() > 0:
		_select_unit(p0_vehicles[0].get_id())


func _process(delta: float) -> void:
	if not game_running:
		return

	# Process engine ticks
	for i in range(TICKS_PER_FRAME):
		engine.advance_tick()

	# Update hover tile
	var mouse_world = get_global_mouse_position()
	var hover_tile = map_renderer.world_to_tile(mouse_world)
	map_renderer.set_hover_tile(hover_tile)

	# Update tile info in HUD
	if map_renderer.is_valid_tile(hover_tile):
		var terrain = _get_terrain_name(hover_tile)
		var extra_info := ""
		if selected_unit_id != -1:
			if overlay.is_tile_reachable(hover_tile):
				var tile_cost = overlay.get_tile_cost(hover_tile)
				extra_info = "  (move cost: %d)" % tile_cost
			elif overlay.is_enemy_at_tile(hover_tile):
				extra_info = "  [ATTACK TARGET]"
		hud.update_tile_info(hover_tile, terrain + extra_info)

	# Update path/attack preview when hovering with a unit selected
	if selected_unit_id != -1 and hover_tile != _last_hover_tile:
		_last_hover_tile = hover_tile
		_update_hover_preview(hover_tile)

	# Periodically refresh unit positions (in case of movement)
	if Engine.get_process_frames() % 10 == 0:
		unit_renderer.refresh_units()
		unit_renderer.selected_unit_id = selected_unit_id


func _update_hover_preview(hover_tile: Vector2i) -> void:
	## Update path preview or attack preview based on what's under the cursor
	if not map_renderer.is_valid_tile(hover_tile):
		overlay.clear_path_preview()
		overlay.clear_attack_preview()
		return

	# Check if hovering over an attackable enemy
	if overlay.is_enemy_at_tile(hover_tile):
		overlay.clear_path_preview()
		var enemy_info = overlay.get_enemy_at_tile(hover_tile)
		if not enemy_info.is_empty() and pathfinder:
			var preview = pathfinder.preview_attack(selected_unit_id, enemy_info["id"])
			preview["target_pos"] = hover_tile
			overlay.set_attack_preview(preview)
		return

	# Check if hovering over a reachable tile (movement)
	overlay.clear_attack_preview()
	if overlay.is_tile_reachable(hover_tile) and pathfinder:
		var path = pathfinder.calculate_path(selected_unit_id, hover_tile)
		overlay.set_path_preview(path)
	else:
		overlay.clear_path_preview()


func _unhandled_input(event: InputEvent) -> void:
	if not game_running:
		return

	# Block input during attack animations
	if _awaiting_attack:
		return

	if event is InputEventMouseButton:
		var mb = event as InputEventMouseButton
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_LEFT:
				_handle_left_click(mb.position)
				get_viewport().set_input_as_handled()
			elif mb.button_index == MOUSE_BUTTON_RIGHT:
				_handle_right_click()
				get_viewport().set_input_as_handled()


func _handle_left_click(screen_pos: Vector2) -> void:
	var world_pos = get_global_mouse_position()
	var tile = map_renderer.world_to_tile(world_pos)

	if not map_renderer.is_valid_tile(tile):
		return

	# Check if we clicked on a unit
	var clicked_unit = unit_renderer.get_unit_at_tile(tile)

	if selected_unit_id == -1:
		# No unit selected - try to select one
		if clicked_unit != -1:
			_select_unit(clicked_unit)
	else:
		# We have a selected unit
		if clicked_unit == selected_unit_id:
			# Clicked on the same unit - deselect
			_deselect_unit()
		elif clicked_unit != -1:
			# Clicked on a different unit - check if ours or enemy
			var our_vehicles = engine.get_player_vehicles(current_player)
			var is_ours := false
			for v in our_vehicles:
				if v.get_id() == clicked_unit:
					is_ours = true
					break

			if is_ours:
				_select_unit(clicked_unit)
			elif overlay.is_enemy_at_tile(tile):
				# Attack enemy unit (in range)
				_try_attack(tile, clicked_unit)
			else:
				# Enemy unit but not in range - just select it for info
				print("[Game] Enemy unit at ", tile, " is out of attack range")
		else:
			# Clicked on empty tile - move there using pathfinding
			_try_move(tile)


func _handle_right_click() -> void:
	_deselect_unit()


func _select_unit(unit_id: int) -> void:
	selected_unit_id = unit_id
	unit_renderer.selected_unit_id = unit_id
	unit_renderer.queue_redraw()

	# Calculate and show movement range + attack range
	_update_overlays()

	# Update HUD with unit info
	_update_selected_unit_hud()
	print("[Game] Selected unit: ", unit_id)


func _deselect_unit() -> void:
	selected_unit_id = -1
	unit_renderer.selected_unit_id = -1
	unit_renderer.queue_redraw()
	overlay.clear_all()
	_last_hover_tile = Vector2i(-1, -1)
	hud.clear_selected_unit()


func _update_overlays() -> void:
	## Update both movement range and attack range overlays
	if selected_unit_id == -1 or not pathfinder:
		overlay.clear_all()
		return

	# Movement range
	var reachable = pathfinder.get_reachable_tiles(selected_unit_id)
	overlay.set_reachable_tiles(reachable)

	# Attack range (only for units with weapons)
	var range_tiles = pathfinder.get_attack_range_tiles(selected_unit_id)
	var enemies = pathfinder.get_enemies_in_range(selected_unit_id)
	if not range_tiles.is_empty():
		overlay.set_attack_range(range_tiles, enemies)
	else:
		overlay.clear_attack_range()


func _try_move(target_tile: Vector2i) -> void:
	if selected_unit_id == -1 or not pathfinder:
		return

	# Don't move if already animating
	if move_animator.is_animating(selected_unit_id):
		return

	# Use the real pathfinder to get a proper A* path
	var path = pathfinder.calculate_path(selected_unit_id, target_tile)
	if path.is_empty():
		print("[Game] No path to ", target_tile)
		return

	# Check if the path cost is within movement range
	var cost = pathfinder.get_path_cost(selected_unit_id, path)
	var speed = pathfinder.get_movement_points(selected_unit_id)
	if cost > speed:
		print("[Game] Path too expensive: cost ", cost, " > speed ", speed)
		return

	var result = actions.move_unit(selected_unit_id, path)
	if result:
		print("[Game] Moving unit ", selected_unit_id, " to ", target_tile, " (cost: ", cost, "/", speed, ")")
		# Start smooth visual animation along the path
		move_animator.start_animation(selected_unit_id, path)
		# Clear overlays during animation
		overlay.clear_all()
	else:
		print("[Game] Move failed for unit ", selected_unit_id)


func _try_attack(target_tile: Vector2i, target_unit_id: int) -> void:
	if selected_unit_id == -1 or not pathfinder:
		return

	# Get attack preview for the animation
	var preview = pathfinder.preview_attack(selected_unit_id, target_unit_id)
	var damage: int = preview.get("damage", 0)
	var will_destroy: bool = preview.get("will_destroy", false)

	# Get attacker info for muzzle type
	var attacker_unit = _find_unit(selected_unit_id)
	var muzzle_type := "Big"
	var attacker_pos := Vector2i(0, 0)
	if attacker_unit:
		muzzle_type = attacker_unit.get_muzzle_type()
		attacker_pos = attacker_unit.get_position()

	# Execute the attack in the engine
	var result = actions.attack(selected_unit_id, target_tile, target_unit_id)
	if result:
		print("[Game] Unit ", selected_unit_id, " attacks ", target_unit_id, " at ", target_tile,
			  " -> ", damage, " damage", " (DESTROY)" if will_destroy else "")

		# Block further input during attack animation
		_awaiting_attack = true

		# Play combat effects
		combat_fx.play_attack_sequence(attacker_pos, target_tile,
			damage, will_destroy, muzzle_type,
			selected_unit_id, target_unit_id)

		# Clear attack preview
		overlay.clear_attack_preview()
	else:
		print("[Game] Cannot attack from unit ", selected_unit_id)


func _find_unit(unit_id: int):
	## Find a unit by ID across all players. Returns GameUnit or null.
	for pi in range(engine.get_player_count()):
		var u = engine.get_unit_by_id(pi, unit_id)
		if u and u.get_id() > 0:
			return u
	return null


func _update_hud() -> void:
	# Turn info
	hud.update_turn_info(engine.get_turn_number(), engine.get_game_time(), engine.is_turn_active())

	# Player info
	var player = engine.get_player(current_player)
	if player:
		hud.update_player_info(
			player.get_name(),
			player.get_credits(),
			player.get_vehicle_count(),
			player.get_building_count()
		)

	# End turn button
	hud.set_end_turn_enabled(engine.is_turn_active())


func _update_selected_unit_hud() -> void:
	if selected_unit_id == -1:
		hud.clear_selected_unit()
		return

	var unit = _find_unit(selected_unit_id)

	if unit:
		var pos = unit.get_position()
		var mp = 0
		var mp_max = 0
		if pathfinder:
			mp = pathfinder.get_movement_points(selected_unit_id)
			mp_max = pathfinder.get_movement_points_max(selected_unit_id)
		hud.update_selected_unit({
			"name": unit.get_name(),
			"id": unit.get_id(),
			"hp": unit.get_hitpoints(),
			"hp_max": unit.get_hitpoints_max(),
			"speed": mp,
			"speed_max": mp_max,
			"damage": unit.get_damage(),
			"armor": unit.get_armor(),
			"range": unit.get_range(),
			"shots": unit.get_shots(),
			"shots_max": unit.get_shots_max(),
			"ammo": unit.get_ammo(),
			"ammo_max": unit.get_ammo_max(),
			"pos_x": pos.x,
			"pos_y": pos.y,
		})
	else:
		hud.clear_selected_unit()


func _get_terrain_name(tile: Vector2i) -> String:
	var game_map = engine.get_map()
	if not game_map:
		return ""
	if game_map.is_water(tile):
		return "[Water]"
	elif game_map.is_coast(tile):
		return "[Coast]"
	elif game_map.is_blocked(tile):
		return "[Blocked]"
	else:
		return "[Ground]"


# --- Signal handlers ---

func _on_attack_animation_finished(attacker_id: int, target_id: int) -> void:
	_awaiting_attack = false

	# Refresh everything after attack
	pathfinder = engine.get_pathfinder()
	unit_renderer.refresh_units()
	unit_renderer.selected_unit_id = selected_unit_id

	# Update overlays and HUD
	if selected_unit_id != -1:
		_update_overlays()
		_update_selected_unit_hud()
	_update_hud()


func _on_move_animation_finished(unit_id: int) -> void:
	# Refresh units to show final engine positions
	unit_renderer.refresh_units()
	unit_renderer.selected_unit_id = selected_unit_id

	# Re-fetch pathfinder since movement points changed
	pathfinder = engine.get_pathfinder()

	# If the animated unit is our selected unit, show updated range
	if unit_id == selected_unit_id:
		_update_overlays()
		_update_selected_unit_hud()


func _on_turn_started(turn: int) -> void:
	print("[Game] === Turn ", turn, " started! ===")
	# Re-fetch pathfinder since model state changed
	pathfinder = engine.get_pathfinder()
	unit_renderer.refresh_units()
	unit_renderer.selected_unit_id = selected_unit_id
	if selected_unit_id != -1:
		_update_overlays()
	_update_hud()


func _on_turn_ended() -> void:
	print("[Game] Turn ended, processing...")
	_update_hud()


func _on_player_finished_turn(player_id: int) -> void:
	print("[Game] Player ", player_id, " finished turn")
	_update_hud()


func _on_end_turn_pressed() -> void:
	if not game_running:
		return

	print("[Game] Ending turn for player ", current_player)
	var result = engine.end_player_turn(current_player)
	if result:
		# In a 2-player test, also end AI's turn automatically
		for i in range(engine.get_player_count()):
			if i != current_player:
				engine.end_player_turn(i)
		_update_hud()
	else:
		print("[Game] Could not end turn (already ended?)")
