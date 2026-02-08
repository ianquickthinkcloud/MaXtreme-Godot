extends Control
## Minimap -- Renders a small overview map showing terrain, units, fog, and camera viewport.
## Placed in the HUD CanvasLayer (bottom-right corner).
##
## Features:
##   - Terrain rendered as an ImageTexture from cached map data
##   - Unit dots color-coded by player
##   - Fog of war overlay (dark areas for unexplored)
##   - Camera viewport rectangle showing current view
##   - Click to pan camera
##   - Draggable viewport rectangle

const MINIMAP_SIZE := 180  # Pixels (square)
const BORDER_WIDTH := 2
const BORDER_COLOR := Color(0.20, 0.25, 0.35, 1.0)
const BG_COLOR := Color(0.06, 0.08, 0.12, 0.9)
const VIEWPORT_COLOR := Color(1.0, 1.0, 1.0, 0.6)
const UNIT_DOT_SIZE := 2.5
const BUILDING_DOT_SIZE := 3.0
const UNIT_COLORS := [
	Color(0.3, 0.6, 1.0),   # Blue
	Color(1.0, 0.3, 0.25),  # Red
	Color(0.3, 0.85, 0.35), # Green
	Color(1.0, 0.85, 0.2),  # Yellow
	Color(0.7, 0.35, 0.85), # Purple
	Color(0.2, 0.85, 0.85), # Cyan
	Color(1.0, 0.6, 0.2),   # Orange
	Color(0.6, 0.6, 0.6),   # Gray
]

signal minimap_clicked(world_position: Vector2)

var _map_renderer = null
var _engine = null
var _fog_renderer = null
var _camera: Camera2D = null
var _map_w := 0
var _map_h := 0
var _terrain_texture: ImageTexture = null
var _scale_x := 1.0
var _scale_y := 1.0
var _dragging := false
var _current_player := 0
var _zoom_level := 1  # Phase 25: 1 = normal, 2 = zoomed
var _attack_units_only := false  # Phase 25: Filter to show only armed units


func setup(engine, map_renderer, fog_renderer, camera: Camera2D, current_player: int) -> void:
	_engine = engine
	_map_renderer = map_renderer
	_fog_renderer = fog_renderer
	_camera = camera
	_current_player = current_player

	if _engine:
		var game_map = _engine.get_map()
		if game_map:
			_map_w = game_map.get_width()
			_map_h = game_map.get_height()

	_scale_x = float(MINIMAP_SIZE) / maxf(_map_w, 1.0)
	_scale_y = float(MINIMAP_SIZE) / maxf(_map_h, 1.0)

	custom_minimum_size = Vector2(MINIMAP_SIZE + BORDER_WIDTH * 2, MINIMAP_SIZE + BORDER_WIDTH * 2)

	# Generate terrain image
	_generate_terrain_texture()


func _generate_terrain_texture() -> void:
	## Pre-render the terrain as an Image for fast drawing.
	if _map_w == 0 or _map_h == 0 or not _map_renderer:
		return

	var render_size := MINIMAP_SIZE * _zoom_level
	_scale_x = float(render_size) / maxf(_map_w, 1.0)
	_scale_y = float(render_size) / maxf(_map_h, 1.0)

	var img := Image.create(render_size, render_size, false, Image.FORMAT_RGB8)

	for py in range(render_size):
		for px in range(render_size):
			var tx := int(float(px) / _scale_x)
			var ty := int(float(py) / _scale_y)
			tx = clampi(tx, 0, _map_w - 1)
			ty = clampi(ty, 0, _map_h - 1)
			var color: Color = _map_renderer.get_terrain_color_at(tx, ty)
			img.set_pixel(px, py, color)

	_terrain_texture = ImageTexture.create_from_image(img)


func refresh() -> void:
	queue_redraw()


func toggle_zoom() -> void:
	## Phase 25: Toggle between normal (1x) and zoomed (2x) minimap.
	_zoom_level = 1 if _zoom_level == 2 else 2
	var new_size := MINIMAP_SIZE * _zoom_level
	custom_minimum_size = Vector2(new_size + BORDER_WIDTH * 2, new_size + BORDER_WIDTH * 2)
	_generate_terrain_texture()
	queue_redraw()


func toggle_attack_filter() -> void:
	## Phase 25: Toggle showing only attack-capable units on the minimap.
	_attack_units_only = not _attack_units_only
	queue_redraw()


func is_attack_filter_active() -> bool:
	return _attack_units_only


func _process(_delta: float) -> void:
	# Redraw periodically (every 6 frames) for smooth camera tracking
	if Engine.get_process_frames() % 6 == 0:
		queue_redraw()


func _draw() -> void:
	var render_size := MINIMAP_SIZE * _zoom_level
	var offset := Vector2(BORDER_WIDTH, BORDER_WIDTH)

	# Background
	draw_rect(Rect2(Vector2.ZERO, Vector2(render_size + BORDER_WIDTH * 2, render_size + BORDER_WIDTH * 2)), BG_COLOR)

	# Border
	draw_rect(Rect2(Vector2.ZERO, Vector2(render_size + BORDER_WIDTH * 2, render_size + BORDER_WIDTH * 2)),
		BORDER_COLOR, false, BORDER_WIDTH)

	# Terrain
	if _terrain_texture:
		draw_texture_rect(_terrain_texture, Rect2(offset, Vector2(render_size, render_size)), false)

	# Fog of war overlay
	if _fog_renderer and _fog_renderer.fog_enabled and _map_w > 0:
		_draw_fog(offset)

	# Units
	if _engine:
		_draw_units(offset)

	# Camera viewport rectangle
	if _camera:
		_draw_camera_viewport(offset)


