extends Node2D
## OverlayRenderer -- Renders movement range, path preview, attack range,
## attack preview (targeting reticle), and build placement overlays.
##
## Polished version with:
##   - Smooth gradient movement range (blue -> orange -> red)
##   - Animated path preview with directional markers
##   - Glowing attack range with enemy highlights
##   - Targeting reticle with damage prediction
##   - Build placement with grid-aligned preview

const TILE_SIZE := 64

# Movement range colors (cost gradient)
const COLOR_MOVE_NEAR := Color(0.15, 0.45, 0.85, 0.22)      # Low cost (blue)
const COLOR_MOVE_MID := Color(0.25, 0.70, 0.50, 0.20)       # Medium cost (teal)
const COLOR_MOVE_FAR := Color(0.85, 0.60, 0.15, 0.18)       # High cost (orange)
const COLOR_MOVE_EDGE := Color(0.85, 0.25, 0.15, 0.15)      # Near max cost (red)
const COLOR_MOVE_BORDER := Color(0.20, 0.55, 0.90, 0.35)    # Range border

# Path preview colors
const COLOR_PATH_LINE := Color(0.85, 0.90, 1.0, 0.7)
const COLOR_PATH_DOT := Color(1.0, 1.0, 1.0, 0.9)
const COLOR_PATH_DEST := Color(0.30, 0.85, 1.0, 0.8)

# Attack range colors
const COLOR_ATTACK_RANGE := Color(0.85, 0.15, 0.10, 0.12)
const COLOR_ATTACK_BORDER := Color(0.90, 0.20, 0.15, 0.30)
const COLOR_ENEMY_HIGHLIGHT := Color(1.0, 0.25, 0.15, 0.35)
const COLOR_ENEMY_BORDER := Color(1.0, 0.30, 0.20, 0.55)

# Attack preview (targeting) colors
const COLOR_RETICLE := Color(1.0, 0.25, 0.15, 0.8)
const COLOR_RETICLE_INNER := Color(1.0, 0.85, 0.20, 0.6)

# Build preview colors
const COLOR_BUILD_VALID := Color(0.20, 0.85, 0.30, 0.25)
const COLOR_BUILD_INVALID := Color(0.90, 0.20, 0.15, 0.25)
const COLOR_BUILD_BORDER_VALID := Color(0.25, 0.90, 0.35, 0.6)
const COLOR_BUILD_BORDER_INVALID := Color(0.95, 0.25, 0.15, 0.6)

# Resource overlay colors (Phase 22)
const COLOR_RES_METAL := Color(0.55, 0.65, 0.85, 0.4)
const COLOR_RES_OIL := Color(0.15, 0.15, 0.15, 0.45)
const COLOR_RES_GOLD := Color(0.95, 0.80, 0.15, 0.35)

# --- Movement range data ---
var _reachable_tiles: Array = []
var _reachable_set: Dictionary = {}  # "x,y" -> cost
var _max_cost := 1.0

# --- Path preview ---
var _path_preview: PackedVector2Array = PackedVector2Array()

# --- Attack range ---
var _attack_range_tiles: Array = []
var _attackable_enemies: Array = []
var _attackable_set: Dictionary = {}  # "x,y" -> enemy_info

# --- Attack preview (targeting reticle) ---
var _attack_preview: Dictionary = {}

# --- Build preview ---
var _build_preview_pos := Vector2i(-1, -1)
var _build_preview_is_big := false
var _build_preview_valid := false

# --- Resource overlay (Phase 22) ---
var _resource_tiles: Array = []

# --- Stat overlay (Phase 25) ---
# Each entry: {pos: Vector2i, text: String, color: Color, bg_color: Color}
var _stat_overlay_tiles: Array = []
var _grid_visible := false
const COLOR_GRID := Color(0.3, 0.35, 0.4, 0.15)

var _time := 0.0


# --- Public API ---

func set_reachable_tiles(tiles: Array) -> void:
	_reachable_tiles = tiles
	_reachable_set.clear()
	_max_cost = 1.0
	for t in tiles:
		var pos: Vector2i = t.get("pos", Vector2i(0, 0))
		var key := "%d,%d" % [pos.x, pos.y]
		var cost: float = t.get("cost", 0.0)
		_reachable_set[key] = cost
		if cost > _max_cost:
			_max_cost = cost
	queue_redraw()


func set_path_preview(path: PackedVector2Array) -> void:
	_path_preview = path
	queue_redraw()


func clear_path_preview() -> void:
	_path_preview = PackedVector2Array()
	queue_redraw()


