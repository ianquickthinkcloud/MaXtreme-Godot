extends Node2D
## Main Game Scene - ties together the engine, map, units, camera, and HUD.
## This is the primary gameplay scene for MaXtreme.

const TILE_SIZE := 64
const TICKS_PER_FRAME := 1  # How many engine ticks to process per visual frame

var engine: GameEngine
var actions: RefCounted  # GameActions
var map_renderer: Node2D
var unit_renderer: Node2D
var camera: Camera2D
var hud: CanvasLayer

var selected_unit_id := -1
var current_player := 0  # Which player we're controlling (local player)
var game_running := false


func _ready() -> void:
	# Get references to child nodes
	engine = $GameEngine
	map_renderer = $MapRenderer
	unit_renderer = $UnitRenderer
	camera = $GameCamera
	hud = $GameHUD

	# Connect signals
	engine.connect("turn_started", _on_turn_started)
	engine.connect("turn_ended", _on_turn_ended)
	engine.connect("player_finished_turn", _on_player_finished_turn)
	hud.connect("end_turn_pressed", _on_end_turn_pressed)

	# Start a new test game
	_start_game()


func _start_game() -> void:
	print("[Game] Starting new game...")
	var result := engine.new_game_test()

	if not result.get("success", false):
		print("[Game] FAILED to start game: ", result.get("error", "unknown"))
		return

	game_running = true

	# Set up map
	var game_map := engine.get_map()
	map_renderer.setup(game_map)

	# Get actions interface
	actions = engine.get_actions()

	# Set up units
	unit_renderer.setup(engine)

	# Center camera on Player 0's first unit
	var p0_vehicles := engine.get_player_vehicles(0)
	if p0_vehicles.size() > 0:
		var first_pos: Vector2i = p0_vehicles[0].get_position()
		camera.center_on_tile(first_pos, TILE_SIZE)

	# Update HUD
	_update_hud()

	print("[Game] Game started! Turn ", engine.get_turn_number())
	print("[Game] Map: ", game_map.get_width(), "x", game_map.get_height())
	print("[Game] Controls:")
	print("[Game]   Left-click:  Select unit / Move selected unit")
	print("[Game]   Right-click: Deselect")
	print("[Game]   WASD/Arrows: Pan camera")
	print("[Game]   Mouse wheel: Zoom")
	print("[Game]   Middle-drag: Pan camera")
	print("[Game]   Edge scroll: Pan camera")


func _process(delta: float) -> void:
	if not game_running:
		return

	# Process engine ticks
	for i in range(TICKS_PER_FRAME):
		engine.advance_tick()

	# Update hover tile
	var mouse_world := get_global_mouse_position()
	var hover_tile := map_renderer.world_to_tile(mouse_world)
	map_renderer.set_hover_tile(hover_tile)

	# Update tile info in HUD
	if map_renderer.is_valid_tile(hover_tile):
		var terrain := _get_terrain_name(hover_tile)
		hud.update_tile_info(hover_tile, terrain)

	# Periodically refresh unit positions (in case of movement)
	# Only refresh every 10 frames for performance
	if Engine.get_process_frames() % 10 == 0:
		unit_renderer.refresh_units()
		# Keep selection highlight
		unit_renderer.selected_unit_id = selected_unit_id


func _unhandled_input(event: InputEvent) -> void:
	if not game_running:
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_LEFT:
				_handle_left_click(mb.position)
				get_viewport().set_input_as_handled()
			elif mb.button_index == MOUSE_BUTTON_RIGHT:
				_handle_right_click()
				get_viewport().set_input_as_handled()


func _handle_left_click(screen_pos: Vector2) -> void:
	var world_pos := get_global_mouse_position()
	var tile := map_renderer.world_to_tile(world_pos)

	if not map_renderer.is_valid_tile(tile):
		return

	# Check if we clicked on a unit
	var clicked_unit := unit_renderer.get_unit_at_tile(tile)

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
			# Clicked on a different unit
			# Check if it's our unit (select) or enemy (attack)
			var our_vehicles := engine.get_player_vehicles(current_player)
			var is_ours := false
			for v in our_vehicles:
				if v.get_id() == clicked_unit:
					is_ours = true
					break

			if is_ours:
				_select_unit(clicked_unit)
			else:
				# Attack! (try it)
				_try_attack(tile, clicked_unit)
		else:
			# Clicked on empty tile - move there
			_try_move(tile)


