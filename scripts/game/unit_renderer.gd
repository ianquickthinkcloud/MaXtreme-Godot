extends Node2D
## UnitRenderer -- Renders all vehicles and buildings with real sprites.
##
## Features:
##   - Directional vehicle sprites (8 directions based on last move heading)
##   - Shadow sprites rendered beneath units
##   - Animated infantry/commando with frame cycling
##   - Player color tinting on vehicles
##   - Building effect overlays for working factories/mines
##   - Selection rings with pulse animation
##   - HP bars with gradient coloring
##   - Construction progress indicators
##   - Damage cracks overlay for heavily damaged units
##   - Fallback colored shapes when sprites are missing

const TILE_SIZE := 64
const SHADOW_OFFSET := Vector2(3, 3)
const SHADOW_ALPHA := 0.5
const PLAYER_TINT_STRENGTH := 0.35
const SELECTION_PULSE_SPEED := 3.0
const ANIM_FPS := 8.0  # Animation frames per second for infantry/commando
const DAMAGE_THRESHOLD := 0.4  # Show damage effect below this HP ratio

# Player colors (indexed by player number)
const PLAYER_COLORS := [
	Color(0.20, 0.45, 1.00),  # Blue
	Color(1.00, 0.25, 0.20),  # Red
	Color(0.20, 0.80, 0.30),  # Green
	Color(1.00, 0.85, 0.15),  # Yellow
	Color(0.70, 0.30, 0.85),  # Purple
	Color(0.15, 0.85, 0.85),  # Cyan
	Color(1.00, 0.55, 0.15),  # Orange
	Color(0.55, 0.55, 0.55),  # Gray
]

var engine = null
var move_animator = null
var sprite_cache = null  # SpriteCache instance
var fog_renderer = null
var current_player := 0
var selected_unit_id := -1

# Cached unit data for rendering
var _unit_data: Array = []       # Array of dictionaries with render info
var _unit_positions: Dictionary = {}  # tile_key -> unit_id (for click detection)
var _unit_directions: Dictionary = {} # unit_id -> last known direction (0-7)
var _anim_time := 0.0            # For animated units and selection pulse
var _anim_unit_types: Dictionary = {} # type_name -> {has_anim: bool, frame_count: int}


func setup(eng) -> void:
	engine = eng
	_unit_directions.clear()
	_anim_unit_types.clear()
	refresh_units()


func refresh_units() -> void:
	if engine == null:
		return

	_unit_data.clear()
	_unit_positions.clear()

	var player_count: int = engine.get_player_count()

	for pi in range(player_count):
		var player_color: Color = PLAYER_COLORS[pi % PLAYER_COLORS.size()]

		# Vehicles
		var vehicles = engine.get_player_vehicles(pi)
		for v in vehicles:
			var uid: int = v.get_id()
			var pos: Vector2i = v.get_position()
			var type_name: String = v.get_type_name()
			var hp: int = v.get_hitpoints()
			var hp_max: int = v.get_hitpoints_max()

			# Check animation info (cached per type)
			if not _anim_unit_types.has(type_name) and sprite_cache:
				var has_anim: bool = sprite_cache.has_animation_frames(type_name)
				var frame_count: int = sprite_cache.get_animation_frame_count(type_name) if has_anim else 0
				_anim_unit_types[type_name] = {"has_anim": has_anim, "frame_count": frame_count}

			_unit_data.append({
				"id": uid,
				"pos": pos,
				"type_name": type_name,
				"player": pi,
				"color": player_color,
				"hp": hp,
				"hp_max": hp_max,
				"is_building": false,
				"is_big": false,
				"is_working": false,
				"is_constructing": v.is_building_a_building(),
				"build_progress": 0.0,
				# Phase 19: State indicators
				"is_sentry": v.is_sentry_active(),
				"is_manual_fire": v.is_manual_fire(),
				"is_disabled": v.is_disabled(),
				"stored_units": v.get_stored_units_count(),
			})

			var key := "%d,%d" % [pos.x, pos.y]
			_unit_positions[key] = uid

		# Buildings
		var buildings = engine.get_player_buildings(pi)
		for b in buildings:
			var uid: int = b.get_id()
			var pos: Vector2i = b.get_position()
			var type_name: String = b.get_type_name()
			var hp: int = b.get_hitpoints()
			var hp_max: int = b.get_hitpoints_max()
			var is_big: bool = b.get_is_big() if b.has_method("get_is_big") else false
			var is_working: bool = b.is_working()

			# Build progress
			var build_progress := 1.0
			if b.has_method("get_build_costs_remaining") and b.has_method("get_build_cost"):
				var remaining: int = b.get_build_costs_remaining()
				var total: int = b.get_build_cost()
				if total > 0:
					build_progress = 1.0 - (float(remaining) / float(total))

			_unit_data.append({
				"id": uid,
				"pos": pos,
				"type_name": type_name,
				"player": pi,
				"color": player_color,
				"hp": hp,
				"hp_max": hp_max,
				"is_building": true,
				"is_big": is_big,
				"is_working": is_working,
				"is_constructing": false,
				"build_progress": build_progress,
				# Phase 19: State indicators
				"is_sentry": b.is_sentry_active(),
				"is_manual_fire": b.is_manual_fire(),
				"is_disabled": b.is_disabled(),
				"stored_units": b.get_stored_units_count(),
			})

			# Register tile occupancy (big buildings span 2x2)
			var tile_key := "%d,%d" % [pos.x, pos.y]
			_unit_positions[tile_key] = uid
			if is_big:
				_unit_positions["%d,%d" % [pos.x + 1, pos.y]] = uid
				_unit_positions["%d,%d" % [pos.x, pos.y + 1]] = uid
				_unit_positions["%d,%d" % [pos.x + 1, pos.y + 1]] = uid

	queue_redraw()


