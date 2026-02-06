extends Node2D
## Renders movement range overlay and path preview.
## Drawn as a separate layer above the map but below units.

const TILE_SIZE := 64

# Movement range data: Array of {pos: Vector2i, cost: int}
var _reachable_tiles: Array = []
var _max_cost := 0  # For gradient coloring

# Path preview: PackedVector2Array of tile positions
var _path_preview := PackedVector2Array()

# Colors
const COLOR_RANGE_EASY := Color(0.2, 0.7, 1.0, 0.2)   # Blue tint - cheap to reach
const COLOR_RANGE_MED := Color(1.0, 0.8, 0.2, 0.2)     # Yellow tint - moderate cost
const COLOR_RANGE_HARD := Color(1.0, 0.3, 0.2, 0.2)    # Red tint - expensive
const COLOR_RANGE_BORDER := Color(0.3, 0.6, 1.0, 0.35)  # Border of reachable area
const COLOR_PATH_LINE := Color(1.0, 1.0, 1.0, 0.8)      # Path line
const COLOR_PATH_DOT := Color(1.0, 1.0, 0.3, 0.9)       # Path waypoint dots
const COLOR_PATH_END := Color(0.2, 1.0, 0.4, 0.6)       # Destination marker

var _reachable_set: Dictionary = {}  # For quick lookup: Vector2i -> cost

# Attack range data
var _attack_range_tiles := PackedVector2Array()
var _attackable_enemies: Array = []  # Array of {id, pos, owner}
var _attackable_set: Dictionary = {}  # Vector2i -> enemy dict

# Attack preview
var _attack_preview: Dictionary = {}  # {damage, target_hp_after, will_destroy, target_pos}

# Colors
const COLOR_ATTACK_RANGE := Color(1.0, 0.2, 0.2, 0.08)   # Red tint for attack range
const COLOR_ATTACK_BORDER := Color(1.0, 0.3, 0.3, 0.3)    # Attack range border
const COLOR_ENEMY_HIGHLIGHT := Color(1.0, 0.0, 0.0, 0.3)  # Red highlight on enemies
const COLOR_ENEMY_BORDER := Color(1.0, 0.2, 0.2, 0.7)     # Red border on enemies


func clear_all() -> void:
	_reachable_tiles.clear()
	_reachable_set.clear()
	_path_preview = PackedVector2Array()
	_max_cost = 0
	_attack_range_tiles = PackedVector2Array()
	_attackable_enemies.clear()
	_attackable_set.clear()
	_attack_preview.clear()
	queue_redraw()


func set_reachable_tiles(tiles: Array) -> void:
	_reachable_tiles = tiles
	_reachable_set.clear()
	_max_cost = 0
	for t in tiles:
		var pos: Vector2i = t["pos"]
		var cost: int = t["cost"]
		_reachable_set[pos] = cost
		if cost > _max_cost:
			_max_cost = cost
	queue_redraw()


func set_path_preview(path: PackedVector2Array) -> void:
	_path_preview = path
	queue_redraw()


func clear_path_preview() -> void:
	_path_preview = PackedVector2Array()
	queue_redraw()


func is_tile_reachable(tile: Vector2i) -> bool:
	return _reachable_set.has(tile)


func get_tile_cost(tile: Vector2i) -> int:
	if _reachable_set.has(tile):
		return _reachable_set[tile]
	return -1


func set_attack_range(range_tiles: PackedVector2Array, enemies: Array) -> void:
	_attack_range_tiles = range_tiles
	_attackable_enemies = enemies
	_attackable_set.clear()
	for e in enemies:
		_attackable_set[e["pos"]] = e
	queue_redraw()


func clear_attack_range() -> void:
	_attack_range_tiles = PackedVector2Array()
	_attackable_enemies.clear()
	_attackable_set.clear()
	_attack_preview.clear()
	queue_redraw()


func set_attack_preview(preview: Dictionary) -> void:
	_attack_preview = preview
	queue_redraw()


func clear_attack_preview() -> void:
	_attack_preview.clear()
	queue_redraw()


func is_enemy_at_tile(tile: Vector2i) -> bool:
	return _attackable_set.has(tile)


func get_enemy_at_tile(tile: Vector2i) -> Dictionary:
	if _attackable_set.has(tile):
		return _attackable_set[tile]
	return {}


func _draw() -> void:
	_draw_attack_range()
	_draw_movement_range()
	_draw_path_preview()
	_draw_attack_preview()


