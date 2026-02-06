extends Node2D
## Renders all units on the map as colored shapes.
## Units are drawn as circles/squares with player colors.
## Selected unit gets a highlight ring.

const TILE_SIZE := 64
const UNIT_RADIUS := 22.0
const UNIT_OUTLINE := 2.0

var engine = null  # GameEngine reference
var move_animator = null  # MoveAnimator reference (optional)
var selected_unit_id := -1
var _unit_positions: Dictionary = {}  # unit_id -> Vector2i
var _unit_data: Array = []  # Array of dictionaries for drawing

# Player colors
var player_colors := [
	Color(0.2, 0.4, 1.0),    # Blue
	Color(1.0, 0.2, 0.2),    # Red
	Color(0.2, 0.8, 0.2),    # Green
	Color(1.0, 0.8, 0.0),    # Yellow
	Color(0.8, 0.2, 0.8),    # Purple
	Color(0.0, 0.8, 0.8),    # Cyan
	Color(1.0, 0.5, 0.0),    # Orange
	Color(0.6, 0.6, 0.6),    # Gray
]


func setup(p_engine) -> void:
	engine = p_engine
	refresh_units()


func _process(_delta: float) -> void:
	# Continuously redraw during animations for smooth movement
	if move_animator and move_animator.has_animations():
		queue_redraw()


func refresh_units() -> void:
	_unit_data.clear()
	_unit_positions.clear()
	if not engine:
		queue_redraw()
		return

	var player_count = engine.get_player_count()
	for pi in range(player_count):
		var color = player_colors[pi % player_colors.size()]
		var player = engine.get_player(pi)
		var player_color: Color = player.get_color() if player else color

		# Vehicles
		var vehicles = engine.get_player_vehicles(pi)
		for v in vehicles:
			var v_uid: int = v.get_id()
			var v_pos: Vector2i = v.get_position()
			var v_name: String = v.get_name()
			var v_hp: int = v.get_hitpoints()
			var v_hp_max: int = v.get_hitpoints_max()
			var v_is_tank := v_name.contains("Tank")
			_unit_data.append({
				"id": v_uid,
				"pos": v_pos,
				"name": v_name,
				"player": pi,
				"color": player_color,
				"hp": v_hp,
				"hp_max": v_hp_max,
				"is_vehicle": true,
				"is_tank": v_is_tank,
			})
			_unit_positions[v_uid] = v_pos

		# Buildings
		var buildings = engine.get_player_buildings(pi)
		for b in buildings:
			var b_uid: int = b.get_id()
			var b_pos: Vector2i = b.get_position()
			var b_name: String = b.get_name()
			var b_hp: int = b.get_hitpoints()
			var b_hp_max: int = b.get_hitpoints_max()
			_unit_data.append({
				"id": b_uid,
				"pos": b_pos,
				"name": b_name,
				"player": pi,
				"color": player_color,
				"hp": b_hp,
				"hp_max": b_hp_max,
				"is_vehicle": false,
				"is_tank": false,
			})
			_unit_positions[b_uid] = b_pos

	queue_redraw()


func get_unit_at_tile(tile: Vector2i) -> int:
	## Returns the unit ID at the given tile, or -1 if none.
	for uid in _unit_positions:
		if _unit_positions[uid] == tile:
			return uid
	return -1


func get_unit_position(unit_id: int) -> Vector2i:
	if _unit_positions.has(unit_id):
		return _unit_positions[unit_id]
	return Vector2i(-1, -1)


func _draw() -> void:
	for ud in _unit_data:
		var uid: int = ud["id"]
		var center := Vector2(ud["pos"].x * TILE_SIZE + TILE_SIZE / 2.0,
							  ud["pos"].y * TILE_SIZE + TILE_SIZE / 2.0)

		# Override position with animation if active
		if move_animator and move_animator.is_animating(uid):
			center = move_animator.get_animated_position(uid)

		var draw_color: Color = ud["color"]
		var is_selected = (uid == selected_unit_id)

		if ud["is_vehicle"]:
			_draw_vehicle(center, draw_color, ud, is_selected)
		else:
			_draw_building(center, draw_color, ud, is_selected)


func _draw_vehicle(center: Vector2, color: Color, ud: Dictionary, is_selected: bool) -> void:
	# Selection ring
	if is_selected:
		draw_arc(center, UNIT_RADIUS + 5, 0, TAU, 32, Color.WHITE, 3.0)
		draw_arc(center, UNIT_RADIUS + 5, 0, TAU, 32, Color(1, 1, 0, 0.7), 2.0)

	# Body - tanks are squares, others are circles
	if ud["is_tank"]:
		var half := UNIT_RADIUS * 0.85
		var rect := Rect2(center.x - half, center.y - half, half * 2, half * 2)
		draw_rect(rect, color)
		draw_rect(rect, color.darkened(0.3), false, UNIT_OUTLINE)
		# Turret barrel
		draw_line(center, center + Vector2(0, -UNIT_RADIUS - 4), color.darkened(0.2), 4.0)
	else:
		draw_circle(center, UNIT_RADIUS, color)
		draw_arc(center, UNIT_RADIUS, 0, TAU, 32, color.darkened(0.3), UNIT_OUTLINE)

	# HP bar
	_draw_hp_bar(center, ud["hp"], ud["hp_max"], color)


func _draw_building(center: Vector2, color: Color, ud: Dictionary, is_selected: bool) -> void:
	if is_selected:
		var sel_half := UNIT_RADIUS + 5
		draw_rect(Rect2(center.x - sel_half, center.y - sel_half, sel_half * 2, sel_half * 2),
				  Color(1, 1, 0, 0.4), false, 3.0)

	# Buildings are diamonds
	var r := UNIT_RADIUS
	var points := PackedVector2Array([
		center + Vector2(0, -r),
		center + Vector2(r, 0),
		center + Vector2(0, r),
		center + Vector2(-r, 0),
	])
	draw_colored_polygon(points, color)
	var outline_points := PackedVector2Array([points[0], points[1], points[2], points[3], points[0]])
	draw_polyline(outline_points, color.darkened(0.3), UNIT_OUTLINE)

	_draw_hp_bar(center, ud["hp"], ud["hp_max"], color)


func _draw_hp_bar(center: Vector2, hp: int, hp_max: int, color: Color) -> void:
	if hp_max <= 0:
		return
	var bar_width := UNIT_RADIUS * 1.8
	var bar_height := 4.0
	var bar_y := center.y + UNIT_RADIUS + 4
	var bar_x := center.x - bar_width / 2.0

	# Background
	draw_rect(Rect2(bar_x, bar_y, bar_width, bar_height), Color(0, 0, 0, 0.5))

	# Fill
	var ratio := float(hp) / float(hp_max)
	var fill_color := Color.GREEN if ratio > 0.5 else (Color.YELLOW if ratio > 0.25 else Color.RED)
	draw_rect(Rect2(bar_x, bar_y, bar_width * ratio, bar_height), fill_color)