func get_unit_at_tile(tile: Vector2i) -> int:
	var key := "%d,%d" % [tile.x, tile.y]
	return _unit_positions.get(key, -1)


func update_unit_direction(unit_id: int, from_tile: Vector2i, to_tile: Vector2i) -> void:
	## Update the facing direction of a unit based on movement.
	var dx := to_tile.x - from_tile.x
	var dy := to_tile.y - from_tile.y
	if dx == 0 and dy == 0:
		return
	# Convert delta to 8-direction index:
	# 0=N, 1=NE, 2=E, 3=SE, 4=S, 5=SW, 6=W, 7=NW
	var direction := 0
	if dx > 0 and dy < 0: direction = 1      # NE
	elif dx > 0 and dy == 0: direction = 2    # E
	elif dx > 0 and dy > 0: direction = 3     # SE
	elif dx == 0 and dy > 0: direction = 4    # S
	elif dx < 0 and dy > 0: direction = 5     # SW
	elif dx < 0 and dy == 0: direction = 6    # W
	elif dx < 0 and dy < 0: direction = 7     # NW
	else: direction = 0                        # N (dx==0, dy<0)
	_unit_directions[unit_id] = direction


func _process(delta: float) -> void:
	_anim_time += delta
	# Redraw every frame for animations
	queue_redraw()


func _draw() -> void:
	if engine == null:
		return

	# Determine visible area
	var canvas_xform := get_canvas_transform()
	var inv_xform := canvas_xform.affine_inverse()
	var vp_size := get_viewport_rect().size
	var top_left := inv_xform * Vector2.ZERO
	var bottom_right := inv_xform * vp_size
	var visible_rect := Rect2(top_left, bottom_right - top_left).grow(TILE_SIZE * 2)

	# Two-pass rendering: shadows first, then units on top
	# Pass 1: Shadows
	for unit in _unit_data:
		var world_pos := _get_unit_world_pos(unit)
		if not visible_rect.has_point(world_pos):
			continue
		if _is_hidden_by_fog(unit):
			continue
		_draw_shadow(unit, world_pos)

	# Pass 2: Units
	for unit in _unit_data:
		var world_pos := _get_unit_world_pos(unit)
		if not visible_rect.has_point(world_pos):
			continue
		if _is_hidden_by_fog(unit):
			continue

		# Selection indicator (drawn behind unit)
		if unit["id"] == selected_unit_id:
			_draw_selection_indicator(unit, world_pos)

		# Draw the unit
		if unit["is_building"]:
			_draw_building(unit, world_pos)
		else:
			_draw_vehicle(unit, world_pos)

		# HP bar
		_draw_hp_bar(unit, world_pos)

		# Construction progress
		if unit["is_constructing"]:
			_draw_construction_badge(world_pos)
		elif unit["is_building"] and unit["build_progress"] < 1.0:
			_draw_build_progress(unit, world_pos)

		# Working indicator for buildings
		if unit["is_building"] and unit["is_working"]:
			_draw_working_effect(unit, world_pos)

		# Damage cracks
		var hp_ratio := float(unit["hp"]) / maxf(float(unit["hp_max"]), 1.0)
		if hp_ratio < DAMAGE_THRESHOLD and hp_ratio > 0:
			_draw_damage_effect(world_pos, hp_ratio, unit["is_building"])

		# Phase 19: State indicator badges
		_draw_state_badges(unit, world_pos)


