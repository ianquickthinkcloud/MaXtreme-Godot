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
var fog = null            # FogRenderer node
var combat_fx = null      # CombatEffects node
var camera = null         # Camera2D node
var hud = null            # GameHUD node
var move_animator = null  # MoveAnimator node

var selected_unit_id := -1
var current_player := 0  # Which player we're controlling (local player)
var game_running := false
var _last_hover_tile := Vector2i(-1, -1)
var _awaiting_attack := false  # True while an attack animation is playing

# Command target selection modes
var _cmd_mode := ""  # "load", "repair", "reload", "steal", "disable", "activate", "transfer_target"
var _cmd_source_id := -1  # Unit initiating the command (for target selection)

# Build mode state
var _build_mode := false
var _build_type_id := ""
var _build_type_name := ""
var _build_is_big := false
var _build_cost := 0
var _build_speed := 0  # Phase 26: 0=normal, 1=2x, 2=4x turbo
var _build_constructor_id := -1  # ID of the constructor initiating the build
var _path_build_mode := false  # Phase 26: True when placing path end position
var _path_build_start := Vector2i(-1, -1)  # Phase 26: Start of path build

var build_panel = null       # BuildPanel node
var production_panel = null  # ProductionPanel node
var pause_menu = null        # PauseMenu node
var game_over_screen = null  # GameOverScreen node
var network_status = null    # NetworkStatus overlay node
var minimap = null           # Minimap node
var _game_paused := false
var _is_multiplayer := false # True if this is a networked game
var _is_hotseat := false     # True if this is a hot seat game
var _hotseat_player_count := 0  # Number of human players in hot seat
var _hotseat_transition := false  # True while showing the turn transition screen
var _turn_transition_overlay: ColorRect = null  # Full-screen overlay for hot seat transitions
var _turn_transition_label: Label = null
var _turn_transition_sublabel: Label = null
var _turn_transition_button: Button = null
var _sprite_cache_ref = null # Keep a reference to the shared sprite cache
var _prev_research_levels: Dictionary = {}  # Phase 21: Track previous research levels for notifications
var _resource_overlay_visible := false  # Phase 22: Toggle for resource overlay
var _prev_energy_balance: Dictionary = {}  # Phase 22: Track energy for warnings
var _surveyed_tile_count: int = 0  # Phase 22: Track surveyed tiles for discovery notifications
var _turn_report_items: Array = []  # Phase 23: Accumulate events during turn processing
var _prev_unit_counts: Dictionary = {}  # Phase 23: Track production completion {player_id: count}
const AUTOSAVE_SLOT := 10  # Phase 24: Auto-save slot number

# Phase 29: Keyboard Shortcuts & UX
var _unit_groups: Dictionary = {}  # {1-9: Array[int] of unit IDs}
var _box_selecting := false
var _box_select_start := Vector2.ZERO  # Screen position
var _box_select_rect: ColorRect = null  # Visual feedback
var _selected_units: Array = []  # Multi-select unit IDs (empty = use selected_unit_id)
var _shift_held := false  # Track shift for path preview


func _ready() -> void:
	# Get references to child nodes
	engine = $GameEngine
	map_renderer = $MapRenderer
	unit_renderer = $UnitRenderer
	overlay = $OverlayRenderer
	fog = $FogRenderer
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
	engine.connect("player_won", _on_player_won)
	engine.connect("player_lost", _on_player_lost)
	hud.connect("end_turn_pressed", _on_end_turn_pressed)
	hud.connect("build_pressed", _on_build_button_pressed)
	hud.connect("command_pressed", _on_command_pressed)
	hud.connect("research_allocation_changed", _on_research_allocation_changed)
	hud.connect("gold_upgrade_requested", _on_gold_upgrade_requested)
	hud.connect("mining_distribution_changed", _on_mining_distribution_changed)
	hud.connect("jump_to_position", _on_jump_to_position)
	hud.connect("save_game_requested", _on_save_game_requested)
	hud.connect("load_game_requested", _on_load_game_requested)
	hud.connect("stat_overlay_changed", _on_stat_overlay_changed)
	hud.connect("grid_overlay_toggled", _on_grid_overlay_toggled)
	hud.connect("fog_overlay_toggled", _on_fog_overlay_toggled)
	hud.connect("connector_overlay_toggled", _on_connector_overlay_toggled)

	# Phase 23: Connect engine event signals
	engine.connect("unit_attacked", _on_unit_attacked)
	engine.connect("unit_destroyed", _on_unit_destroyed)
	engine.connect("unit_disabled", _on_unit_disabled)
	engine.connect("build_error", _on_build_error)
	engine.connect("sudden_death", _on_sudden_death)
	move_animator.connect("animation_finished", _on_move_animation_finished)
	move_animator.connect("direction_changed", _on_unit_direction_changed)
	combat_fx.connect("effect_sequence_finished", _on_attack_animation_finished)

	# Create shared sprite cache and distribute to all systems
	unit_renderer.move_animator = move_animator
	var _sprite_cache = preload("res://scripts/game/sprite_cache.gd").new()
	_sprite_cache_ref = _sprite_cache
	unit_renderer.sprite_cache = _sprite_cache
	combat_fx._sprite_cache = _sprite_cache
	hud.set_sprite_cache(_sprite_cache)

	# Set up build panel (child of GameHUD CanvasLayer)
	build_panel = hud.get_node_or_null("BuildPanel")
	if build_panel:
		build_panel.set_sprite_cache(_sprite_cache)
		# Phase 26: prefer building_selected_ex with speed parameter
		if build_panel.has_signal("building_selected_ex"):
			build_panel.connect("building_selected_ex", _on_building_selected_ex)
		else:
			build_panel.connect("building_selected", _on_building_selected)
		build_panel.connect("panel_closed", _on_build_panel_closed)

	# Set up production panel (child of GameHUD CanvasLayer)
	production_panel = hud.get_node_or_null("ProductionPanel")
	if production_panel:
		production_panel.set_sprite_cache(_sprite_cache)

	# Set up pause menu
	pause_menu = get_node_or_null("PauseMenu")
	if pause_menu:
		pause_menu.resumed.connect(_on_pause_resumed)
		pause_menu.quit_to_menu.connect(_on_quit_to_menu)
		if pause_menu.has_signal("save_requested"):
			pause_menu.save_requested.connect(_on_pause_save)
		if pause_menu.has_signal("load_requested"):
			pause_menu.load_requested.connect(_on_pause_load)

	# Set up game over screen
	game_over_screen = get_node_or_null("GameOverScreen")
	if game_over_screen:
		game_over_screen.return_to_menu.connect(_on_quit_to_menu)
		game_over_screen.continue_playing.connect(func() -> void: _game_paused = false)

	# Start the game
	_start_game()


func _start_game() -> void:
	# Check if we have a game config from GameManager (came from New Game Setup)
	var config: Dictionary = {}
	if GameManager:
		config = GameManager.game_config

	# Phase 24: Handle load mode — load a save file instead of starting new game
	if config.get("load_mode", false):
		var load_slot: int = config.get("load_slot", 1)
		print("[Game] Loading save from slot %d..." % load_slot)
		var result: Dictionary = engine.load_game(load_slot)
		if not result.get("success", false):
			push_error("[Game] FAILED to load save: ", result.get("error", "unknown"))
			return
		# Clear load mode so reloads don't keep re-loading
		config.erase("load_mode")
		config.erase("load_slot")

		# Detect hot seat from loaded game (TODO: detect from save metadata)
		var game_type_str: String = config.get("game_type", "")
		if game_type_str == "hotseat":
			_is_hotseat = true
			_hotseat_player_count = engine.get_player_count()
			current_player = 0
			_create_turn_transition_overlay()

		game_running = true
		_update_hud()
		_update_selected_unit_hud()
		print("[Game] Loaded save — Turn %d, %d players" % [result.get("turn", 0), result.get("player_count", 0)])
		return

	_is_multiplayer = config.get("multiplayer", false)

	if _is_multiplayer:
		# Multiplayer: the lobby has already set up the game.
		# Hand off the lobby's server/client to our engine.
		print("[Game] Starting multiplayer game...")
		if GameManager.lobby:
			var handoff_ok: bool = GameManager.lobby.handoff_to_engine(engine)
			if not handoff_ok:
				push_error("[Game] Lobby handoff to engine failed!")
				return

			# Connect multiplayer signals
			engine.connect("freeze_mode_changed", _on_freeze_mode_changed)
			engine.connect("connection_lost", _on_connection_lost)
		else:
			push_error("[Game] No lobby found for multiplayer game!")
			return
	else:
		# Single-player or hot seat: create a new game directly
		var result: Dictionary
		if config.size() > 0 and config.has("map_name"):
			# Check if we have extended settings (game_type, etc.)
			if config.has("game_type"):
				print("[Game] Starting game with extended settings...")
				result = engine.new_game_ex(config)
			else:
				print("[Game] Starting configured game...")
				result = engine.new_game(
					config.get("map_name", ""),
					config.get("player_names", ["Player 1", "Player 2"]),
					config.get("player_colors", [Color.BLUE, Color.RED]),
					config.get("player_clans", [-1, -1]),
					config.get("start_credits", 150)
				)
		else:
			# Fallback: start a test game (for development / direct scene launch)
			print("[Game] Starting test game (no config from GameManager)...")
			result = engine.new_game_test()

		if not result.get("success", false):
			push_error("[Game] FAILED to start game: ", result.get("error", "unknown"))
			return

	# Detect hot seat mode
	var game_type_str: String = config.get("game_type", "")
	if game_type_str == "hotseat":
		_is_hotseat = true
		_hotseat_player_count = engine.get_player_count()
		current_player = 0
		print("[Game] Hot Seat mode with ", _hotseat_player_count, " players")
		_create_turn_transition_overlay()

	game_running = true

	# Set up map
	var game_map = engine.get_map()
	map_renderer.setup(game_map)

	# Get subsystems
	actions = engine.get_actions()
	pathfinder = engine.get_pathfinder()

	# Set up fog of war
	if fog:
		var map_w: int = game_map.get_width() if game_map else 0
		var map_h: int = game_map.get_height() if game_map else 0
		fog.setup(map_w, map_h, current_player)
		fog.refresh(engine)

	# Set up units (pass fog renderer for visibility filtering)
	unit_renderer.fog_renderer = fog
	unit_renderer.current_player = current_player
	unit_renderer.setup(engine)

	# Center camera on current player's first unit
	var p0_vehicles = engine.get_player_vehicles(current_player)
	if p0_vehicles.size() > 0:
		var first_pos = p0_vehicles[0].get_position()
		camera.center_on_tile(first_pos, TILE_SIZE)
	else:
		camera.position = Vector2(32 * TILE_SIZE, 32 * TILE_SIZE)

	# Update HUD
	_update_hud()

	var map_w = game_map.get_width() if game_map else 0
	var map_h = game_map.get_height() if game_map else 0
	var mode_str := " [Multiplayer]" if _is_multiplayer else ""
	print("[Game] Ready!%s Turn %d | Map: %dx%d" % [mode_str, engine.get_turn_number(), map_w, map_h])
	print("[Game] Controls: Left-click=Select/Move/Attack, Right-click=Deselect, WASD=Pan, Scroll=Zoom")

	# Start in-game music (random background track -- if music files exist)
	AudioManager.stop_music()
	AudioManager.play_music()  # Picks a random track from musics.json

	# Create minimap
	_create_minimap()

	# Auto-select the first vehicle so movement range is visible immediately
	if p0_vehicles.size() > 0:
		_select_unit(p0_vehicles[0].get_id())

	# Create network status overlay and chat for multiplayer
	if _is_multiplayer:
		_create_network_status_overlay()
		_create_chat_overlay()


