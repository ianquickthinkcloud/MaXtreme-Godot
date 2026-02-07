extends Node2D
## MapRenderer -- Renders the game terrain with procedural textures, terrain transitions,
## animated water, and atmospheric effects.
##
## Terrain types are read from the engine's cStaticMap. Each tile is rendered with:
##   - Base color from terrain type with noise variation
##   - Coastal transition blending at water/ground edges
##   - Animated water shimmer effect
##   - Subtle resource deposit indicators
##   - Clean grid overlay with adaptive visibility

const TILE_SIZE := 64

# -- Terrain base colors (richer palette) --
const COLOR_GROUND_DARK := Color(0.22, 0.38, 0.18)
const COLOR_GROUND_MID := Color(0.30, 0.48, 0.22)
const COLOR_GROUND_LIGHT := Color(0.38, 0.55, 0.28)
const COLOR_WATER_DEEP := Color(0.08, 0.18, 0.42)
const COLOR_WATER_MID := Color(0.12, 0.25, 0.52)
const COLOR_WATER_LIGHT := Color(0.16, 0.32, 0.58)
const COLOR_WATER_SHIMMER := Color(0.25, 0.45, 0.72)
const COLOR_COAST_DRY := Color(0.52, 0.48, 0.32)
const COLOR_COAST_WET := Color(0.42, 0.40, 0.30)
const COLOR_COAST_SAND := Color(0.62, 0.56, 0.38)
const COLOR_BLOCKED_DARK := Color(0.22, 0.20, 0.18)
const COLOR_BLOCKED_MID := Color(0.28, 0.26, 0.24)
const COLOR_BLOCKED_LIGHT := Color(0.34, 0.32, 0.28)
const COLOR_GRID := Color(0.0, 0.0, 0.0, 0.08)
const COLOR_GRID_THICK := Color(0.0, 0.0, 0.0, 0.15)
const COLOR_HOVER_FILL := Color(1.0, 1.0, 1.0, 0.12)
const COLOR_HOVER_BORDER := Color(1.0, 1.0, 1.0, 0.45)

var _map = null  # GameMap reference
var _map_w := 0
var _map_h := 0
var _hover_tile := Vector2i(-1, -1)
var _noise: FastNoiseLite = null
var _water_time := 0.0  # Animated water phase
var _terrain_cache: PackedByteArray  # Cached terrain types for fast lookup
var _neighbor_cache: PackedByteArray  # Cached neighbor info for transitions


func setup(game_map) -> void:
	_map = game_map
	if _map:
		_map_w = _map.get_width()
		_map_h = _map.get_height()
	else:
		_map_w = 0
		_map_h = 0

	# Create noise generator for terrain variation
	_noise = FastNoiseLite.new()
	_noise.seed = 42
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise.frequency = 0.08
	_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_noise.fractal_octaves = 3

	# Cache terrain data for fast rendering
	_build_terrain_cache()

	queue_redraw()


func _build_terrain_cache() -> void:
	## Pre-compute terrain types and neighbor data for all tiles.
	_terrain_cache.resize(_map_w * _map_h)
	_neighbor_cache.resize(_map_w * _map_h)

	for y in range(_map_h):
		for x in range(_map_w):
			var pos := Vector2i(x, y)
			var idx := y * _map_w + x
			# Terrain type: 0=ground, 1=water, 2=coast, 3=blocked
			if _map.is_water(pos):
				_terrain_cache[idx] = 1
			elif _map.is_coast(pos):
				_terrain_cache[idx] = 2
			elif _map.is_blocked(pos):
				_terrain_cache[idx] = 3
			else:
				_terrain_cache[idx] = 0

			# Neighbor flags: bits for adjacent water tiles (for coastal transitions)
			# Bit layout: N=1, NE=2, E=4, SE=8, S=16, SW=32, W=64, NW=128
			var flags := 0
			if _is_water_at(x, y - 1): flags |= 1
			if _is_water_at(x + 1, y - 1): flags |= 2
			if _is_water_at(x + 1, y): flags |= 4
			if _is_water_at(x + 1, y + 1): flags |= 8
			if _is_water_at(x, y + 1): flags |= 16
			if _is_water_at(x - 1, y + 1): flags |= 32
			if _is_water_at(x - 1, y): flags |= 64
			if _is_water_at(x - 1, y - 1): flags |= 128
			_neighbor_cache[idx] = flags


func _is_water_at(x: int, y: int) -> bool:
	if x < 0 or x >= _map_w or y < 0 or y >= _map_h:
		return false
	return _map.is_water(Vector2i(x, y))


func set_hover_tile(tile: Vector2i) -> void:
	if tile != _hover_tile:
		_hover_tile = tile
		queue_redraw()


func world_to_tile(world_pos: Vector2) -> Vector2i:
	var tx := int(world_pos.x / TILE_SIZE)
	var ty := int(world_pos.y / TILE_SIZE)
	return Vector2i(tx, ty)


