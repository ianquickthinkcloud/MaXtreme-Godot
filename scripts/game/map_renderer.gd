extends Node2D
## Renders the game map as colored tiles using _draw().
## Each tile is a TILE_SIZE x TILE_SIZE pixel square.

const TILE_SIZE := 64

# Colors for terrain types
const COLOR_GROUND := Color(0.35, 0.55, 0.25)   # Earthy green
const COLOR_WATER := Color(0.15, 0.30, 0.60)     # Deep blue
const COLOR_COAST := Color(0.60, 0.55, 0.35)     # Sandy
const COLOR_BLOCKED := Color(0.30, 0.28, 0.25)   # Rocky gray
const COLOR_GRID := Color(0.0, 0.0, 0.0, 0.08)   # Subtle grid lines

var game_map: RefCounted = null  # GameMap from engine
var map_width := 0
var map_height := 0
var _hover_tile := Vector2i(-1, -1)


func setup(p_map: RefCounted) -> void:
	game_map = p_map
	if game_map:
		map_width = game_map.get_width()
		map_height = game_map.get_height()
	queue_redraw()


func set_hover_tile(tile: Vector2i) -> void:
	if tile != _hover_tile:
		_hover_tile = tile
		queue_redraw()


func world_to_tile(world_pos: Vector2) -> Vector2i:
	var tx := int(world_pos.x) / TILE_SIZE
	var ty := int(world_pos.y) / TILE_SIZE
	if world_pos.x < 0: tx -= 1
	if world_pos.y < 0: ty -= 1
	return Vector2i(tx, ty)


func tile_to_world_center(tile: Vector2i) -> Vector2:
	return Vector2(tile.x * TILE_SIZE + TILE_SIZE / 2.0,
				   tile.y * TILE_SIZE + TILE_SIZE / 2.0)


func is_valid_tile(tile: Vector2i) -> bool:
	return tile.x >= 0 and tile.x < map_width and tile.y >= 0 and tile.y < map_height


func _draw() -> void:
	if not game_map or map_width == 0:
		return

	# Draw terrain tiles
	for y in range(map_height):
		for x in range(map_width):
			var pos := Vector2i(x, y)
			var color := _get_terrain_color(pos)

			# Slight variation for visual interest
			var noise_val := (sin(x * 3.7 + y * 2.3) * 0.03)
			color = color.lightened(noise_val)

			var rect := Rect2(x * TILE_SIZE, y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
			draw_rect(rect, color)

			# Grid lines
			draw_rect(rect, COLOR_GRID, false, 1.0)

	# Draw hover highlight
	if is_valid_tile(_hover_tile):
		var hover_rect := Rect2(_hover_tile.x * TILE_SIZE, _hover_tile.y * TILE_SIZE,
								TILE_SIZE, TILE_SIZE)
		draw_rect(hover_rect, Color(1, 1, 1, 0.15))
		draw_rect(hover_rect, Color(1, 1, 1, 0.4), false, 2.0)


func _get_terrain_color(pos: Vector2i) -> Color:
	if not game_map:
		return COLOR_GROUND

	if game_map.is_water(pos):
		return COLOR_WATER
	elif game_map.is_coast(pos):
		return COLOR_COAST
	elif game_map.is_blocked(pos):
		return COLOR_BLOCKED
	else:
		return COLOR_GROUND
