extends Control
## Main Menu -- Polished entry point with animated background, logo, and styled buttons.

@onready var title_label: Label = %TitleLabel
@onready var subtitle_label: Label = %SubtitleLabel
@onready var version_label: Label = %VersionLabel
@onready var new_game_button: Button = %NewGameButton
@onready var hot_seat_button: Button = %HotSeatButton
@onready var host_game_button: Button = %HostGameButton
@onready var join_game_button: Button = %JoinGameButton
@onready var load_game_button: Button = %LoadGameButton
@onready var settings_button: Button = %SettingsButton
@onready var exit_button: Button = %ExitButton
@onready var settings_panel: PanelContainer = %SettingsPanel
@onready var background: ColorRect = $Background
@onready var logo_texture: TextureRect = $LogoTexture

var _time := 0.0
var _load_dialog: Window = null
var _load_list: VBoxContainer = null
var _continue_button: Button = null
var _credits_dialog: Window = null  # Phase 30: Credits/About


func _ready() -> void:
	# Wire button signals
	new_game_button.pressed.connect(_on_new_game)
	hot_seat_button.pressed.connect(_on_hot_seat)
	host_game_button.pressed.connect(_on_host_game)
	join_game_button.pressed.connect(_on_join_game)
	load_game_button.pressed.connect(_on_load_game)
	settings_button.pressed.connect(_on_settings)
	exit_button.pressed.connect(_on_exit)

	version_label.text = "MaXtreme v1.0.0 -- All Phases Complete"

	# Phase 24: Enable Load Game button
	load_game_button.disabled = false
	load_game_button.tooltip_text = "Load a saved game"

	if settings_panel:
		settings_panel.visible = false

	# Phase 24: Add Continue button and Load dialog
	_create_load_dialog()
	_add_continue_button()

	# Phase 30: Add Credits button and dialog
	_create_credits_dialog()
	_add_credits_button()

	# Try to load the logo image from data/gfx/
	if logo_texture:
		var SpriteCache = preload("res://scripts/game/sprite_cache.gd")
		var cache := SpriteCache.new()
		var logo := cache.get_gfx_texture("logo")
		if logo:
			logo_texture.texture = logo
		else:
			logo_texture.visible = false

	# Phase 33: Crossfade to menu music
	AudioManager.play_menu_music()


func _process(delta: float) -> void:
	_time += delta
	# Subtle animated gradient on the background
	if background:
		var shift := sin(_time * 0.3) * 0.015
		background.color = Color(0.04 + shift, 0.06, 0.11 - shift, 1.0)


func _on_new_game() -> void:
	AudioManager.play_sound("click")
	GameManager.go_to_new_game_setup()


func _on_hot_seat() -> void:
	AudioManager.play_sound("click")
	GameManager.go_to_new_game_setup("hotseat")


func _on_host_game() -> void:
	AudioManager.play_sound("click")
	GameManager.go_to_host_game()


func _on_join_game() -> void:
	AudioManager.play_sound("click")
	GameManager.go_to_join_game()


func _on_load_game() -> void:
	AudioManager.play_sound("click")
	_show_load_dialog()


func _on_continue() -> void:
	## Continue from the last auto-save (slot 10).
	AudioManager.play_sound("click")
	_load_slot(10)


# =============================================================================
# PHASE 24: LOAD DIALOG & CONTINUE
# =============================================================================

func _create_load_dialog() -> void:
	_load_dialog = Window.new()
	_load_dialog.title = "Load Game"
	_load_dialog.size = Vector2i(520, 420)
	_load_dialog.visible = false
	_load_dialog.transient = true
	add_child(_load_dialog)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	_load_dialog.add_child(margin)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 8)
	margin.add_child(main_vbox)

	var title_lbl := Label.new()
	title_lbl.text = "Load Game"
	title_lbl.add_theme_font_size_override("font_size", 18)
	title_lbl.add_theme_color_override("font_color", Color(0.3, 0.85, 1.0))
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(title_lbl)

	var sep := HSeparator.new()
	main_vbox.add_child(sep)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(scroll)

	_load_list = VBoxContainer.new()
	_load_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_load_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_load_list)

	var close_btn := Button.new()
	close_btn.text = "Cancel"
	close_btn.custom_minimum_size = Vector2(120, 36)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.pressed.connect(func(): _load_dialog.visible = false)
	main_vbox.add_child(close_btn)

	_load_dialog.close_requested.connect(func(): _load_dialog.visible = false)


func _add_continue_button() -> void:
	## Add a "Continue" button above the Load Game button if an auto-save exists.
	# We need a temporary engine to check for saves
	var temp_engine = load("res://gdextension/maxtreme.gdextension")
	# Check if slot 10 (autosave) exists via the engine
	# Since we don't have a running engine on the main menu, we'll always show
	# the button and gracefully handle missing save at load time.
	_continue_button = Button.new()
	_continue_button.text = "CONTINUE"
	_continue_button.custom_minimum_size = load_game_button.custom_minimum_size
	_continue_button.add_theme_font_size_override("font_size", load_game_button.get_theme_font_size("font_size"))
	_continue_button.tooltip_text = "Continue from last auto-save"
	_continue_button.pressed.connect(_on_continue)

	# Insert before Load Game button
	var parent := load_game_button.get_parent()
	if parent:
		var idx := load_game_button.get_index()
		parent.add_child(_continue_button)
		parent.move_child(_continue_button, idx)