func set_attack_range(tiles: Array, enemies: Array) -> void:
	_attack_range_tiles = tiles
	_attackable_enemies = enemies
	_attackable_set.clear()
	for e in enemies:
		var pos = e.get("pos", Vector2i(0, 0))
		var key := "%d,%d" % [pos.x, pos.y]
		_attackable_set[key] = e
	queue_redraw()


func clear_attack_range() -> void:
	_attack_range_tiles.clear()
	_attackable_enemies.clear()
	_attackable_set.clear()
	queue_redraw()


func set_attack_preview(preview: Dictionary) -> void:
	_attack_preview = preview
	queue_redraw()


func clear_attack_preview() -> void:
	_attack_preview.clear()
	queue_redraw()


func set_build_preview(pos: Vector2i, is_big: bool, is_valid: bool) -> void:
	_build_preview_pos = pos
	_build_preview_is_big = is_big
	_build_preview_valid = is_valid
	queue_redraw()


func clear_build_preview() -> void:
	_build_preview_pos = Vector2i(-1, -1)
	queue_redraw()


func set_stat_overlay(tiles: Array) -> void:
	## Set stat overlay data. tiles: Array of {pos: Vector2i, text: String, color: Color, bg_color: Color}
	_stat_overlay_tiles = tiles
	queue_redraw()


func clear_stat_overlay() -> void:
	_stat_overlay_tiles.clear()
	queue_redraw()


func set_grid_visible(visible: bool) -> void:
	_grid_visible = visible
	queue_redraw()


func is_grid_visible() -> bool:
	return _grid_visible


func set_resource_overlay(tiles: Array) -> void:
	## Set resource overlay data. tiles: Array of {pos: Vector2i, type: String, value: int}
	_resource_tiles = tiles
	queue_redraw()


func clear_resource_overlay() -> void:
	_resource_tiles.clear()
	queue_redraw()


func clear_all() -> void:
	_reachable_tiles.clear()
	_reachable_set.clear()
	_path_preview = PackedVector2Array()
	_attack_range_tiles.clear()
	_attackable_enemies.clear()
	_attackable_set.clear()
	_attack_preview.clear()
	_build_preview_pos = Vector2i(-1, -1)
	# Note: resource overlay is NOT cleared by clear_all (it's a persistent toggle)
	queue_redraw()


func is_tile_reachable(tile: Vector2i) -> bool:
	return _reachable_set.has("%d,%d" % [tile.x, tile.y])


func get_tile_cost(tile: Vector2i) -> float:
	return _reachable_set.get("%d,%d" % [tile.x, tile.y], -1.0)


func is_enemy_at_tile(tile: Vector2i) -> bool:
	return _attackable_set.has("%d,%d" % [tile.x, tile.y])


func get_enemy_at_tile(tile: Vector2i) -> Dictionary:
	return _attackable_set.get("%d,%d" % [tile.x, tile.y], {})


# --- Rendering ---

func _process(delta: float) -> void:
	_time += delta
	# Periodic redraw for animated elements
	if not _attack_preview.is_empty() or _build_preview_pos != Vector2i(-1, -1):
		queue_redraw()


func _draw() -> void:
	if _grid_visible:
		_draw_grid()
	if not _resource_tiles.is_empty():
		_draw_resource_overlay()
	if not _stat_overlay_tiles.is_empty():
		_draw_stat_overlay()
	if not _reachable_set.is_empty():
		_draw_movement_range()
	if not _attack_range_tiles.is_empty():
		_draw_attack_range()
	if not _path_preview.is_empty():
		_draw_path_preview()
	if not _attack_preview.is_empty():
		_draw_attack_preview()
	if _build_preview_pos != Vector2i(-1, -1):
		_draw_build_preview()


func _draw_movement_range() -> void:
	## Draw movement range with cost-based gradient coloring and edge detection.
	for tile_data in _reachable_tiles:
		var tile_pos: Vector2i = tile_data.get("pos", Vector2i(0, 0))
		var tx: int = tile_pos.x
		var ty: int = tile_pos.y
		var cost: float = tile_data.get("cost", 0.0)
		var rect := Rect2(tx * TILE_SIZE, ty * TILE_SIZE, TILE_SIZE, TILE_SIZE)

		# Cost-based color gradient
		var ratio := cost / maxf(_max_cost, 1.0)
		var fill_color: Color
		if ratio < 0.33:
			fill_color = COLOR_MOVE_NEAR.lerp(COLOR_MOVE_MID, ratio / 0.33)
		elif ratio < 0.66:
			fill_color = COLOR_MOVE_MID.lerp(COLOR_MOVE_FAR, (ratio - 0.33) / 0.33)
		else:
			fill_color = COLOR_MOVE_FAR.lerp(COLOR_MOVE_EDGE, (ratio - 0.66) / 0.34)

		draw_rect(rect, fill_color)

		# Draw border on edges of reachable area
		_draw_range_border_edges(tx, ty, rect)