func _process(delta: float) -> void:
	if not game_running or _game_paused:
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

	# Update path/attack/build preview when hovering
	if hover_tile != _last_hover_tile:
		_last_hover_tile = hover_tile
		if _build_mode:
			_update_build_preview(hover_tile)
		elif selected_unit_id != -1:
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
	elif _shift_held and pathfinder:
		# Phase 29: Shift+hover shows path even outside movement range
		var path = pathfinder.calculate_path(selected_unit_id, hover_tile)
		if not path.is_empty():
			overlay.set_path_preview(path)
		else:
			overlay.clear_path_preview()
	else:
		overlay.clear_path_preview()


func _unhandled_input(event: InputEvent) -> void:
	if not game_running or _hotseat_transition:
		return

	# ESC key handling: pause menu > cancel build mode
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if _game_paused:
			# If pause menu is open, close it
			if pause_menu and pause_menu.is_open:
				_on_pause_resumed()
				get_viewport().set_input_as_handled()
				return
		elif _build_mode:
			_cancel_build_mode()
			get_viewport().set_input_as_handled()
			return
		else:
			# Open pause menu
			_toggle_pause()
			get_viewport().set_input_as_handled()
			return

	# Block all game input when paused or during attack animations
	if _game_paused:
		return
	if _awaiting_attack:
		return

	# --- Phase 29: Keyboard Shortcuts ---
	if event is InputEventKey:
		var ke := event as InputEventKey
		_shift_held = ke.shift_pressed
		if ke.pressed and not ke.echo:
			if _handle_keyboard_shortcut(ke):
				get_viewport().set_input_as_handled()
				return

	if event is InputEventMouseButton:
		var mb = event as InputEventMouseButton
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_LEFT:
				if _build_mode:
					_handle_build_click()
				elif mb.shift_pressed:
					# Phase 29: Start box select
					_start_box_select(mb.position)
				else:
					_handle_left_click(mb.position)
				get_viewport().set_input_as_handled()
			elif mb.button_index == MOUSE_BUTTON_RIGHT:
				if _build_mode:
					_cancel_build_mode()
				else:
					_handle_right_click()
				get_viewport().set_input_as_handled()
		else:
			# Mouse button released
			if mb.button_index == MOUSE_BUTTON_LEFT and _box_selecting:
				_finish_box_select(mb.position)
				get_viewport().set_input_as_handled()

	# Phase 29: Update box select visual during drag
	if event is InputEventMouseMotion and _box_selecting:
		_update_box_select((event as InputEventMouseMotion).position)


func _handle_left_click(screen_pos: Vector2) -> void:
	var world_pos = get_global_mouse_position()
	var tile = map_renderer.world_to_tile(world_pos)

	if not map_renderer.is_valid_tile(tile):
		return

	# Phase 19: Check command target selection mode first
	if _cmd_mode != "":
		if _handle_cmd_mode_click(tile):
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
	# Cancel command mode on right-click
	if _cmd_mode != "":
		_cancel_cmd_mode()
		return
	_deselect_unit()


func _select_unit(unit_id: int) -> void:
	selected_unit_id = unit_id
	_selected_units.clear()  # Phase 29: Clear multi-select on single selection
	unit_renderer.selected_unit_id = unit_id
	unit_renderer.queue_redraw()

	# Cancel build mode if active
	if _build_mode:
		_cancel_build_mode()

	# Calculate and show movement range + attack range
	_update_overlays()

	# Update HUD with unit info
	_update_selected_unit_hud()

	# Check if this is a factory building - show production panel
	var unit = _find_unit(unit_id)
	if unit and unit.is_building() and unit.get_build_list_size() >= 0:
		var can_build_str = unit.get_can_build()
		if can_build_str != "":
			_on_factory_selected(unit)
		elif production_panel:
			production_panel.close()
	elif production_panel:
		production_panel.close()

	print("[Game] Selected unit: ", unit_id)


func _deselect_unit() -> void:
	selected_unit_id = -1
	_selected_units.clear()  # Phase 29: Clear multi-select
	unit_renderer.selected_unit_id = -1
	unit_renderer.queue_redraw()
	overlay.clear_all()
	_cancel_cmd_mode()
	_last_hover_tile = Vector2i(-1, -1)
	hud.clear_selected_unit()
	if _build_mode:
		_cancel_build_mode()
	if build_panel:
		build_panel.close()
	if production_panel:
		production_panel.close()


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
		# Get unit type name for movement sounds
		var unit = _find_unit(selected_unit_id)
		var unit_type_name := ""
		if unit:
			unit_type_name = unit.get_type_name()
		# Start smooth visual animation along the path
		move_animator.start_animation(selected_unit_id, path, unit_type_name)
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

		# Play combat effects with per-unit attack sound
		combat_fx.attacker_type_name = attacker_unit.get_type_name() if attacker_unit else ""
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


func _refresh_fog() -> void:
	## Refresh fog of war from the engine's scan map.
	if fog and engine:
		fog.refresh(engine)
	if minimap:
		minimap.refresh()