func _draw_movement_range() -> void:
	if _reachable_tiles.is_empty():
		return

	for t in _reachable_tiles:
		var pos: Vector2i = t["pos"]
		var cost: int = t["cost"]
		var rect := Rect2(pos.x * TILE_SIZE, pos.y * TILE_SIZE, TILE_SIZE, TILE_SIZE)

		# Color based on cost (gradient from blue to yellow to red)
		var fill_color: Color
		if _max_cost > 0:
			var ratio := float(cost) / float(_max_cost)
			if ratio < 0.5:
				fill_color = COLOR_RANGE_EASY.lerp(COLOR_RANGE_MED, ratio * 2.0)
			else:
				fill_color = COLOR_RANGE_MED.lerp(COLOR_RANGE_HARD, (ratio - 0.5) * 2.0)
		else:
			fill_color = COLOR_RANGE_EASY

		draw_rect(rect, fill_color)

	# Draw border around the reachable area
	for t in _reachable_tiles:
		var pos: Vector2i = t["pos"]
		# Check each edge - draw border if neighbor is NOT reachable
		var left := Vector2i(pos.x - 1, pos.y)
		var right := Vector2i(pos.x + 1, pos.y)
		var up := Vector2i(pos.x, pos.y - 1)
		var down := Vector2i(pos.x, pos.y + 1)

		var x0 := pos.x * TILE_SIZE
		var y0 := pos.y * TILE_SIZE

		if not _reachable_set.has(left):
			draw_line(Vector2(x0, y0), Vector2(x0, y0 + TILE_SIZE), COLOR_RANGE_BORDER, 2.0)
		if not _reachable_set.has(right):
			draw_line(Vector2(x0 + TILE_SIZE, y0), Vector2(x0 + TILE_SIZE, y0 + TILE_SIZE), COLOR_RANGE_BORDER, 2.0)
		if not _reachable_set.has(up):
			draw_line(Vector2(x0, y0), Vector2(x0 + TILE_SIZE, y0), COLOR_RANGE_BORDER, 2.0)
		if not _reachable_set.has(down):
			draw_line(Vector2(x0, y0 + TILE_SIZE), Vector2(x0 + TILE_SIZE, y0 + TILE_SIZE), COLOR_RANGE_BORDER, 2.0)


func _draw_path_preview() -> void:
	if _path_preview.size() < 2:
		return

	# Draw path line connecting tile centers
	var line_points := PackedVector2Array()
	for p in _path_preview:
		var center := Vector2(p.x * TILE_SIZE + TILE_SIZE / 2.0,
							  p.y * TILE_SIZE + TILE_SIZE / 2.0)
		line_points.append(center)

	# Main path line (thick white)
	draw_polyline(line_points, COLOR_PATH_LINE, 3.0, true)

	# Waypoint dots
	for i in range(line_points.size()):
		var pt := line_points[i]
		if i == line_points.size() - 1:
			# Destination: larger green marker
			draw_circle(pt, 8.0, COLOR_PATH_END)
			draw_arc(pt, 10.0, 0, TAU, 16, Color.WHITE, 2.0)
		elif i > 0:
			# Intermediate waypoints: small dots
			draw_circle(pt, 3.0, COLOR_PATH_DOT)


func _draw_attack_range() -> void:
	if _attack_range_tiles.is_empty():
		return

	# Light red tint on all attack range tiles
	for p in _attack_range_tiles:
		var rect := Rect2(int(p.x) * TILE_SIZE, int(p.y) * TILE_SIZE, TILE_SIZE, TILE_SIZE)
		draw_rect(rect, COLOR_ATTACK_RANGE)

	# Highlight enemy units with red squares
	for e in _attackable_enemies:
		var pos: Vector2i = e["pos"]
		var rect := Rect2(pos.x * TILE_SIZE + 2, pos.y * TILE_SIZE + 2, TILE_SIZE - 4, TILE_SIZE - 4)
		draw_rect(rect, COLOR_ENEMY_HIGHLIGHT)
		draw_rect(rect, COLOR_ENEMY_BORDER, false, 2.0)


func _draw_attack_preview() -> void:
	if _attack_preview.is_empty():
		return

	if not _attack_preview.has("target_pos"):
		return

	var target_pos: Vector2i = _attack_preview["target_pos"]
	var center := Vector2(target_pos.x * TILE_SIZE + TILE_SIZE / 2.0,
						  target_pos.y * TILE_SIZE + TILE_SIZE / 2.0)
	var damage: int = _attack_preview.get("damage", 0)
	var will_destroy: bool = _attack_preview.get("will_destroy", false)

	# Targeting reticle
	var r := TILE_SIZE / 2.0 + 4.0
	var reticle_color := Color(1, 0, 0, 0.8) if will_destroy else Color(1, 0.5, 0, 0.8)
	# Cross hairs
	draw_line(center + Vector2(-r, 0), center + Vector2(-r * 0.4, 0), reticle_color, 2.0)
	draw_line(center + Vector2(r, 0), center + Vector2(r * 0.4, 0), reticle_color, 2.0)
	draw_line(center + Vector2(0, -r), center + Vector2(0, -r * 0.4), reticle_color, 2.0)
	draw_line(center + Vector2(0, r), center + Vector2(0, r * 0.4), reticle_color, 2.0)
	# Circle
	draw_arc(center, r, 0, TAU, 24, reticle_color, 2.0)

	# Damage preview text
	if damage > 0:
		var font = ThemeDB.fallback_font
		if font:
			var text = "-" + str(damage)
			if will_destroy:
				text += " KILL"
			var text_color = Color.RED if will_destroy else Color.YELLOW
			draw_string(font, center + Vector2(r + 4, -4), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, text_color)