func _get_unit_world_pos(unit: Dictionary) -> Vector2:
	## Get the world position (pixel center) of a unit, accounting for animation.
	var pos: Vector2i = unit["pos"]
	var base := Vector2(pos.x * TILE_SIZE + TILE_SIZE / 2.0, pos.y * TILE_SIZE + TILE_SIZE / 2.0)

	# Check if this unit is being animated (movement)
	if move_animator and move_animator.is_animating(unit["id"]):
		var anim_pos: Vector2 = move_animator.get_animated_position(unit["id"])
		if anim_pos != Vector2(-1, -1):
			return anim_pos

	return base


func _is_hidden_by_fog(unit: Dictionary) -> bool:
	## Check if an enemy unit should be hidden by fog.
	if not fog_renderer or not fog_renderer.fog_enabled:
		return false
	if unit["player"] == current_player:
		return false  # Own units always visible
	return not fog_renderer.is_tile_visible(unit["pos"])


func _draw_shadow(unit: Dictionary, world_pos: Vector2) -> void:
	## Draw a shadow sprite or procedural shadow beneath the unit.
	if not sprite_cache:
		return

	var shadow_pos := world_pos + SHADOW_OFFSET

	if unit["is_building"]:
		var tex: Texture2D = sprite_cache.get_building_shadow(unit["type_name"])
		if tex:
			var size: float = TILE_SIZE if not unit["is_big"] else TILE_SIZE * 2
			var draw_pos := shadow_pos - Vector2(size / 2.0, size / 2.0)
			if unit["is_big"]:
				draw_pos += Vector2(TILE_SIZE / 2.0, TILE_SIZE / 2.0)
			draw_texture_rect(tex, Rect2(draw_pos, Vector2(size, size)),
				false, Color(1, 1, 1, SHADOW_ALPHA))
		else:
			# Procedural shadow for buildings without shadow sprite
			_draw_procedural_shadow(shadow_pos, unit["is_big"])
	else:
		var direction = _unit_directions.get(unit["id"], 0)
		var tex: Texture2D = sprite_cache.get_vehicle_shadow(unit["type_name"], direction)
		if tex:
			var draw_pos := shadow_pos - Vector2(tex.get_width() / 2.0, tex.get_height() / 2.0)
			draw_texture_rect(tex, Rect2(draw_pos, tex.get_size()),
				false, Color(1, 1, 1, SHADOW_ALPHA))
		else:
			# Small elliptical shadow
			_draw_procedural_shadow(shadow_pos, false)