func _update_hud() -> void:
	# Turn info
	hud.update_turn_info(engine.get_turn_number(), engine.get_game_time(), engine.is_turn_active())

	# Player info + resource display
	var player = engine.get_player(current_player)
	if player:
		hud.update_player_info(
			player.get_name(),
			player.get_credits(),
			player.get_vehicle_count(),
			player.get_building_count()
		)
		# Resource bar
		var storage = player.get_resource_storage()
		var production = player.get_resource_production()
		var needed = player.get_resource_needed()
		var energy = player.get_energy_balance()
		hud.update_resource_display(storage, production, needed, energy, player.get_credits())

		# Phase 20: Human resources
		if player.has_method("get_human_balance"):
			var humans = player.get_human_balance()
			hud.update_human_display(humans)

		# Phase 20 + 27: Score display with victory target
		var score: int = player.get_score()
		var victory_type: String = engine.get_victory_type()
		var victory_settings: Dictionary = engine.get_victory_settings() if engine.has_method("get_victory_settings") else {}
		var target_points: int = victory_settings.get("target_points", 0)
		hud.update_score_display(score, victory_type, target_points)

	# Phase 20: Turn timer
	if engine.has_method("has_turn_deadline"):
		var has_deadline: bool = engine.has_turn_deadline()
		var time_remaining: float = engine.get_turn_time_remaining() if has_deadline else -1.0
		hud.update_timer_display(time_remaining, has_deadline)

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

		# Build extra info string for buildings/constructors
		var extra_info := ""
		if unit.is_building():
			if unit.is_working():
				var bl_size = unit.get_build_list_size()
				if bl_size > 0:
					var bl = unit.get_build_list()
					extra_info = "Producing: %s (%d in queue)" % [bl[0].get("type_name", "?"), bl_size]
				else:
					extra_info = "Working"
			elif unit.can_start_work():
				extra_info = "Idle (can start)"
			var mining = unit.get_mining_production()
			if mining.get("metal", 0) > 0 or mining.get("oil", 0) > 0 or mining.get("gold", 0) > 0:
				extra_info += "  Mining: M%d O%d G%d" % [mining.get("metal", 0), mining.get("oil", 0), mining.get("gold", 0)]
		elif unit.is_vehicle() and unit.is_building_a_building():
			var remaining_turns: int = unit.get_build_turns_remaining()
			var remaining_cost: int = unit.get_build_costs_remaining()
			var start_cost: int = unit.get_build_costs_start()
			var progress := 0.0
			if start_cost > 0:
				progress = 1.0 - (float(remaining_cost) / float(start_cost))
			extra_info = "Building... (%d turns, %d metal left, %.0f%%)" % [remaining_turns, remaining_cost, progress * 100.0]

		# Fetch capabilities and state for command buttons
		var caps = unit.get_capabilities()
		var is_own: bool = (unit.get_owner_id() == current_player)
		var stored_count: int = unit.get_stored_units_count()
		var cargo_list = unit.get_stored_units() if stored_count > 0 else []

		hud.update_selected_unit({
			"name": unit.get_name(),
			"type_name": unit.get_type_name(),
			"id": unit.get_id(),
			"is_building": unit.is_building(),
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
			"is_constructor": unit.is_constructor(),
			"extra_info": extra_info,
			# Phase 19: Capability and state data for command buttons
			"capabilities": caps,
			"is_own": is_own,
			"is_sentry": unit.is_sentry_active(),
			"is_manual_fire": unit.is_manual_fire(),
			"is_working": unit.is_working(),
			"is_disabled": unit.is_disabled(),
			"disabled_turns": unit.get_disabled_turns(),
			"stored_units": stored_count,
			"stored_resources": unit.get_stored_resources(),
			"cargo_list": cargo_list,
			# Phase 20: Experience, version, dated
			"rank": unit.get_commando_rank(),
			"rank_name": unit.get_commando_rank_name(),
			"is_dated": unit.is_dated(),
			"version": unit.get_version(),
			"scan": unit.get_scan(),
			"owner_id": unit.get_owner_id(),
			"description": unit.get_description(),
			# Phase 22: Mine building flag
			"is_mine": unit.is_building() and (unit.get_mining_max().get("metal", 0) > 0 or unit.get_mining_max().get("oil", 0) > 0 or unit.get_mining_max().get("gold", 0) > 0),
			# Phase 26: Construction state
			"is_constructing": unit.is_vehicle() and unit.is_building_a_building(),
			"can_build_path": unit.is_vehicle() and unit.can_build_path() if unit.has_method("can_build_path") else false,
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


# --- Build Mode ---

func _on_build_button_pressed() -> void:
	## Called when the BUILD button in the HUD is clicked
	if selected_unit_id == -1:
		return
	var unit = _find_unit(selected_unit_id)
	if not unit or not unit.is_constructor():
		return
	if build_panel:
		build_panel.open_for_unit(unit)


func _on_building_selected(type_id: String, type_name: String, is_big: bool, cost: int) -> void:
	## Called when a building is picked from the build panel (legacy signal)
	_on_building_selected_ex(type_id, type_name, is_big, cost, 0)


func _on_building_selected_ex(type_id: String, type_name: String, is_big: bool, cost: int, speed: int) -> void:
	## Called when a building is picked from the build panel (with turbo speed)
	_build_mode = true
	_build_type_id = type_id
	_build_type_name = type_name
	_build_is_big = is_big
	_build_cost = cost
	_build_speed = speed
	_build_constructor_id = selected_unit_id
	_path_build_mode = false
	_path_build_start = Vector2i(-1, -1)
	if build_panel:
		build_panel.close()
	# Clear movement overlays and show build preview instead
	overlay.clear_all()
	var speed_label := ["1x", "2x", "4x"][clampi(speed, 0, 2)]
	print("[Game] Build mode: placing %s (%s, cost: %d, speed: %s)" % [type_name, "2x2" if is_big else "1x1", cost, speed_label])


func _on_build_panel_closed() -> void:
	pass  # Panel was closed without selecting


func _update_build_preview(hover_tile: Vector2i) -> void:
	## Update the build placement overlay while in build mode
	if not _build_mode:
		return
	if not map_renderer.is_valid_tile(hover_tile):
		overlay.clear_build_preview()
		return

	# Basic validation: check that all tiles are valid ground (not water/blocked)
	var valid := _is_valid_build_position(hover_tile)
	overlay.set_build_preview(hover_tile, _build_is_big, valid)

	# Phase 26: Show cost/time info in the tile label
	var speed_label := ["1x", "2x", "4x"][clampi(_build_speed, 0, 2)]
	var unit = _find_unit(_build_constructor_id)
	if unit:
		var turbo = unit.get_turbo_build_info(_build_type_id)
		var cost_key := "cost_%d" % _build_speed
		var turns_key := "turns_%d" % _build_speed
		var cost_val: int = turbo.get(cost_key, _build_cost)
		var turns_val: int = turbo.get(turns_key, 0)
		hud.tile_label.text = "%s  [%d metal, %d turns, %s]" % [_build_type_name, cost_val, turns_val, speed_label]
	else:
		hud.tile_label.text = "%s  [%d metal, %s]" % [_build_type_name, _build_cost, speed_label]


func _is_valid_build_position(pos: Vector2i) -> bool:
	## Check if a building can be placed at the given position.
	var game_map = engine.get_map()
	if not game_map:
		return false

	var size := 2 if _build_is_big else 1
	for dx in range(size):
		for dy in range(size):
			var check := Vector2i(pos.x + dx, pos.y + dy)
			if not map_renderer.is_valid_tile(check):
				return false
			if game_map.is_water(check) or game_map.is_blocked(check):
				return false
			# Check for existing units at this tile
			if unit_renderer.get_unit_at_tile(check) != -1:
				# Allow if it's the constructor itself
				var uid = unit_renderer.get_unit_at_tile(check)
				if uid != _build_constructor_id:
					return false
	return true


func _handle_build_click() -> void:
	## Handle left-click while in build mode: try to place the building
	var world_pos = get_global_mouse_position()
	var tile = map_renderer.world_to_tile(world_pos)

	if not map_renderer.is_valid_tile(tile):
		return

	# Phase 26: Path building mode — second click sets end position
	if _path_build_mode:
		_handle_path_build_end(tile)
		return

	if not _is_valid_build_position(tile):
		print("[Game] Cannot build here - invalid position")
		return

	# Phase 26: Use selected turbo build speed
	var build_speed := _build_speed

	# Call engine action to start build
	if actions:
		var result = actions.start_build(_build_constructor_id, _build_type_id, build_speed, tile)
		if result:
			AudioManager.play_sound("build_place")
			var speed_label := ["1x", "2x", "4x"][clampi(build_speed, 0, 2)]
			print("[Game] Started building %s at (%d, %d) [speed: %s]" % [_build_type_name, tile.x, tile.y, speed_label])
			_cancel_build_mode()
			# Refresh everything
			_refresh_fog()
			unit_renderer.refresh_units()
			_update_hud()
			if selected_unit_id != -1:
				_update_selected_unit_hud()
		else:
			print("[Game] Build action failed (engine rejected)")


func _cancel_build_mode() -> void:
	_build_mode = false
	_build_type_id = ""
	_build_type_name = ""
	_build_is_big = false
	_build_cost = 0
	_build_speed = 0
	_build_constructor_id = -1
	_path_build_mode = false
	_path_build_start = Vector2i(-1, -1)
	overlay.clear_build_preview()
	# Restore movement overlays if a unit is selected
	if selected_unit_id != -1:
		_update_overlays()
	if build_panel:
		build_panel.close()
	print("[Game] Build mode cancelled")


# --- Phase 26: Path Building (road/bridge/platform) ---

func _cmd_start_path_build() -> void:
	## Enter path building mode: user picks start (vehicle pos) then end position
	if selected_unit_id == -1:
		return
	var unit = _find_unit(selected_unit_id)
	if not unit or not unit.can_build_path():
		print("[Game] This unit cannot build paths")
		return

	# The constructor must be able to build a road/bridge/platform type
	var buildable = unit.get_buildable_types()
	if buildable.is_empty():
		print("[Game] No buildable types for path building")
		return

	# Use the first buildable type (usually connector/road)
	var first_type = buildable[0]
	_build_mode = true
	_build_type_id = first_type.get("id", "")
	_build_type_name = first_type.get("name", "Road/Bridge")
	_build_is_big = false
	_build_cost = first_type.get("cost", 0)
	_build_speed = 0
	_build_constructor_id = selected_unit_id
	_path_build_mode = true
	_path_build_start = unit.get_position()

	if build_panel:
		build_panel.close()
	overlay.clear_all()
	print("[Game] Path build mode: click destination for %s path" % _build_type_name)


func _handle_path_build_end(tile: Vector2i) -> void:
	## Handle the second click in path building mode (sets the path end)
	if not map_renderer.is_valid_tile(tile):
		return

	if actions:
		var result = actions.start_build_path(
			_build_constructor_id, _build_type_id, _build_speed,
			_path_build_start, tile
		)
		if result:
			AudioManager.play_sound("build_place")
			print("[Game] Started path build from (%d,%d) to (%d,%d)" % [
				_path_build_start.x, _path_build_start.y, tile.x, tile.y])
			_cancel_build_mode()
			_refresh_fog()
			unit_renderer.refresh_units()
			_update_hud()
			if selected_unit_id != -1:
				_update_selected_unit_hud()
		else:
			print("[Game] Path build action failed (engine rejected)")


# --- Phase 26: Cancel Construction ---

func _cmd_cancel_construction() -> void:
	## Cancel an in-progress construction (vehicle building a building)
	if selected_unit_id == -1:
		return
	var unit = _find_unit(selected_unit_id)
	if not unit:
		return
	if unit.is_vehicle() and unit.is_building_a_building():
		if actions.stop(selected_unit_id):
			print("[Game] Cancelled construction for unit ", selected_unit_id)
			_refresh_after_action()
		else:
			print("[Game] Failed to cancel construction")


func _on_factory_selected(unit) -> void:
	## Called when a factory building is selected - show production panel
	if production_panel and unit and unit.is_building():
		production_panel.open_for_factory(unit, actions)


# --- Signal handlers ---

func _on_attack_animation_finished(attacker_id: int, target_id: int) -> void:
	_awaiting_attack = false

	# Refresh everything after attack
	pathfinder = engine.get_pathfinder()
	_refresh_fog()
	unit_renderer.refresh_units()
	unit_renderer.selected_unit_id = selected_unit_id

	# Update overlays and HUD
	if selected_unit_id != -1:
		_update_overlays()
		_update_selected_unit_hud()
	_update_hud()


func _on_unit_direction_changed(unit_id: int, direction: int) -> void:
	## Update the unit renderer's direction tracking when a unit moves.
	if unit_renderer:
		unit_renderer._unit_directions[unit_id] = direction


func _on_move_animation_finished(unit_id: int) -> void:
	# Refresh units to show final engine positions -- fog first so unit filter works
	pathfinder = engine.get_pathfinder()
	_refresh_fog()
	unit_renderer.refresh_units()
	unit_renderer.selected_unit_id = selected_unit_id

	# If the animated unit is our selected unit, show updated range
	if unit_id == selected_unit_id:
		_update_overlays()
		_update_selected_unit_hud()


func _on_turn_started(turn: int) -> void:
	print("[Game] === Turn ", turn, " started! ===")
	# Re-fetch pathfinder since model state changed
	pathfinder = engine.get_pathfinder()
	_refresh_fog()
	unit_renderer.refresh_units()
	unit_renderer.selected_unit_id = selected_unit_id
	if selected_unit_id != -1:
		_update_overlays()
	_update_hud()
	# Phase 21: Check for research level-ups
	_check_research_notifications()
	# Phase 22: Check energy warnings + refresh resource overlay
	_check_energy_warnings()
	_check_resource_discoveries()
	if _resource_overlay_visible:
		_refresh_resource_overlay()

	# Phase 23: Check resource warnings and show turn report
	_check_resource_warnings()
	_check_production_complete()
	var report: Array = _build_turn_report()
	if not report.is_empty():
		hud.show_turn_report(report)

	# Phase 24: Auto-save at turn boundaries
	_do_autosave()


func _on_turn_ended() -> void:
	print("[Game] Turn ended, processing...")
	_update_hud()


func _on_player_finished_turn(player_id: int) -> void:
	print("[Game] Player ", player_id, " finished turn")
	_update_hud()


func _on_end_turn_pressed() -> void:
	if not game_running or _hotseat_transition:
		return

	AudioManager.play_sound("turn_end")
	print("[Game] Ending turn for player ", current_player)
	var ok = engine.end_player_turn(current_player)
	if not ok:
		print("[Game] Could not end turn (already ended?)")
		return

	if _is_hotseat:
		# Hot Seat: cycle to next player or advance turn
		var next_player := current_player + 1
		if next_player >= _hotseat_player_count:
			# All players have finished -- end turn for real, advance game turn
			# Process the turn
			engine.advance_ticks(10)
			# Next turn starts with player 0
			next_player = 0
		# Show transition screen
		_show_hotseat_transition(next_player)
	else:
		if not _is_multiplayer:
			# In single-player, also end other players' turns automatically
			for i in range(engine.get_player_count()):
				if i != current_player:
					engine.end_player_turn(i)
		_update_hud()


# --- Pause menu ---

func _toggle_pause() -> void:
	if _game_paused:
		_on_pause_resumed()
	else:
		_game_paused = true
		if pause_menu:
			pause_menu.open()
		print("[Game] Game paused")


func _on_pause_resumed() -> void:
	_game_paused = false
	if pause_menu:
		pause_menu.close()
	print("[Game] Game resumed")


func _on_quit_to_menu() -> void:
	game_running = false
	_game_paused = false
	AudioManager.stop_music()
	if GameManager:
		GameManager.go_to_main_menu()


# --- Victory / Defeat (Phase 27 enhanced) ---

var _sudden_death_active := false  # Phase 27: Sudden death mode flag

func _on_player_won(player_id: int) -> void:
	var player = engine.get_player(player_id)
	var player_name: String = player.get_name() if player else ("Player %d" % player_id)
	print("[Game] === VICTORY: ", player_name, " wins! ===")

	# Build victory details with game context
	var victory_settings: Dictionary = engine.get_victory_settings()
	var vtype: String = victory_settings.get("type", "elimination")
	var details := ""
	match vtype:
		"turn_limit":
			details = "Turn limit reached (%d turns)." % victory_settings.get("target_turns", 0)
		"points":
			details = "Score target reached (%d points)." % victory_settings.get("target_points", 0)
		_:
			details = "All opponents have been eliminated."

	if _sudden_death_active:
		details += "\nDecided in Sudden Death mode."

	# Stop background music, play victory/defeat music
	AudioManager.stop_music()

	if player_id == current_player:
		# We won!
		if game_over_screen:
			game_over_screen.show_victory(player_name, details)
			_game_paused = true
	else:
		# Someone else won -- we lost
		if game_over_screen:
			game_over_screen.show_defeat(player_name, "%s has achieved victory.\n%s" % [player_name, details])
			_game_paused = true

	# Show statistics for all players
	_show_end_game_stats()


func _on_player_lost(player_id: int) -> void:
	var player = engine.get_player(player_id)
	var player_name: String = player.get_name() if player else ("Player %d" % player_id)
	print("[Game] === DEFEAT: ", player_name, " eliminated! ===")

	if player_id == current_player:
		# We lost
		AudioManager.stop_music()
		if game_over_screen:
			game_over_screen.show_defeat(player_name, "All your units have been destroyed.")
			_game_paused = true
			_show_end_game_stats()


func _show_end_game_stats() -> void:
	## Gather and display end-game statistics for all players.
	if not game_over_screen:
		return

	var player_stats: Array = []
	var player_count: int = engine.get_player_count()

	for pi in range(player_count):
		var player = engine.get_player(pi)
		if not player:
			continue

		var stats: Dictionary = player.get_game_over_stats() if player.has_method("get_game_over_stats") else {}
		var score_history: PackedInt32Array = player.get_score_history() if player.has_method("get_score_history") else PackedInt32Array()

		player_stats.append({
			"name": player.get_name(),
			"color": player.get_color(),
			"score": player.get_score(),
			"built_vehicles": stats.get("built_vehicles", 0),
			"lost_vehicles": stats.get("lost_vehicles", 0),
			"built_buildings": stats.get("built_buildings", 0),
			"lost_buildings": stats.get("lost_buildings", 0),
			"eco_spheres": stats.get("eco_spheres", 0),
			"is_defeated": player.is_defeated(),
			"vehicles_alive": stats.get("vehicles_alive", player.get_vehicle_count()),
			"buildings_alive": stats.get("buildings_alive", player.get_building_count()),
			"score_history": score_history,
		})

	game_over_screen.show_statistics(player_stats)


# --- Multiplayer ---

func _create_minimap() -> void:
	## Create and set up the minimap in the HUD.
	var MinimapScript = preload("res://scripts/game/minimap.gd")
	minimap = MinimapScript.new()
	minimap.name = "Minimap"

	var minimap_container = hud.get_node_or_null("MinimapContainer")
	if minimap_container:
		minimap_container.add_child(minimap)
		minimap.setup(engine, map_renderer, fog, camera, current_player)
		minimap.minimap_clicked.connect(_on_minimap_clicked)
		# Phase 25: Add minimap zoom and filter buttons
		var mm_btn_row := HBoxContainer.new()
		mm_btn_row.add_theme_constant_override("separation", 2)
		minimap_container.add_child(mm_btn_row)
		var zoom_btn := Button.new()
		zoom_btn.text = "Zoom"
		zoom_btn.custom_minimum_size = Vector2(50, 20)
		zoom_btn.add_theme_font_size_override("font_size", 9)
		zoom_btn.pressed.connect(func(): minimap.toggle_zoom())
		mm_btn_row.add_child(zoom_btn)
		var filter_btn := Button.new()
		filter_btn.text = "Armed"
		filter_btn.custom_minimum_size = Vector2(50, 20)
		filter_btn.add_theme_font_size_override("font_size", 9)
		filter_btn.toggle_mode = true
		filter_btn.pressed.connect(func(): minimap.toggle_attack_filter())
		mm_btn_row.add_child(filter_btn)
	else:
		push_warning("[Game] MinimapContainer not found in HUD")


func _on_minimap_clicked(world_position: Vector2) -> void:
	## Pan camera to the clicked minimap location.
	if camera:
		camera.position = world_position


func _create_chat_overlay() -> void:
	## Create the in-game chat overlay for multiplayer.
	var chat = preload("res://scripts/ui/chat_overlay.gd").new()
	chat.name = "ChatOverlay"
	add_child(chat)
	chat.add_system_message("Multiplayer game started!")


func _create_network_status_overlay() -> void:
	## Create a simple network status overlay for freeze mode display.
	network_status = preload("res://scripts/ui/network_status.gd").new()
	network_status.name = "NetworkStatus"
	# Add as a CanvasLayer so it draws above everything
	var canvas := CanvasLayer.new()
	canvas.name = "NetworkStatusLayer"
	canvas.layer = 100
	add_child(canvas)
	canvas.add_child(network_status)


func _on_freeze_mode_changed(mode: String) -> void:
	## Called when the game enters or exits a freeze mode (waiting for network).
	print("[Game] Freeze mode: ", mode)
	if network_status:
		network_status.set_freeze_mode(mode)


func _on_connection_lost() -> void:
	## Called when the connection to the server is lost.
	print("[Game] CONNECTION LOST!")
	_game_paused = true
	if network_status:
		network_status.show_connection_lost()

	# After a delay, return to main menu
	await get_tree().create_timer(5.0).timeout
	_on_quit_to_menu()


# --- Hot Seat turn transitions ---

func _create_turn_transition_overlay() -> void:
	## Create a full-screen overlay for hot seat player transitions.
	## Added to a CanvasLayer so it draws above everything.
	var canvas := CanvasLayer.new()
	canvas.name = "TurnTransitionLayer"
	canvas.layer = 90
	add_child(canvas)

	_turn_transition_overlay = ColorRect.new()
	_turn_transition_overlay.color = Color(0.02, 0.04, 0.08, 0.95)
	_turn_transition_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_turn_transition_overlay.visible = false
	canvas.add_child(_turn_transition_overlay)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.offset_left = -250
	vbox.offset_top = -120
	vbox.offset_right = 250
	vbox.offset_bottom = 120
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.set("theme_override_constants/separation", 20)
	_turn_transition_overlay.add_child(vbox)

	_turn_transition_label = Label.new()
	_turn_transition_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_turn_transition_label.add_theme_font_size_override("font_size", 36)
	_turn_transition_label.add_theme_color_override("font_color", Color(0.3, 0.75, 1.0))
	vbox.add_child(_turn_transition_label)

	_turn_transition_sublabel = Label.new()
	_turn_transition_sublabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_turn_transition_sublabel.add_theme_font_size_override("font_size", 18)
	_turn_transition_sublabel.add_theme_color_override("font_color", Color(0.55, 0.60, 0.70))
	vbox.add_child(_turn_transition_sublabel)

	_turn_transition_button = Button.new()
	_turn_transition_button.text = "READY"
	_turn_transition_button.custom_minimum_size = Vector2(200, 50)
	_turn_transition_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_turn_transition_button.add_theme_font_size_override("font_size", 22)
	_turn_transition_button.pressed.connect(_on_hotseat_ready_pressed)
	vbox.add_child(_turn_transition_button)


func _show_hotseat_transition(next_player_idx: int) -> void:
	## Show the hot seat transition screen between players.
	_hotseat_transition = true
	_game_paused = true

	# Deselect everything
	selected_unit_id = -1
	unit_renderer.selected_unit_id = -1
	if overlay:
		overlay.clear_all()

	# Get next player's name
	var player = engine.get_player(next_player_idx)
	var player_name: String = player.get_name() if player else ("Player %d" % (next_player_idx + 1))

	if _turn_transition_label:
		_turn_transition_label.text = player_name + "'s Turn"
	if _turn_transition_sublabel:
		var turn_num: int = engine.get_turn_number()
		_turn_transition_sublabel.text = "Turn %d -- Press READY when the screen is clear" % turn_num
	if _turn_transition_overlay:
		_turn_transition_overlay.visible = true

	# Store which player is next
	_turn_transition_overlay.set_meta("next_player", next_player_idx)


func _on_hotseat_ready_pressed() -> void:
	## Player pressed READY on the transition screen.
	AudioManager.play_sound("click")

	if not _turn_transition_overlay:
		return

	var next_player_idx: int = _turn_transition_overlay.get_meta("next_player", 0)

	# Switch to next player
	current_player = next_player_idx

	# Start this player's turn in the engine
	engine.start_player_turn(current_player)

	# Hide overlay
	_turn_transition_overlay.visible = false
	_hotseat_transition = false
	_game_paused = false

	# Refresh everything for the new player
	if fog:
		fog.current_player = current_player
		fog.refresh(engine)
	_refresh_fog()
	unit_renderer.current_player = current_player
	unit_renderer.refresh_units()
	_update_hud()

	# Center camera on this player's units
	_center_camera_on_player(current_player)

	print("[Game] Hot Seat: now controlling player ", current_player)


func _center_camera_on_player(player_idx: int) -> void:
	## Center the camera on the first unit of the given player.
	var vehicles = engine.get_player_vehicles(player_idx)
	if vehicles.size() > 0:
		var pos: Vector2i = vehicles[0].get_position()
		if camera:
			camera.position = Vector2(pos.x * TILE_SIZE + TILE_SIZE / 2.0,
									  pos.y * TILE_SIZE + TILE_SIZE / 2.0)
		return
	var buildings = engine.get_player_buildings(player_idx)
	if buildings.size() > 0:
		var pos: Vector2i = buildings[0].get_position()
		if camera:
			camera.position = Vector2(pos.x * TILE_SIZE + TILE_SIZE / 2.0,
									  pos.y * TILE_SIZE + TILE_SIZE / 2.0)


# =============================================================================
# PHASE 19: UNIT COMMAND SYSTEM
# =============================================================================

func _cancel_cmd_mode() -> void:
	## Cancel the current command target selection mode.
	if _cmd_mode != "":
		print("[Game] Cancelled command mode: ", _cmd_mode)
		_cmd_mode = ""
		_cmd_source_id = -1
		overlay.clear_all()
		if selected_unit_id != -1:
			_update_overlays()


func _on_command_pressed(command: String) -> void:
	## Handle command button presses from the HUD.
	if not game_running:
		return

	# --- Global commands (no unit selection needed) ---
	if command == "open_casualties":
		_cmd_open_casualties()
		return
	elif command == "open_player_stats":
		_cmd_open_player_stats()
		return
	elif command == "open_army":
		_cmd_open_army()
		return
	elif command == "open_economy":
		_cmd_open_economy()
		return
	elif command == "open_research":
		_cmd_open_research()
		return
	elif command == "open_upgrades":
		_cmd_open_upgrades()
		return
	elif command == "open_bases":
		_cmd_open_bases()
		return
	elif command == "toggle_resource_overlay":
		_cmd_toggle_resource_overlay()
		return

	# --- Unit-specific commands ---
	if selected_unit_id == -1:
		return

	# Cancel any active command mode
	_cancel_cmd_mode()

	print("[Game] Command: ", command, " on unit ", selected_unit_id)

	# --- Immediate toggle actions ---
	if command == "sentry":
		_cmd_toggle_sentry()
	elif command == "manual_fire":
		_cmd_toggle_manual_fire()
	elif command == "stop":
		_cmd_stop()
	elif command == "survey":
		_cmd_toggle_survey()
	elif command == "lay_mines":
		_cmd_toggle_lay_mines()
	elif command == "clear_mines":
		_cmd_toggle_clear_mines()
	elif command == "clear":
		_cmd_clear_rubble()
	elif command == "self_destroy":
		_cmd_self_destroy()
	elif command == "rename":
		_cmd_rename()
	elif command == "info":
		_cmd_show_unit_info()
	# --- Phase 21: Research & Upgrades ---
	elif command == "upgrade_unit":
		_cmd_upgrade_unit()
	elif command == "upgrade_all":
		_cmd_upgrade_all()
	# --- Phase 22: Mining & Economy ---
	elif command == "survey":
		_cmd_toggle_survey()
	elif command == "mining":
		_cmd_open_mining()
	# --- Phase 26: Construction Enhancements ---
	elif command == "cancel_build":
		_cmd_cancel_construction()
	elif command == "path_build":
		_cmd_start_path_build()
	# --- Target-selection actions (enter selection mode) ---
	elif command == "load":
		_cmd_enter_mode("load")
	elif command == "activate":
		_cmd_activate_unit()
	elif command == "repair":
		_cmd_enter_mode("repair")
	elif command == "reload":
		_cmd_enter_mode("reload")
	elif command == "steal":
		_cmd_enter_mode("steal")
	elif command == "disable":
		_cmd_enter_mode("disable")
	elif command == "transfer":
		_cmd_enter_mode("transfer_target")
	# --- Dialog confirmations ---
	elif command.begins_with("rename_confirmed:"):
		var new_name: String = command.substr(len("rename_confirmed:"))
		_cmd_rename_confirm(new_name)
	elif command.begins_with("transfer_confirmed:"):
		var parts: PackedStringArray = command.substr(len("transfer_confirmed:")).split(":")
		if parts.size() >= 2:
			_cmd_transfer_confirm(parts[0], int(parts[1]))


# --- Immediate commands ---

func _cmd_toggle_sentry() -> void:
	if actions.toggle_sentry(selected_unit_id):
		print("[Game] Toggled sentry on unit ", selected_unit_id)
		_refresh_after_action()
	else:
		print("[Game] Failed to toggle sentry")


func _cmd_toggle_manual_fire() -> void:
	if actions.toggle_manual_fire(selected_unit_id):
		print("[Game] Toggled manual fire on unit ", selected_unit_id)
		_refresh_after_action()
	else:
		print("[Game] Failed to toggle manual fire")


func _cmd_stop() -> void:
	if actions.stop(selected_unit_id):
		print("[Game] Stopped unit ", selected_unit_id)
		_refresh_after_action()
	else:
		print("[Game] Failed to stop unit")


func _cmd_cancel_build_from_stop() -> void:
	## Called from STOP button — if the unit is constructing, cancel it
	var unit = _find_unit(selected_unit_id)
	if unit and unit.is_vehicle() and unit.is_building_a_building():
		_cmd_cancel_construction()
	else:
		_cmd_stop()


func _cmd_toggle_survey() -> void:
	var unit = _find_unit(selected_unit_id)
	if not unit:
		return
	# Auto-move is a toggle; check if we're turning it on or off
	# The engine will handle the toggle internally
	if actions.set_auto_move(selected_unit_id, true):
		print("[Game] Toggled auto-survey on unit ", selected_unit_id)
		_refresh_after_action()
	else:
		print("[Game] Failed to toggle survey")


func _cmd_toggle_lay_mines() -> void:
	if actions.set_minelayer_status(selected_unit_id, true, false):
		print("[Game] Toggled mine laying on unit ", selected_unit_id)
		_refresh_after_action()
	else:
		print("[Game] Failed to toggle mine laying")


func _cmd_toggle_clear_mines() -> void:
	if actions.set_minelayer_status(selected_unit_id, false, true):
		print("[Game] Toggled mine clearing on unit ", selected_unit_id)
		_refresh_after_action()
	else:
		print("[Game] Failed to toggle mine clearing")


func _cmd_clear_rubble() -> void:
	if actions.clear_area(selected_unit_id):
		print("[Game] Clearing area with unit ", selected_unit_id)
		_refresh_after_action()
	else:
		print("[Game] Failed to clear area (may need to be adjacent to rubble)")


func _cmd_self_destroy() -> void:
	# Confirm before destroying
	if actions.self_destroy(selected_unit_id):
		print("[Game] Self-destructed building ", selected_unit_id)
		_deselect_unit()
		_refresh_after_action()
	else:
		print("[Game] Failed to self-destruct")


func _cmd_show_unit_info() -> void:
	## Open the full unit information popup.
	var unit = _find_unit(selected_unit_id)
	if not unit:
		return
	var pos = unit.get_position()
	var mp = 0
	var mp_max = 0
	if pathfinder:
		mp = pathfinder.get_movement_points(selected_unit_id)
		mp_max = pathfinder.get_movement_points_max(selected_unit_id)

	hud.show_unit_info({
		"name": unit.get_name(),
		"type_name": unit.get_type_name(),
		"id": unit.get_id(),
		"is_building": unit.is_building(),
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
		"scan": unit.get_scan(),
		"pos_x": pos.x,
		"pos_y": pos.y,
		"owner_id": unit.get_owner_id(),
		"is_sentry": unit.is_sentry_active(),
		"is_manual_fire": unit.is_manual_fire(),
		"is_disabled": unit.is_disabled(),
		"disabled_turns": unit.get_disabled_turns(),
		"is_dated": unit.is_dated(),
		"version": unit.get_version(),
		"rank": unit.get_commando_rank(),
		"rank_name": unit.get_commando_rank_name(),
		"stored_units": unit.get_stored_units_count(),
		"stored_resources": unit.get_stored_resources(),
		"description": unit.get_description(),
	})


func _cmd_rename() -> void:
	var unit = _find_unit(selected_unit_id)
	if unit:
		hud.show_rename_dialog(unit.get_name())


func _cmd_rename_confirm(new_name: String) -> void:
	if selected_unit_id == -1:
		return
	if actions.rename_unit(selected_unit_id, new_name):
		print("[Game] Renamed unit ", selected_unit_id, " to: ", new_name)
		_refresh_after_action()
	else:
		print("[Game] Failed to rename unit")


# --- Target-selection mode ---

func _cmd_enter_mode(mode: String) -> void:
	## Enter a command mode that requires clicking a target on the map.
	_cmd_mode = mode
	_cmd_source_id = selected_unit_id
	overlay.clear_all()
	print("[Game] Entered %s mode -- click a target" % mode)


func _cmd_activate_unit() -> void:
	## Open the activation (unload) dialog with a list of stored units.
	var unit = _find_unit(selected_unit_id)
	if not unit or unit.get_stored_units_count() <= 0:
		return

	var stored = unit.get_stored_units()
	if stored.size() == 0:
		return

	# For simplicity, activate the first stored unit at the first adjacent valid tile
	# In the future this should be a proper selection UI
	var container_pos: Vector2i = unit.get_position()
	var candidates: Array[Vector2i] = []
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var adj := Vector2i(container_pos.x + dx, container_pos.y + dy)
			if map_renderer.is_valid_tile(adj):
				candidates.append(adj)

	if candidates.size() > 0 and stored.size() > 0:
		var first_stored_id: int = stored[0].get("id", -1)
		if first_stored_id >= 0:
			# Enter activation target selection mode
			_cmd_mode = "activate"
			_cmd_source_id = selected_unit_id
			# Store the vehicle to activate
			set_meta("activate_vehicle_id", first_stored_id)
			print("[Game] Click a tile to unload unit %d" % first_stored_id)
			return

	print("[Game] No valid position to unload")


func _handle_cmd_mode_click(tile: Vector2i) -> bool:
	## Handle a left-click while in command target selection mode.
	## Returns true if the click was consumed.
	if _cmd_mode == "" or _cmd_source_id == -1:
		return false

	var target_unit_id: int = unit_renderer.get_unit_at_tile(tile)

	match _cmd_mode:
		"load":
			if target_unit_id != -1 and target_unit_id != _cmd_source_id:
				if actions.load_unit(_cmd_source_id, target_unit_id):
					print("[Game] Loaded unit %d into %d" % [target_unit_id, _cmd_source_id])
				else:
					print("[Game] Failed to load unit (may not be adjacent or compatible)")
			else:
				print("[Game] No unit to load at ", tile)
			_cancel_cmd_mode()
			_refresh_after_action()
			return true

		"repair":
			if target_unit_id != -1 and target_unit_id != _cmd_source_id:
				if actions.repair_reload(_cmd_source_id, target_unit_id, "repair"):
					print("[Game] Repairing unit ", target_unit_id)
				else:
					print("[Game] Failed to repair (may not be adjacent or have supplies)")
			_cancel_cmd_mode()
			_refresh_after_action()
			return true

		"reload":
			if target_unit_id != -1 and target_unit_id != _cmd_source_id:
				if actions.repair_reload(_cmd_source_id, target_unit_id, "reload"):
					print("[Game] Reloading unit ", target_unit_id)
				else:
					print("[Game] Failed to reload (may not be adjacent or have supplies)")
			_cancel_cmd_mode()
			_refresh_after_action()
			return true

		"steal":
			if target_unit_id != -1:
				if actions.steal_disable(_cmd_source_id, target_unit_id, true):
					print("[Game] Stealing unit ", target_unit_id)
				else:
					print("[Game] Failed to steal (must be adjacent to enemy)")
			_cancel_cmd_mode()
			_refresh_after_action()
			return true

		"disable":
			if target_unit_id != -1:
				if actions.steal_disable(_cmd_source_id, target_unit_id, false):
					print("[Game] Disabling unit ", target_unit_id)
				else:
					print("[Game] Failed to disable (must be adjacent to enemy)")
			_cancel_cmd_mode()
			_refresh_after_action()
			return true

		"activate":
			var vehicle_to_activate: int = get_meta("activate_vehicle_id", -1)
			if vehicle_to_activate >= 0:
				if actions.activate_unit(_cmd_source_id, vehicle_to_activate, tile):
					print("[Game] Activated unit %d at %s" % [vehicle_to_activate, tile])
				else:
					print("[Game] Failed to activate unit at ", tile)
			_cancel_cmd_mode()
			_refresh_after_action()
			return true

		"upgrade_vehicle":
			# Click on a depot/hangar to upgrade the vehicle there
			if target_unit_id != -1 and target_unit_id != _cmd_source_id:
				var target_unit = _find_unit(target_unit_id)
				if target_unit and target_unit.is_building():
					if actions.upgrade_vehicle(target_unit_id, _cmd_source_id):
						print("[Game] Upgraded vehicle %d at depot %d" % [_cmd_source_id, target_unit_id])
					else:
						print("[Game] Failed to upgrade vehicle (must be stored in depot)")
				else:
					print("[Game] Target must be a depot building")
			else:
				print("[Game] No depot at ", tile)
			_cancel_cmd_mode()
			_refresh_after_action()
			return true

		"transfer_target":
			if target_unit_id != -1 and target_unit_id != _cmd_source_id:
				# Store the transfer target, show the transfer dialog
				set_meta("transfer_target_id", target_unit_id)
				var unit = _find_unit(_cmd_source_id)
				var max_res: int = unit.get_stored_resources() if unit else 100
				hud.show_transfer_dialog(max_res)
				_cmd_mode = ""  # Exit mode, dialog handles the rest
			else:
				print("[Game] No target for transfer at ", tile)
				_cancel_cmd_mode()
			return true

	return false


func _cmd_transfer_confirm(resource_type: String, amount: int) -> void:
	## Confirm a resource transfer (from dialog).
	var target_id: int = get_meta("transfer_target_id", -1)
	if target_id == -1 or _cmd_source_id == -1:
		print("[Game] Transfer: no target or source")
		return

	if actions.transfer_resources(_cmd_source_id, target_id, amount, resource_type):
		print("[Game] Transferred %d %s from %d to %d" % [amount, resource_type, _cmd_source_id, target_id])
	else:
		print("[Game] Transfer failed")
	_cmd_source_id = -1
	_refresh_after_action()


# =============================================================================
# PHASE 21: RESEARCH & UPGRADES
# =============================================================================

func _cmd_open_research() -> void:
	## Open the research allocation panel.
	var player = engine.get_player(current_player)
	if not player:
		return
	var levels: Dictionary = player.get_research_levels()
	var centers_per_area: Array = player.get_research_centers_per_area()
	var remaining_turns: Array = player.get_research_remaining_turns()
	var total_centers: int = player.get_research_centers_working()
	hud.show_research_panel(levels, centers_per_area, remaining_turns, total_centers)


func _cmd_open_upgrades() -> void:
	## Open the gold upgrades panel.
	var player = engine.get_player(current_player)
	if not player or not actions:
		return
	var upgradeable: Array = actions.get_upgradeable_units(current_player)
	var credits: int = player.get_credits()
	hud.show_upgrades_panel(upgradeable, credits)


func _on_research_allocation_changed(areas: Array) -> void:
	## Apply new research allocation from the panel.
	if not actions:
		return
	if actions.change_research(areas):
		print("[Game] Research allocation updated: ", areas)
		_refresh_after_action()
	else:
		print("[Game] Failed to change research allocation")


func _on_gold_upgrade_requested(id_first: int, id_second: int, stat_index: int) -> void:
	## Purchase a gold upgrade for a unit type.
	if not actions:
		return
	var cost: int = actions.buy_unit_upgrade(current_player, id_first, id_second, stat_index)
	if cost > 0:
		print("[Game] Purchased upgrade (stat %d) for %d.%d — cost: %d" % [stat_index, id_first, id_second, cost])
		# Refresh the upgrades panel to show updated values
		_cmd_open_upgrades()
		_refresh_after_action()
	else:
		print("[Game] Failed to purchase upgrade")


func _cmd_upgrade_unit() -> void:
	## Upgrade the selected unit to the latest version.
	if selected_unit_id == -1 or not actions:
		return
	var unit = _find_unit(selected_unit_id)
	if not unit:
		return
	if unit.is_building():
		# Building upgrade
		var cost: int = actions.get_building_upgrade_cost(selected_unit_id)
		if cost < 0:
			print("[Game] Building already at latest version")
			return
		if actions.upgrade_building(selected_unit_id, false):
			print("[Game] Upgraded building %d (cost: %d metal)" % [selected_unit_id, cost])
			_refresh_after_action()
		else:
			print("[Game] Failed to upgrade building")
	else:
		# Vehicle upgrade — need to find a depot the vehicle is stored in.
		# For now, try to find a nearby depot.
		_cmd_enter_mode("upgrade_vehicle")


func _cmd_upgrade_all() -> void:
	## Upgrade all buildings of the same type in the sub-base.
	if selected_unit_id == -1 or not actions:
		return
	if actions.upgrade_building(selected_unit_id, true):
		print("[Game] Upgraded all buildings of same type as %d" % selected_unit_id)
		_refresh_after_action()
	else:
		print("[Game] Failed to upgrade all buildings")


# =============================================================================
# PHASE 22: MINING, RESOURCES & ECONOMY
# =============================================================================

func _cmd_toggle_survey() -> void:
	## Toggle auto-survey mode for the selected surveyor vehicle.
	if selected_unit_id == -1:
		return
	var unit = _find_unit(selected_unit_id)
	if not unit or unit.is_building():
		return
	var caps: Dictionary = unit.get_capabilities()
	if not caps.get("can_survey", false):
		return
	# Toggle auto-move (surveyor auto-move = auto-survey)
	if actions.set_auto_move(selected_unit_id, true):
		print("[Game] Auto-survey enabled for unit %d" % selected_unit_id)
	else:
		print("[Game] Failed to toggle auto-survey")
	_refresh_after_action()


func _cmd_open_mining() -> void:
	## Open the mining allocation dialog for the selected mine building.
	if selected_unit_id == -1:
		return
	var unit = _find_unit(selected_unit_id)
	if not unit or not unit.is_building():
		return
	var current: Dictionary = unit.get_mining_production()
	var max_prod: Dictionary = unit.get_mining_max()
	var max_total: int = max_prod.get("metal", 0) + max_prod.get("oil", 0) + max_prod.get("gold", 0)
	if max_total <= 0:
		print("[Game] This building has no mining capacity")
		return
	hud.show_mining_dialog(selected_unit_id, current, max_prod, max_total)


func _on_mining_distribution_changed(unit_id: int, metal: int, oil: int, gold: int) -> void:
	## Apply new mining distribution from the dialog.
	if not actions:
		return
	if actions.set_resource_distribution(unit_id, metal, oil, gold):
		print("[Game] Mining allocation updated for %d: M=%d O=%d G=%d" % [unit_id, metal, oil, gold])
		_refresh_after_action()
	else:
		print("[Game] Failed to set mining distribution")


func _cmd_open_bases() -> void:
	## Open the sub-base overview panel.
	var player = engine.get_player(current_player)
	if not player:
		return
	var sub_bases: Array = player.get_sub_bases()
	hud.show_subbase_panel(sub_bases)


func _cmd_toggle_resource_overlay() -> void:
	## Toggle the resource overlay on the map.
	_resource_overlay_visible = not _resource_overlay_visible
	if _resource_overlay_visible:
		_refresh_resource_overlay()
	else:
		overlay.clear_resource_overlay()
	print("[Game] Resource overlay: ", "ON" if _resource_overlay_visible else "OFF")


func _refresh_resource_overlay() -> void:
	## Refresh the resource overlay from survey data.
	if not _resource_overlay_visible:
		return
	var player = engine.get_player(current_player)
	var game_map = engine.get_map()
	if not player or not game_map:
		return
	var map_size: Vector2i = game_map.get_size()
	var resource_tiles: Array = []
	for y in range(map_size.y):
		for x in range(map_size.x):
			var pos := Vector2i(x, y)
			if player.has_resource_explored(pos):
				var res: Dictionary = game_map.get_resource_at(pos)
				var res_type: String = res.get("type", "none")
				if res_type != "none" and res.get("value", 0) > 0:
					resource_tiles.append({
						"pos": pos,
						"type": res_type,
						"value": res.get("value", 0)
					})
	overlay.set_resource_overlay(resource_tiles)


# =============================================================================
# PHASE 29: KEYBOARD SHORTCUTS & UX
# =============================================================================

func _handle_keyboard_shortcut(ke: InputEventKey) -> bool:
	## Process a keypress and return true if handled.
	var kc: int = ke.keycode

	# --- 29.6: Screenshot (Alt+C) ---
	if ke.alt_pressed and kc == KEY_C:
		_take_screenshot()
		return true

	# --- 29.4: Saved camera positions (F5-F8 save with Alt, recall without) ---
	if kc >= KEY_F5 and kc <= KEY_F8:
		var slot: int = kc - KEY_F5  # 0-3
		if ke.alt_pressed:
			camera.save_position(slot)
			hud.show_alert("Camera position %d saved" % (slot + 1), Color(0.3, 0.85, 0.5))
		else:
			if camera.recall_position(slot):
				hud.show_alert("Camera position %d recalled" % (slot + 1), Color(0.3, 0.7, 1.0))
		return true

	# --- 29.2: Unit group hotkeys (Ctrl+1-9 to assign, 1-9 to recall) ---
	if kc >= KEY_1 and kc <= KEY_9:
		var group_num: int = kc - KEY_0  # 1-9
		if ke.ctrl_pressed:
			_assign_unit_group(group_num)
			return true
		else:
			_recall_unit_group(group_num)
			return true

	# --- 29.1: RTS hotkeys for unit commands ---
	if selected_unit_id == -1:
		# Global hotkeys (no unit selected)
		match kc:
			KEY_ENTER, KEY_KP_ENTER:
				hud.end_turn_pressed.emit()
				return true
			KEY_SPACE:
				_cycle_to_next_idle_unit()
				return true
			KEY_TAB:
				_cycle_to_next_unit(ke.shift_pressed)
				return true
		return false

	# Unit command hotkeys
	match kc:
		KEY_A:
			_on_command_pressed("manual_fire")
			return true
		KEY_S:
			_on_command_pressed("sentry")
			return true
		KEY_G:
			_on_command_pressed("stop")
			return true
		KEY_R:
			_on_command_pressed("repair")
			return true
		KEY_L:
			_on_command_pressed("load")
			return true
		KEY_U:
			_on_command_pressed("activate")
			return true
		KEY_M:
			_on_command_pressed("mining")
			return true
		KEY_B:
			hud.build_pressed.emit()
			return true
		KEY_I:
			_on_command_pressed("info")
			return true
		KEY_T:
			_on_command_pressed("transfer")
			return true
		KEY_X:
			_on_command_pressed("self_destroy")
			return true
		KEY_N:
			_on_command_pressed("rename")
			return true
		KEY_V:
			_on_command_pressed("survey")
			return true
		KEY_P:
			_on_command_pressed("path_build")
			return true
		KEY_C:
			_on_command_pressed("clear")
			return true
		KEY_DELETE:
			_on_command_pressed("self_destroy")
			return true
		KEY_ENTER, KEY_KP_ENTER:
			hud.end_turn_pressed.emit()
			return true
		KEY_SPACE:
			_cycle_to_next_idle_unit()
			return true
		KEY_TAB:
			_cycle_to_next_unit(ke.shift_pressed)
			return true

	return false


# --- 29.2: Unit Groups ---

func _assign_unit_group(group_num: int) -> void:
	## Assign selected unit(s) to a group.
	var ids: Array = []
	if _selected_units.size() > 0:
		ids = _selected_units.duplicate()
	elif selected_unit_id != -1:
		ids = [selected_unit_id]
	if ids.is_empty():
		return
	_unit_groups[group_num] = ids
	hud.show_alert("Group %d: %d unit(s) assigned" % [group_num, ids.size()],
		Color(0.3, 0.85, 0.5))
	print("[Game] Group %d assigned: %s" % [group_num, str(ids)])


func _recall_unit_group(group_num: int) -> void:
	## Recall a unit group.
	if not _unit_groups.has(group_num):
		hud.show_alert("Group %d is empty" % group_num, Color(0.7, 0.65, 0.5))
		return
	var ids: Array = _unit_groups[group_num]
	if ids.is_empty():
		return

	# Validate units still exist
	var valid_ids: Array = []
	for uid in ids:
		var u = _find_unit(uid)
		if u:
			valid_ids.append(uid)
	_unit_groups[group_num] = valid_ids

	if valid_ids.is_empty():
		hud.show_alert("Group %d: no surviving units" % group_num, Color(1.0, 0.5, 0.4))
		return

	# Select first unit and center camera on it
	_select_unit(valid_ids[0])
	var unit = _find_unit(valid_ids[0])
	if unit:
		camera.center_on_tile(unit.get_position(), TILE_SIZE)

	if valid_ids.size() > 1:
		_selected_units = valid_ids
		hud.show_alert("Group %d: %d units" % [group_num, valid_ids.size()],
			Color(0.3, 0.7, 1.0))


# --- 29.3: Box-Select / Multi-Select ---

func _start_box_select(screen_pos: Vector2) -> void:
	## Begin a box selection drag.
	_box_selecting = true
	_box_select_start = screen_pos
	if not _box_select_rect:
		_box_select_rect = ColorRect.new()
		_box_select_rect.color = Color(0.2, 0.6, 1.0, 0.2)
		_box_select_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		get_tree().root.add_child(_box_select_rect)
	_box_select_rect.visible = true
	_box_select_rect.position = screen_pos
	_box_select_rect.size = Vector2.ZERO


func _update_box_select(screen_pos: Vector2) -> void:
	## Update box selection visual during drag.
	if not _box_select_rect:
		return
	var tl := Vector2(min(_box_select_start.x, screen_pos.x), min(_box_select_start.y, screen_pos.y))
	var br := Vector2(max(_box_select_start.x, screen_pos.x), max(_box_select_start.y, screen_pos.y))
	_box_select_rect.position = tl
	_box_select_rect.size = br - tl


func _finish_box_select(screen_pos: Vector2) -> void:
	## Finish box selection and select units within the rectangle.
	_box_selecting = false
	if _box_select_rect:
		_box_select_rect.visible = false

	# Calculate the screen-space rectangle
	var tl := Vector2(min(_box_select_start.x, screen_pos.x), min(_box_select_start.y, screen_pos.y))
	var br := Vector2(max(_box_select_start.x, screen_pos.x), max(_box_select_start.y, screen_pos.y))

	# If the rectangle is too small, treat as a regular click
	if (br - tl).length() < 10:
		_handle_left_click(_box_select_start)
		return

	# Convert screen rectangle corners to world positions then to tiles
	var world_tl := camera.get_global_transform().affine_inverse() * tl
	var world_br := camera.get_global_transform().affine_inverse() * br

	# More reliable: use screen_to_world via camera transform
	var vp_size := get_viewport_rect().size
	var cam_pos := camera.get_screen_center_position()
	var cam_zoom := camera.zoom

	# Convert screen coords to world coords
	world_tl = cam_pos + (tl - vp_size / 2.0) / cam_zoom
	world_br = cam_pos + (br - vp_size / 2.0) / cam_zoom

	var tile_tl := map_renderer.world_to_tile(world_tl)
	var tile_br := map_renderer.world_to_tile(world_br)

	# Find our units in the box
	var selected_ids: Array = []
	var vehicles: Array = engine.get_player_vehicles(current_player)
	for v in vehicles:
		var pos: Vector2i = v.get_position()
		if pos.x >= tile_tl.x and pos.x <= tile_br.x and pos.y >= tile_tl.y and pos.y <= tile_br.y:
			selected_ids.append(v.get_id())

	if selected_ids.is_empty():
		return

	# Select first unit for the HUD
	_select_unit(selected_ids[0])
	_selected_units = selected_ids

	if selected_ids.size() > 1:
		hud.show_alert("%d units selected" % selected_ids.size(), Color(0.3, 0.7, 1.0))
	print("[Game] Box selected: %s" % str(selected_ids))


# --- 29.5: Path Preview (Shift+hover) ---
# Path preview is already triggered on hover when a unit is selected (see _update_hover_preview).
# The shift key is tracked via _shift_held. When shift is held while hovering, we force
# path preview display even if the tile is not in reachable range (showing a long-distance path).
# This is handled by modifying _update_hover_preview below.

# --- 29.6: Screenshot ---

func _take_screenshot() -> void:
	## Capture a screenshot and save to user data folder.
	var img: Image = get_viewport().get_texture().get_image()
	if not img:
		hud.show_alert("Screenshot failed", Color(1.0, 0.4, 0.35))
		return

	var timestamp: String = Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var dir_path := "user://screenshots"
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)
	var file_path := "%s/maxtreme_%s.png" % [dir_path, timestamp]
	var err := img.save_png(file_path)
	if err == OK:
		hud.show_alert("Screenshot saved: %s" % file_path.get_file(), Color(0.3, 0.85, 0.5))
		print("[Game] Screenshot saved: ", file_path)
	else:
		hud.show_alert("Screenshot error: %d" % err, Color(1.0, 0.4, 0.35))


# --- Unit cycling helpers ---

func _cycle_to_next_idle_unit() -> void:
	## Cycle to the next idle unit belonging to the current player.
	var vehicles: Array = engine.get_player_vehicles(current_player)
	var candidates: Array = []
	for v in vehicles:
		# Idle = has movement points, not sentry, not disabled, not working
		if v.get_speed() > 0 and not v.is_sentry_active() and not v.is_disabled() and not v.is_working():
			candidates.append(v)

	if candidates.is_empty():
		hud.show_alert("No idle units", Color(0.7, 0.65, 0.5))
		return

	# Find next candidate after currently selected
	var start_idx := 0
	if selected_unit_id != -1:
		for i in range(candidates.size()):
			if candidates[i].get_id() == selected_unit_id:
				start_idx = (i + 1) % candidates.size()
				break

	var next_unit = candidates[start_idx]
	_select_unit(next_unit.get_id())
	camera.center_on_tile(next_unit.get_position(), TILE_SIZE)


func _cycle_to_next_unit(reverse: bool) -> void:
	## Cycle through all units (Tab / Shift+Tab).
	var vehicles: Array = engine.get_player_vehicles(current_player)
	var buildings: Array = engine.get_player_buildings(current_player)
	var all_units: Array = []
	for v in vehicles:
		all_units.append(v)
	for b in buildings:
		all_units.append(b)

	if all_units.is_empty():
		return

	# Find current index
	var current_idx := -1
	if selected_unit_id != -1:
		for i in range(all_units.size()):
			if all_units[i].get_id() == selected_unit_id:
				current_idx = i
				break

	var next_idx: int
	if reverse:
		next_idx = (current_idx - 1 + all_units.size()) % all_units.size() if current_idx >= 0 else all_units.size() - 1
	else:
		next_idx = (current_idx + 1) % all_units.size() if current_idx >= 0 else 0

	var next_unit = all_units[next_idx]
	_select_unit(next_unit.get_id())
	camera.center_on_tile(next_unit.get_position(), TILE_SIZE)


# =============================================================================
# PHASE 28: REPORTS & STATISTICS
# =============================================================================

func _cmd_open_casualties() -> void:
	## Open the casualties report panel.
	var report: Array = engine.get_casualties_report()
	var player_names: Dictionary = {}
	for i in range(engine.get_player_count()):
		var p = engine.get_player(i)
		if p:
			player_names[p.get_id()] = {"name": p.get_name(), "color": p.get_color()}
	hud.show_casualties_report(report, player_names)


func _cmd_open_player_stats() -> void:
	## Open the player statistics panel.
	var players: Array = []
	for i in range(engine.get_player_count()):
		var p = engine.get_player(i)
		if not p:
			continue
		var stats: Dictionary = p.get_game_over_stats()
		stats["name"] = p.get_name()
		stats["color"] = p.get_color()
		players.append(stats)
	hud.show_player_stats(players)


func _cmd_open_army() -> void:
	## Open the army overview panel with all units for the current player.
	var units: Array = []

	var vehicles: Array = engine.get_player_vehicles(current_player)
	for v in vehicles:
		var d: Dictionary = {}
		d["id"] = v.get_id()
		d["name"] = v.get_name()
		d["type_name"] = v.get_type_name()
		d["is_building"] = false
		d["hp"] = v.get_hitpoints()
		d["hp_max"] = v.get_hitpoints_max()
		d["damage"] = v.get_damage()
		d["armor"] = v.get_armor()
		d["ammo"] = v.get_ammo()
		d["ammo_max"] = v.get_ammo_max()
		d["speed"] = v.get_speed()
		d["position"] = v.get_position()
		d["is_working"] = v.is_working()
		d["is_disabled"] = v.is_disabled()
		d["is_sentry"] = v.is_sentry_active()
		d["can_attack"] = v.has_weapon()
		units.append(d)

	var buildings: Array = engine.get_player_buildings(current_player)
	for b in buildings:
		var d: Dictionary = {}
		d["id"] = b.get_id()
		d["name"] = b.get_name()
		d["type_name"] = b.get_type_name()
		d["is_building"] = true
		d["hp"] = b.get_hitpoints()
		d["hp_max"] = b.get_hitpoints_max()
		d["damage"] = b.get_damage()
		d["armor"] = b.get_armor()
		d["ammo"] = b.get_ammo()
		d["ammo_max"] = b.get_ammo_max()
		d["speed"] = 0
		d["position"] = b.get_position()
		d["is_working"] = b.is_working()
		d["is_disabled"] = b.is_disabled()
		d["is_sentry"] = b.is_sentry_active()
		d["can_attack"] = b.has_weapon()
		units.append(d)

	hud.show_army_overview(units)


func _cmd_open_economy() -> void:
	## Open the economy summary panel.
	var player = engine.get_player(current_player)
	if not player:
		return
	var economy: Dictionary = player.get_economy_summary()
	hud.show_economy_summary(economy)


# =============================================================================
# PHASE 23: NOTIFICATIONS & EVENT LOG
# =============================================================================

func _on_unit_attacked(player_id: int, unit_id: int, unit_name: String, position: Vector2i) -> void:
	## C++ signal: a unit belonging to player_id was attacked.
	if player_id == current_player:
		hud.show_alert(
			"%s under attack at (%d, %d)!" % [unit_name, position.x, position.y],
			Color(1.0, 0.35, 0.2),
			position)
	else:
		hud.add_event(
			"Enemy %s attacked at (%d, %d)" % [unit_name, position.x, position.y],
			Color(0.6, 0.65, 0.7),
			position)


func _on_unit_destroyed(player_id: int, unit_id: int, unit_name: String, position: Vector2i) -> void:
	## C++ signal: a unit belonging to player_id was destroyed.
	if player_id == current_player:
		hud.show_alert(
			"%s DESTROYED at (%d, %d)!" % [unit_name, position.x, position.y],
			Color(1.0, 0.2, 0.15),
			position)
	else:
		hud.add_event(
			"Enemy %s destroyed at (%d, %d)" % [unit_name, position.x, position.y],
			Color(0.5, 0.8, 0.5),
			position)


func _on_unit_disabled(unit_id: int, unit_name: String, position: Vector2i) -> void:
	## C++ signal: a unit was disabled (by infiltrator).
	hud.show_alert(
		"%s DISABLED at (%d, %d)!" % [unit_name, position.x, position.y],
		Color(0.9, 0.6, 0.2),
		position)


func _on_build_error(player_id: int, error_type: String) -> void:
	## C++ signal: a build error occurred.
	if player_id != current_player:
		return
	var msg: String
	var color := Color(1.0, 0.6, 0.3)
	match error_type:
		"position_blocked":
			msg = "Production blocked — position occupied!"
		"insufficient_material":
			msg = "Production halted — insufficient materials!"
		_:
			msg = "Build error: %s" % error_type
	hud.show_alert(msg, color)


func _on_sudden_death() -> void:
	## C++ signal: sudden death mode activated (Phase 27 enhanced).
	_sudden_death_active = true
	hud.show_alert("SUDDEN DEATH MODE — First to gain score lead wins!", Color(1.0, 0.15, 0.1))
	# Add to event log
	if hud.has_method("add_event"):
		hud.add_event("SUDDEN DEATH — Victory condition tied. First player to gain score lead wins!", "", Vector2i(-1, -1))


func _on_jump_to_position(pos: Vector2i) -> void:
	## Camera jump from event log or alert.
	if camera:
		var world_pos := Vector2(pos.x * 64 + 32, pos.y * 64 + 32)
		camera.position = world_pos


func _check_production_complete() -> void:
	## Check if any factories finished producing this turn.
	var player = engine.get_player(current_player)
	if not player:
		return
	var buildings: Array = engine.get_player_buildings(current_player)
	for bldg_ref in buildings:
		var bldg = bldg_ref
		if not bldg or not bldg.is_building():
			continue
		var build_list: Array = bldg.get_build_list()
		# If a factory was working but build list is now empty, production finished
		# We track this via build_list changes — a simpler heuristic:
		# check if any factory has repeat_build OFF and an empty build list while it was working
		if bldg.is_working() and build_list.size() == 0:
			# Production just completed
			var name: String = bldg.get_name()
			var pos: Vector2i = bldg.get_position()
			hud.show_alert(
				"%s — production complete!" % name,
				Color(0.3, 0.85, 0.5),
				pos)


func _check_resource_warnings() -> void:
	## Check for low/insufficient resource warnings.
	var player = engine.get_player(current_player)
	if not player:
		return
	var storage: Dictionary = player.get_resource_storage()
	var needed: Dictionary = player.get_resource_needed()
	var production: Dictionary = player.get_resource_production()

	# Check each resource type
	var res_names := ["metal", "oil", "gold"]
	var res_labels := ["Metal", "Oil", "Gold"]
	var res_colors := [Color(0.55, 0.65, 0.85), Color(0.5, 0.5, 0.5), Color(0.95, 0.85, 0.3)]

	for i in range(3):
		var key: String = res_names[i]
		var stored: int = storage.get(key, 0)
		var need: int = needed.get(key, 0)
		var prod: int = production.get(key, 0)

		if need > 0 and stored <= 0 and prod < need:
			hud.add_event(
				"%s INSUFFICIENT — production halted!" % res_labels[i],
				Color(1.0, 0.3, 0.2))
		elif need > 0 and stored > 0 and stored < need * 2 and prod < need:
			hud.add_event(
				"%s running low (%d remaining)" % [res_labels[i], stored],
				Color(1.0, 0.7, 0.3))


func _build_turn_report() -> Array:
	## Build the turn report summary for the current turn.
	var report: Array = []
	var player = engine.get_player(current_player)
	if not player:
		return report

	# Research completions
	var levels: Dictionary = {}
	var level_arr: Array = player.get_research_levels()
	var area_names := ["Attack", "Shots", "Range", "Armor", "Hitpoints", "Speed", "Scan", "Cost"]
	for i in range(mini(level_arr.size(), 8)):
		levels[area_names[i]] = level_arr[i]

	for area_name in levels:
		var cur_level: int = levels[area_name]
		var prev_level: int = _prev_research_levels.get(area_name, 0)
		if cur_level > prev_level and _prev_research_levels.size() > 0:
			report.append({
				"text": "%s research reached level %d!" % [area_name, cur_level],
				"color": Color(0.3, 1.0, 0.5)
			})

	# Energy status
	var energy: Dictionary = player.get_energy_balance()
	var e_prod: int = energy.get("production", 0)
	var e_need: int = energy.get("need", 0)
	if e_need > e_prod:
		report.append({
			"text": "Energy shortage: %d / %d needed" % [e_prod, e_need],
			"color": Color(1.0, 0.4, 0.2)
		})

	# Resource status
	var storage: Dictionary = player.get_resource_storage()
	var needed: Dictionary = player.get_resource_needed()
	var res_types := [["metal", "Metal"], ["oil", "Oil"], ["gold", "Gold"]]
	for rt in res_types:
		var stored: int = storage.get(rt[0], 0)
		var need: int = needed.get(rt[0], 0)
		if need > 0 and stored <= 0:
			report.append({
				"text": "%s depleted — production affected!" % rt[1],
				"color": Color(1.0, 0.3, 0.2)
			})

	# Human balance
	var humans: Dictionary = player.get_human_balance()
	var h_prod: int = humans.get("production", 0)
	var h_need: int = humans.get("need", 0)
	if h_need > h_prod:
		report.append({
			"text": "Worker shortage: %d / %d needed" % [h_prod, h_need],
			"color": Color(1.0, 0.6, 0.3)
		})

	return report


# =============================================================================
# PHASE 24: SAVE/LOAD
# =============================================================================

func _on_pause_save() -> void:
	## Open save dialog from pause menu.
	var saves: Array = engine.get_save_game_list()
	var turn: int = engine.get_turn_number()
	hud.show_save_dialog(saves, turn)


func _on_pause_load() -> void:
	## Open load dialog from pause menu.
	var saves: Array = engine.get_save_game_list()
	hud.show_load_dialog(saves)


func _on_save_game_requested(slot: int, save_name: String) -> void:
	## Save the game to the requested slot.
	if engine.save_game(slot, save_name):
		hud.add_event("Game saved to slot %d: %s" % [slot, save_name], Color(0.3, 0.85, 0.5))
		hud.show_alert("Game saved!", Color(0.3, 0.85, 0.5))
		print("[Game] Saved to slot %d: %s" % [slot, save_name])
	else:
		hud.show_alert("Save failed!", Color(1.0, 0.3, 0.2))
		print("[Game] Save failed for slot %d" % slot)


func _on_load_game_requested(slot: int) -> void:
	## Load a game from the requested slot.
	## This reloads the entire game state, so we need to restart the scene.
	GameManager.game_config["load_slot"] = slot
	GameManager.game_config["load_mode"] = true
	get_tree().change_scene_to_file("res://scenes/game/main_game.tscn")


func _do_autosave() -> void:
	## Auto-save at turn boundaries.
	var turn: int = engine.get_turn_number()
	if turn <= 1:
		return  # Don't auto-save on the very first turn
	var save_name := "Turn %d - Autosave" % turn
	if engine.save_game(AUTOSAVE_SLOT, save_name):
		print("[Game] Auto-saved to slot %d: %s" % [AUTOSAVE_SLOT, save_name])


# =============================================================================
# PHASE 25: MAP OVERLAYS & TOGGLES
# =============================================================================

var _current_stat_overlay: String = ""

func _on_stat_overlay_changed(overlay_name: String) -> void:
	_current_stat_overlay = overlay_name
	if overlay_name.is_empty():
		overlay.clear_stat_overlay()
		# Also clear resource overlay if survey was active
		if not _resource_overlay_visible:
			overlay.clear_resource_overlay()
	elif overlay_name == "survey":
		# Survey overlay reuses the resource overlay from Phase 22
		overlay.clear_stat_overlay()
		_refresh_resource_overlay()
	else:
		_refresh_stat_overlay()


func _on_grid_overlay_toggled(enabled: bool) -> void:
	overlay.set_grid_visible(enabled)


func _on_fog_overlay_toggled(enabled: bool) -> void:
	if fog:
		fog.fog_enabled = not enabled  # Toggle: button ON = fog OFF
		fog.queue_redraw()


var _connector_overlay_visible := false  # Phase 26: Connector network overlay

func _on_connector_overlay_toggled(enabled: bool) -> void:
	_connector_overlay_visible = enabled
	if enabled:
		_refresh_connector_overlay()
	else:
		overlay.clear_connector_overlay()


func _refresh_connector_overlay() -> void:
	## Rebuild the connector network overlay showing building connections.
	if not _connector_overlay_visible:
		return

	var tiles: Array = []
	var player_count: int = engine.get_player_count()

	for pi in range(player_count):
		var buildings: Array = engine.get_player_buildings(pi)
		var player_color: Color = unit_renderer.PLAYER_COLORS[pi % unit_renderer.PLAYER_COLORS.size()]
		var line_color := Color(player_color.r, player_color.g, player_color.b, 0.6)

		for bldg in buildings:
			if not bldg:
				continue
			if not bldg.connects_to_base():
				continue

			var flags: Dictionary = bldg.get_connection_flags()
			if flags.is_empty():
				continue

			var tile_info := {
				"pos": bldg.get_position(),
				"is_big": bldg.is_big() if bldg.has_method("is_big") else false,
				"color": line_color,
				"BaseN": flags.get("BaseN", false),
				"BaseE": flags.get("BaseE", false),
				"BaseS": flags.get("BaseS", false),
				"BaseW": flags.get("BaseW", false),
				"BaseBN": flags.get("BaseBN", false),
				"BaseBE": flags.get("BaseBE", false),
				"BaseBS": flags.get("BaseBS", false),
				"BaseBW": flags.get("BaseBW", false),
			}
			tiles.append(tile_info)

	overlay.set_connector_overlay(tiles)


func _refresh_stat_overlay() -> void:
	## Rebuild the stat overlay tiles based on the current overlay type.
	if _current_stat_overlay.is_empty():
		return

	var tiles: Array = []
	var player_count: int = engine.get_player_count()

	for pi in range(player_count):
		var is_own: bool = (pi == current_player)
		# For enemy units, only show if visible (fog check)
		var vehicles: Array = engine.get_player_vehicles(pi)
		var buildings: Array = engine.get_player_buildings(pi)
		var all_units: Array = vehicles + buildings

		for unit in all_units:
			if not unit:
				continue
			var pos: Vector2i = unit.get_position()
			# Skip enemy units hidden by fog
			if not is_own and fog and fog.fog_enabled:
				if not fog.is_tile_visible(pos):
					continue

			var tile_data: Dictionary = _get_stat_overlay_for_unit(unit, pi, is_own)
			if not tile_data.is_empty():
				tiles.append(tile_data)

	overlay.set_stat_overlay(tiles)


func _get_stat_overlay_for_unit(unit, player_idx: int, is_own: bool) -> Dictionary:
	## Returns overlay tile data for a unit based on the current overlay type.
	var pos: Vector2i = unit.get_position()
	var text := ""
	var color := Color(1, 1, 1, 0.8)
	var bg_color := Color(0, 0, 0, 0)

	match _current_stat_overlay:
		"survey":
			# Show surveyed status — only for tiles, handled differently
			# For survey overlay, we show resource values on surveyed tiles
			# This is already handled by the resource overlay; skip units
			return {}

		"hits":
			var hp: int = unit.get_hitpoints()
			var hp_max: int = unit.get_hitpoints_max()
			if hp_max <= 0:
				return {}
			var ratio := float(hp) / float(hp_max)
			text = "%d/%d" % [hp, hp_max]
			if ratio > 0.6:
				color = Color(0.3, 0.9, 0.4, 0.85)
			elif ratio > 0.3:
				color = Color(1.0, 0.85, 0.2, 0.85)
			else:
				color = Color(1.0, 0.3, 0.2, 0.9)
				bg_color = Color(0.4, 0.05, 0.05, 0.2)

		"scan":
			var scan: int = unit.get_scan()
			if scan <= 0:
				return {}
			text = str(scan)
			color = Color(0.3, 0.85, 1.0, 0.85)

		"status":
			# Show unit state flags
			var parts: Array = []
			if unit.is_disabled():
				parts.append("DIS")
			if unit.is_sentry_active():
				parts.append("SEN")
			if unit.is_manual_fire():
				parts.append("MAN")
			if unit.is_working():
				parts.append("WRK")
			if parts.is_empty():
				text = "OK"
				color = Color(0.5, 0.6, 0.5, 0.5)
			else:
				text = " ".join(parts)
				color = Color(1.0, 0.7, 0.3, 0.85)

		"ammo":
			var ammo: int = unit.get_ammo()
			var ammo_max: int = unit.get_ammo_max()
			if ammo_max <= 0:
				return {}
			text = "%d/%d" % [ammo, ammo_max]
			var ratio := float(ammo) / float(ammo_max)
			if ratio > 0.5:
				color = Color(0.7, 0.85, 1.0, 0.8)
			elif ratio > 0.2:
				color = Color(1.0, 0.7, 0.3, 0.85)
			else:
				color = Color(1.0, 0.3, 0.2, 0.9)

		"colour":
			# Highlight tiles by owner colour
			var PLAYER_COLORS := [
				Color(0.2, 0.4, 1.0, 0.25),
				Color(1.0, 0.2, 0.2, 0.25),
				Color(0.2, 0.8, 0.2, 0.25),
				Color(1.0, 0.8, 0.0, 0.25),
				Color(0.7, 0.2, 0.8, 0.25),
				Color(1.0, 0.5, 0.1, 0.25),
				Color(0.1, 0.8, 0.8, 0.25),
				Color(0.5, 0.5, 0.5, 0.25),
			]
			bg_color = PLAYER_COLORS[player_idx % PLAYER_COLORS.size()]
			text = ""
			return {"pos": pos, "text": "", "color": color, "bg_color": bg_color}

		"lock":
			# Show only sentry/locked units
			if not unit.is_sentry_active():
				return {}
			text = "LOCK"
			color = Color(1.0, 0.85, 0.2, 0.9)
			bg_color = Color(0.3, 0.25, 0.05, 0.2)

	if text.is_empty() and bg_color.a <= 0:
		return {}
	return {"pos": pos, "text": text, "color": color, "bg_color": bg_color}


func _check_resource_discoveries() -> void:
	## Check if any new resource tiles were discovered since last check.
	## This is a lightweight check—count surveyed tiles and notify if increased.
	var player = engine.get_player(current_player)
	var game_map = engine.get_map()
	if not player or not game_map:
		return
	var map_size: Vector2i = game_map.get_size()
	var count := 0
	var latest_resource: Dictionary = {}
	for y in range(map_size.y):
		for x in range(map_size.x):
			var pos := Vector2i(x, y)
			if player.has_resource_explored(pos):
				count += 1
				var res: Dictionary = game_map.get_resource_at(pos)
				if res.get("type", "none") != "none" and res.get("value", 0) > 0:
					latest_resource = {"type": res.get("type"), "value": res.get("value"), "pos": pos}

	if count > _surveyed_tile_count and _surveyed_tile_count > 0 and not latest_resource.is_empty():
		hud.show_resource_discovery(
			latest_resource.get("type", "unknown"),
			latest_resource.get("value", 0),
			latest_resource.get("pos", Vector2i(0, 0)))
	_surveyed_tile_count = count


func _check_energy_warnings() -> void:
	## Check if energy is insufficient and show a warning.
	var player = engine.get_player(current_player)
	if not player:
		return
	var energy: Dictionary = player.get_energy_balance()
	var prod: int = energy.get("production", 0)
	var need: int = energy.get("need", 0)
	if need > prod and prod > 0:
		hud.show_energy_warning("Energy shortage! %d / %d — buildings may shut down!" % [prod, need])
	elif need > 0 and prod <= 0:
		hud.show_energy_warning("CRITICAL: No energy production! All powered buildings offline!")


func _check_research_notifications() -> void:
	## Compare current research levels with previous to detect level-ups.
	var player = engine.get_player(current_player)
	if not player:
		return
	var levels: Dictionary = player.get_research_levels()
	var area_keys := ["attack", "shots", "range", "armor", "hitpoints", "speed", "scan", "cost"]
	var area_names := ["Attack", "Shots", "Range", "Armor", "Hitpoints", "Speed", "Scan", "Cost"]

	for i in range(area_keys.size()):
		var key: String = area_keys[i]
		var cur_level: int = levels.get(key, 0)
		var prev_level: int = _prev_research_levels.get(key, 0)
		if cur_level > prev_level and prev_level > 0:
			# Research leveled up!
			hud.show_research_notification(area_names[i], cur_level)
			AudioManager.play_sound("research_complete")

	_prev_research_levels = levels


func _refresh_after_action() -> void:
	## Refresh game state after an action is performed.
	if pathfinder:
		pathfinder = engine.get_pathfinder()
	_refresh_fog()
	unit_renderer.refresh_units()
	unit_renderer.selected_unit_id = selected_unit_id
	if selected_unit_id != -1:
		_update_overlays()
		_update_selected_unit_hud()
	_update_hud()
	# Phase 26: Refresh connector overlay if active
	if _connector_overlay_visible:
		_refresh_connector_overlay()
