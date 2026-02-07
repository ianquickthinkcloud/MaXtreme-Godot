extends Control
## Multiplayer Lobby -- Player list, map selection, chat, ready/start.

@onready var title_label: Label = %TitleLabel
@onready var player_list: ItemList = %PlayerList
@onready var map_option: OptionButton = %MapOption
@onready var map_download_progress: ProgressBar = %MapDownloadProgress
@onready var chat_history: RichTextLabel = %ChatHistory
@onready var chat_input: LineEdit = %ChatInput
@onready var leave_button: Button = %LeaveButton
@onready var ready_button: Button = %ReadyButton
@onready var start_button: Button = %StartButton
@onready var status_label: Label = %StatusLabel

var _lobby: Node = null  # GameLobby instance from GameManager
var _is_host := false
var _is_ready := false
var _available_maps: Array = []
var _temp_engine: Node = null  # For loading map list


func _ready() -> void:
	leave_button.pressed.connect(_on_leave)
	ready_button.pressed.connect(_on_ready_toggle)
	start_button.pressed.connect(_on_start_game)
	chat_input.text_submitted.connect(_on_chat_submit)
	map_option.item_selected.connect(_on_map_selected)

	# Get lobby from GameManager
	_lobby = GameManager.lobby
	_is_host = (GameManager.lobby_role == "host")

	if _lobby == null:
		status_label.text = "ERROR: No lobby connection. Returning to menu."
		await get_tree().create_timer(2.0).timeout
		GameManager.go_to_main_menu()
		return

	# Connect lobby signals
	_lobby.player_list_changed.connect(_on_player_list_changed)
	_lobby.chat_received.connect(_on_chat_received)
	_lobby.map_changed.connect(_on_map_changed)
	_lobby.map_download_progress.connect(_on_map_download_progress)
	_lobby.game_starting.connect(_on_game_starting)
	_lobby.connection_failed.connect(_on_connection_lost)

	# Configure UI based on role
	if _is_host:
		title_label.text = "Multiplayer Lobby (Host)"
		start_button.visible = true
		start_button.disabled = true  # Until all ready
		ready_button.visible = false  # Host is always ready
		map_option.disabled = false
		_load_map_list()
	else:
		title_label.text = "Multiplayer Lobby"
		start_button.visible = false
		ready_button.visible = true
		map_option.disabled = true  # Only host can select map

	status_label.text = "Waiting for players..."
	_add_chat_system_message("Welcome to the lobby!")


func _process(_delta: float) -> void:
	if _lobby:
		_lobby.poll()


func _load_map_list() -> void:
	# Load available maps using a temporary engine
	_temp_engine = ClassDB.instantiate("GameEngine")
	if _temp_engine == null:
		return
	add_child(_temp_engine)
	_temp_engine.load_game_data()
	_available_maps = _temp_engine.get_available_maps()
	_temp_engine.queue_free()
	_temp_engine = null

	map_option.clear()
	for map_name in _available_maps:
		var display_name: String = map_name
		if display_name.ends_with(".wrl"):
			display_name = display_name.substr(0, display_name.length() - 4)
		map_option.add_item(display_name)

	# Auto-select first map
	if _available_maps.size() > 0:
		map_option.select(0)
		_on_map_selected(0)


func _on_map_selected(index: int) -> void:
	if not _is_host or not _lobby:
		return
	if index < 0 or index >= _available_maps.size():
		return
	var map_name: String = _available_maps[index]
	_lobby.select_map(map_name)
	_add_chat_system_message("Map changed to: %s" % map_name)


func _on_player_list_changed() -> void:
	if not _lobby:
		return
	var players: Array = _lobby.get_player_list()
	player_list.clear()
	var all_ready := true
	for p in players:
		var ready_str := " [Ready]" if p.get("ready", false) else ""
		var name: String = p.get("name", "???")
		var color: Color = p.get("color", Color.WHITE)
		player_list.add_item(name + ready_str)
		var idx: int = player_list.item_count - 1
		player_list.set_item_custom_fg_color(idx, color)
		if not p.get("ready", false):
			all_ready = false

	# Host: enable start only when all players are ready
	if _is_host:
		start_button.disabled = not all_ready or players.size() < 2


func _on_chat_received(from_name: String, message: String) -> void:
	_add_chat_message(from_name, message)


func _on_chat_submit(text: String) -> void:
	if text.strip_edges().is_empty():
		return
	if _lobby:
		_lobby.send_chat(text)
	chat_input.clear()
	chat_input.grab_focus()


func _on_map_changed(map_name: String) -> void:
	status_label.text = "Map: %s" % map_name
	# Try to find the map in the dropdown
	for i in range(map_option.item_count):
		if map_option.get_item_text(i) == map_name or _available_maps[i] == map_name if i < _available_maps.size() else false:
			map_option.select(i)
			break


func _on_map_download_progress(percent: float) -> void:
	map_download_progress.visible = true
	map_download_progress.value = percent
	status_label.text = "Downloading map: %d%%" % int(percent)
	if percent >= 100.0:
		map_download_progress.visible = false
		status_label.text = "Map download complete!"


func _on_ready_toggle() -> void:
	AudioManager.play_sound("click")
	if not _lobby:
		return
	_is_ready = not _is_ready
	_lobby.set_ready(_is_ready)
	ready_button.text = "NOT READY" if _is_ready else "READY"
	if _is_ready:
		ready_button.modulate = Color(0.5, 1.0, 0.5)
	else:
		ready_button.modulate = Color.WHITE


func _on_start_game() -> void:
	AudioManager.play_sound("click")
	if not _is_host or not _lobby:
		return
	status_label.text = "Starting game..."
	start_button.disabled = true
	_lobby.start_game()


func _on_game_starting() -> void:
	status_label.text = "Game starting!"
	_add_chat_system_message("Game is starting...")

	# Build the game config from lobby state
	var config := {
		"multiplayer": true,
		"lobby_role": GameManager.lobby_role,
	}
	GameManager.start_game(config)


func _on_connection_lost(reason: String) -> void:
	status_label.text = "Disconnected: %s" % reason
	_add_chat_system_message("Connection lost: %s" % reason)
	await get_tree().create_timer(3.0).timeout
	_on_leave()


func _on_leave() -> void:
	AudioManager.play_sound("click")
	if _lobby:
		_lobby.disconnect_lobby()
		_lobby.queue_free()
	GameManager.lobby = null
	GameManager.lobby_role = ""
	GameManager.go_to_main_menu()


# --- Chat helpers ---

func _add_chat_message(from_name: String, message: String) -> void:
	chat_history.append_text("[b]%s:[/b] %s\n" % [from_name, message])


func _add_chat_system_message(message: String) -> void:
	chat_history.append_text("[color=gray][i]%s[/i][/color]\n" % message)