func _draw_range_border_edges(tx: int, ty: int, rect: Rect2) -> void:
	## Draw border lines on edges that are at the boundary of reachable tiles.
	var key_n := "%d,%d" % [tx, ty - 1]
	var key_s := "%d,%d" % [tx, ty + 1]
	var key_e := "%d,%d" % [tx + 1, ty]
	var key_w := "%d,%d" % [tx - 1, ty]

	if not _reachable_set.has(key_n):
		draw_line(rect.position, Vector2(rect.end.x, rect.position.y), COLOR_MOVE_BORDER, 1.5)
	if not _reachable_set.has(key_s):
		draw_line(Vector2(rect.position.x, rect.end.y), rect.end, COLOR_MOVE_BORDER, 1.5)
	if not _reachable_set.has(key_e):
		draw_line(Vector2(rect.end.x, rect.position.y), rect.end, COLOR_MOVE_BORDER, 1.5)
	if not _reachable_set.has(key_w):
		draw_line(rect.position, Vector2(rect.position.x, rect.end.y), COLOR_MOVE_BORDER, 1.5)


func _draw_path_preview() -> void:
	## Draw the movement path as a smooth line with waypoint markers.
	if _path_preview.size() < 2:
		return

	# Convert tile coords to world centers
	var world_points := PackedVector2Array()
	for tile in _path_preview:
		world_points.append(Vector2(tile.x * TILE_SIZE + TILE_SIZE / 2.0,
									tile.y * TILE_SIZE + TILE_SIZE / 2.0))

	# Draw path line (outer glow + inner bright)
	draw_polyline(world_points, Color(COLOR_PATH_LINE.r, COLOR_PATH_LINE.g, COLOR_PATH_LINE.b, COLOR_PATH_LINE.a * 0.3), 5.0)
	draw_polyline(world_points, COLOR_PATH_LINE, 2.0)

	# Waypoint dots
	for i in range(1, world_points.size() - 1):
		draw_circle(world_points[i], 3.0, COLOR_PATH_DOT)

	# Destination marker (pulsing)
	var dest := world_points[-1]
	var pulse := sin(_time * 4.0) * 0.3 + 0.7
	draw_circle(dest, 8.0 * pulse, Color(COLOR_PATH_DEST.r, COLOR_PATH_DEST.g, COLOR_PATH_DEST.b, COLOR_PATH_DEST.a * 0.3))
	draw_circle(dest, 5.0, COLOR_PATH_DEST)
	draw_circle(dest, 2.5, Color(1, 1, 1, 0.8))

	# Direction arrow at destination
	if world_points.size() >= 2:
		var prev := world_points[-2]
		var dir := (dest - prev).normalized()
		var arrow_tip := dest + dir * 12
		var arrow_left := dest + dir.rotated(2.5) * 6
		var arrow_right := dest + dir.rotated(-2.5) * 6
		draw_polygon(PackedVector2Array([arrow_tip, arrow_left, arrow_right]),
			PackedColorArray([COLOR_PATH_DEST, COLOR_PATH_DEST, COLOR_PATH_DEST]))


