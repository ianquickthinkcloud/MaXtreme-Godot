extends Camera2D
## Game Camera with pan (middle-click/WASD/arrow keys) and zoom (scroll wheel).

const ZOOM_MIN := 0.25
const ZOOM_MAX := 4.0
const ZOOM_STEP := 0.1
const PAN_SPEED := 600.0
const EDGE_SCROLL_MARGIN := 20  # pixels from edge to trigger scroll

var _dragging := false
var _drag_start := Vector2.ZERO

func _ready() -> void:
	zoom = Vector2(1.5, 1.5)
	position_smoothing_enabled = true
	position_smoothing_speed = 10.0


func _unhandled_input(event: InputEvent) -> void:
	# Zoom with mouse wheel
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				_zoom_at(mb.position, ZOOM_STEP)
				get_viewport().set_input_as_handled()
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_zoom_at(mb.position, -ZOOM_STEP)
				get_viewport().set_input_as_handled()

		# Middle click drag for panning
		if mb.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = mb.pressed
			_drag_start = mb.position
			get_viewport().set_input_as_handled()

	# Middle mouse drag
	if event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		position -= mm.relative / zoom
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	# Keyboard panning (WASD or arrow keys)
	var pan := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		pan.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		pan.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		pan.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		pan.x += 1.0

	# Edge scrolling
	var mouse_pos := get_viewport().get_mouse_position()
	var vp_size := get_viewport_rect().size
	if mouse_pos.x < EDGE_SCROLL_MARGIN:
		pan.x -= 1.0
	elif mouse_pos.x > vp_size.x - EDGE_SCROLL_MARGIN:
		pan.x += 1.0
	if mouse_pos.y < EDGE_SCROLL_MARGIN:
		pan.y -= 1.0
	elif mouse_pos.y > vp_size.y - EDGE_SCROLL_MARGIN:
		pan.y += 1.0

	if pan != Vector2.ZERO:
		position += pan.normalized() * PAN_SPEED * delta / zoom.x


func _zoom_at(mouse_pos: Vector2, step: float) -> void:
	var old_zoom := zoom
	var new_z := clampf(zoom.x + step, ZOOM_MIN, ZOOM_MAX)
	zoom = Vector2(new_z, new_z)

	# Zoom toward mouse position
	var viewport_size := get_viewport_rect().size
	var mouse_world_before := position + (mouse_pos - viewport_size / 2.0) / old_zoom
	var mouse_world_after := position + (mouse_pos - viewport_size / 2.0) / zoom
	position += mouse_world_before - mouse_world_after


func center_on_tile(tile_pos: Vector2i, tile_size: int) -> void:
	position = Vector2(tile_pos) * tile_size + Vector2(tile_size / 2.0, tile_size / 2.0)