func _draw_procedural_shadow(pos: Vector2, is_big: bool) -> void:
	## Draw a simple elliptical shadow as fallback.
	var radius_x := 18.0 if not is_big else 32.0
	var radius_y := 10.0 if not is_big else 18.0
	var points := PackedVector2Array()
	for i in range(16):
		var angle := float(i) / 16.0 * TAU
		points.append(pos + Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
	var colors := PackedColorArray()
	for i in range(16):
		colors.append(Color(0, 0, 0, 0.25))
	draw_polygon(points, colors)


func _draw_vehicle(unit: Dictionary, world_pos: Vector2) -> void:
	## Draw a vehicle using directional sprites with player color tinting.
	if not sprite_cache:
		_draw_vehicle_fallback(unit, world_pos)
		return

	var direction: int = _unit_directions.get(unit["id"], 0)

	# Check for animated unit (infantry/commando)
	var anim_info: Dictionary = _anim_unit_types.get(unit["type_name"], {})
	var tex: Texture2D = null

	if anim_info.get("has_anim", false) and anim_info.get("frame_count", 0) > 0:
		# Animated unit: cycle through frames
		var frame_count: int = anim_info["frame_count"]
		var frame: int = int(_anim_time * ANIM_FPS) % frame_count
		# Only animate if unit is moving
		if move_animator and move_animator.is_animating(unit["id"]):
			tex = sprite_cache.get_vehicle_anim_frame(unit["type_name"], direction, frame)
		else:
			# Standing still: use frame 0
			tex = sprite_cache.get_vehicle_anim_frame(unit["type_name"], direction, 0)
			if not tex:
				tex = sprite_cache.get_vehicle_texture(unit["type_name"], direction)
	else:
		tex = sprite_cache.get_vehicle_texture(unit["type_name"], direction)

	if not tex:
		_draw_vehicle_fallback(unit, world_pos)
		return

	# Draw sprite with player color tint
	var tint_color: Color = unit["color"]
	var color_mod := Color(
		lerpf(1.0, tint_color.r, PLAYER_TINT_STRENGTH),
		lerpf(1.0, tint_color.g, PLAYER_TINT_STRENGTH),
		lerpf(1.0, tint_color.b, PLAYER_TINT_STRENGTH),
		1.0
	)

	var draw_pos := world_pos - Vector2(tex.get_width() / 2.0, tex.get_height() / 2.0)
	draw_texture_rect(tex, Rect2(draw_pos, tex.get_size()), false, color_mod)


func _draw_vehicle_fallback(unit: Dictionary, world_pos: Vector2) -> void:
	## Fallback: draw a colored shape when no sprite is available.
	var radius := 20.0
	var color: Color = unit["color"]

	# Draw filled circle with outline
	draw_circle(world_pos, radius, color.darkened(0.2))
	draw_circle(world_pos, radius - 2, color)

	# Direction indicator (small triangle pointing in facing direction)
	var dir_idx: int = _unit_directions.get(unit["id"], 0)
	var dir_angle: float = dir_idx * TAU / 8.0 - PI / 2.0
	var tip := world_pos + Vector2(cos(dir_angle), sin(dir_angle)) * radius
	var left := world_pos + Vector2(cos(dir_angle + 2.5), sin(dir_angle + 2.5)) * (radius * 0.5)
	var right := world_pos + Vector2(cos(dir_angle - 2.5), sin(dir_angle - 2.5)) * (radius * 0.5)
	draw_polygon(PackedVector2Array([tip, left, right]),
		PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE]))


func _draw_building(unit: Dictionary, world_pos: Vector2) -> void:
	## Draw a building using its sprite, scaled to fit tile footprint.
	if not sprite_cache:
		_draw_building_fallback(unit, world_pos)
		return

	var tex: Texture2D = sprite_cache.get_building_texture(unit["type_name"])
	if not tex:
		_draw_building_fallback(unit, world_pos)
		return

	var size: float = TILE_SIZE if not unit["is_big"] else TILE_SIZE * 2
	var draw_pos: Vector2
	if unit["is_big"]:
		draw_pos = world_pos - Vector2(TILE_SIZE / 2.0, TILE_SIZE / 2.0)
		draw_pos += Vector2(TILE_SIZE / 2.0, TILE_SIZE / 2.0)  # Offset for 2x2 center
		draw_pos -= Vector2(size / 2.0, size / 2.0)
	else:
		draw_pos = world_pos - Vector2(size / 2.0, size / 2.0)

	# Player color tint (lighter than vehicles)
	var tint_color: Color = unit["color"]
	var color_mod := Color(
		lerpf(1.0, tint_color.r, PLAYER_TINT_STRENGTH * 0.6),
		lerpf(1.0, tint_color.g, PLAYER_TINT_STRENGTH * 0.6),
		lerpf(1.0, tint_color.b, PLAYER_TINT_STRENGTH * 0.6),
		1.0
	)

	draw_texture_rect(tex, Rect2(draw_pos, Vector2(size, size)), false, color_mod)


func _draw_building_fallback(unit: Dictionary, world_pos: Vector2) -> void:
	## Fallback: draw a diamond shape for buildings without sprites.
	var half := TILE_SIZE * 0.4 if not unit["is_big"] else TILE_SIZE * 0.8
	var center := world_pos
	if unit["is_big"]:
		center += Vector2(TILE_SIZE / 2.0, TILE_SIZE / 2.0)
	var color: Color = unit["color"]

	var points := PackedVector2Array([
		center + Vector2(0, -half),
		center + Vector2(half, 0),
		center + Vector2(0, half),
		center + Vector2(-half, 0),
	])
	var colors := PackedColorArray([color, color, color.darkened(0.3), color.darkened(0.3)])
	draw_polygon(points, colors)
	# Outline
	for i in range(4):
		draw_line(points[i], points[(i + 1) % 4], color.lightened(0.3), 1.5)


