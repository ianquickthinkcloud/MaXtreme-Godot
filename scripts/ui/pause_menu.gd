extends CanvasLayer
## Pause Menu -- Shown when ESC is pressed during gameplay.
## Pauses game processing, allows Resume, Save, Load, Settings, and Quit to Menu.

@onready var panel: PanelContainer = $Panel
@onready var resume_button: Button = $Panel/VBox/ResumeButton
@onready var settings_button: Button = $Panel/VBox/SettingsButton
@onready var quit_button: Button = $Panel/VBox/QuitButton
@onready var settings_panel: PanelContainer = $SettingsOverlay

signal resumed
signal quit_to_menu
signal save_requested
signal load_requested

var is_open := false


func _ready() -> void:
	resume_button.pressed.connect(_on_resume)
	settings_button.pressed.connect(_on_settings)
	quit_button.pressed.connect(_on_quit)

	if settings_panel:
		settings_panel.visible = false
		if settings_panel.has_signal("panel_closed"):
			settings_panel.panel_closed.connect(func() -> void: settings_panel.visible = false)

	# Phase 24: Add Save & Load buttons dynamically
	var vbox: VBoxContainer = $Panel/VBox
	if vbox:
		var save_btn := Button.new()
		save_btn.text = "Save Game"
		save_btn.custom_minimum_size = Vector2(220, 48)
		save_btn.add_theme_font_size_override("font_size", 16)
		save_btn.pressed.connect(_on_save)
		vbox.add_child(save_btn)
		vbox.move_child(save_btn, 1)  # After Resume

		var load_btn := Button.new()
		load_btn.text = "Load Game"
		load_btn.custom_minimum_size = Vector2(220, 48)
		load_btn.add_theme_font_size_override("font_size", 16)
		load_btn.pressed.connect(_on_load)
		vbox.add_child(load_btn)
		vbox.move_child(load_btn, 2)  # After Save

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


func _on_save() -> void:
	AudioManager.play_sound("click")
	save_requested.emit()


func _on_load() -> void:
	AudioManager.play_sound("click")
	load_requested.emit()


func _on_settings() -> void:
	AudioManager.play_sound("click")
	if settings_panel:
		settings_panel.visible = not settings_panel.visible


func _on_quit() -> void:
	AudioManager.play_sound("click")
	close()
	quit_to_menu.emit()
