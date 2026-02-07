extends Node2D
## FogRenderer -- Renders fog of war with smooth edges and atmospheric effects.
##
## Three visibility states:
##   - Visible: No fog (player can see units and terrain)
##   - Explored: Semi-transparent dark overlay (terrain visible, no units)
##   - Unexplored: Near-opaque dark fog (nothing visible)

const TILE_SIZE := 64

const COLOR_UNEXPLORED := Color(0.02, 0.03, 0.06, 0.88)
const COLOR_EXPLORED := Color(0.03, 0.04, 0.08, 0.52)

var _map_w := 0
var _map_h := 0
var _current_player := 0
var _scan_data: PackedInt32Array = PackedInt32Array()
var _explored_tiles: Dictionary = {}  # "x,y" -> true
var fog_enabled := true


func setup(map_w: int, map_h: int, player: int) -> void:
	_map_w = map_w
	_map_h = map_h
	_current_player = player
	_explored_tiles.clear()
	queue_redraw()


func refresh(engine) -> void:
	## Refresh fog data from the engine's scan map.
	if engine == null or _map_w == 0:
		return

	var player = engine.get_player(_current_player)
	if player == null:
		return

	_scan_data = player.get_scan_map_data()

	# Mark currently visible tiles as explored
	for y in range(_map_h):
		for x in range(_map_w):
			var idx := y * _map_w + x
			if idx < _scan_data.size() and _scan_data[idx] > 0:
				_explored_tiles["%d,%d" % [x, y]] = true

	queue_redraw()


func is_tile_visible(tile: Vector2i) -> bool:
	## Check if a tile is currently visible (in scan range).
	if not fog_enabled:
		return true
	var idx := tile.y * _map_w + tile.x
	if idx < 0 or idx >= _scan_data.size():
		return false
	return _scan_data[idx] > 0


func is_tile_explored(tile: Vector2i) -> bool:
	## Check if a tile has ever been visible.
	if not fog_enabled:
		return true
	return _explored_tiles.has("%d,%d" % [tile.x, tile.y])


func _draw() -> void:
	if not fog_enabled or _map_w == 0:
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

	for ty in range(min_ty, max_ty):
		for tx in range(min_tx, max_tx):
			var tile := Vector2i(tx, ty)
			if is_tile_visible(tile):
				continue  # No fog on visible tiles

			var rect := Rect2(tx * TILE_SIZE, ty * TILE_SIZE, TILE_SIZE, TILE_SIZE)

			if is_tile_explored(tile):
				# Explored but not currently visible -- semi-dark
				draw_rect(rect, COLOR_EXPLORED)
			else:
				# Never explored -- full dark fog
				draw_rect(rect, COLOR_UNEXPLORED)

				# Edge softening: draw slightly lighter edges where explored tiles are adjacent
				_draw_fog_edge_softening(tx, ty, rect)


func _draw_fog_edge_softening(tx: int, ty: int, rect: Rect2) -> void:
	## Draw subtle gradient at the edge between unexplored and explored fog.
	var edge_size := TILE_SIZE * 0.25
	var edge_color := Color(COLOR_UNEXPLORED.r, COLOR_UNEXPLORED.g, COLOR_UNEXPLORED.b, COLOR_UNEXPLORED.a * 0.4)

	# Check each cardinal neighbor
	if _is_explored_at(tx, ty - 1):  # North explored
		draw_rect(Rect2(rect.position.x, rect.position.y, TILE_SIZE, edge_size), edge_color)
	if _is_explored_at(tx, ty + 1):  # South explored
		draw_rect(Rect2(rect.position.x, rect.end.y - edge_size, TILE_SIZE, edge_size), edge_color)
	if _is_explored_at(tx - 1, ty):  # West explored
		draw_rect(Rect2(rect.position.x, rect.position.y, edge_size, TILE_SIZE), edge_color)
	if _is_explored_at(tx + 1, ty):  # East explored
		draw_rect(Rect2(rect.end.x - edge_size, rect.position.y, edge_size, TILE_SIZE), edge_color)


func _is_explored_at(x: int, y: int) -> bool:
	if x < 0 or x >= _map_w or y < 0 or y >= _map_h:
		return false
	return _explored_tiles.has("%d,%d" % [x, y])