func _draw_selection_indicator(unit: Dictionary, world_pos: Vector2) -> void:
	## Draw a pulsing selection ring/rectangle around the selected unit.
	var pulse := sin(_anim_time * SELECTION_PULSE_SPEED) * 0.3 + 0.7  # 0.4 - 1.0
	var sel_color := Color(0.3, 0.85, 1.0, pulse)  # Cyan pulse

	if unit["is_building"]:
		var size: float = TILE_SIZE if not unit["is_big"] else TILE_SIZE * 2
		var rect_pos := world_pos - Vector2(size / 2.0, size / 2.0)
		if unit["is_big"]:
			rect_pos += Vector2(TILE_SIZE / 2.0, TILE_SIZE / 2.0)
			rect_pos -= Vector2(size / 2.0, size / 2.0)
		var sel_rect := Rect2(rect_pos - Vector2(3, 3), Vector2(size + 6, size + 6))
		draw_rect(sel_rect, sel_color, false, 2.0)
		# Corner accents
		var corner_len := 10.0
		_draw_corner_accents(sel_rect, sel_color, corner_len)
	else:
		var radius := 24.0
		# Outer glow ring
		draw_arc(world_pos, radius + 3, 0, TAU, 32, Color(sel_color.r, sel_color.g, sel_color.b, sel_color.a * 0.3), 4.0)
		# Main ring
		draw_arc(world_pos, radius, 0, TAU, 32, sel_color, 2.0)
		# Inner bright ring
		draw_arc(world_pos, radius - 2, 0, TAU, 32, Color(1, 1, 1, pulse * 0.3), 1.0)


func _draw_corner_accents(rect: Rect2, color: Color, length: float) -> void:
	## Draw decorative corner brackets on a selection rectangle.
	var tl := rect.position
	var top_right := Vector2(rect.end.x, rect.position.y)
	var bl := Vector2(rect.position.x, rect.end.y)
	var br := rect.end
	var w := 2.5

	# Top-left
	draw_line(tl, tl + Vector2(length, 0), color, w)
	draw_line(tl, tl + Vector2(0, length), color, w)
	# Top-right
	draw_line(top_right, top_right + Vector2(-length, 0), color, w)
	draw_line(top_right, top_right + Vector2(0, length), color, w)
	# Bottom-left
	draw_line(bl, bl + Vector2(length, 0), color, w)
	draw_line(bl, bl + Vector2(0, -length), color, w)
	# Bottom-right
	draw_line(br, br + Vector2(-length, 0), color, w)
	draw_line(br, br + Vector2(0, -length), color, w)


func _draw_hp_bar(unit: Dictionary, world_pos: Vector2) -> void:
	## Draw an HP bar below the unit.
	var hp_ratio := float(unit["hp"]) / maxf(float(unit["hp_max"]), 1.0)
	if hp_ratio >= 1.0:
		return  # Don't show HP bar for full-health units

	var bar_width := 36.0
	var bar_height := 4.0
	var bar_y_offset := 26.0

	var bar_pos := world_pos + Vector2(-bar_width / 2.0, bar_y_offset)

	# Background
	draw_rect(Rect2(bar_pos - Vector2(1, 1), Vector2(bar_width + 2, bar_height + 2)), Color(0, 0, 0, 0.7))

	# HP fill (green -> yellow -> red gradient)
	var fill_color: Color
	if hp_ratio > 0.6:
		fill_color = Color(0.2, 0.85, 0.25)
	elif hp_ratio > 0.3:
		fill_color = Color(0.95, 0.85, 0.15)
	else:
		fill_color = Color(0.95, 0.20, 0.15)

	draw_rect(Rect2(bar_pos, Vector2(bar_width * hp_ratio, bar_height)), fill_color)


