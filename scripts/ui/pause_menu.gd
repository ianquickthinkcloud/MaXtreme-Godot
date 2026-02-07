extends CanvasLayer
## Pause Menu -- Shown when ESC is pressed during gameplay.
## Pauses game processing, allows Resume, Settings, and Quit to Menu.

@onready var panel: PanelContainer = $Panel
@onready var resume_button: Button = $Panel/VBox/ResumeButton
@onready var settings_button: Button = $Panel/VBox/SettingsButton
@onready var quit_button: Button = $Panel/VBox/QuitButton
@onready var settings_panel: PanelContainer = $SettingsOverlay

signal resumed
signal quit_to_menu

var is_open := false


func _ready() -> void:
	resume_button.pressed.connect(_on_resume)
	settings_button.pressed.connect(_on_settings)
	quit_button.pressed.connect(_on_quit)

	if settings_panel:
		settings_panel.visible = false
		if settings_panel.has_signal("panel_closed"):
			settings_panel.panel_closed.connect(func() -> void: settings_panel.visible = false)

	visible = false
	is_open = false
	layer = 100  # On top of everything


func open() -> void:
	visible = true
	is_open = true
	if settings_panel:
		settings_panel.visible = false


func close() -> void:
	visible = false
	is_open = false
	if settings_panel:
		settings_panel.visible = false


func _on_resume() -> void:
	AudioManager.play_sound("click")
	close()
	resumed.emit()


func _on_settings() -> void:
	AudioManager.play_sound("click")
	if settings_panel:
		settings_panel.visible = not settings_panel.visible


func _on_quit() -> void:
	AudioManager.play_sound("click")
	close()
	quit_to_menu.emit()
