extends Control
## Join Game Screen -- Connect to a hosted multiplayer game.

@onready var name_edit: LineEdit = %NameEdit
@onready var host_edit: LineEdit = %HostEdit
@onready var port_spinbox: SpinBox = %PortSpinBox
@onready var color_picker: ColorPickerButton = %ColorPicker
@onready var connect_button: Button = %ConnectButton
@onready var back_button: Button = %BackButton
@onready var status_label: Label = %StatusLabel

var _lobby: Node = null
var _connecting := false


func _ready() -> void:
	connect_button.pressed.connect(_on_connect)
	back_button.pressed.connect(_on_back)
	status_label.text = "Enter the host IP and press CONNECT."


func _on_connect() -> void:
	AudioManager.play_sound("click")

	if _connecting:
		return

	var player_name: String = name_edit.text.strip_edges()
	if player_name.is_empty():
		status_label.text = "Please enter a player name."
		return

	var host_ip: String = host_edit.text.strip_edges()
	if host_ip.is_empty():
		status_label.text = "Please enter a host IP address."
		return

	var port: int = int(port_spinbox.value)
	var player_color: Color = color_picker.color

	status_label.text = "Connecting to %s:%d..." % [host_ip, port]
	_connecting = true
	connect_button.disabled = true

	# Create the GameLobby and attempt to join
	_lobby = ClassDB.instantiate("GameLobby")
	if _lobby == null:
		status_label.text = "ERROR: GameLobby class not available. Is the GDExtension loaded?"
		_connecting = false
		connect_button.disabled = false
		return

	add_child(_lobby)

	# Connect signals for connection result
	_lobby.connection_established.connect(_on_connected)
	_lobby.connection_failed.connect(_on_connection_failed)

	var success: bool = _lobby.join_game(host_ip, port, player_name, player_color)
	if not success:
		status_label.text = "Failed to initiate connection."
		_lobby.queue_free()
		_lobby = null
		_connecting = false
		connect_button.disabled = false
		return


func _on_connected() -> void:
	status_label.text = "Connected! Transitioning to lobby..."
	_connecting = false

	# Store lobby reference in GameManager and go to lobby
	GameManager.lobby = _lobby
	GameManager.lobby_role = "client"
	# Reparent lobby to GameManager
	_lobby.reparent(GameManager)
	_lobby = null
	GameManager.go_to_lobby()


func _on_connection_failed(reason: String) -> void:
	status_label.text = "Connection failed: %s" % reason
	_connecting = false
	connect_button.disabled = false
	if _lobby:
		_lobby.queue_free()
		_lobby = null


func _on_back() -> void:
	AudioManager.play_sound("click")
	if _lobby:
		_lobby.disconnect_lobby()
		_lobby.queue_free()
		_lobby = null
	GameManager.go_to_main_menu()
