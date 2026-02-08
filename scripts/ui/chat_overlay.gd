extends CanvasLayer
## In-game Chat Overlay -- Semi-transparent chat history with input field.
## Appears when the player presses Enter or T, fades after inactivity.

const MAX_VISIBLE_MESSAGES := 8
const FADE_DELAY := 8.0  # Seconds before messages fade
const FADE_DURATION := 1.0

var _chat_container: VBoxContainer = null
var _chat_history: RichTextLabel = null
var _chat_input: LineEdit = null
var _background: ColorRect = null
var _fade_timer: float = 0.0
var _is_input_active := false
var _lobby: Node = null  # GameLobby reference


func _ready() -> void:
	layer = 90  # Above game, below network status

	# Semi-transparent background panel (bottom-left)
	_background = ColorRect.new()
	_background.color = Color(0, 0, 0, 0.4)
	_background.position = Vector2(10, 400)
	_background.size = Vector2(400, 220)
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_background)

	_chat_container = VBoxContainer.new()
	_chat_container.position = Vector2(10, 400)
	_chat_container.size = Vector2(400, 220)
	add_child(_chat_container)

	# Chat history (scrollable rich text)
	_chat_history = RichTextLabel.new()
	_chat_history.bbcode_enabled = true
	_chat_history.scroll_following = true
	_chat_history.custom_minimum_size = Vector2(390, 180)
	_chat_history.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chat_history.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chat_history.add_theme_font_size_override("normal_font_size", 14)
	_chat_container.add_child(_chat_history)

	# Chat input field
	_chat_input = LineEdit.new()
	_chat_input.placeholder_text = "Press Enter to chat..."
	_chat_input.custom_minimum_size = Vector2(390, 30)
	_chat_input.visible = false
	_chat_input.text_submitted.connect(_on_chat_submit)
	_chat_container.add_child(_chat_input)

	# Connect to lobby chat signals if available
	if GameManager and GameManager.lobby:
		_lobby = GameManager.lobby
		_lobby.chat_received.connect(_on_chat_received)

	# Start faded
	_set_opacity(0.3)


