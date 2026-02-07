extends Control
## Choose Landing Position — Players pick where on the map to deploy.
## For Hot Seat: each player picks sequentially.
## Map is displayed as a minimap-style overview for position selection.

@onready var title_label: Label = %TitleLabel
@onready var map_display: Control = %MapDisplay
@onready var confirm_button: Button = %ConfirmButton
@onready var status_label: Label = %StatusLabel
@onready var position_label: Label = %PositionLabel

# Engine instance for map data
var _engine: Node = null

var _current_player_idx := 0
var _player_count := 0
var _player_names: Array = []
var _player_colors: Array = []
var _is_hotseat := false

var _map_name := ""
var _map_width := 0
var _map_height := 0

# The selected position (in tile coordinates)
var _selected_pos := Vector2i(-1, -1)
# Scale: pixels per tile in the display
var _tile_scale := 1.0

# Map terrain image for display
var _map_texture: ImageTexture = null


func _ready() -> void:
	confirm_button.pressed.connect(_on_confirm)

	var config: Dictionary = GameManager.game_config
	_player_count = config.get("player_names", []).size()
	_player_names = config.get("player_names", [])
	_player_colors = config.get("player_colors", [])
	_is_hotseat = config.get("game_type", "") == "hotseat"
	_map_name = config.get("map_name", "")
	_current_player_idx = GameManager.pregame_current_player

	# Create engine for map data
	_engine = ClassDB.instantiate("GameEngine")
	if _engine:
		add_child(_engine)
		_engine.load_game_data()

	# Connect map display signals
	map_display.draw.connect(_on_map_display_draw)
	map_display.gui_input.connect(_on_map_display_gui_input)
	map_display.mouse_filter = Control.MOUSE_FILTER_STOP

	_load_map_data()
	_setup_for_player()


func _exit_tree() -> void:
	if _engine:
		_engine.queue_free()
		_engine = null


func _load_map_data() -> void:
	## Load the map and create a minimap preview texture.
	if not _engine:
		return

	# Get map info by starting a temporary game query
	var maps: Array = _engine.get_available_maps()
	if maps.size() == 0:
		status_label.text = "ERROR: No maps available!"
		return

	# We need the map dimensions. We'll get them by checking the map.
	# For now, use a default and update when we have real data.
	# Start a minimal game to get the map loaded, then extract dimensions.
	_engine.initialize_engine()
	var result: Dictionary = _engine.new_game_ex(GameManager.game_config)
	if result.get("success", false):
		_map_width = result.get("map_width", 64)
		_map_height = result.get("map_height", 64)
	else:
		_map_width = 64
		_map_height = 64

	# Generate a simple map preview image
	_generate_map_preview()


func _generate_map_preview() -> void:
	## Create a coloured map preview using terrain data from the engine.
	if not _engine or _map_width == 0 or _map_height == 0:
		return

	var game_map = _engine.get_map()
	if game_map == null:
		return

	var img := Image.create(_map_width, _map_height, false, Image.FORMAT_RGB8)

	# Draw terrain based on the map tile types (returns String: "water", "coast", "ground", "blocked")
	for y in range(_map_height):
		for x in range(_map_width):
			var tile_type: String = game_map.get_terrain_type(Vector2i(x, y))
			var color := Color(0.2, 0.5, 0.2)  # Default: green (land)

			match tile_type:
				"water":
					color = Color(0.1, 0.2, 0.5)
				"coast":
					color = Color(0.6, 0.6, 0.3)
				"ground":
					color = Color(0.2, 0.5, 0.2)
				"blocked":
					color = Color(0.4, 0.35, 0.25)
				_:
					color = Color(0.3, 0.5, 0.3)

			img.set_pixel(x, y, color)

	_map_texture = ImageTexture.create_from_image(img)

	# Connect resized to recalculate scale
	if not map_display.resized.is_connected(_recalc_scale):
		map_display.resized.connect(_recalc_scale)
	# Defer initial scale calculation to allow layout to settle
	call_deferred("_recalc_scale")


func _recalc_scale() -> void:
	# Calculate scale to fit the display area
	var display_size: Vector2 = map_display.size
	if display_size.x <= 0 or _map_width == 0 or _map_height == 0:
		return
	_tile_scale = minf(display_size.x / _map_width, display_size.y / _map_height)
	map_display.queue_redraw()


func _setup_for_player() -> void:
	var player_name: String = _player_names[_current_player_idx] if _current_player_idx < _player_names.size() else "Player"
	title_label.text = "%s — Choose Landing Position" % player_name
	_selected_pos = Vector2i(-1, -1)
	position_label.text = "Click on the map to select a landing position."
	confirm_button.disabled = true
	status_label.text = "Click on the map to choose where your units will deploy."

	# Mark previously chosen positions (by other players)
	map_display.queue_redraw()


