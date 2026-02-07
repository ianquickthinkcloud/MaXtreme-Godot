extends Control
## NetworkStatus -- Overlay that shows freeze mode and connection status
## in multiplayer games. Added as a child of a CanvasLayer.

var _status_label: Label = null
var _background: ColorRect = null
var _is_frozen := false
var _is_disconnected := false


func _ready() -> void:
	# Create a semi-transparent background panel
	_background = ColorRect.new()
	_background.color = Color(0, 0, 0, 0.6)
	_background.visible = false
	_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_background)

	# Create status label
	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.set_anchors_preset(Control.PRESET_CENTER)
	_status_label.add_theme_font_size_override("font_size", 28)
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	_status_label.visible = false
	add_child(_status_label)


func set_freeze_mode(mode: String) -> void:
	## Show or hide the freeze overlay based on the current network state.
	if mode == "" or mode == "none":
		_is_frozen = false
		_background.visible = false
		_status_label.visible = false
	else:
		_is_frozen = true
		_status_label.text = "Waiting for network..."
		_background.visible = true
		_status_label.visible = true


func show_connection_lost() -> void:
	## Show the connection lost message.
	_is_disconnected = true
	_status_label.text = "Connection Lost!\nReturning to menu..."
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	_background.visible = true
	_status_label.visible = true