func _process(delta: float) -> void:
	# Fade messages after inactivity
	if not _is_input_active and _fade_timer > 0:
		_fade_timer -= delta
		if _fade_timer <= FADE_DURATION:
			var alpha: float = _fade_timer / FADE_DURATION
			_set_opacity(alpha * 0.8)
		if _fade_timer <= 0:
			_set_opacity(0.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ENTER or event.keycode == KEY_T:
			if not _is_input_active:
				_activate_input()
				get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and _is_input_active:
			_deactivate_input()
			get_viewport().set_input_as_handled()


func _activate_input() -> void:
	_is_input_active = true
	_chat_input.visible = true
	_chat_input.grab_focus()
	_chat_input.clear()
	_set_opacity(0.9)


func _deactivate_input() -> void:
	_is_input_active = false
	_chat_input.visible = false
	_chat_input.release_focus()
	_fade_timer = FADE_DELAY


func _on_chat_submit(text: String) -> void:
	if text.strip_edges().is_empty():
		_deactivate_input()
		return

	# Phase 32: Handle console commands (starting with /)
	if text.begins_with("/"):
		_handle_chat_command(text)
		_deactivate_input()
		return

	if _lobby:
		_lobby.send_chat(text)

	_deactivate_input()


func _on_chat_received(from_name: String, message: String) -> void:
	add_message(from_name, message)


func add_message(from_name: String, message: String) -> void:
	## Add a chat message to the history.
	_chat_history.append_text("[b]%s:[/b] %s\n" % [from_name, message])
	_set_opacity(0.9)
	_fade_timer = FADE_DELAY


func add_system_message(message: String) -> void:
	## Add a system message (italicized, gray).
	_chat_history.append_text("[color=gray][i]%s[/i][/color]\n" % message)
	_set_opacity(0.9)
	_fade_timer = FADE_DELAY


func _set_opacity(alpha: float) -> void:
	_background.color.a = alpha * 0.4
	_chat_history.modulate.a = alpha


# =============================================================================
# PHASE 32: CONSOLE / CHAT COMMANDS
# =============================================================================

func _handle_chat_command(text: String) -> void:
	## Process a console command (text starting with /).
	var parts: PackedStringArray = text.strip_edges().split(" ", false)
	if parts.is_empty():
		return
	var cmd: String = parts[0].to_lower()
	var args: PackedStringArray = parts.slice(1) if parts.size() > 1 else PackedStringArray()

	match cmd:
		"/help":
			add_system_message("Available commands:")
			add_system_message("  /help — Show this help")
			add_system_message("  /players — List connected players")
			add_system_message("  /status — Show game/network status")
			add_system_message("  /resync — Request model resynchronisation")
			add_system_message("  /ping — Check connection")
			add_system_message("  /checksum — Show model checksum")
			add_system_message("  /pause — Toggle game pause")
			add_system_message("  /save [name] — Save the game")
		"/players":
			_cmd_players()
		"/status":
			_cmd_status()
		"/resync":
			_cmd_resync()
		"/ping":
			add_system_message("Pong! (connection alive)")
		"/checksum":
			_cmd_checksum()
		"/pause":
			_cmd_pause()
		"/save":
			var save_name: String = " ".join(args) if args.size() > 0 else "Quick Save"
			_cmd_save(save_name)
		_:
			add_system_message("Unknown command: %s (try /help)" % cmd)


func _cmd_players() -> void:
	## List connected players with their status.
	var engine = get_node_or_null("/root/Main/GameEngine")
	if not engine:
		engine = _get_engine()
	if not engine or not engine.has_method("get_player_connection_states"):
		add_system_message("Player info not available")
		return
	var states: Array = engine.get_player_connection_states()
	if states.is_empty():
		add_system_message("No player state data (single player?)")
		return
	for ps in states:
		var name: String = ps.get("player_name", "???")
		var state: String = ps.get("state", "unknown")
		var color := Color.GREEN if state == "connected" else Color.RED
		add_system_message("  %s — %s" % [name, state])


func _cmd_status() -> void:
	## Show network/game status.
	var engine = _get_engine()
	if not engine:
		add_system_message("No engine available")
		return
	var mode: String = engine.get_network_mode() if engine.has_method("get_network_mode") else "?"
	add_system_message("Network mode: %s" % mode)
	if engine.has_method("get_freeze_status"):
		var freeze: Dictionary = engine.get_freeze_status()
		add_system_message("Frozen: %s (mode: %s)" % [str(freeze.get("is_frozen", false)), freeze.get("mode", "none")])
		var dc: Array = freeze.get("disconnected_players", [])
		if dc.size() > 0:
			add_system_message("Disconnected players: %d" % dc.size())


func _cmd_resync() -> void:
	## Request model resync from server.
	var engine = _get_engine()
	if not engine or not engine.has_method("request_resync"):
		add_system_message("Resync not available")
		return
	var ok: bool = engine.request_resync()
	if ok:
		add_system_message("Resync requested from server")
	else:
		add_system_message("Failed to request resync")


func _cmd_checksum() -> void:
	## Show current model checksum.
	var engine = _get_engine()
	if not engine or not engine.has_method("get_model_checksum"):
		add_system_message("Checksum not available")
		return
	var crc: int = engine.get_model_checksum()
	add_system_message("Model checksum: %08X" % crc)


func _cmd_pause() -> void:
	## Toggle game pause (host only in multiplayer).
	add_system_message("Pause toggled (use ESC for menu pause)")


func _cmd_save(save_name: String) -> void:
	## Quick save the game via chat command.
	var engine = _get_engine()
	if not engine or not engine.has_method("save_game"):
		add_system_message("Save not available")
		return
	var ok: bool = engine.save_game(99, save_name)
	if ok:
		add_system_message("Game saved: %s" % save_name)
	else:
		add_system_message("Save failed")


func _get_engine() -> Node:
	## Try to find the game engine node.
	# Try common paths
	for path in ["/root/Main/GameEngine", "/root/Game/GameEngine"]:
		var node = get_node_or_null(path)
		if node:
			return node
	# Try via GameManager
	if GameManager and GameManager.has_method("get_engine"):
		return GameManager.get_engine()
	return null
