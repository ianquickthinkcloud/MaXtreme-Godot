extends Control
## Multiplayer Lobby -- Player list, map selection, chat, ready/start.
## Enhanced in Phase 32 with clan selection, kick, map checksum, save/load.

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

# Phase 32: Additional UI elements (created dynamically)
var _clan_option: OptionButton = null
var _kick_button: Button = null
var _checksum_label: Label = null
var _load_save_button: Button = null
var _save_list_dialog: Window = null


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

	# Phase 32: Add enhanced UI elements
	_add_clan_selector()
	_add_host_controls()
	_add_checksum_label()


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
	## Phase 32 enhanced: Show player colors, ready indicators, defeated status.
	if not _lobby:
		return
	var players: Array = _lobby.get_player_list()
	player_list.clear()
	var all_ready := true
	var ready_count := 0
	var total_count := players.size()
	for p in players:
		var is_ready: bool = p.get("ready", false)
		var is_defeated: bool = p.get("defeated", false)
		var name: String = p.get("name", "???")
		var color: Color = p.get("color", Color.WHITE)
		var player_id: int = p.get("id", -1)

		# Build display string with status indicators
		var status_parts: PackedStringArray = PackedStringArray()
		if is_ready:
			status_parts.append("READY")
			ready_count += 1
		if is_defeated:
			status_parts.append("DEFEATED")
		var status_str := " [%s]" % ", ".join(status_parts) if status_parts.size() > 0 else ""

		# Show player ID for host kick reference
		var id_prefix := "#%d " % player_id if _is_host else ""
		player_list.add_item(id_prefix + name + status_str)
		var idx: int = player_list.item_count - 1

		# Color coding: green if ready, grey if defeated, player color otherwise
		if is_defeated:
			player_list.set_item_custom_fg_color(idx, Color(0.5, 0.5, 0.5))
		elif is_ready:
			player_list.set_item_custom_fg_color(idx, Color(0.4, 1.0, 0.5))
		else:
			player_list.set_item_custom_fg_color(idx, color)
			all_ready = false

	# Update status label with ready count
	status_label.text = "%d/%d players ready" % [ready_count, total_count]

	# Host: enable start only when all players are ready
	if _is_host:
		start_button.disabled = not all_ready or players.size() < 2
		if _kick_button:
			_kick_button.disabled = players.size() <= 1


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
		if map_option.get_item_text(i) == map_name or (_available_maps[i] == map_name if i < _available_maps.size() else false):
			map_option.select(i)
			break

	# Phase 32: Update checksum label
	if _checksum_label and _lobby:
		var crc: int = _lobby.get_map_checksum()
		if crc != 0:
			_checksum_label.text = "CRC: %08X" % crc
		else:
			_checksum_label.text = "CRC: --"


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


# =============================================================================
# PHASE 32: MULTIPLAYER ENHANCEMENTS
# =============================================================================

func _add_clan_selector() -> void:
	## 32.1: Add clan/team selection dropdown.
	if not _lobby:
		return

	# Get available clans from lobby
	var clans: Array = _lobby.get_available_clans()
	if clans.is_empty():
		return

	# Create a container for the clan selector
	var hbox := HBoxContainer.new()
	hbox.name = "ClanSelector"
	var clan_label := Label.new()
	clan_label.text = "Clan:"
	clan_label.add_theme_font_size_override("font_size", 14)
	hbox.add_child(clan_label)

	_clan_option = OptionButton.new()
	_clan_option.custom_minimum_size = Vector2(200, 30)
	_clan_option.add_item("No Clan", -1)
	for clan in clans:
		_clan_option.add_item(clan["name"], clan["id"])
		# Set tooltip with description
		var idx: int = _clan_option.item_count - 1
		_clan_option.set_item_tooltip(idx, clan["description"])
	_clan_option.selected = 0
	_clan_option.item_selected.connect(_on_clan_selected)
	hbox.add_child(_clan_option)

	# Insert above the chat area (after map option's parent)
	var parent := map_option.get_parent()
	if parent:
		parent.add_child(hbox)
		parent.move_child(hbox, map_option.get_index() + 1)


func _on_clan_selected(index: int) -> void:
	if not _lobby:
		return
	var clan_id: int = _clan_option.get_item_id(index)
	_lobby.set_clan(clan_id)
	var clan_name: String = _clan_option.get_item_text(index)
	_add_chat_system_message("Selected clan: %s" % clan_name)


func _add_host_controls() -> void:
	## 32.6: Add kick button for host.
	if not _is_host:
		return

	_kick_button = Button.new()
	_kick_button.text = "KICK"
	_kick_button.custom_minimum_size = Vector2(80, 32)
	_kick_button.add_theme_font_size_override("font_size", 12)
	_kick_button.tooltip_text = "Kick selected player"
	_kick_button.disabled = true
	_kick_button.pressed.connect(_on_kick_player)

	# Insert next to the start button
	var parent := start_button.get_parent()
	if parent:
		parent.add_child(_kick_button)
		parent.move_child(_kick_button, start_button.get_index())

	# 32.10: Load saved multiplayer game button
	_load_save_button = Button.new()
	_load_save_button.text = "LOAD SAVE"
	_load_save_button.custom_minimum_size = Vector2(100, 32)
	_load_save_button.add_theme_font_size_override("font_size", 12)
	_load_save_button.tooltip_text = "Load a saved multiplayer game"
	_load_save_button.pressed.connect(_on_load_save)
	if parent:
		parent.add_child(_load_save_button)
		parent.move_child(_load_save_button, start_button.get_index())


func _on_kick_player() -> void:
	## 32.6: Kick the selected player from the lobby.
	if not _is_host or not _lobby:
		return
	var selected_items: PackedInt32Array = player_list.get_selected_items()
	if selected_items.is_empty():
		_add_chat_system_message("Select a player to kick")
		return
	var players: Array = _lobby.get_player_list()
	var idx: int = selected_items[0]
	if idx >= 0 and idx < players.size():
		var target: Dictionary = players[idx]
		var target_id: int = target.get("id", -1)
		var target_name: String = target.get("name", "???")
		_lobby.kick_player_connection(target_id)
		_add_chat_system_message("Kicked player: %s" % target_name)


func _on_load_save() -> void:
	## 32.10: Show saved multiplayer games dialog.
	if not _is_host or not _lobby:
		return
	_add_chat_system_message("Multiplayer save/load: feature requires save game files.")


func _add_checksum_label() -> void:
	## 32.4: Add map checksum display.
	_checksum_label = Label.new()
	_checksum_label.text = "CRC: --"
	_checksum_label.add_theme_font_size_override("font_size", 11)
	_checksum_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_checksum_label.tooltip_text = "Map checksum for validation"

	# Place near the map option
	var parent := map_option.get_parent()
	if parent:
		parent.add_child(_checksum_label)
		parent.move_child(_checksum_label, map_option.get_index() + 1)
