extends Control
## NetworkStatus -- Overlay that shows freeze mode, connection status,
## desync detection, and player states in multiplayer games.
## Enhanced in Phase 32 with detailed freeze info, desync warnings, and player states.

var _status_label: Label = null
var _detail_label: Label = null  # Phase 32: Shows disconnected players, reason
var _checksum_label: Label = null  # Phase 32: Desync detection indicator
var _resync_button: Button = null  # Phase 32: Manual resync request
var _background: ColorRect = null
var _is_frozen := false
var _is_disconnected := false
var _engine: Node = null  # Reference to GameEngine for querying state


func _ready() -> void:
	# Create a semi-transparent background panel
	_background = ColorRect.new()
	_background.color = Color(0, 0, 0, 0.6)
	_background.visible = false
	_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_background)

	# Create a center container for status info
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(vbox)

	# Main status label
	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 28)
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	_status_label.visible = false
	vbox.add_child(_status_label)

	# Phase 32: Detail label (shows which player, reason)
	_detail_label = Label.new()
	_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_label.add_theme_font_size_override("font_size", 16)
	_detail_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.7))
	_detail_label.visible = false
	vbox.add_child(_detail_label)

	# Phase 32: Resync button
	_resync_button = Button.new()
	_resync_button.text = "Request Resync"
	_resync_button.custom_minimum_size = Vector2(180, 36)
	_resync_button.add_theme_font_size_override("font_size", 14)
	_resync_button.tooltip_text = "Request model resynchronisation from server"
	_resync_button.visible = false
	_resync_button.pressed.connect(_on_resync_request)
	vbox.add_child(_resync_button)

	# Phase 32: Checksum indicator (top-right corner, always visible in multiplayer)
	_checksum_label = Label.new()
	_checksum_label.position = Vector2(10, 10)
	_checksum_label.add_theme_font_size_override("font_size", 11)
	_checksum_label.add_theme_color_override("font_color", Color(0.4, 0.6, 0.4, 0.6))
	_checksum_label.visible = false
	add_child(_checksum_label)


func set_engine(eng: Node) -> void:
	## Phase 32: Set the engine reference for querying freeze/desync status.
	_engine = eng
	if _engine:
		_checksum_label.visible = true


func set_freeze_mode(mode: String) -> void:
	## Show or hide the freeze overlay based on the current network state.
	## Phase 32 enhanced: Shows detailed reason and disconnected player info.
	if mode == "" or mode == "none":
		_is_frozen = false
		_background.visible = false
		_status_label.visible = false
		_detail_label.visible = false
		_resync_button.visible = false
	else:
		_is_frozen = true
		_background.visible = true
		_status_label.visible = true
		_detail_label.visible = true

		# Phase 32: Query engine for detailed freeze status
		if _engine and _engine.has_method("get_freeze_status"):
			var freeze: Dictionary = _engine.get_freeze_status()
			var freeze_mode: String = freeze.get("mode", "unknown")
			match freeze_mode:
				"pause":
					_status_label.text = "Game Paused"
					_status_label.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
					_detail_label.text = "Waiting for host to unpause..."
				"wait_client":
					_status_label.text = "Waiting for Player..."
					_status_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
					# Show which players are disconnected
					var dc: Array = freeze.get("disconnected_players", [])
					if dc.size() > 0:
						var names := PackedStringArray()
						for p in dc:
							names.append("Player #%d (%s)" % [p.get("id", -1), p.get("state", "?")])
						_detail_label.text = "Disconnected: %s" % ", ".join(names)
					else:
						_detail_label.text = "A player is not responding..."
				"wait_server":
					_status_label.text = "Waiting for Server..."
					_status_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.3))
					_detail_label.text = "Server may be processing or unreachable"
					_resync_button.visible = true
				"wait_turnend":
					_status_label.text = "Processing Turn..."
					_status_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
					_detail_label.text = "Server is calculating turn results"
				_:
					_status_label.text = "Waiting for network..."
					_status_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
					_detail_label.text = ""
		else:
			_status_label.text = "Waiting for network..."
			_detail_label.text = ""


func update_checksum() -> void:
	## Phase 32: Update the checksum indicator (call periodically).
	if not _engine or not _checksum_label.visible:
		return
	if _engine.has_method("get_model_checksum"):
		var crc: int = _engine.get_model_checksum()
		_checksum_label.text = "Model CRC: %08X" % crc


func show_desync_warning() -> void:
	## Phase 32: Show a desync warning banner.
	_status_label.text = "DESYNC DETECTED"
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
	_detail_label.text = "Model state mismatch — requesting resync..."
	_detail_label.visible = true
	_status_label.visible = true
	_background.visible = true
	_background.color = Color(0.3, 0, 0, 0.7)
	_resync_button.visible = true


func show_connection_lost() -> void:
	## Show the connection lost message.
	_is_disconnected = true
	_status_label.text = "Connection Lost!"
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	_detail_label.text = "Returning to menu..."
	_detail_label.visible = true
	_background.visible = true
	_status_label.visible = true


func _on_resync_request() -> void:
	## Phase 32: Request model resync from server.
	if _engine and _engine.has_method("request_resync"):
		_engine.request_resync()
		_detail_label.text = "Resync requested, waiting for server..."
		_resync_button.disabled = true
		# Re-enable after a cooldown
		await get_tree().create_timer(5.0).timeout
		_resync_button.disabled = false