func _draw_attack_range() -> void:
	## Draw attack range overlay with glowing enemy highlights.
	# Range tiles
	for tile in _attack_range_tiles:
		var tx: int = int(tile.x)
		var ty: int = int(tile.y)
		var rect := Rect2(tx * TILE_SIZE, ty * TILE_SIZE, TILE_SIZE, TILE_SIZE)
		draw_rect(rect, COLOR_ATTACK_RANGE)

	# Range border
	for tile in _attack_range_tiles:
		var tx: int = int(tile.x)
		var ty: int = int(tile.y)
		var rect := Rect2(tx * TILE_SIZE, ty * TILE_SIZE, TILE_SIZE, TILE_SIZE)
		var key_n := "%d,%d" % [tx, ty - 1]
		var key_s := "%d,%d" % [tx, ty + 1]
		var key_e := "%d,%d" % [tx + 1, ty]
		var key_w := "%d,%d" % [tx - 1, ty]
		var range_set := {}
		for t in _attack_range_tiles:
			range_set["%d,%d" % [int(t.x), int(t.y)]] = true
		if not range_set.has(key_n):
			draw_line(rect.position, Vector2(rect.end.x, rect.position.y), COLOR_ATTACK_BORDER, 1.5)
		if not range_set.has(key_s):
			draw_line(Vector2(rect.position.x, rect.end.y), rect.end, COLOR_ATTACK_BORDER, 1.5)
		if not range_set.has(key_e):
			draw_line(Vector2(rect.end.x, rect.position.y), rect.end, COLOR_ATTACK_BORDER, 1.5)
		if not range_set.has(key_w):
			draw_line(rect.position, Vector2(rect.position.x, rect.end.y), COLOR_ATTACK_BORDER, 1.5)

	# Enemy highlights (pulsing)
	var pulse := sin(_time * 3.0) * 0.15 + 0.85
	for enemy in _attackable_enemies:
		var pos = enemy.get("pos", Vector2i(0, 0))
		var rect := Rect2(pos.x * TILE_SIZE, pos.y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
		var inset := rect.grow(-2)
		draw_rect(inset, Color(COLOR_ENEMY_HIGHLIGHT.r, COLOR_ENEMY_HIGHLIGHT.g, COLOR_ENEMY_HIGHLIGHT.b, COLOR_ENEMY_HIGHLIGHT.a * pulse))
		draw_rect(inset, COLOR_ENEMY_BORDER, false, 2.0)


func _draw_attack_preview() -> void:
	## Draw targeting reticle with damage prediction on hovered enemy.
	var target_pos = _attack_preview.get("target_pos", Vector2i(-1, -1))
	if target_pos == Vector2i(-1, -1):
		return

	var center := Vector2(target_pos.x * TILE_SIZE + TILE_SIZE / 2.0,
						   target_pos.y * TILE_SIZE + TILE_SIZE / 2.0)

	var pulse := sin(_time * 5.0) * 0.2 + 0.8

	# Outer circle (crosshair)
	var radius := 28.0
	draw_arc(center, radius, 0, TAU, 32, Color(COLOR_RETICLE.r, COLOR_RETICLE.g, COLOR_RETICLE.b, COLOR_RETICLE.a * pulse), 2.0)

	# Inner circle
	draw_arc(center, radius * 0.4, 0, TAU, 16, COLOR_RETICLE_INNER, 1.5)

	# Crosshair lines
	var gap := 10.0
	var line_len := 18.0
	draw_line(center + Vector2(-radius - line_len, 0), center + Vector2(-gap, 0), COLOR_RETICLE, 1.5)
	draw_line(center + Vector2(gap, 0), center + Vector2(radius + line_len, 0), COLOR_RETICLE, 1.5)
	draw_line(center + Vector2(0, -radius - line_len), center + Vector2(0, -gap), COLOR_RETICLE, 1.5)
	draw_line(center + Vector2(0, gap), center + Vector2(0, radius + line_len), COLOR_RETICLE, 1.5)

	# Damage prediction text
	var damage: int = _attack_preview.get("damage", 0)
	var will_destroy: bool = _attack_preview.get("will_destroy", false)
	var font := ThemeDB.fallback_font

	var text := "%d DMG" % damage
	var text_color := Color(1.0, 0.2, 0.1) if will_destroy else Color(1.0, 0.85, 0.2)

	var text_pos := center + Vector2(0, -radius - 14)
	draw_string(font, text_pos + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_CENTER, -1, 13, Color(0, 0, 0, 0.6))
	draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_CENTER, -1, 13, text_color)

	if will_destroy:
		var kill_pos := center + Vector2(0, radius + 20)
		draw_string(font, kill_pos + Vector2(1, 1), "KILL", HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color(0, 0, 0, 0.6))
		draw_string(font, kill_pos, "KILL", HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color(1.0, 0.15, 0.1, pulse))


