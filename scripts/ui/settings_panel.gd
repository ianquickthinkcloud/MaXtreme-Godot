extends PanelContainer
## Settings Panel -- Reusable settings UI used in both main menu and pause menu.
## Phase 30: Enhanced with display settings, scroll speed, autosave, and credits.

@onready var fullscreen_check: CheckBox = %FullscreenCheck
@onready var vsync_check: CheckBox = %VsyncCheck
@onready var edge_scroll_check: CheckBox = %EdgeScrollCheck
@onready var master_vol_slider: HSlider = %MasterVolSlider
@onready var music_vol_slider: HSlider = %MusicVolSlider
@onready var sfx_vol_slider: HSlider = %SfxVolSlider
@onready var close_button: Button = $VBox/CloseButton

signal panel_closed

# Phase 30: Dynamic controls
var _scroll_speed_slider: HSlider = null
var _scroll_speed_label: Label = null
var _shadows_check: CheckBox = null
var _animations_check: CheckBox = null
var _effects_check: CheckBox = null
var _tracks_check: CheckBox = null
var _autosave_check: CheckBox = null
var _phase30_added := false


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

	# Phase 30: Add new controls
	_add_phase30_controls()


func _add_phase30_controls() -> void:
	if _phase30_added:
		return
	_phase30_added = true

	# Find the VBox to add controls to
	var vbox: VBoxContainer = $VBox
	if not vbox:
		return
	# Insert before the close button
	var close_idx: int = close_button.get_index() if close_button else vbox.get_child_count()

	# --- Camera section ---
	var cam_header := Label.new()
	cam_header.text = "Camera"
	cam_header.add_theme_font_size_override("font_size", 14)
	cam_header.add_theme_color_override("font_color", Color(0.3, 0.85, 1.0))
	vbox.add_child(cam_header)
	vbox.move_child(cam_header, close_idx)
	close_idx += 1

	# Scroll speed slider
	var speed_row := HBoxContainer.new()
	speed_row.add_theme_constant_override("separation", 8)
	var speed_lbl := Label.new()
	speed_lbl.text = "Scroll Speed:"
	speed_lbl.add_theme_font_size_override("font_size", 12)
	speed_lbl.custom_minimum_size.x = 100
	speed_row.add_child(speed_lbl)

	_scroll_speed_slider = HSlider.new()
	_scroll_speed_slider.min_value = 200
	_scroll_speed_slider.max_value = 1500
	_scroll_speed_slider.step = 50
	_scroll_speed_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	speed_row.add_child(_scroll_speed_slider)

	_scroll_speed_label = Label.new()
	_scroll_speed_label.text = "600"
	_scroll_speed_label.add_theme_font_size_override("font_size", 12)
	_scroll_speed_label.custom_minimum_size.x = 40
	speed_row.add_child(_scroll_speed_label)

	vbox.add_child(speed_row)
	vbox.move_child(speed_row, close_idx)
	close_idx += 1

	_scroll_speed_slider.value_changed.connect(func(val: float) -> void:
		_scroll_speed_label.text = str(int(val))
		GameManager.update_setting("camera_scroll_speed", int(val)))

	# --- Display section ---
	var disp_sep := HSeparator.new()
	vbox.add_child(disp_sep)
	vbox.move_child(disp_sep, close_idx)
	close_idx += 1

	var disp_header := Label.new()
	disp_header.text = "Display"
	disp_header.add_theme_font_size_override("font_size", 14)
	disp_header.add_theme_color_override("font_color", Color(0.3, 0.85, 1.0))
	vbox.add_child(disp_header)
	vbox.move_child(disp_header, close_idx)
	close_idx += 1

	_shadows_check = CheckBox.new()
	_shadows_check.text = "Shadows"
	_shadows_check.add_theme_font_size_override("font_size", 12)
	_shadows_check.toggled.connect(func(on: bool) -> void: GameManager.update_setting("display_shadows", on))
	vbox.add_child(_shadows_check)
	vbox.move_child(_shadows_check, close_idx)
	close_idx += 1

	_animations_check = CheckBox.new()
	_animations_check.text = "Animations"
	_animations_check.add_theme_font_size_override("font_size", 12)
	_animations_check.toggled.connect(func(on: bool) -> void: GameManager.update_setting("display_animations", on))
	vbox.add_child(_animations_check)
	vbox.move_child(_animations_check, close_idx)
	close_idx += 1

	_effects_check = CheckBox.new()
	_effects_check.text = "Building Effects"
	_effects_check.add_theme_font_size_override("font_size", 12)
	_effects_check.toggled.connect(func(on: bool) -> void: GameManager.update_setting("display_effects", on))
	vbox.add_child(_effects_check)
	vbox.move_child(_effects_check, close_idx)
	close_idx += 1

	_tracks_check = CheckBox.new()
	_tracks_check.text = "Vehicle Tracks"
	_tracks_check.add_theme_font_size_override("font_size", 12)
	_tracks_check.toggled.connect(func(on: bool) -> void: GameManager.update_setting("display_tracks", on))
	vbox.add_child(_tracks_check)
	vbox.move_child(_tracks_check, close_idx)
	close_idx += 1

	# --- Gameplay section ---
	var game_sep := HSeparator.new()
	vbox.add_child(game_sep)
	vbox.move_child(game_sep, close_idx)
	close_idx += 1

	var game_header := Label.new()
	game_header.text = "Gameplay"
	game_header.add_theme_font_size_override("font_size", 14)
	game_header.add_theme_color_override("font_color", Color(0.3, 0.85, 1.0))
	vbox.add_child(game_header)
	vbox.move_child(game_header, close_idx)
	close_idx += 1

	_autosave_check = CheckBox.new()
	_autosave_check.text = "Autosave at Turn Start"
	_autosave_check.add_theme_font_size_override("font_size", 12)
	_autosave_check.toggled.connect(func(on: bool) -> void: GameManager.update_setting("autosave_enabled", on))
	vbox.add_child(_autosave_check)
	vbox.move_child(_autosave_check, close_idx)
	close_idx += 1


func _refresh_from_settings() -> void:
	var s: Dictionary = GameManager.settings
	fullscreen_check.button_pressed = s.get("display_fullscreen", false)
	vsync_check.button_pressed = s.get("display_vsync", true)
	edge_scroll_check.button_pressed = s.get("camera_edge_scroll", true)
	master_vol_slider.value = s.get("audio_master", 80)
	music_vol_slider.value = s.get("audio_music", 60)
	sfx_vol_slider.value = s.get("audio_sfx", 80)

	# Phase 30 controls
	if _scroll_speed_slider:
		_scroll_speed_slider.value = s.get("camera_scroll_speed", 600)
		if _scroll_speed_label:
			_scroll_speed_label.text = str(int(_scroll_speed_slider.value))
	if _shadows_check:
		_shadows_check.button_pressed = s.get("display_shadows", true)
	if _animations_check:
		_animations_check.button_pressed = s.get("display_animations", true)
	if _effects_check:
		_effects_check.button_pressed = s.get("display_effects", true)
	if _tracks_check:
		_tracks_check.button_pressed = s.get("display_tracks", true)
	if _autosave_check:
		_autosave_check.button_pressed = s.get("autosave_enabled", true)


func open() -> void:
	_refresh_from_settings()
	visible = true


func _on_close() -> void:
	visible = false
	panel_closed.emit()