func tile_to_world_center(tile: Vector2i) -> Vector2:
	return Vector2(tile.x * TILE_SIZE + TILE_SIZE / 2.0, tile.y * TILE_SIZE + TILE_SIZE / 2.0)


func is_valid_tile(tile: Vector2i) -> bool:
	return tile.x >= 0 and tile.y >= 0 and tile.x < _map_w and tile.y < _map_h


func _process(delta: float) -> void:
	_water_time += delta
	# Redraw periodically for water animation (every ~3 frames at 60fps)
	if Engine.get_process_frames() % 3 == 0:
		queue_redraw()


func _draw() -> void:
	if _map == null or _map_w == 0:
		return

	# Determine visible tile range from camera viewport
	var canvas_xform := get_canvas_transform()
	var inv_xform := canvas_xform.affine_inverse()
	var vp_size := get_viewport_rect().size
	var top_left := inv_xform * Vector2.ZERO
	var bottom_right := inv_xform * vp_size

	var min_tx := maxi(int(top_left.x / TILE_SIZE) - 1, 0)
	var min_ty := maxi(int(top_left.y / TILE_SIZE) - 1, 0)
	var max_tx := mini(int(bottom_right.x / TILE_SIZE) + 2, _map_w)
	var max_ty := mini(int(bottom_right.y / TILE_SIZE) + 2, _map_h)

	# Calculate zoom level for adaptive detail
	var zoom_level := canvas_xform.get_scale().x

	# Draw terrain tiles
	for ty in range(min_ty, max_ty):
		for tx in range(min_tx, max_tx):
			var rect := Rect2(tx * TILE_SIZE, ty * TILE_SIZE, TILE_SIZE, TILE_SIZE)
			var idx := ty * _map_w + tx
			var terrain_type: int = _terrain_cache[idx]
			var water_neighbors: int = _neighbor_cache[idx]

			# Get base tile color with noise variation
			var base_color := _get_tile_color(tx, ty, terrain_type)

			# Draw base tile
			draw_rect(rect, base_color)

			# Draw coastal transitions (blend at edges where water meets land)
			if terrain_type != 1 and water_neighbors != 0:
				_draw_coastal_transition(tx, ty, water_neighbors, rect)

			# Animated water shimmer
			if terrain_type == 1:
				_draw_water_shimmer(tx, ty, rect)

			# Grid lines (adaptive based on zoom)
			if zoom_level > 0.5:
				_draw_grid_lines(tx, ty, rect, zoom_level)

	# Hover highlight
	if is_valid_tile(_hover_tile):
		var hover_rect := Rect2(_hover_tile.x * TILE_SIZE, _hover_tile.y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
		draw_rect(hover_rect, COLOR_HOVER_FILL)
		# Hover border
		var border_width := 2.0 / maxf(zoom_level, 0.25)
		draw_rect(hover_rect, COLOR_HOVER_BORDER, false, border_width)


func _get_tile_color(x: int, y: int, terrain_type: int) -> Color:
	## Get the color for a terrain tile with noise-based variation.
	var noise_val := _noise.get_noise_2d(float(x), float(y))  # Range -1..1
	var detail_noise := _noise.get_noise_2d(float(x) * 3.0 + 100.0, float(y) * 3.0 + 100.0)

	match terrain_type:
		1:  # Water
			# Deeper variation with subtle movement
			var water_noise := noise_val * 0.3 + sin(_water_time * 0.4 + x * 0.5 + y * 0.3) * 0.1
			if water_noise < -0.15:
				return COLOR_WATER_DEEP
			elif water_noise < 0.15:
				return COLOR_WATER_MID.lerp(COLOR_WATER_DEEP, (0.15 - water_noise) / 0.3)
			else:
				return COLOR_WATER_MID.lerp(COLOR_WATER_LIGHT, (water_noise - 0.15) / 0.3)

		2:  # Coast
			var blend := (noise_val + 1.0) * 0.5  # 0..1
			if detail_noise > 0.2:
				return COLOR_COAST_SAND.lerp(COLOR_COAST_DRY, blend * 0.5)
			else:
				return COLOR_COAST_DRY.lerp(COLOR_COAST_WET, blend * 0.6)

		3:  # Blocked (mountains/rocks)
			var blend := (noise_val + 1.0) * 0.5
			var rock_detail := detail_noise * 0.15
			return COLOR_BLOCKED_MID.lerp(
				COLOR_BLOCKED_DARK if blend < 0.4 else COLOR_BLOCKED_LIGHT,
				absf(blend - 0.5) * 1.5
			) + Color(rock_detail, rock_detail, rock_detail, 0.0)

		_:  # Ground
			var blend := (noise_val + 1.0) * 0.5  # 0..1
			var detail := detail_noise * 0.08
			var base: Color
			if blend < 0.35:
				base = COLOR_GROUND_DARK.lerp(COLOR_GROUND_MID, blend / 0.35)
			elif blend < 0.65:
				base = COLOR_GROUND_MID
			else:
				base = COLOR_GROUND_MID.lerp(COLOR_GROUND_LIGHT, (blend - 0.65) / 0.35)
			return base + Color(detail, detail * 1.2, detail * 0.5, 0.0)


func _draw_coastal_transition(x: int, y: int, water_flags: int, rect: Rect2) -> void:
	## Draw subtle water-edge blending on land tiles adjacent to water.
	var transition_size := TILE_SIZE * 0.35
	var water_color := Color(COLOR_WATER_MID.r, COLOR_WATER_MID.g, COLOR_WATER_MID.b, 0.25)
	var foam_color := Color(0.7, 0.75, 0.8, 0.15)

	# Cardinal edges (stronger effect)
	if water_flags & 1:  # North
		draw_rect(Rect2(rect.position.x, rect.position.y, TILE_SIZE, transition_size * 0.6), water_color)
		draw_rect(Rect2(rect.position.x, rect.position.y, TILE_SIZE, 2), foam_color)
	if water_flags & 16:  # South
		draw_rect(Rect2(rect.position.x, rect.end.y - transition_size * 0.6, TILE_SIZE, transition_size * 0.6), water_color)
		draw_rect(Rect2(rect.position.x, rect.end.y - 2, TILE_SIZE, 2), foam_color)
	if water_flags & 64:  # West
		draw_rect(Rect2(rect.position.x, rect.position.y, transition_size * 0.6, TILE_SIZE), water_color)
		draw_rect(Rect2(rect.position.x, rect.position.y, 2, TILE_SIZE), foam_color)
	if water_flags & 4:  # East
		draw_rect(Rect2(rect.end.x - transition_size * 0.6, rect.position.y, transition_size * 0.6, TILE_SIZE), water_color)
		draw_rect(Rect2(rect.end.x - 2, rect.position.y, 2, TILE_SIZE), foam_color)


func _draw_water_shimmer(x: int, y: int, rect: Rect2) -> void:
	## Draw animated light reflections on water tiles.
	var shimmer_phase := _water_time * 0.6 + x * 0.7 + y * 1.1
	var shimmer_alpha := (sin(shimmer_phase) * 0.5 + 0.5) * 0.08
	if shimmer_alpha > 0.02:
		var shimmer_x := rect.position.x + (sin(shimmer_phase * 0.3) * 0.5 + 0.5) * TILE_SIZE * 0.6
		var shimmer_y := rect.position.y + (cos(shimmer_phase * 0.4) * 0.5 + 0.5) * TILE_SIZE * 0.4
		var shimmer_rect := Rect2(shimmer_x, shimmer_y, TILE_SIZE * 0.3, TILE_SIZE * 0.15)
		draw_rect(shimmer_rect, Color(COLOR_WATER_SHIMMER.r, COLOR_WATER_SHIMMER.g, COLOR_WATER_SHIMMER.b, shimmer_alpha))

	# Secondary subtle wave pattern
	var wave_phase := _water_time * 0.3 + x * 1.3 - y * 0.9
	var wave_alpha := (sin(wave_phase) * 0.5 + 0.5) * 0.04
	if wave_alpha > 0.01:
		var wave_y := rect.position.y + (sin(wave_phase * 0.5) * 0.5 + 0.5) * TILE_SIZE * 0.7
		draw_line(
			Vector2(rect.position.x + 4, wave_y),
			Vector2(rect.end.x - 4, wave_y + 2),
			Color(1, 1, 1, wave_alpha), 1.0
		)


func _draw_grid_lines(x: int, y: int, rect: Rect2, zoom: float) -> void:
	## Draw grid lines with adaptive thickness and visibility.
	var line_alpha := clampf((zoom - 0.5) * 0.8, 0.0, 1.0)
	if line_alpha < 0.01:
		return

	var line_width := 1.0 / maxf(zoom, 0.5)

	# Thicker lines every 8 tiles for orientation
	var is_major_x := (x % 8 == 0)
	var is_major_y := (y % 8 == 0)

	var color: Color
	if is_major_x or is_major_y:
		color = Color(COLOR_GRID_THICK.r, COLOR_GRID_THICK.g, COLOR_GRID_THICK.b, COLOR_GRID_THICK.a * line_alpha)
		line_width *= 1.5
	else:
		color = Color(COLOR_GRID.r, COLOR_GRID.g, COLOR_GRID.b, COLOR_GRID.a * line_alpha)

	# Draw right and bottom edges only (to avoid double-drawing)
	draw_line(Vector2(rect.end.x, rect.position.y), Vector2(rect.end.x, rect.end.y), color, line_width)
	draw_line(Vector2(rect.position.x, rect.end.y), Vector2(rect.end.x, rect.end.y), color, line_width)


# --- Utility for minimap ---

func get_terrain_color_at(x: int, y: int) -> Color:
	## Get the base terrain color for a tile (no noise, for minimap use).
	if x < 0 or x >= _map_w or y < 0 or y >= _map_h:
		return Color.BLACK
	var idx := y * _map_w + x
	match _terrain_cache[idx]:
		1: return COLOR_WATER_MID
		2: return COLOR_COAST_DRY
		3: return COLOR_BLOCKED_MID
		_: return COLOR_GROUND_MID
