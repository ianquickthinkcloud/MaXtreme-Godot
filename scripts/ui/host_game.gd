extends Control
## Host Game Screen -- Configure and host a multiplayer game.

@onready var name_edit: LineEdit = %NameEdit
@onready var port_spinbox: SpinBox = %PortSpinBox
@onready var color_picker: ColorPickerButton = %ColorPicker
@onready var host_button: Button = %HostButton
@onready var back_button: Button = %BackButton
@onready var status_label: Label = %StatusLabel


func _ready() -> void:
	host_button.pressed.connect(_on_host)
	back_button.pressed.connect(_on_back)
	status_label.text = "Configure your game and press HOST GAME."


func _on_host() -> void:
	AudioManager.play_sound("click")

	var player_name: String = name_edit.text.strip_edges()
	if player_name.is_empty():
		status_label.text = "Please enter a player name."
		return

	var port: int = int(port_spinbox.value)
	var player_color: Color = color_picker.color

	status_label.text = "Starting server on port %d..." % port

	# Create the GameLobby and attempt to host
	var lobby = ClassDB.instantiate("GameLobby")
	if lobby == null:
		status_label.text = "ERROR: GameLobby class not available. Is the GDExtension loaded?"
		return

	add_child(lobby)

	var success: bool = lobby.host_game(port, player_name, player_color)
	if not success:
		status_label.text = "Failed to start server on port %d. Is the port already in use?" % port
		lobby.queue_free()
		return

	status_label.text = "Server started! Transitioning to lobby..."

	# Store lobby reference in GameManager and go to lobby
	GameManager.lobby = lobby
	GameManager.lobby_role = "host"
	# Reparent lobby to GameManager so it persists across scene changes
	lobby.reparent(GameManager)
	GameManager.go_to_lobby()


func _on_back() -> void:
	AudioManager.play_sound("click")
	GameManager.go_to_main_menu()
