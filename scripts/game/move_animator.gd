extends Node
## Handles smooth visual animation of unit movement along paths.
## The engine teleports units to their destination instantly;
## this class provides visual interpolation so units glide smoothly.

signal animation_finished(unit_id: int)
signal direction_changed(unit_id: int, direction: int)

const TILE_SIZE := 64
const MOVE_SPEED := 200.0  # Pixels per second

# Currently animating movement
var _active_animations: Dictionary = {}  # unit_id -> AnimData
var _unit_type_names: Dictionary = {}  # unit_id -> type_name (for sound lookup)

class AnimData:
	var path: PackedVector2Array  # Path in tile coords
	var path_index: int = 0       # Current segment (0 = between path[0] and path[1])
	var progress: float = 0.0     # 0.0 to 1.0 within current segment
	var world_pos: Vector2        # Current interpolated world position (pixels)


func start_animation(unit_id: int, path: PackedVector2Array, type_name: String = "") -> void:
	if path.size() < 2:
		animation_finished.emit(unit_id)
		return

	var anim = AnimData.new()
	anim.path = path
	anim.path_index = 0
	anim.progress = 0.0
	anim.world_pos = _tile_to_world(path[0])
	_active_animations[unit_id] = anim

	# Store type name for audio
	if type_name != "":
		_unit_type_names[unit_id] = type_name

	# Emit initial direction
	if path.size() >= 2:
		var dir := _calc_direction(path[0], path[1])
		direction_changed.emit(unit_id, dir)

	# Play start/drive sound
	var utype: String = _unit_type_names.get(unit_id, "")
	if utype != "":
		AudioManager.play_unit_sound(utype, "start")
		AudioManager.play_unit_sound(utype, "drive")


func cancel_animation(unit_id: int) -> void:
	_active_animations.erase(unit_id)


func cancel_all() -> void:
	_active_animations.clear()


func is_animating(unit_id: int) -> bool:
	return _active_animations.has(unit_id)


func has_animations() -> bool:
	return not _active_animations.is_empty()


func get_animated_position(unit_id: int) -> Vector2:
	## Returns the animated world position (pixel center) for a unit,
	## or Vector2(-1, -1) if not animating.
	if _active_animations.has(unit_id):
		return _active_animations[unit_id].world_pos
	return Vector2(-1, -1)


func _process(delta: float) -> void:
	if _active_animations.is_empty():
		return

	var finished_units: Array = []

	for unit_id in _active_animations:
		var anim: AnimData = _active_animations[unit_id]

		# Calculate segment distance and advance
		var from_world = _tile_to_world(anim.path[anim.path_index])
		var to_world = _tile_to_world(anim.path[anim.path_index + 1])
		var segment_distance = from_world.distance_to(to_world)

		if segment_distance > 0.01:
			anim.progress += (MOVE_SPEED * delta) / segment_distance
		else:
			anim.progress = 1.0

		if anim.progress >= 1.0:
			# Finished this segment
			anim.path_index += 1
			anim.progress = 0.0

			if anim.path_index >= anim.path.size() - 1:
				# Finished entire path
				anim.world_pos = to_world
				finished_units.append(unit_id)
				continue
			else:
				# Start next segment -- emit direction change
				from_world = _tile_to_world(anim.path[anim.path_index])
				to_world = _tile_to_world(anim.path[anim.path_index + 1])
				var dir := _calc_direction(anim.path[anim.path_index], anim.path[anim.path_index + 1])
				direction_changed.emit(unit_id, dir)

		# Interpolate position
		anim.world_pos = from_world.lerp(to_world, clampf(anim.progress, 0.0, 1.0))

	# Clean up finished animations
	for uid in finished_units:
		_active_animations.erase(uid)
		# Play stop sound
		var utype: String = _unit_type_names.get(uid, "")
		if utype != "":
			AudioManager.play_unit_sound(utype, "stop")
		animation_finished.emit(uid)


func _tile_to_world(tile: Vector2) -> Vector2:
	return Vector2(tile.x * TILE_SIZE + TILE_SIZE / 2.0,
				   tile.y * TILE_SIZE + TILE_SIZE / 2.0)


func _calc_direction(from_tile: Vector2, to_tile: Vector2) -> int:
	## Calculate 8-direction index from tile movement.
	## 0=N, 1=NE, 2=E, 3=SE, 4=S, 5=SW, 6=W, 7=NW
	var dx := int(to_tile.x - from_tile.x)
	var dy := int(to_tile.y - from_tile.y)
	if dx == 0 and dy < 0: return 0   # N
	if dx > 0 and dy < 0: return 1    # NE
	if dx > 0 and dy == 0: return 2   # E
	if dx > 0 and dy > 0: return 3    # SE
	if dx == 0 and dy > 0: return 4   # S
	if dx < 0 and dy > 0: return 5    # SW
	if dx < 0 and dy == 0: return 6   # W
	if dx < 0 and dy < 0: return 7    # NW
	return 0