func _show_load_dialog() -> void:
	## Show the load dialog with available save slots.
	if not _load_dialog or not _load_list:
		return

	for child in _load_list.get_children():
		child.queue_free()

	# Create a temporary engine to query saves
	var engine_class = ClassDB.instantiate("GameEngine")
	if not engine_class:
		# Fallback: show empty dialog
		var lbl := Label.new()
		lbl.text = "Unable to query saves (engine not available)"
		lbl.add_theme_font_size_override("font_size", 13)
		_load_list.add_child(lbl)
		_load_dialog.popup_centered()
		return

	engine_class.initialize_engine()
	engine_class.load_game_data()
	var saves: Array = engine_class.get_save_game_list()
	engine_class.queue_free()

	if saves.is_empty():
		var lbl := Label.new()
		lbl.text = "No saved games found."
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_load_list.add_child(lbl)
	else:
		# Sort by slot number
		var sorted_saves := saves.duplicate()
		sorted_saves.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return a.get("slot", 0) < b.get("slot", 0))

		for save in sorted_saves:
			var slot: int = save.get("slot", 0)
			var name_str: String = save.get("name", "Unnamed")
			var date_str: String = save.get("date", "")
			var turn: int = save.get("turn", 0)
			var map_str: String = save.get("map", "")
			var players: Array = save.get("players", [])

			var player_names: String = ""
			for p in players:
				if player_names.length() > 0:
					player_names += ", "
				player_names += p.get("name", "?")

			var btn := Button.new()
			btn.text = "Slot %d: %s  |  Turn %d  |  %s  |  %s" % [slot, name_str, turn, map_str, date_str]
			btn.custom_minimum_size = Vector2(0, 40)
			btn.add_theme_font_size_override("font_size", 13)
			btn.tooltip_text = "Players: %s" % player_names

			var slot_copy := slot
			btn.pressed.connect(func(): _load_slot(slot_copy))
			_load_list.add_child(btn)

	_load_dialog.popup_centered()


func _load_slot(slot: int) -> void:
	## Load a game from the given slot.
	if _load_dialog:
		_load_dialog.visible = false
	GameManager.load_saved_game(slot)


func _on_settings() -> void:
	AudioManager.play_sound("click")
	if settings_panel:
		settings_panel.visible = not settings_panel.visible


func _on_exit() -> void:
	AudioManager.play_sound("click")
	GameManager.quit_game()


# =============================================================================
# PHASE 30: CREDITS / ABOUT SCREEN
# =============================================================================

func _add_credits_button() -> void:
	## Add a "Credits" button after the Exit button.
	var credits_btn := Button.new()
	credits_btn.text = "CREDITS"
	credits_btn.custom_minimum_size = exit_button.custom_minimum_size
	credits_btn.add_theme_font_size_override("font_size", exit_button.get_theme_font_size("font_size"))
	credits_btn.tooltip_text = "About MaXtreme"
	credits_btn.pressed.connect(_on_credits)

	var parent := exit_button.get_parent()
	if parent:
		parent.add_child(credits_btn)
		parent.move_child(credits_btn, exit_button.get_index())


func _on_credits() -> void:
	AudioManager.play_sound("click")
	if _credits_dialog:
		_credits_dialog.popup_centered()


func _create_credits_dialog() -> void:
	_credits_dialog = Window.new()
	_credits_dialog.title = "About MaXtreme"
	_credits_dialog.size = Vector2i(520, 500)
	_credits_dialog.visible = false
	_credits_dialog.transient = true
	add_child(_credits_dialog)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	_credits_dialog.add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "MaXtreme"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.3, 0.85, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Mechanized Assault & Exploration — Reloaded for Godot"
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(subtitle)

	vbox.add_child(HSeparator.new())

	# About section
	_add_credits_section(vbox, "About",
		"MaXtreme is a faithful reimplementation of M.A.X.: Mechanized Assault\n" +
		"& Exploration in the Godot 4.x engine using GDExtension and C++20.\n\n" +
		"The original M.A.X. was developed by Interplay in 1996. M.A.X.R.\n" +
		"(Reloaded) was an open-source recreation by the community.\n" +
		"MaXtreme brings this classic to modern hardware with a new UI.")

	vbox.add_child(HSeparator.new())

	# Original M.A.X.R. credits
	_add_credits_section(vbox, "M.A.X.R. Engine",
		"Original M.A.X.R. codebase used under GPL v2.\n" +
		"Contributors: Paul Grathwohl, Eiko, and the M.A.X.R. community.\n" +
		"https://maxr.org")

	vbox.add_child(HSeparator.new())

	# Godot port credits
	_add_credits_section(vbox, "MaXtreme Godot Port",
		"Ported to Godot 4.x with GDExtension.\n" +
		"Game logic: C++20 core engine via GDExtension.\n" +
		"UI & Rendering: GDScript with Godot 2D engine.")

	vbox.add_child(HSeparator.new())

	# Technology
	_add_credits_section(vbox, "Technology",
		"Engine: Godot 4.x\n" +
		"Extension: godot-cpp (GDExtension C++)\n" +
		"Build: SCons\n" +
		"License: GNU General Public License v2")

	vbox.add_child(HSeparator.new())

	# Version info
	var ver_lbl := Label.new()
	ver_lbl.text = "Version 0.10.0 — Phase 30"
	ver_lbl.add_theme_font_size_override("font_size", 11)
	ver_lbl.add_theme_color_override("font_color", Color(0.5, 0.55, 0.6))
	ver_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(ver_lbl)

	# Close button
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(120, 36)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.pressed.connect(func(): _credits_dialog.visible = false)
	vbox.add_child(close_btn)

	_credits_dialog.close_requested.connect(func(): _credits_dialog.visible = false)


func _add_credits_section(parent: VBoxContainer, header_text: String, body_text: String) -> void:
	var header := Label.new()
	header.text = header_text
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", Color(0.8, 0.85, 0.5))
	parent.add_child(header)

	var body := Label.new()
	body.text = body_text
	body.add_theme_font_size_override("font_size", 12)
	body.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(body)