func _draw_build_preview() -> void:
	## Draw building placement preview with validity indication.
	var size := 2 if _build_preview_is_big else 1
	var px := _build_preview_pos.x * TILE_SIZE
	var py := _build_preview_pos.y * TILE_SIZE
	var rect := Rect2(px, py, TILE_SIZE * size, TILE_SIZE * size)

	var pulse := sin(_time * 3.0) * 0.15 + 0.85

	var fill_color: Color
	var border_color: Color
	if _build_preview_valid:
		fill_color = Color(COLOR_BUILD_VALID.r, COLOR_BUILD_VALID.g, COLOR_BUILD_VALID.b, COLOR_BUILD_VALID.a * pulse)
		border_color = COLOR_BUILD_BORDER_VALID
	else:
		fill_color = Color(COLOR_BUILD_INVALID.r, COLOR_BUILD_INVALID.g, COLOR_BUILD_INVALID.b, COLOR_BUILD_INVALID.a * pulse)
		border_color = COLOR_BUILD_BORDER_INVALID

	draw_rect(rect, fill_color)
	draw_rect(rect, border_color, false, 2.0)

	# Grid lines for multi-tile buildings
	if size > 1:
		for i in range(1, size):
			draw_line(Vector2(px + i * TILE_SIZE, py), Vector2(px + i * TILE_SIZE, py + size * TILE_SIZE),
				Color(border_color.r, border_color.g, border_color.b, 0.3), 1.0)
			draw_line(Vector2(px, py + i * TILE_SIZE), Vector2(px + size * TILE_SIZE, py + i * TILE_SIZE),
				Color(border_color.r, border_color.g, border_color.b, 0.3), 1.0)

	# Label
	var label_text := "Place" if _build_preview_valid else "Invalid"
	var label_color := Color(0.3, 0.9, 0.4) if _build_preview_valid else Color(1.0, 0.3, 0.2)
	var font := ThemeDB.fallback_font
	var label_pos := Vector2(px + (TILE_SIZE * size) / 2.0, py - 8)
	draw_string(font, label_pos + Vector2(1, 1), label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color(0, 0, 0, 0.5))
	draw_string(font, label_pos, label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 12, label_color)


func _draw_grid() -> void:
	## Draw a grid overlay across the visible map area (Phase 25).
	# We'll draw a reasonable range; the camera culls the rest anyway.
	var vp := get_viewport()
	if not vp:
		return
	var canvas_xform := get_canvas_transform()
	var inv := canvas_xform.affine_inverse()
	var vp_size := vp.get_visible_rect().size
	var tl := inv * Vector2.ZERO
	var br := inv * vp_size
	var start_x := int(tl.x / TILE_SIZE) - 1
	var start_y := int(tl.y / TILE_SIZE) - 1
	var end_x := int(br.x / TILE_SIZE) + 2
	var end_y := int(br.y / TILE_SIZE) + 2

	for x in range(start_x, end_x):
		var px := float(x * TILE_SIZE)
		draw_line(Vector2(px, start_y * TILE_SIZE), Vector2(px, end_y * TILE_SIZE), COLOR_GRID, 1.0)
	for y in range(start_y, end_y):
		var py := float(y * TILE_SIZE)
		draw_line(Vector2(start_x * TILE_SIZE, py), Vector2(end_x * TILE_SIZE, py), COLOR_GRID, 1.0)


func _draw_stat_overlay() -> void:
	## Draw per-unit stat text overlay on tiles (Phase 25).
	var font := ThemeDB.fallback_font
	for tile_info in _stat_overlay_tiles:
		var pos: Vector2i = tile_info.get("pos", Vector2i(0, 0))
		var text: String = tile_info.get("text", "")
		var color: Color = tile_info.get("color", Color(1, 1, 1, 0.8))
		var bg_color: Color = tile_info.get("bg_color", Color(0, 0, 0, 0))

		var rect := Rect2(pos.x * TILE_SIZE, pos.y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
		if bg_color.a > 0:
			draw_rect(rect, bg_color)

		var center := Vector2(pos.x * TILE_SIZE + TILE_SIZE / 2.0,
							  pos.y * TILE_SIZE + TILE_SIZE / 2.0 + 4)
		draw_string(font, center + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_CENTER, -1, 11, Color(0, 0, 0, 0.5))
		draw_string(font, center, text, HORIZONTAL_ALIGNMENT_CENTER, -1, 11, color)


func _draw_resource_overlay() -> void:
	## Draw colour-coded resource deposits on surveyed tiles (Phase 22).
	var font := ThemeDB.fallback_font
	for tile_info in _resource_tiles:
		var pos: Vector2i = tile_info.get("pos", Vector2i(0, 0))
		var res_type: String = tile_info.get("type", "none")
		var value: int = tile_info.get("value", 0)

		var rect := Rect2(pos.x * TILE_SIZE, pos.y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
		var color: Color
		match res_type:
			"metal": color = COLOR_RES_METAL
			"oil":   color = COLOR_RES_OIL
			"gold":  color = COLOR_RES_GOLD
			_: continue

		# Scale alpha by resource density (value 1-16)
		var density := clampf(float(value) / 16.0, 0.3, 1.0)
		color.a *= density
		draw_rect(rect, color)

		# Draw value label
		var center := Vector2(pos.x * TILE_SIZE + TILE_SIZE / 2.0,
							  pos.y * TILE_SIZE + TILE_SIZE / 2.0 + 4)
		var label_color := Color(1, 1, 1, 0.7)
		draw_string(font, center, str(value), HORIZONTAL_ALIGNMENT_CENTER, -1, 10, label_color)