func _handle_right_click() -> void:
	_deselect_unit()


func _select_unit(unit_id: int) -> void:
	selected_unit_id = unit_id
	unit_renderer.selected_unit_id = unit_id
	unit_renderer.queue_redraw()

	# Update HUD with unit info
	_update_selected_unit_hud()
	print("[Game] Selected unit: ", unit_id)


func _deselect_unit() -> void:
	selected_unit_id = -1
	unit_renderer.selected_unit_id = -1
	unit_renderer.queue_redraw()
	hud.clear_selected_unit()


func _try_move(target_tile: Vector2i) -> void:
	if selected_unit_id == -1:
		return

	# Build a simple path (just start and end for now)
	var current_pos := unit_renderer.get_unit_position(selected_unit_id)
	if current_pos == Vector2i(-1, -1):
		return

	# Create path as PackedVector2Array
	var path := PackedVector2Array()
	# Simple straight-line path (the engine's pathfinder would be better,
	# but for the prototype we just send start and destination)
	path.append(Vector2(current_pos.x, current_pos.y))
	path.append(Vector2(target_tile.x, target_tile.y))

	var result := actions.move_unit(selected_unit_id, path)
	if result:
		print("[Game] Moving unit ", selected_unit_id, " to ", target_tile)
		# Refresh units to show new position
		unit_renderer.refresh_units()
		unit_renderer.selected_unit_id = selected_unit_id
	else:
		print("[Game] Cannot move unit ", selected_unit_id, " to ", target_tile)


func _try_attack(target_tile: Vector2i, target_unit_id: int) -> void:
	if selected_unit_id == -1:
		return

	var result := actions.attack(selected_unit_id, target_tile, target_unit_id)
	if result:
		print("[Game] Unit ", selected_unit_id, " attacking ", target_unit_id, " at ", target_tile)
		unit_renderer.refresh_units()
		unit_renderer.selected_unit_id = selected_unit_id
	else:
		print("[Game] Cannot attack from unit ", selected_unit_id)


func _update_hud() -> void:
	# Turn info
	hud.update_turn_info(engine.get_turn_number(), engine.get_game_time(), engine.is_turn_active())

	# Player info
	var player := engine.get_player(current_player)
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

	# Find the unit
	var unit = null
	for pi in range(engine.get_player_count()):
		unit = engine.get_unit_by_id(pi, selected_unit_id)
		if unit and unit.get_id() > 0:
			break

	if unit and unit.get_id() > 0:
		var pos: Vector2i = unit.get_position()
		hud.update_selected_unit({
			"name": unit.get_name(),
			"id": unit.get_id(),
			"hp": unit.get_hp(),
			"hp_max": unit.get_hp_max(),
			"speed": unit.get_speed(),
			"speed_max": unit.get_speed_max(),
			"damage": unit.get_damage(),
			"armor": unit.get_armor(),
			"pos_x": pos.x,
			"pos_y": pos.y,
		})
	else:
		hud.clear_selected_unit()


func _get_terrain_name(tile: Vector2i) -> String:
	var game_map := engine.get_map()
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

func _on_turn_started(turn: int) -> void:
	print("[Game] === Turn ", turn, " started! ===")
	unit_renderer.refresh_units()
	unit_renderer.selected_unit_id = selected_unit_id
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
	var result := engine.end_player_turn(current_player)
	if result:
		# In a 2-player test, also end AI's turn automatically
		# (In future, AI would make its own decisions)
		for i in range(engine.get_player_count()):
			if i != current_player:
				engine.end_player_turn(i)
		_update_hud()
	else:
		print("[Game] Could not end turn (already ended?)")
