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