func _draw_construction_badge(world_pos: Vector2) -> void:
	## Draw a small construction icon badge on vehicles that are building.
	var badge_pos := world_pos + Vector2(14, -18)
	# Gear/wrench icon (small orange circle with cross)
	draw_circle(badge_pos, 7, Color(0, 0, 0, 0.7))
	draw_circle(badge_pos, 5, Color(1.0, 0.65, 0.15))
	draw_line(badge_pos - Vector2(3, 0), badge_pos + Vector2(3, 0), Color.WHITE, 1.5)
	draw_line(badge_pos - Vector2(0, 3), badge_pos + Vector2(0, 3), Color.WHITE, 1.5)


func _draw_build_progress(unit: Dictionary, world_pos: Vector2) -> void:
	## Draw a build progress bar for buildings under construction.
	var progress: float = unit["build_progress"]
	var bar_width := 40.0
	var bar_height := 5.0
	var bar_pos := world_pos + Vector2(-bar_width / 2.0, -30)

	# Background
	draw_rect(Rect2(bar_pos - Vector2(1, 1), Vector2(bar_width + 2, bar_height + 2)), Color(0, 0, 0, 0.7))
	# Progress fill (blue -> cyan)
	var fill_color := Color(0.2, 0.5, 1.0).lerp(Color(0.3, 0.9, 1.0), progress)
	draw_rect(Rect2(bar_pos, Vector2(bar_width * progress, bar_height)), fill_color)


func _draw_working_effect(unit: Dictionary, world_pos: Vector2) -> void:
	## Draw an animated working indicator for active buildings.
	## Uses the building's effect.png sprite if available, otherwise procedural.
	if sprite_cache:
		var effect_tex: Texture2D = sprite_cache.get_building_effect(unit["type_name"])
		if effect_tex:
			var alpha := sin(_anim_time * 2.0) * 0.3 + 0.7  # Pulsing 0.4 - 1.0
			var size: float = TILE_SIZE if not unit["is_big"] else TILE_SIZE * 2
			var draw_pos := world_pos - Vector2(size / 2.0, size / 2.0)
			if unit["is_big"]:
				draw_pos += Vector2(TILE_SIZE / 2.0, TILE_SIZE / 2.0)
				draw_pos -= Vector2(size / 2.0, size / 2.0)
			draw_texture_rect(effect_tex, Rect2(draw_pos, Vector2(size, size)),
				false, Color(1, 1, 1, alpha))
			return

	# Procedural: rotating dots
	var dot_count := 3
	var orbit_radius := 8.0
	var indicator_pos := world_pos + Vector2(18, -18)
	for i in range(dot_count):
		var angle := _anim_time * 3.0 + float(i) * TAU / dot_count
		var dot_pos := indicator_pos + Vector2(cos(angle), sin(angle)) * orbit_radius
		draw_circle(dot_pos, 2.5, Color(0.3, 0.85, 1.0, 0.8))


func _draw_damage_effect(world_pos: Vector2, hp_ratio: float, _is_building: bool) -> void:
	## Draw visual damage indicators (cracks/sparks) on heavily damaged units.
	var severity := 1.0 - hp_ratio / DAMAGE_THRESHOLD  # 0..1 where 1 = worst
	var spark_alpha := severity * 0.6

	# Damage cracks (dark lines)
	var crack_seed := int(world_pos.x * 7 + world_pos.y * 13)
	var rng := RandomNumberGenerator.new()
	rng.seed = crack_seed

	var crack_count := 2 + int(severity * 3)
	for i in range(crack_count):
		var start := world_pos + Vector2(rng.randf_range(-16, 16), rng.randf_range(-16, 16))
		var end := start + Vector2(rng.randf_range(-10, 10), rng.randf_range(-10, 10))
		draw_line(start, end, Color(0.15, 0.12, 0.10, 0.5 * severity), 1.5)

	# Occasional sparks (animated)
	if severity > 0.5:
		var spark_phase := _anim_time * 4.0 + crack_seed
		if sin(spark_phase) > 0.6:
			var spark_pos := world_pos + Vector2(
				sin(spark_phase * 1.3) * 12,
				cos(spark_phase * 0.9) * 12
			)
			draw_circle(spark_pos, 3.0, Color(1.0, 0.6, 0.1, spark_alpha))
			draw_circle(spark_pos, 1.5, Color(1.0, 0.9, 0.5, spark_alpha))


# =============================================================================
# Phase 19: State indicator badges
# =============================================================================