func _draw_fog(offset: Vector2) -> void:
	## Draw fog overlay on the minimap (unexplored = dark, explored = semi-dark).
	var render_size := MINIMAP_SIZE * _zoom_level
	# Draw at a lower resolution for performance
	var step := 2 * _zoom_level
	for py in range(0, render_size, step):
		for px in range(0, render_size, step):
			var tx := int(float(px) / _scale_x)
			var ty := int(float(py) / _scale_y)
			var tile := Vector2i(clampi(tx, 0, _map_w - 1), clampi(ty, 0, _map_h - 1))

			if not _fog_renderer.is_tile_visible(tile):
				var alpha: float
				if _fog_renderer.is_tile_explored(tile):
					alpha = 0.35  # Explored but not visible
				else:
					alpha = 0.75  # Never seen
				draw_rect(Rect2(offset + Vector2(px, py), Vector2(step, step)),
					Color(0, 0, 0, alpha))


func _draw_units(offset: Vector2) -> void:
	## Draw unit dots on the minimap.
	var player_count: int = _engine.get_player_count()

	for pi in range(player_count):
		var color: Color = UNIT_COLORS[pi % UNIT_COLORS.size()]

		# Vehicles
		var vehicles = _engine.get_player_vehicles(pi)
		for v in vehicles:
			# Phase 25: Attack filter
			if _attack_units_only and not v.has_weapon():
				continue

			var pos: Vector2i = v.get_position()
			# Skip if hidden by fog (enemy units)
			if pi != _current_player and _fog_renderer:
				if _fog_renderer.fog_enabled and not _fog_renderer.is_tile_visible(pos):
					continue

			var dot := UNIT_DOT_SIZE * _zoom_level
			var minimap_pos := offset + Vector2(pos.x * _scale_x, pos.y * _scale_y)
			draw_rect(Rect2(minimap_pos - Vector2(dot / 2.0, dot / 2.0),
				Vector2(dot, dot)), color)

		# Buildings
		var buildings = _engine.get_player_buildings(pi)
		for b in buildings:
			# Phase 25: Attack filter — only show buildings with weapons
			if _attack_units_only and not b.has_weapon():
				continue

			var pos: Vector2i = b.get_position()
			if pi != _current_player and _fog_renderer:
				if _fog_renderer.fog_enabled and not _fog_renderer.is_tile_visible(pos):
					continue

			var dot := BUILDING_DOT_SIZE * _zoom_level
			var minimap_pos := offset + Vector2(pos.x * _scale_x, pos.y * _scale_y)
			draw_rect(Rect2(minimap_pos - Vector2(dot / 2.0, dot / 2.0),
				Vector2(dot, dot)), color.lightened(0.2))


func _draw_camera_viewport(offset: Vector2) -> void:
	## Draw the camera's current viewport as a rectangle on the minimap.
	var canvas_xform := _camera.get_canvas_transform()
	var inv := canvas_xform.affine_inverse()
	var vp_size := get_viewport_rect().size

	var world_tl := inv * Vector2.ZERO
	var world_br := inv * vp_size

	# Convert world coordinates to minimap coordinates
	var TILE_SIZE := 64.0
	var mm_x1 := (world_tl.x / TILE_SIZE) * _scale_x
	var mm_y1 := (world_tl.y / TILE_SIZE) * _scale_y
	var mm_x2 := (world_br.x / TILE_SIZE) * _scale_x
	var mm_y2 := (world_br.y / TILE_SIZE) * _scale_y

	var vp_rect := Rect2(
		offset + Vector2(mm_x1, mm_y1),
		Vector2(mm_x2 - mm_x1, mm_y2 - mm_y1)
	)

	# Viewport rectangle
	draw_rect(vp_rect, VIEWPORT_COLOR, false, 1.5)
	# Semi-transparent fill
	draw_rect(vp_rect, Color(1, 1, 1, 0.05))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_dragging = true
				_handle_minimap_click(mb.position)
				accept_event()
			else:
				_dragging = false

	elif event is InputEventMouseMotion and _dragging:
		_handle_minimap_click(event.position)
		accept_event()


func _handle_minimap_click(local_pos: Vector2) -> void:
	## Convert minimap click to world position and emit signal.
	var offset := Vector2(BORDER_WIDTH, BORDER_WIDTH)
	var mm_pos := local_pos - offset

	# Convert minimap position to tile position
	var tile_x := mm_pos.x / _scale_x
	var tile_y := mm_pos.y / _scale_y

	# Clamp to map bounds
	tile_x = clampf(tile_x, 0, _map_w - 1)
	tile_y = clampf(tile_y, 0, _map_h - 1)

	# Convert to world position (pixel center of tile)
	var TILE_SIZE := 64.0
	var world_pos := Vector2(tile_x * TILE_SIZE + TILE_SIZE / 2.0,
							  tile_y * TILE_SIZE + TILE_SIZE / 2.0)

	minimap_clicked.emit(world_pos)