func _on_map_display_draw() -> void:
	## Custom draw for the map display node.
	if _map_texture == null:
		return

	# Draw the map texture scaled up
	var dst_size := Vector2(_map_width * _tile_scale, _map_height * _tile_scale)
	var dst_rect := Rect2(Vector2.ZERO, dst_size)
	map_display.draw_texture_rect(_map_texture, dst_rect, false)

	# Draw previously selected landing positions (other players)
	for i in range(_player_count):
		if i == _current_player_idx:
			continue
		var pos: Vector2i = GameManager.pregame_landing_positions[i]
		if pos.x < 0:
			continue
		var color: Color = _player_colors[i] if i < _player_colors.size() else Color.GRAY
		var px := Vector2(pos.x * _tile_scale + _tile_scale * 0.5, pos.y * _tile_scale + _tile_scale * 0.5)
		map_display.draw_circle(px, 6.0 * _tile_scale, Color(color, 0.4))
		map_display.draw_arc(px, 6.0 * _tile_scale, 0, TAU, 32, color, 2.0)

	# Draw current selection
	if _selected_pos.x >= 0:
		var color: Color = _player_colors[_current_player_idx] if _current_player_idx < _player_colors.size() else Color.WHITE
		var px := Vector2(_selected_pos.x * _tile_scale + _tile_scale * 0.5, _selected_pos.y * _tile_scale + _tile_scale * 0.5)
		map_display.draw_circle(px, 4.0 * _tile_scale, Color(color, 0.6))
		map_display.draw_arc(px, 6.0 * _tile_scale, 0, TAU, 32, color, 3.0)
		# Draw crosshair
		map_display.draw_line(px - Vector2(8 * _tile_scale, 0), px + Vector2(8 * _tile_scale, 0), color, 1.5)
		map_display.draw_line(px - Vector2(0, 8 * _tile_scale), px + Vector2(0, 8 * _tile_scale), color, 1.5)


func _on_map_display_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_handle_map_click(mb.position)


func _handle_map_click(pixel_pos: Vector2) -> void:
	if _tile_scale <= 0:
		return

	var tile_x := int(pixel_pos.x / _tile_scale)
	var tile_y := int(pixel_pos.y / _tile_scale)

	# Bounds check with margin
	if tile_x < 2 or tile_x >= _map_width - 2 or tile_y < 2 or tile_y >= _map_height - 2:
		status_label.text = "Position too close to the map edge. Choose a position further in."
		return

	# Terrain check: must be on ground
	if _engine:
		var game_map = _engine.get_map()
		if game_map:
			var terrain: String = game_map.get_terrain_type(Vector2i(tile_x, tile_y))
			if terrain == "water" or terrain == "blocked" or terrain == "invalid":
				status_label.text = "Cannot land on %s terrain. Choose solid ground." % terrain
				return

	# Check proximity to other players' positions
	var too_close := false
	var warning := false
	for i in range(_player_count):
		if i == _current_player_idx:
			continue
		var other_pos: Vector2i = GameManager.pregame_landing_positions[i]
		if other_pos.x < 0:
			continue
		var dist := Vector2(tile_x - other_pos.x, tile_y - other_pos.y).length()
		if dist < 10.0:
			too_close = true
			break
		elif dist < 28.0:
			warning = true

	if too_close:
		status_label.text = "Too close to another player! Choose a position further away."
		return

	_selected_pos = Vector2i(tile_x, tile_y)
	position_label.text = "Selected position: (%d, %d)" % [tile_x, tile_y]
	confirm_button.disabled = false

	if warning:
		status_label.text = "Warning: Close to another player. You may confirm or choose another position."
	else:
		status_label.text = "Position looks good! Press Confirm to deploy here."

	map_display.queue_redraw()


func _on_confirm() -> void:
	if _selected_pos.x < 0:
		status_label.text = "Please select a position first."
		return

	# Store the position
	GameManager.pregame_landing_positions[_current_player_idx] = _selected_pos

	# Advance to next player or start the game
	_current_player_idx += 1

	if _current_player_idx < _player_count:
		GameManager.pregame_current_player = _current_player_idx
		if _is_hotseat:
			_show_transition(_current_player_idx)
		else:
			_setup_for_player()
	else:
		# All players have chosen — start the game!
		GameManager.advance_pregame_to_game()


func _show_transition(next_player_idx: int) -> void:
	## Full-screen transition for hot seat.
	var overlay := ColorRect.new()
	overlay.color = Color(0.05, 0.05, 0.12, 1.0)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 100
	add_child(overlay)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	overlay.add_child(vbox)

	var next_name: String = _player_names[next_player_idx] if next_player_idx < _player_names.size() else "Player"
	var lbl := Label.new()
	lbl.text = "Pass to %s" % next_name
	lbl.add_theme_font_size_override("font_size", 32)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(lbl)

	var sub := Label.new()
	sub.text = "Choose your landing position"
	sub.add_theme_font_size_override("font_size", 18)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.modulate = Color(0.7, 0.7, 0.7)
	vbox.add_child(sub)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	vbox.add_child(spacer)

	var ready_btn := Button.new()
	ready_btn.text = "READY"
	ready_btn.custom_minimum_size = Vector2(200, 50)
	ready_btn.pressed.connect(func() -> void:
		overlay.queue_free()
		_setup_for_player()
	)
	vbox.add_child(ready_btn)