func _draw_state_badges(unit: Dictionary, world_pos: Vector2) -> void:
	## Draw small badge icons for unit state: sentry, manual fire, disabled, cargo.
	var badge_x := -20.0
	var badge_y := -22.0

	# Disabled: red X overlay + dim tint
	if unit.get("is_disabled", false):
		_draw_disabled_overlay(world_pos, unit["is_building"])

	# Sentry mode: eye icon (top-left badge)
	if unit.get("is_sentry", false):
		var pos := world_pos + Vector2(badge_x, badge_y)
		_draw_badge_sentry(pos)
		badge_x += 16.0

	# Manual fire: crosshair icon
	if unit.get("is_manual_fire", false):
		var pos := world_pos + Vector2(badge_x, badge_y)
		_draw_badge_manual_fire(pos)
		badge_x += 16.0

	# Stored units: cargo count
	var stored: int = unit.get("stored_units", 0)
	if stored > 0:
		var pos := world_pos + Vector2(badge_x, badge_y)
		_draw_badge_cargo(pos, stored)


func _draw_disabled_overlay(world_pos: Vector2, is_building: bool) -> void:
	## Draw a red-tinted X over disabled units.
	var size := 20.0 if not is_building else 32.0
	var alpha := sin(_anim_time * 3.0) * 0.15 + 0.35  # Pulsing 0.2 - 0.5
	var color := Color(1.0, 0.15, 0.15, alpha)

	# Red X
	draw_line(world_pos + Vector2(-size, -size), world_pos + Vector2(size, size), color, 2.5)
	draw_line(world_pos + Vector2(size, -size), world_pos + Vector2(-size, size), color, 2.5)

	# Red circle around
	draw_arc(world_pos, size + 2, 0, TAU, 24, Color(1.0, 0.2, 0.1, alpha * 0.6), 1.5)


func _draw_badge_sentry(pos: Vector2) -> void:
	## Draw a small eye icon for sentry mode.
	# Background circle
	draw_circle(pos, 7, Color(0, 0, 0, 0.7))

	# Eye shape (two arcs)
	var eye_color := Color(0.3, 1.0, 0.4, 0.9)
	var points_top := PackedVector2Array()
	var points_bot := PackedVector2Array()
	for i in range(9):
		var t := float(i) / 8.0
		var angle := lerp(-0.8, 0.8, t)
		points_top.append(pos + Vector2(cos(angle) * 5.0, sin(angle) * 3.0 - 1.5))
		points_bot.append(pos + Vector2(cos(angle) * 5.0, -sin(angle) * 3.0 + 1.5))

	for i in range(points_top.size() - 1):
		draw_line(points_top[i], points_top[i + 1], eye_color, 1.0)
		draw_line(points_bot[i], points_bot[i + 1], eye_color, 1.0)

	# Pupil
	draw_circle(pos, 2.0, eye_color)


func _draw_badge_manual_fire(pos: Vector2) -> void:
	## Draw a small crosshair icon for manual fire mode.
	draw_circle(pos, 7, Color(0, 0, 0, 0.7))

	var color := Color(1.0, 0.6, 0.2, 0.9)
	# Crosshair lines
	draw_line(pos + Vector2(-4, 0), pos + Vector2(4, 0), color, 1.2)
	draw_line(pos + Vector2(0, -4), pos + Vector2(0, 4), color, 1.2)
	# Circle
	draw_arc(pos, 3.5, 0, TAU, 12, color, 1.0)


func _draw_badge_cargo(pos: Vector2, count: int) -> void:
	## Draw a cargo count badge.
	draw_circle(pos, 7, Color(0, 0, 0, 0.7))
	draw_circle(pos, 5.5, Color(0.2, 0.5, 0.85, 0.8))

	# Number (using simple approach - draw individual digits as lines)
	# For simplicity, just draw the number as a label would
	# We can't use draw_string in _draw, so use a simple visual
	var text_color := Color(1, 1, 1, 0.95)
	if count <= 3:
		# Draw dots for 1-3
		for i in range(count):
			var dot_x := pos.x - float(count - 1) * 2.0 + float(i) * 4.0
			draw_circle(Vector2(dot_x, pos.y), 1.5, text_color)
	else:
		# Just draw a bright indicator
		draw_circle(pos, 3.0, text_color)
