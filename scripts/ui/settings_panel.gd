extends PanelContainer
## Settings Panel -- Reusable settings UI used in both main menu and pause menu.

@onready var fullscreen_check: CheckBox = %FullscreenCheck
@onready var vsync_check: CheckBox = %VsyncCheck
@onready var edge_scroll_check: CheckBox = %EdgeScrollCheck
@onready var master_vol_slider: HSlider = %MasterVolSlider
@onready var music_vol_slider: HSlider = %MusicVolSlider
@onready var sfx_vol_slider: HSlider = %SfxVolSlider
@onready var close_button: Button = $VBox/CloseButton

signal panel_closed


func _ready() -> void:
	# Load current settings into controls
	_refresh_from_settings()

	# Connect controls
	fullscreen_check.toggled.connect(func(on: bool) -> void: GameManager.update_setting("display_fullscreen", on))
	vsync_check.toggled.connect(func(on: bool) -> void: GameManager.update_setting("display_vsync", on))
	edge_scroll_check.toggled.connect(func(on: bool) -> void: GameManager.update_setting("camera_edge_scroll", on))
	master_vol_slider.value_changed.connect(func(val: float) -> void: GameManager.update_setting("audio_master", int(val)))
	music_vol_slider.value_changed.connect(func(val: float) -> void: GameManager.update_setting("audio_music", int(val)))
	sfx_vol_slider.value_changed.connect(func(val: float) -> void: GameManager.update_setting("audio_sfx", int(val)))
	close_button.pressed.connect(_on_close)


func _refresh_from_settings() -> void:
	var s: Dictionary = GameManager.settings
	fullscreen_check.button_pressed = s.get("display_fullscreen", false)
	vsync_check.button_pressed = s.get("display_vsync", true)
	edge_scroll_check.button_pressed = s.get("camera_edge_scroll", true)
	master_vol_slider.value = s.get("audio_master", 80)
	music_vol_slider.value = s.get("audio_music", 60)
	sfx_vol_slider.value = s.get("audio_sfx", 80)


func open() -> void:
	_refresh_from_settings()
	visible = true


func _on_close() -> void:
	visible = false
	panel_closed.emit()
