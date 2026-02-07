extends CanvasLayer
## Game Over Screen -- Shows victory or defeat result.

@onready var result_label: Label = $Panel/VBox/ResultLabel
@onready var details_label: Label = $Panel/VBox/DetailsLabel
@onready var menu_button: Button = $Panel/VBox/MenuButton
@onready var continue_button: Button = $Panel/VBox/ContinueButton

signal return_to_menu
signal continue_playing

var is_showing := false


func _ready() -> void:
	menu_button.pressed.connect(func() -> void: return_to_menu.emit())
	continue_button.pressed.connect(func() -> void:
		is_showing = false
		visible = false
		continue_playing.emit()
	)
	visible = false
	is_showing = false
	layer = 90  # Below pause menu, above game


func show_victory(player_name: String, details: String = "") -> void:
	result_label.text = "VICTORY!"
	result_label.modulate = Color(1.0, 0.85, 0.0)
	details_label.text = "%s has won the game!" % player_name
	if details != "":
		details_label.text += "\n" + details
	visible = true
	is_showing = true


func show_defeat(player_name: String, details: String = "") -> void:
	result_label.text = "DEFEAT"
	result_label.modulate = Color(1.0, 0.2, 0.2)
	details_label.text = "%s has been eliminated." % player_name
	if details != "":
		details_label.text += "\n" + details
	visible = true
	is_showing = true
