extends CanvasLayer
## GameHUD -- Polished heads-up display with resource bar, unit info panel,
## minimap, and game controls.
##
## Layout:
##   Top: Resource bar (metal/oil/gold/energy/credits) + turn/player info
##   Bottom-left: Selected unit panel with icon, stats, and command buttons
##   Bottom-right: Minimap
##   Bottom-center: End turn button + tile info

signal end_turn_pressed
signal build_pressed
signal command_pressed(command: String)  ## Generic command button signal
signal research_allocation_changed(areas: Array)  ## Phase 21: Player changed research allocation
signal gold_upgrade_requested(id_first: int, id_second: int, stat_index: int)  ## Phase 21: Gold upgrade purchase
signal mining_distribution_changed(unit_id: int, metal: int, oil: int, gold: int)  ## Phase 22: Mining reallocation
signal jump_to_position(pos: Vector2i)  ## Phase 23: Camera jump from event log
signal save_game_requested(slot: int, save_name: String)  ## Phase 24: Save
signal load_game_requested(slot: int)  ## Phase 24: Load
signal stat_overlay_changed(overlay_name: String)  ## Phase 25: Overlay toggle
signal grid_overlay_toggled(enabled: bool)  ## Phase 25: Grid toggle
signal fog_overlay_toggled(enabled: bool)  ## Phase 25: Fog toggle
signal minimap_zoom_toggled()  ## Phase 25: Minimap zoom
signal minimap_filter_toggled()  ## Phase 25: Minimap attack-only filter
signal connector_overlay_toggled(enabled: bool)  ## Phase 26: Base network overlay

# References set by code
var _sprite_cache = null

# --- Top bar elements ---
@onready var turn_label: Label = $TopBar/TurnLabel
@onready var player_label: Label = $TopBar/PlayerLabel
@onready var status_label: Label = $TopBar/StatusLabel

# --- Resource bar elements ---
@onready var metal_label: Label = $ResourceBar/MetalLabel
@onready var oil_label: Label = $ResourceBar/OilLabel
@onready var gold_label: Label = $ResourceBar/GoldLabel
@onready var energy_label: Label = $ResourceBar/EnergyLabel
@onready var credits_label: Label = $ResourceBar/CreditsLabel

# --- Unit panel elements ---
@onready var unit_panel: PanelContainer = $UnitPanel
@onready var unit_icon: TextureRect = $UnitPanel/VBox/IconRow/UnitIcon
@onready var unit_name: Label = $UnitPanel/VBox/IconRow/UnitNameVBox/UnitName
@onready var unit_id_label: Label = $UnitPanel/VBox/IconRow/UnitNameVBox/UnitIDLabel
@onready var unit_stats: Label = $UnitPanel/VBox/UnitStats
@onready var unit_combat: Label = $UnitPanel/VBox/UnitCombat
@onready var unit_pos: Label = $UnitPanel/VBox/UnitPos
@onready var unit_extra: Label = $UnitPanel/VBox/UnitExtra
@onready var build_button: Button = $UnitPanel/VBox/BuildButton

# --- Bottom bar ---
@onready var end_turn_button: Button = $BottomBar/EndTurnButton
@onready var tile_label: Label = $BottomBar/TileLabel

# --- Minimap container ---
@onready var minimap_container: Control = $MinimapContainer

# --- Phase 20: Additional HUD elements (created programmatically) ---
var _humans_label: Label = null
var _score_label: Label = null
var _timer_label: Label = null
var _unit_status_label: Label = null  # Experience/dated line in unit panel

# --- Unit info popup ---
var _unit_info_popup: Window = null
var _unit_info_content: RichTextLabel = null

# --- Command buttons (created programmatically) ---
var _cmd_grid_1: HBoxContainer = null
var _cmd_grid_2: HBoxContainer = null
var _cmd_buttons: Dictionary = {}  # command_name -> Button
var _cargo_panel: VBoxContainer = null
var _cargo_label: Label = null
var _cargo_list: VBoxContainer = null

# --- Rename dialog ---
var _rename_dialog: AcceptDialog = null
var _rename_input: LineEdit = null

# --- Transfer dialog ---
var _transfer_dialog: AcceptDialog = null
var _transfer_slider: HSlider = null
var _transfer_type_option: OptionButton = null
var _transfer_amount_label: Label = null

# --- Phase 21: Research & Upgrades ---
var _research_panel: Window = null
var _research_rows: Array = []  # Array of {label, level, turns, slider} dicts
var _research_total_label: Label = null
var _research_apply_button: Button = null

var _upgrades_panel: Window = null
var _upgrades_list: VBoxContainer = null
var _upgrades_credits_label: Label = null
var _upgrades_data: Array = []  # Cached data from get_upgradeable_units()

var _research_notification_label: Label = null
var _research_notification_timer: float = 0.0

# --- Phase 22: Mining & Economy ---
var _mining_dialog: Window = null
var _mining_sliders: Array = []  # [{slider, label, max_label}] for metal/oil/gold
var _mining_total_label: Label = null
var _mining_apply_button: Button = null
var _mining_unit_id: int = -1

var _energy_warning_label: Label = null
var _energy_warning_timer: float = 0.0

var _subbase_panel: Window = null
var _subbase_list: VBoxContainer = null

# --- Phase 23: Event Log & Notifications ---
var _event_log_panel: Window = null
var _event_log_list: VBoxContainer = null
var _event_log_entries: Array = []  # Array of {text, color, position, timestamp}
const MAX_EVENT_LOG_ENTRIES := 200

var _alert_label: Label = null
var _alert_timer: float = 0.0
var _alert_queue: Array = []  # Queue of {text, color, position}

var _turn_report_panel: Window = null
var _turn_report_list: VBoxContainer = null

# --- Phase 24: Save/Load ---
# --- Phase 25: Overlay Toggles ---
var _active_stat_overlay: String = ""  # "", "survey", "hits", "scan", "status", "ammo", "colour", "lock"

var _save_load_dialog: Window = null
var _save_load_title: Label = null
var _save_load_list: VBoxContainer = null
var _save_load_name_input: LineEdit = null
var _save_load_action_button: Button = null
var _save_load_mode: String = "save"  # "save" or "load"
var _save_load_selected_slot: int = -1

# --- Phase 28: Reports & Statistics ---
var _casualties_panel: Window = null
var _casualties_list: VBoxContainer = null
var _player_stats_panel: Window = null
var _player_stats_list: VBoxContainer = null
var _army_panel: Window = null
var _army_list: VBoxContainer = null
var _army_filter_option: OptionButton = null
var _economy_panel: Window = null
var _economy_content: VBoxContainer = null


func _ready() -> void:
	end_turn_button.pressed.connect(func():
		AudioManager.play_sound("turn_end")  # Phase 33: Turn end click
		end_turn_pressed.emit())
	build_button.pressed.connect(func():
		AudioManager.play_sound("click")  # Phase 33: Build button click
		build_pressed.emit())
	unit_panel.visible = false
	_create_global_buttons()
	_create_phase20_hud_elements()
	_create_command_buttons()
	_create_cargo_panel()
	_create_rename_dialog()
	_create_transfer_dialog()
	_create_unit_info_popup()
	_create_research_panel()
	_create_upgrades_panel()
	_create_research_notification()
	_create_mining_dialog()
	_create_energy_warning()
	_create_subbase_panel()
	_create_event_log()
	_create_alert_display()
	_create_turn_report_panel()
	_create_save_load_dialog()
	_create_overlay_toolbar()
	_create_casualties_panel()
	_create_player_stats_panel()
	_create_army_panel()
	_create_economy_panel()


func set_sprite_cache(cache) -> void:
	_sprite_cache = cache


func _create_global_buttons() -> void:
	## Create always-available buttons for Research and Upgrades (Phase 21).
	var bottom_bar: HBoxContainer = $BottomBar

	var research_btn := Button.new()
	research_btn.text = "RESEARCH"
	research_btn.custom_minimum_size = Vector2(100, 36)
	research_btn.add_theme_font_size_override("font_size", 12)
	research_btn.tooltip_text = "Open research allocation panel"
	research_btn.pressed.connect(func(): command_pressed.emit("open_research"))
	bottom_bar.add_child(research_btn)
	bottom_bar.move_child(research_btn, 0)

	var upgrades_btn := Button.new()
	upgrades_btn.text = "UPGRADES"
	upgrades_btn.custom_minimum_size = Vector2(100, 36)
	upgrades_btn.add_theme_font_size_override("font_size", 12)
	upgrades_btn.tooltip_text = "Open gold upgrades menu"
	upgrades_btn.pressed.connect(func(): command_pressed.emit("open_upgrades"))
	bottom_bar.add_child(upgrades_btn)
	bottom_bar.move_child(upgrades_btn, 1)

	var bases_btn := Button.new()
	bases_btn.text = "BASES"
	bases_btn.custom_minimum_size = Vector2(80, 36)
	bases_btn.add_theme_font_size_override("font_size", 12)
	bases_btn.tooltip_text = "View sub-base overview"
	bases_btn.pressed.connect(func(): command_pressed.emit("open_bases"))
	bottom_bar.add_child(bases_btn)
	bottom_bar.move_child(bases_btn, 2)

	var log_btn := Button.new()
	log_btn.text = "LOG"
	log_btn.custom_minimum_size = Vector2(60, 36)
	log_btn.add_theme_font_size_override("font_size", 12)
	log_btn.tooltip_text = "Open event log"
	log_btn.pressed.connect(func(): _show_event_log())
	bottom_bar.add_child(log_btn)
	bottom_bar.move_child(log_btn, 4)

	var res_overlay_btn := Button.new()
	res_overlay_btn.text = "RESOURCES"
	res_overlay_btn.custom_minimum_size = Vector2(100, 36)
	res_overlay_btn.add_theme_font_size_override("font_size", 12)
	res_overlay_btn.tooltip_text = "Toggle resource deposit overlay on map"
	res_overlay_btn.pressed.connect(func(): command_pressed.emit("toggle_resource_overlay"))
	bottom_bar.add_child(res_overlay_btn)
	bottom_bar.move_child(res_overlay_btn, 3)

	# Phase 28: Reports & Statistics buttons
	var casualties_btn := Button.new()
	casualties_btn.text = "LOSSES"
	casualties_btn.custom_minimum_size = Vector2(70, 36)
	casualties_btn.add_theme_font_size_override("font_size", 12)
	casualties_btn.tooltip_text = "View casualties report"
	casualties_btn.pressed.connect(func():
		AudioManager.play_sound("click")
		command_pressed.emit("open_casualties"))
	bottom_bar.add_child(casualties_btn)

	var stats_btn := Button.new()
	stats_btn.text = "STATS"
	stats_btn.custom_minimum_size = Vector2(70, 36)
	stats_btn.add_theme_font_size_override("font_size", 12)
	stats_btn.tooltip_text = "View player statistics"
	stats_btn.pressed.connect(func():
		AudioManager.play_sound("click")
		command_pressed.emit("open_player_stats"))
	bottom_bar.add_child(stats_btn)

	var army_btn := Button.new()
	army_btn.text = "ARMY"
	army_btn.custom_minimum_size = Vector2(70, 36)
	army_btn.add_theme_font_size_override("font_size", 12)
	army_btn.tooltip_text = "View army overview"
	army_btn.pressed.connect(func():
		AudioManager.play_sound("click")
		command_pressed.emit("open_army"))
	bottom_bar.add_child(army_btn)

	var econ_btn := Button.new()
	econ_btn.text = "ECON"
	econ_btn.custom_minimum_size = Vector2(70, 36)
	econ_btn.add_theme_font_size_override("font_size", 12)
	econ_btn.tooltip_text = "View economy summary"
	econ_btn.pressed.connect(func():
		AudioManager.play_sound("click")
		command_pressed.emit("open_economy"))
	bottom_bar.add_child(econ_btn)


# =============================================================================
# PHASE 20: ADDITIONAL HUD ELEMENTS
# =============================================================================

func _create_phase20_hud_elements() -> void:
	## Add humans label to resource bar, score + timer to top bar.
	var res_bar: HBoxContainer = $ResourceBar

	# Humans label (after credits)
	_humans_label = Label.new()
	_humans_label.name = "HumansLabel"
	_humans_label.text = "Humans: 0/0"
	_humans_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_humans_label.add_theme_font_size_override("font_size", 12)
	_humans_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_humans_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	res_bar.add_child(_humans_label)

	# Score label (in top bar, after status)
	var top_bar: HBoxContainer = $TopBar
	_score_label = Label.new()
	_score_label.name = "ScoreLabel"
	_score_label.text = ""
	_score_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_score_label.add_theme_font_size_override("font_size", 13)
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_score_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_score_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.3))
	top_bar.add_child(_score_label)

	# Timer label (in bottom bar, before end turn)
	var bottom_bar: HBoxContainer = $BottomBar
	_timer_label = Label.new()
	_timer_label.name = "TimerLabel"
	_timer_label.text = ""
	_timer_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_timer_label.add_theme_font_size_override("font_size", 14)
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_timer_label.visible = false
	bottom_bar.add_child(_timer_label)
	# Move timer before end turn button
	bottom_bar.move_child(_timer_label, bottom_bar.get_child_count() - 2)

	# Unit status label (experience/dated) — added to unit panel VBox
	var unit_vbox: VBoxContainer = $UnitPanel/VBox
	_unit_status_label = Label.new()
	_unit_status_label.name = "UnitStatusLabel"
	_unit_status_label.text = ""
	_unit_status_label.add_theme_font_size_override("font_size", 11)
	_unit_status_label.visible = false
	# Insert after UnitExtra, before BuildButton
	var extra_idx: int = unit_extra.get_index()
	unit_vbox.add_child(_unit_status_label)
	unit_vbox.move_child(_unit_status_label, extra_idx + 1)


func _create_unit_info_popup() -> void:
	## Create the full unit status popup window.
	_unit_info_popup = Window.new()
	_unit_info_popup.title = "Unit Information"
	_unit_info_popup.size = Vector2i(450, 550)
	_unit_info_popup.visible = false
	_unit_info_popup.unresizable = false
	_unit_info_popup.transient = true
	_unit_info_popup.exclusive = false
	add_child(_unit_info_popup)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_unit_info_popup.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	_unit_info_content = RichTextLabel.new()
	_unit_info_content.bbcode_enabled = true
	_unit_info_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_unit_info_content.scroll_following = false
	_unit_info_content.fit_content = true
	vbox.add_child(_unit_info_content)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(100, 32)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.pressed.connect(func(): _unit_info_popup.visible = false)
	vbox.add_child(close_btn)

	_unit_info_popup.close_requested.connect(func(): _unit_info_popup.visible = false)


# =============================================================================
# COMMAND BUTTON CREATION
# =============================================================================

const CMD_BUTTON_STYLE := {
	"font_size": 11,
	"min_width": 80,
	"min_height": 28,
}

func _create_cmd_button(cmd_name: String, label: String, tooltip: String) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.tooltip_text = tooltip
	btn.custom_minimum_size = Vector2(CMD_BUTTON_STYLE["min_width"], CMD_BUTTON_STYLE["min_height"])
	btn.add_theme_font_size_override("font_size", CMD_BUTTON_STYLE["font_size"])
	btn.visible = false
	btn.pressed.connect(func():
		AudioManager.play_sound("click")  # Phase 33: UI click sound
		command_pressed.emit(cmd_name))
	_cmd_buttons[cmd_name] = btn
	return btn


func _create_command_buttons() -> void:
	## Create two rows of command buttons below the build button.
	var vbox: VBoxContainer = $UnitPanel/VBox

	# Separator before commands
	var sep := HSeparator.new()
	sep.name = "CmdSep"
	vbox.add_child(sep)

	# Row 1: Combat + stance buttons
	_cmd_grid_1 = HBoxContainer.new()
	_cmd_grid_1.name = "CmdRow1"
	_cmd_grid_1.add_theme_constant_override("separation", 4)
	vbox.add_child(_cmd_grid_1)

	_cmd_grid_1.add_child(_create_cmd_button("sentry", "SENTRY", "Toggle sentry mode (auto-fire at enemies)"))
	_cmd_grid_1.add_child(_create_cmd_button("manual_fire", "MANUAL", "Toggle manual fire (only fire when ordered)"))
	_cmd_grid_1.add_child(_create_cmd_button("stop", "STOP", "Stop current action"))

	# Row 2: Special + logistics buttons
	_cmd_grid_2 = HBoxContainer.new()
	_cmd_grid_2.name = "CmdRow2"
	_cmd_grid_2.add_theme_constant_override("separation", 4)
	vbox.add_child(_cmd_grid_2)

	_cmd_grid_2.add_child(_create_cmd_button("survey", "SURVEY", "Toggle auto-survey mode"))
	_cmd_grid_2.add_child(_create_cmd_button("lay_mines", "MINES", "Toggle mine laying"))
	_cmd_grid_2.add_child(_create_cmd_button("clear_mines", "SWEEP", "Toggle mine sweeping"))
	_cmd_grid_2.add_child(_create_cmd_button("clear", "CLEAR", "Clear rubble/terrain"))
	_cmd_grid_2.add_child(_create_cmd_button("steal", "STEAL", "Infiltrate and steal enemy unit"))
	_cmd_grid_2.add_child(_create_cmd_button("disable", "DISABLE", "Infiltrate and disable enemy unit"))

	# Row 3: Logistics
	var cmd_grid_3 := HBoxContainer.new()
	cmd_grid_3.name = "CmdRow3"
	cmd_grid_3.add_theme_constant_override("separation", 4)
	vbox.add_child(cmd_grid_3)

	cmd_grid_3.add_child(_create_cmd_button("load", "LOAD", "Load unit into this transport"))
	cmd_grid_3.add_child(_create_cmd_button("activate", "UNLOAD", "Unload a stored unit"))
	cmd_grid_3.add_child(_create_cmd_button("repair", "REPAIR", "Repair an adjacent unit"))
	cmd_grid_3.add_child(_create_cmd_button("reload", "RELOAD", "Reload ammo for an adjacent unit"))
	cmd_grid_3.add_child(_create_cmd_button("transfer", "TRANSFER", "Transfer resources"))
	cmd_grid_3.add_child(_create_cmd_button("rename", "RENAME", "Rename this unit"))
	cmd_grid_3.add_child(_create_cmd_button("self_destroy", "DESTROY", "Self-destruct this building"))
	cmd_grid_3.add_child(_create_cmd_button("survey", "SURVEY", "Toggle auto-survey mode for surveyors"))
	cmd_grid_3.add_child(_create_cmd_button("mining", "MINING", "Adjust mining resource allocation"))
	cmd_grid_3.add_child(_create_cmd_button("upgrade_unit", "UPGRADE", "Upgrade this unit to the latest version"))
	cmd_grid_3.add_child(_create_cmd_button("upgrade_all", "UPGRADE ALL", "Upgrade all buildings of this type"))
	cmd_grid_3.add_child(_create_cmd_button("info", "INFO", "Open detailed unit information"))
	# Phase 26: Path building and cancel build
	cmd_grid_3.add_child(_create_cmd_button("path_build", "PATH BUILD", "Build road/bridge/platform to a target position"))
	cmd_grid_3.add_child(_create_cmd_button("cancel_build", "CANCEL BUILD", "Cancel construction in progress"))
	# Phase 31: Resume interrupted move
	cmd_grid_3.add_child(_create_cmd_button("resume_move", "RESUME", "Resume interrupted movement (F)"))


func _create_cargo_panel() -> void:
	## Create a panel to show stored units (cargo).
	var vbox: VBoxContainer = $UnitPanel/VBox
	_cargo_panel = VBoxContainer.new()
	_cargo_panel.name = "CargoPanel"
	_cargo_panel.visible = false
	vbox.add_child(_cargo_panel)

	_cargo_label = Label.new()
	_cargo_label.text = "Cargo:"
	_cargo_label.add_theme_font_size_override("font_size", 12)
	_cargo_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	_cargo_panel.add_child(_cargo_label)

	_cargo_list = VBoxContainer.new()
	_cargo_list.name = "CargoList"
	_cargo_list.add_theme_constant_override("separation", 2)
	_cargo_panel.add_child(_cargo_list)


func _create_rename_dialog() -> void:
	## Create the rename popup dialog.
	_rename_dialog = AcceptDialog.new()
	_rename_dialog.title = "Rename Unit"
	_rename_dialog.ok_button_text = "Rename"
	_rename_dialog.size = Vector2i(300, 100)
	add_child(_rename_dialog)

	var vbox := VBoxContainer.new()
	_rename_dialog.add_child(vbox)

	var lbl := Label.new()
	lbl.text = "Enter new name:"
	vbox.add_child(lbl)

	_rename_input = LineEdit.new()
	_rename_input.placeholder_text = "Unit name..."
	vbox.add_child(_rename_input)

	_rename_dialog.confirmed.connect(func():
		var new_name: String = _rename_input.text.strip_edges()
		if new_name != "":
			command_pressed.emit("rename_confirmed:" + new_name)
	)


func _create_transfer_dialog() -> void:
	## Create the resource transfer popup dialog.
	_transfer_dialog = AcceptDialog.new()
	_transfer_dialog.title = "Transfer Resources"
	_transfer_dialog.ok_button_text = "Transfer"
	_transfer_dialog.size = Vector2i(350, 180)
	add_child(_transfer_dialog)

	var vbox := VBoxContainer.new()
	_transfer_dialog.add_child(vbox)

	var type_row := HBoxContainer.new()
	vbox.add_child(type_row)
	var type_lbl := Label.new()
	type_lbl.text = "Resource:"
	type_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	type_row.add_child(type_lbl)
	_transfer_type_option = OptionButton.new()
	_transfer_type_option.add_item("Metal", 0)
	_transfer_type_option.add_item("Oil", 1)
	_transfer_type_option.add_item("Gold", 2)
	_transfer_type_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	type_row.add_child(_transfer_type_option)

	_transfer_amount_label = Label.new()
	_transfer_amount_label.text = "Amount: 0"
	_transfer_amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_transfer_amount_label)

	_transfer_slider = HSlider.new()
	_transfer_slider.min_value = 0
	_transfer_slider.max_value = 100
	_transfer_slider.step = 1
	_transfer_slider.custom_minimum_size = Vector2(280, 24)
	_transfer_slider.value_changed.connect(func(val: float):
		_transfer_amount_label.text = "Amount: %d" % int(val)
	)
	vbox.add_child(_transfer_slider)

	_transfer_dialog.confirmed.connect(func():
		var res_types := ["metal", "oil", "gold"]
		var idx: int = _transfer_type_option.selected
		var res_type: String = res_types[idx] if idx >= 0 and idx < 3 else "metal"
		var amount: int = int(_transfer_slider.value)
		if amount > 0:
			command_pressed.emit("transfer_confirmed:%s:%d" % [res_type, amount])
	)


# =============================================================================
# PHASE 21: RESEARCH PANEL
# =============================================================================

const RESEARCH_AREA_NAMES := ["Attack", "Shots", "Range", "Armor", "Hitpoints", "Speed", "Scan", "Cost"]
const RESEARCH_AREA_COLORS := [
	Color(1.0, 0.4, 0.35),   # Attack - red
	Color(1.0, 0.65, 0.3),   # Shots - orange
	Color(0.3, 0.85, 1.0),   # Range - cyan
	Color(0.6, 0.6, 0.8),    # Armor - steel
	Color(0.3, 0.9, 0.45),   # Hitpoints - green
	Color(1.0, 0.9, 0.3),    # Speed - yellow
	Color(0.55, 0.8, 1.0),   # Scan - light blue
	Color(0.85, 0.75, 0.3),  # Cost - gold
]

func _create_research_panel() -> void:
	_research_panel = Window.new()
	_research_panel.title = "Research Allocation"
	_research_panel.size = Vector2i(520, 480)
	_research_panel.visible = false
	_research_panel.unresizable = false
	_research_panel.transient = true
	_research_panel.exclusive = false
	add_child(_research_panel)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	_research_panel.add_child(margin)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 8)
	margin.add_child(main_vbox)

	# Header row: Area | Level | Turns | Centers
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	main_vbox.add_child(header)
	for col_name in ["Area", "Level", "Turns Left", "Centers"]:
		var lbl := Label.new()
		lbl.text = col_name
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if col_name == "Centers":
			lbl.size_flags_stretch_ratio = 2.0
		header.add_child(lbl)

	var sep := HSeparator.new()
	main_vbox.add_child(sep)

	# One row per research area
	_research_rows = []
	for i in range(8):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		main_vbox.add_child(row)

		var name_lbl := Label.new()
		name_lbl.text = RESEARCH_AREA_NAMES[i]
		name_lbl.add_theme_font_size_override("font_size", 13)
		name_lbl.add_theme_color_override("font_color", RESEARCH_AREA_COLORS[i])
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_lbl)

		var level_lbl := Label.new()
		level_lbl.text = "0"
		level_lbl.add_theme_font_size_override("font_size", 13)
		level_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		level_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(level_lbl)

		var turns_lbl := Label.new()
		turns_lbl.text = "-"
		turns_lbl.add_theme_font_size_override("font_size", 13)
		turns_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		turns_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(turns_lbl)

		var slider := HSlider.new()
		slider.min_value = 0
		slider.max_value = 10  # Will be updated with real center count
		slider.step = 1
		slider.value = 0
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.size_flags_stretch_ratio = 2.0
		slider.custom_minimum_size = Vector2(160, 20)
		var idx := i
		slider.value_changed.connect(func(_val: float): _on_research_slider_changed(idx))
		row.add_child(slider)

		_research_rows.append({
			"name": name_lbl,
			"level": level_lbl,
			"turns": turns_lbl,
			"slider": slider
		})

	var sep2 := HSeparator.new()
	main_vbox.add_child(sep2)

	# Total label
	_research_total_label = Label.new()
	_research_total_label.text = "Centers: 0 / 0"
	_research_total_label.add_theme_font_size_override("font_size", 13)
	_research_total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(_research_total_label)

	# Apply + Close buttons
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	main_vbox.add_child(btn_row)

	_research_apply_button = Button.new()
	_research_apply_button.text = "Apply"
	_research_apply_button.custom_minimum_size = Vector2(100, 34)
	_research_apply_button.add_theme_font_size_override("font_size", 14)
	_research_apply_button.pressed.connect(_on_research_apply)
	btn_row.add_child(_research_apply_button)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(100, 34)
	close_btn.add_theme_font_size_override("font_size", 14)
	close_btn.pressed.connect(func(): _research_panel.visible = false)
	btn_row.add_child(close_btn)

	_research_panel.close_requested.connect(func(): _research_panel.visible = false)


func _on_research_slider_changed(_area_idx: int) -> void:
	## Recalculate total centers label when a slider is moved.
	if not _research_total_label:
		return
	var total := 0
	for row in _research_rows:
		total += int(row["slider"].value)
	var max_centers: int = int(_research_total_label.get_meta("max_centers", 0))
	_research_total_label.text = "Centers: %d / %d" % [total, max_centers]
	if total > max_centers:
		_research_total_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3))
		_research_apply_button.disabled = true
	else:
		_research_total_label.add_theme_color_override("font_color", Color(0.7, 0.85, 0.75))
		_research_apply_button.disabled = false


func _on_research_apply() -> void:
	## Emit the allocation change signal.
	var areas := []
	for row in _research_rows:
		areas.append(int(row["slider"].value))
	research_allocation_changed.emit(areas)
	_research_panel.visible = false


func show_research_panel(levels: Dictionary, centers_per_area: Array,
		remaining_turns: Array, total_centers: int) -> void:
	## Populate and show the research allocation panel.
	if not _research_panel:
		return

	var area_keys := ["attack", "shots", "range", "armor", "hitpoints", "speed", "scan", "cost"]
	for i in range(8):
		var row = _research_rows[i]
		row["level"].text = str(levels.get(area_keys[i], 0))
		var turns: int = remaining_turns[i] if i < remaining_turns.size() else 0
		row["turns"].text = str(turns) + " turns" if turns > 0 else "-"
		row["slider"].max_value = total_centers
		row["slider"].value = centers_per_area[i] if i < centers_per_area.size() else 0

	_research_total_label.set_meta("max_centers", total_centers)
	_on_research_slider_changed(0)  # Refresh total label
	_research_panel.popup_centered()


# =============================================================================
# PHASE 21: GOLD UPGRADES PANEL
# =============================================================================

func _create_upgrades_panel() -> void:
	_upgrades_panel = Window.new()
	_upgrades_panel.title = "Gold Upgrades"
	_upgrades_panel.size = Vector2i(600, 550)
	_upgrades_panel.visible = false
	_upgrades_panel.unresizable = false
	_upgrades_panel.transient = true
	_upgrades_panel.exclusive = false
	add_child(_upgrades_panel)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_upgrades_panel.add_child(margin)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 6)
	margin.add_child(main_vbox)

	# Credits display
	_upgrades_credits_label = Label.new()
	_upgrades_credits_label.text = "Credits: 0"
	_upgrades_credits_label.add_theme_font_size_override("font_size", 15)
	_upgrades_credits_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.3))
	_upgrades_credits_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(_upgrades_credits_label)

	var sep := HSeparator.new()
	main_vbox.add_child(sep)

	# Scrollable list of unit types
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 380)
	main_vbox.add_child(scroll)

	_upgrades_list = VBoxContainer.new()
	_upgrades_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_upgrades_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_upgrades_list)

	# Close button
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(100, 34)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.add_theme_font_size_override("font_size", 14)
	close_btn.pressed.connect(func(): _upgrades_panel.visible = false)
	main_vbox.add_child(close_btn)

	_upgrades_panel.close_requested.connect(func(): _upgrades_panel.visible = false)


func show_upgrades_panel(upgradeable_units: Array, credits: int) -> void:
	## Populate and show the gold upgrades panel.
	if not _upgrades_panel:
		return

	_upgrades_data = upgradeable_units
	_upgrades_credits_label.text = "Credits: %d" % credits

	# Clear existing rows
	for child in _upgrades_list.get_children():
		child.queue_free()

	# Create a row for each unit type
	for unit_info in upgradeable_units:
		var unit_name: String = unit_info.get("name", "?")
		var id_first: int = unit_info.get("id_first", 0)
		var id_second: int = unit_info.get("id_second", 0)
		var upgrades: Array = unit_info.get("upgrades", [])

		if upgrades.size() == 0:
			continue

		# Unit header
		var header := Label.new()
		header.text = unit_name
		header.add_theme_font_size_override("font_size", 13)
		header.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
		_upgrades_list.add_child(header)

		# Stat grid
		var grid := GridContainer.new()
		grid.columns = 4  # Stat name | Value | Price | Buy button
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 3)
		_upgrades_list.add_child(grid)

		for stat in upgrades:
			var stat_type: String = stat.get("type", "?")
			var cur_val: int = stat.get("cur_value", 0)
			var next_price: int = stat.get("next_price", -1)
			var purchased: int = stat.get("purchased", 0)
			var stat_idx: int = stat.get("index", 0)

			# Stat name
			var name_lbl := Label.new()
			name_lbl.text = stat_type.capitalize()
			name_lbl.add_theme_font_size_override("font_size", 11)
			name_lbl.custom_minimum_size = Vector2(70, 0)
			grid.add_child(name_lbl)

			# Current value + purchased count
			var val_lbl := Label.new()
			val_lbl.text = "%d (+%d)" % [cur_val, purchased] if purchased > 0 else str(cur_val)
			val_lbl.add_theme_font_size_override("font_size", 11)
			val_lbl.add_theme_color_override("font_color",
				Color(0.3, 0.9, 0.5) if purchased > 0 else Color(0.7, 0.75, 0.8))
			val_lbl.custom_minimum_size = Vector2(80, 0)
			grid.add_child(val_lbl)

			# Price
			var price_lbl := Label.new()
			if next_price > 0:
				price_lbl.text = "%d credits" % next_price
				price_lbl.add_theme_color_override("font_color",
					Color(0.95, 0.85, 0.3) if next_price <= credits else Color(0.6, 0.4, 0.35))
			else:
				price_lbl.text = "MAX"
				price_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
			price_lbl.add_theme_font_size_override("font_size", 11)
			price_lbl.custom_minimum_size = Vector2(90, 0)
			grid.add_child(price_lbl)

			# Buy button
			var buy_btn := Button.new()
			buy_btn.text = "BUY"
			buy_btn.add_theme_font_size_override("font_size", 10)
			buy_btn.custom_minimum_size = Vector2(50, 22)
			buy_btn.disabled = (next_price <= 0 or next_price > credits)
			var _id_f := id_first
			var _id_s := id_second
			var _si := stat_idx
			buy_btn.pressed.connect(func(): gold_upgrade_requested.emit(_id_f, _id_s, _si))
			grid.add_child(buy_btn)

		var sep2 := HSeparator.new()
		_upgrades_list.add_child(sep2)

	_upgrades_panel.popup_centered()


# =============================================================================
# PHASE 21: RESEARCH NOTIFICATION
# =============================================================================

func _create_research_notification() -> void:
	_research_notification_label = Label.new()
	_research_notification_label.text = ""
	_research_notification_label.visible = false
	_research_notification_label.add_theme_font_size_override("font_size", 18)
	_research_notification_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
	_research_notification_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_research_notification_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_research_notification_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_research_notification_label.offset_top = 60
	_research_notification_label.offset_left = -200
	_research_notification_label.offset_right = 200
	_research_notification_label.offset_bottom = 90
	add_child(_research_notification_label)


func show_research_notification(area_name: String, new_level: int) -> void:
	## Show a brief toast notification that research leveled up.
	if not _research_notification_label:
		return
	_research_notification_label.text = "%s Research reached Level %d!" % [area_name, new_level]
	_research_notification_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
	_research_notification_label.visible = true
	_research_notification_label.modulate.a = 1.0
	_research_notification_timer = 3.0


func show_resource_discovery(resource_type: String, value: int, pos: Vector2i) -> void:
	## Show a brief toast that resources were discovered at a location.
	if not _research_notification_label:
		return
	var color: Color
	match resource_type:
		"metal": color = Color(0.55, 0.65, 0.85)
		"oil":   color = Color(0.5, 0.5, 0.5)
		"gold":  color = Color(0.95, 0.85, 0.3)
		_:       color = Color(0.7, 0.8, 0.9)
	_research_notification_label.text = "%s deposit found (%d) at (%d, %d)!" % [
		resource_type.capitalize(), value, pos.x, pos.y]
	_research_notification_label.add_theme_color_override("font_color", color)
	_research_notification_label.visible = true
	_research_notification_label.modulate.a = 1.0
	_research_notification_timer = 3.0


func _process_notification(delta: float) -> void:
	if _research_notification_timer > 0:
		_research_notification_timer -= delta
		if _research_notification_timer <= 0 and _research_notification_label:
			_research_notification_label.visible = false
		elif _research_notification_timer < 1.0 and _research_notification_label:
			# Fade out
			var alpha := _research_notification_timer
			_research_notification_label.modulate.a = alpha


func _process(delta: float) -> void:
	_process_notification(delta)
	_process_energy_warning(delta)
	_process_alert(delta)


# =============================================================================
# PHASE 22: MINING ALLOCATION DIALOG
# =============================================================================

func _create_mining_dialog() -> void:
	_mining_dialog = Window.new()
	_mining_dialog.title = "Mining Allocation"
	_mining_dialog.size = Vector2i(380, 320)
	_mining_dialog.visible = false
	_mining_dialog.transient = true
	add_child(_mining_dialog)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	_mining_dialog.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var res_names := ["Metal", "Oil", "Gold"]
	var res_colors := [Color(0.7, 0.75, 0.85), Color(0.3, 0.3, 0.3), Color(0.95, 0.85, 0.3)]
	_mining_sliders = []

	for i in range(3):
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		vbox.add_child(row)

		var label_row := HBoxContainer.new()
		row.add_child(label_row)

		var name_lbl := Label.new()
		name_lbl.text = res_names[i] + ":"
		name_lbl.add_theme_font_size_override("font_size", 14)
		name_lbl.add_theme_color_override("font_color", res_colors[i])
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label_row.add_child(name_lbl)

		var val_lbl := Label.new()
		val_lbl.text = "0"
		val_lbl.add_theme_font_size_override("font_size", 14)
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		val_lbl.custom_minimum_size = Vector2(40, 0)
		label_row.add_child(val_lbl)

		var max_lbl := Label.new()
		max_lbl.text = "/ 0"
		max_lbl.add_theme_font_size_override("font_size", 12)
		max_lbl.add_theme_color_override("font_color", Color(0.5, 0.55, 0.6))
		label_row.add_child(max_lbl)

		var slider := HSlider.new()
		slider.min_value = 0
		slider.max_value = 16
		slider.step = 1
		slider.value = 0
		slider.custom_minimum_size = Vector2(280, 20)
		var idx := i
		slider.value_changed.connect(func(_v: float): _on_mining_slider_changed(idx))
		row.add_child(slider)

		_mining_sliders.append({"slider": slider, "label": val_lbl, "max_label": max_lbl})

	var sep := HSeparator.new()
	vbox.add_child(sep)

	_mining_total_label = Label.new()
	_mining_total_label.text = "Total: 0 / 0"
	_mining_total_label.add_theme_font_size_override("font_size", 13)
	_mining_total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_mining_total_label)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	vbox.add_child(btn_row)

	_mining_apply_button = Button.new()
	_mining_apply_button.text = "Apply"
	_mining_apply_button.custom_minimum_size = Vector2(90, 32)
	_mining_apply_button.pressed.connect(_on_mining_apply)
	btn_row.add_child(_mining_apply_button)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(90, 32)
	close_btn.pressed.connect(func(): _mining_dialog.visible = false)
	btn_row.add_child(close_btn)

	_mining_dialog.close_requested.connect(func(): _mining_dialog.visible = false)


func _on_mining_slider_changed(_idx: int) -> void:
	## Update labels and total when mining sliders change.
	var total := 0
	for s in _mining_sliders:
		var v: int = int(s["slider"].value)
		s["label"].text = str(v)
		total += v
	var max_total: int = int(_mining_total_label.get_meta("max_total", 16))
	_mining_total_label.text = "Total: %d / %d" % [total, max_total]
	if total > max_total:
		_mining_total_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3))
		_mining_apply_button.disabled = true
	else:
		_mining_total_label.add_theme_color_override("font_color", Color(0.7, 0.85, 0.75))
		_mining_apply_button.disabled = false


func _on_mining_apply() -> void:
	var m: int = int(_mining_sliders[0]["slider"].value)
	var o: int = int(_mining_sliders[1]["slider"].value)
	var g: int = int(_mining_sliders[2]["slider"].value)
	mining_distribution_changed.emit(_mining_unit_id, m, o, g)
	_mining_dialog.visible = false


func show_mining_dialog(unit_id: int, current: Dictionary, max_prod: Dictionary, max_total: int) -> void:
	## Open the mining allocation dialog for a mine building.
	if not _mining_dialog:
		return
	_mining_unit_id = unit_id

	var keys := ["metal", "oil", "gold"]
	for i in range(3):
		var cur: int = current.get(keys[i], 0)
		var mx: int = max_prod.get(keys[i], 0)
		_mining_sliders[i]["slider"].max_value = mx
		_mining_sliders[i]["slider"].value = cur
		_mining_sliders[i]["label"].text = str(cur)
		_mining_sliders[i]["max_label"].text = "/ %d" % mx

	_mining_total_label.set_meta("max_total", max_total)
	_on_mining_slider_changed(0)
	_mining_dialog.popup_centered()


# =============================================================================
# PHASE 22: ENERGY SHORTAGE WARNING
# =============================================================================

func _create_energy_warning() -> void:
	_energy_warning_label = Label.new()
	_energy_warning_label.text = ""
	_energy_warning_label.visible = false
	_energy_warning_label.add_theme_font_size_override("font_size", 16)
	_energy_warning_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.2))
	_energy_warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_energy_warning_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_energy_warning_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_energy_warning_label.offset_top = 90
	_energy_warning_label.offset_left = -250
	_energy_warning_label.offset_right = 250
	_energy_warning_label.offset_bottom = 120
	add_child(_energy_warning_label)


func show_energy_warning(message: String) -> void:
	if not _energy_warning_label:
		return
	_energy_warning_label.text = message
	_energy_warning_label.visible = true
	_energy_warning_label.modulate.a = 1.0
	_energy_warning_timer = 4.0


func _process_energy_warning(delta: float) -> void:
	if _energy_warning_timer > 0:
		_energy_warning_timer -= delta
		if _energy_warning_timer <= 0 and _energy_warning_label:
			_energy_warning_label.visible = false
		elif _energy_warning_timer < 1.5 and _energy_warning_label:
			_energy_warning_label.modulate.a = _energy_warning_timer / 1.5


# =============================================================================
# PHASE 22: SUB-BASE PANEL
# =============================================================================

func _create_subbase_panel() -> void:
	_subbase_panel = Window.new()
	_subbase_panel.title = "Sub-Base Overview"
	_subbase_panel.size = Vector2i(500, 450)
	_subbase_panel.visible = false
	_subbase_panel.transient = true
	add_child(_subbase_panel)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_subbase_panel.add_child(margin)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 6)
	margin.add_child(main_vbox)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(scroll)

	_subbase_list = VBoxContainer.new()
	_subbase_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_subbase_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_subbase_list)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(100, 32)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.pressed.connect(func(): _subbase_panel.visible = false)
	main_vbox.add_child(close_btn)

	_subbase_panel.close_requested.connect(func(): _subbase_panel.visible = false)


func show_subbase_panel(sub_bases: Array) -> void:
	## Populate and show the sub-base overview.
	if not _subbase_panel:
		return

	for child in _subbase_list.get_children():
		child.queue_free()

	for i in range(sub_bases.size()):
		var sb: Dictionary = sub_bases[i]
		var frame := PanelContainer.new()
		_subbase_list.add_child(frame)

		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 3)
		frame.add_child(vbox)

		# Header
		var header := Label.new()
		header.text = "Sub-Base %d  (%d buildings)" % [i + 1, sb.get("building_count", 0)]
		header.add_theme_font_size_override("font_size", 14)
		header.add_theme_color_override("font_color", Color(0.3, 0.85, 1.0))
		vbox.add_child(header)

		# Resources
		var res_lbl := Label.new()
		res_lbl.text = "Storage:  Metal %d/%d  |  Oil %d/%d  |  Gold %d/%d" % [
			sb.get("metal", 0), sb.get("metal_max", 0),
			sb.get("oil", 0), sb.get("oil_max", 0),
			sb.get("gold", 0), sb.get("gold_max", 0)]
		res_lbl.add_theme_font_size_override("font_size", 12)
		vbox.add_child(res_lbl)

		# Production
		var prod_lbl := Label.new()
		var pm: int = sb.get("production_metal", 0) - sb.get("needed_metal", 0)
		var po: int = sb.get("production_oil", 0) - sb.get("needed_oil", 0)
		var pg: int = sb.get("production_gold", 0) - sb.get("needed_gold", 0)
		prod_lbl.text = "Net:  M %s%d  |  O %s%d  |  G %s%d" % [
			"+" if pm >= 0 else "", pm,
			"+" if po >= 0 else "", po,
			"+" if pg >= 0 else "", pg]
		prod_lbl.add_theme_font_size_override("font_size", 12)
		prod_lbl.add_theme_color_override("font_color",
			Color(0.7, 0.85, 0.75) if pm >= 0 and po >= 0 else Color(1.0, 0.6, 0.4))
		vbox.add_child(prod_lbl)

		# Energy
		var e_prod: int = sb.get("energy_prod", 0)
		var e_need: int = sb.get("energy_need", 0)
		var e_net: int = e_prod - e_need
		var energy_lbl := Label.new()
		energy_lbl.text = "Energy: %d / %d  (%s%d)" % [e_prod, e_need, "+" if e_net >= 0 else "", e_net]
		energy_lbl.add_theme_font_size_override("font_size", 12)
		energy_lbl.add_theme_color_override("font_color",
			Color(0.3, 0.85, 1.0) if e_net >= 0 else Color(1.0, 0.35, 0.3))
		vbox.add_child(energy_lbl)

		# Humans
		var h_prod: int = sb.get("human_prod", 0)
		var h_need: int = sb.get("human_need", 0)
		var human_lbl := Label.new()
		human_lbl.text = "Humans: %d / %d" % [h_prod, h_need]
		human_lbl.add_theme_font_size_override("font_size", 12)
		vbox.add_child(human_lbl)

	_subbase_panel.popup_centered()


# =============================================================================
# PHASE 23: EVENT LOG
# =============================================================================

func _create_event_log() -> void:
	_event_log_panel = Window.new()
	_event_log_panel.title = "Event Log"
	_event_log_panel.size = Vector2i(520, 400)
	_event_log_panel.visible = false
	_event_log_panel.transient = true
	add_child(_event_log_panel)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	_event_log_panel.add_child(margin)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 6)
	margin.add_child(main_vbox)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	main_vbox.add_child(scroll)

	_event_log_list = VBoxContainer.new()
	_event_log_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_event_log_list.add_theme_constant_override("separation", 2)
	scroll.add_child(_event_log_list)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	main_vbox.add_child(btn_row)

	var clear_btn := Button.new()
	clear_btn.text = "Clear"
	clear_btn.custom_minimum_size = Vector2(80, 30)
	clear_btn.pressed.connect(func():
		_event_log_entries.clear()
		for c in _event_log_list.get_children():
			c.queue_free()
	)
	btn_row.add_child(clear_btn)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(80, 30)
	close_btn.pressed.connect(func(): _event_log_panel.visible = false)
	btn_row.add_child(close_btn)

	_event_log_panel.close_requested.connect(func(): _event_log_panel.visible = false)


func add_event(text: String, color: Color = Color(0.8, 0.85, 0.9), position: Vector2i = Vector2i(-1, -1)) -> void:
	## Add an entry to the event log. Optionally includes a position for camera jump.
	var entry := {"text": text, "color": color, "position": position, "turn": 0}
	_event_log_entries.append(entry)
	if _event_log_entries.size() > MAX_EVENT_LOG_ENTRIES:
		_event_log_entries.pop_front()

	if not _event_log_list:
		return

	# Build the log row
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", color)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(lbl)

	if position != Vector2i(-1, -1):
		var jump_btn := Button.new()
		jump_btn.text = ">"
		jump_btn.custom_minimum_size = Vector2(28, 22)
		jump_btn.add_theme_font_size_override("font_size", 11)
		jump_btn.tooltip_text = "Jump to (%d, %d)" % [position.x, position.y]
		var pos_copy := position
		jump_btn.pressed.connect(func(): jump_to_position.emit(pos_copy))
		row.add_child(jump_btn)

	_event_log_list.add_child(row)

	# Trim visual entries if too many
	while _event_log_list.get_child_count() > MAX_EVENT_LOG_ENTRIES:
		_event_log_list.get_child(0).queue_free()


func _show_event_log() -> void:
	if _event_log_panel:
		_event_log_panel.popup_centered()


# =============================================================================
# PHASE 23: ALERT DISPLAY (unit under attack, destroyed, etc.)
# =============================================================================

func _create_alert_display() -> void:
	_alert_label = Label.new()
	_alert_label.text = ""
	_alert_label.visible = false
	_alert_label.add_theme_font_size_override("font_size", 18)
	_alert_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.2))
	_alert_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_alert_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_alert_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_alert_label.offset_top = 50
	_alert_label.offset_left = -300
	_alert_label.offset_right = 300
	_alert_label.offset_bottom = 80
	add_child(_alert_label)


func show_alert(text: String, color: Color = Color(1.0, 0.3, 0.2), position: Vector2i = Vector2i(-1, -1)) -> void:
	## Show an alert notification with optional camera jump.
	## Also adds the event to the log.
	add_event(text, color, position)

	# Queue alert for display
	_alert_queue.append({"text": text, "color": color, "position": position})
	if _alert_timer <= 0:
		_pop_next_alert()


func _pop_next_alert() -> void:
	if _alert_queue.is_empty():
		if _alert_label:
			_alert_label.visible = false
		return
	var alert: Dictionary = _alert_queue.pop_front()
	if _alert_label:
		_alert_label.text = alert.get("text", "")
		_alert_label.add_theme_color_override("font_color", alert.get("color", Color(1.0, 0.3, 0.2)))
		_alert_label.visible = true
		_alert_label.modulate.a = 1.0
		_alert_timer = 2.5
	# Auto-jump to position if available
	var pos: Vector2i = alert.get("position", Vector2i(-1, -1))
	if pos != Vector2i(-1, -1):
		jump_to_position.emit(pos)


func _process_alert(delta: float) -> void:
	if _alert_timer > 0:
		_alert_timer -= delta
		if _alert_timer <= 0:
			# Show next queued alert, or fade out
			_pop_next_alert()
		elif _alert_timer < 1.0 and _alert_label:
			_alert_label.modulate.a = _alert_timer / 1.0


# =============================================================================
# PHASE 23: TURN REPORT PANEL
# =============================================================================

func _create_turn_report_panel() -> void:
	_turn_report_panel = Window.new()
	_turn_report_panel.title = "Turn Report"
	_turn_report_panel.size = Vector2i(450, 350)
	_turn_report_panel.visible = false
	_turn_report_panel.transient = true
	add_child(_turn_report_panel)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_turn_report_panel.add_child(margin)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 6)
	margin.add_child(main_vbox)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(scroll)

	_turn_report_list = VBoxContainer.new()
	_turn_report_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_turn_report_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_turn_report_list)

	var close_btn := Button.new()
	close_btn.text = "OK"
	close_btn.custom_minimum_size = Vector2(100, 32)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.pressed.connect(func(): _turn_report_panel.visible = false)
	main_vbox.add_child(close_btn)

	_turn_report_panel.close_requested.connect(func(): _turn_report_panel.visible = false)


func show_turn_report(report_items: Array) -> void:
	## Show the turn report summary panel.
	## report_items: Array of {text, color, position}
	if not _turn_report_panel or not _turn_report_list:
		return

	for child in _turn_report_list.get_children():
		child.queue_free()

	if report_items.is_empty():
		var lbl := Label.new()
		lbl.text = "Nothing significant to report."
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))
		_turn_report_list.add_child(lbl)
	else:
		for item in report_items:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 6)

			var lbl := Label.new()
			lbl.text = item.get("text", "")
			lbl.add_theme_font_size_override("font_size", 13)
			lbl.add_theme_color_override("font_color", item.get("color", Color(0.8, 0.85, 0.9)))
			lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			row.add_child(lbl)

			var pos: Vector2i = item.get("position", Vector2i(-1, -1))
			if pos != Vector2i(-1, -1):
				var jump_btn := Button.new()
				jump_btn.text = ">"
				jump_btn.custom_minimum_size = Vector2(28, 22)
				jump_btn.add_theme_font_size_override("font_size", 11)
				jump_btn.tooltip_text = "Jump to (%d, %d)" % [pos.x, pos.y]
				var pos_copy := pos
				jump_btn.pressed.connect(func(): jump_to_position.emit(pos_copy))
				row.add_child(jump_btn)

			_turn_report_list.add_child(row)

	# Also add all items to the event log
	for item in report_items:
		add_event(item.get("text", ""), item.get("color", Color(0.8, 0.85, 0.9)),
				  item.get("position", Vector2i(-1, -1)))

	_turn_report_panel.popup_centered()


# =============================================================================
# PHASE 25: OVERLAY TOOLBAR
# =============================================================================

func _create_overlay_toolbar() -> void:
	## Create a small overlay toggle bar near the bottom-left of the screen.
	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bar.offset_left = 10
	bar.offset_bottom = -50
	bar.offset_top = -76
	bar.add_theme_constant_override("separation", 2)
	add_child(bar)

	var overlays := [
		["SVY", "survey", "Survey overlay: show surveyed status"],
		["HP", "hits", "Hits overlay: show unit HP"],
		["SCN", "scan", "Scan overlay: show unit scan range"],
		["STS", "status", "Status overlay: show unit state"],
		["AMO", "ammo", "Ammo overlay: show ammo/shots"],
		["CLR", "colour", "Colour overlay: highlight by owner"],
		["LCK", "lock", "Lock overlay: show sentry units"],
		["GRD", "grid", "Grid overlay: show tile grid"],
		["FOG", "fog", "Fog of war: toggle visibility"],
		["NET", "connector", "Network: show base connections"],
	]

	for ov in overlays:
		var btn := Button.new()
		btn.text = ov[0]
		btn.custom_minimum_size = Vector2(38, 24)
		btn.add_theme_font_size_override("font_size", 9)
		btn.tooltip_text = ov[2]
		btn.toggle_mode = true
		var ov_name: String = ov[1]
		btn.toggled.connect(func(pressed: bool): _on_overlay_toggled(ov_name, pressed))
		bar.add_child(btn)


func _on_overlay_toggled(overlay_name: String, pressed: bool) -> void:
	match overlay_name:
		"grid":
			grid_overlay_toggled.emit(pressed)
		"fog":
			fog_overlay_toggled.emit(pressed)
		"connector":
			connector_overlay_toggled.emit(pressed)
		_:
			if pressed:
				_active_stat_overlay = overlay_name
			else:
				if _active_stat_overlay == overlay_name:
					_active_stat_overlay = ""
			stat_overlay_changed.emit(_active_stat_overlay)


# =============================================================================
# PHASE 24: SAVE/LOAD DIALOG
# =============================================================================

func _create_save_load_dialog() -> void:
	_save_load_dialog = Window.new()
	_save_load_dialog.title = "Save Game"
	_save_load_dialog.size = Vector2i(520, 480)
	_save_load_dialog.visible = false
	_save_load_dialog.transient = true
	add_child(_save_load_dialog)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	_save_load_dialog.add_child(margin)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 8)
	margin.add_child(main_vbox)

	_save_load_title = Label.new()
	_save_load_title.text = "Save Game"
	_save_load_title.add_theme_font_size_override("font_size", 18)
	_save_load_title.add_theme_color_override("font_color", Color(0.3, 0.85, 1.0))
	_save_load_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(_save_load_title)

	var sep := HSeparator.new()
	main_vbox.add_child(sep)

	# Slot list
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(scroll)

	_save_load_list = VBoxContainer.new()
	_save_load_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_save_load_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_save_load_list)

	# Save name input (only visible in save mode)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	main_vbox.add_child(name_row)

	var name_label := Label.new()
	name_label.text = "Save name:"
	name_label.add_theme_font_size_override("font_size", 13)
	name_row.add_child(name_label)

	_save_load_name_input = LineEdit.new()
	_save_load_name_input.placeholder_text = "Enter save name..."
	_save_load_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_save_load_name_input.custom_minimum_size = Vector2(200, 32)
	name_row.add_child(_save_load_name_input)

	# Buttons
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	main_vbox.add_child(btn_row)

	_save_load_action_button = Button.new()
	_save_load_action_button.text = "Save"
	_save_load_action_button.custom_minimum_size = Vector2(100, 36)
	_save_load_action_button.add_theme_font_size_override("font_size", 14)
	_save_load_action_button.pressed.connect(_on_save_load_action)
	btn_row.add_child(_save_load_action_button)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(100, 36)
	cancel_btn.add_theme_font_size_override("font_size", 14)
	cancel_btn.pressed.connect(func(): _save_load_dialog.visible = false)
	btn_row.add_child(cancel_btn)

	_save_load_dialog.close_requested.connect(func(): _save_load_dialog.visible = false)


func show_save_dialog(saves: Array, current_turn: int) -> void:
	## Open the save dialog with the list of existing saves.
	_save_load_mode = "save"
	_save_load_selected_slot = -1
	if _save_load_dialog:
		_save_load_dialog.title = "Save Game"
	if _save_load_title:
		_save_load_title.text = "Save Game"
	if _save_load_action_button:
		_save_load_action_button.text = "Save"
		_save_load_action_button.disabled = false
	if _save_load_name_input:
		_save_load_name_input.visible = true
		_save_load_name_input.text = "Turn %d" % current_turn
	_populate_save_load_list(saves)
	_save_load_dialog.popup_centered()


func show_load_dialog(saves: Array) -> void:
	## Open the load dialog with the list of existing saves.
	_save_load_mode = "load"
	_save_load_selected_slot = -1
	if _save_load_dialog:
		_save_load_dialog.title = "Load Game"
	if _save_load_title:
		_save_load_title.text = "Load Game"
	if _save_load_action_button:
		_save_load_action_button.text = "Load"
		_save_load_action_button.disabled = true  # No slot selected yet
	if _save_load_name_input:
		_save_load_name_input.visible = false
	_populate_save_load_list(saves)
	_save_load_dialog.popup_centered()


func _populate_save_load_list(saves: Array) -> void:
	## Build the save slot list.
	if not _save_load_list:
		return

	for child in _save_load_list.get_children():
		child.queue_free()

	# Add "New Save" option at the top (save mode only)
	if _save_load_mode == "save":
		var new_btn := Button.new()
		new_btn.text = "[ New Save Slot ]"
		new_btn.custom_minimum_size = Vector2(0, 36)
		new_btn.add_theme_font_size_override("font_size", 13)
		new_btn.add_theme_color_override("font_color", Color(0.3, 0.85, 0.5))
		# Find first unused slot
		var used_slots: Dictionary = {}
		for s in saves:
			used_slots[s.get("slot", 0)] = true
		var next_slot := 1
		while used_slots.has(next_slot) and next_slot <= 100:
			next_slot += 1
		new_btn.pressed.connect(func(): _select_slot(next_slot, "New Save"))
		_save_load_list.add_child(new_btn)

	# Existing saves (sorted by slot)
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

		var btn := Button.new()
		var player_names: String = ""
		for p in players:
			if player_names.length() > 0:
				player_names += ", "
			player_names += p.get("name", "?")

		btn.text = "Slot %d: %s  |  Turn %d  |  %s  |  %s" % [slot, name_str, turn, map_str, date_str]
		btn.custom_minimum_size = Vector2(0, 36)
		btn.add_theme_font_size_override("font_size", 12)
		btn.tooltip_text = "Players: %s" % player_names

		var slot_copy := slot
		var name_copy := name_str
		btn.pressed.connect(func(): _select_slot(slot_copy, name_copy))
		_save_load_list.add_child(btn)


func _select_slot(slot: int, save_name: String) -> void:
	_save_load_selected_slot = slot
	if _save_load_name_input and _save_load_mode == "save":
		if _save_load_name_input.text.is_empty() or _save_load_name_input.text.begins_with("Turn "):
			_save_load_name_input.text = save_name
	if _save_load_action_button:
		_save_load_action_button.disabled = false
		_save_load_action_button.text = "%s (Slot %d)" % [
			"Save" if _save_load_mode == "save" else "Load",
			slot]


func _on_save_load_action() -> void:
	if _save_load_selected_slot < 0:
		return
	if _save_load_mode == "save":
		var name_str: String = _save_load_name_input.text if _save_load_name_input else "Quick Save"
		if name_str.is_empty():
			name_str = "Quick Save"
		save_game_requested.emit(_save_load_selected_slot, name_str)
	else:
		load_game_requested.emit(_save_load_selected_slot)
	_save_load_dialog.visible = false


# =============================================================================
# UPDATE METHODS
# =============================================================================

func update_turn_info(turn: int, _game_time: int, is_active: bool) -> void:
	turn_label.text = "Turn %d" % turn
	if is_active:
		status_label.text = "ACTIVE"
		status_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4))
	else:
		status_label.text = "WAITING"
		status_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2))


func update_player_info(player_name: String, _credits: int, vehicle_count: int, building_count: int) -> void:
	player_label.text = "%s  |  %d units  |  %d buildings" % [player_name, vehicle_count, building_count]


func update_human_display(humans: Dictionary) -> void:
	## Update the human resources display.
	if not _humans_label:
		return
	var prod: int = humans.get("production", 0)
	var need: int = humans.get("need", 0)
	var net: int = prod - need
	_humans_label.text = "Humans: %d/%d  %s%d" % [prod, need, "+" if net >= 0 else "", net]
	_humans_label.add_theme_color_override("font_color",
		Color(0.7, 0.9, 0.75) if net >= 0 else Color(1.0, 0.5, 0.4))


func update_score_display(score: int, victory_type: String, target_points: int) -> void:
	## Show score in top bar. Shows target for Points victory; always shows score.
	if not _score_label:
		return
	if victory_type == "points" and target_points > 0:
		_score_label.text = "Score: %d / %d" % [score, target_points]
		_score_label.visible = true
		if score >= target_points:
			_score_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
		else:
			_score_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.3))
	elif victory_type == "turn_limit":
		_score_label.text = "Score: %d" % score
		_score_label.visible = true
		_score_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.3))
	elif score > 0:
		_score_label.text = "Score: %d" % score
		_score_label.visible = true
		_score_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.3))
	else:
		_score_label.visible = false


func update_timer_display(time_remaining: float, has_deadline: bool) -> void:
	## Show turn timer countdown when a deadline is active.
	if not _timer_label:
		return
	if not has_deadline or time_remaining < 0:
		_timer_label.visible = false
		return

	_timer_label.visible = true
	var minutes: int = int(time_remaining) / 60
	var seconds: int = int(time_remaining) % 60
	_timer_label.text = "%d:%02d" % [minutes, seconds]

	# Color-code urgency
	if time_remaining < 15.0:
		_timer_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.2))
	elif time_remaining < 60.0:
		_timer_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.2))
	else:
		_timer_label.add_theme_color_override("font_color", Color(0.7, 0.85, 0.75))


func show_unit_info(info: Dictionary) -> void:
	## Open the full unit status popup with detailed info.
	if not _unit_info_popup or not _unit_info_content:
		return

	var bbcode := ""
	bbcode += "[b][font_size=18]%s[/font_size][/b]\n" % info.get("name", "Unknown")
	bbcode += "[color=#778899]ID: %d  |  %s[/color]\n\n" % [
		info.get("id", 0),
		info.get("type_name", "")]

	# Owner
	bbcode += "[b]Owner:[/b] Player %d\n" % info.get("owner_id", 0)

	# Position
	bbcode += "[b]Position:[/b] (%d, %d)\n\n" % [info.get("pos_x", 0), info.get("pos_y", 0)]

	# Stats section
	bbcode += "[b][color=#88BBAA]--- STATS ---[/color][/b]\n"
	bbcode += "HP: %d / %d\n" % [info.get("hp", 0), info.get("hp_max", 0)]
	bbcode += "Armor: %d\n" % info.get("armor", 0)
	bbcode += "Speed: %d / %d\n" % [info.get("speed", 0), info.get("speed_max", 0)]
	bbcode += "Scan: %d\n" % info.get("scan", 0)

	# Combat
	var damage: int = info.get("damage", 0)
	if damage > 0 or info.get("range", 0) > 0:
		bbcode += "\n[b][color=#FF9988]--- COMBAT ---[/color][/b]\n"
		bbcode += "Damage: %d\n" % damage
		bbcode += "Range: %d\n" % info.get("range", 0)
		bbcode += "Shots: %d / %d\n" % [info.get("shots", 0), info.get("shots_max", 0)]
		bbcode += "Ammo: %d / %d\n" % [info.get("ammo", 0), info.get("ammo_max", 0)]

	# State
	bbcode += "\n[b][color=#8899CC]--- STATE ---[/color][/b]\n"
	if info.get("is_sentry", false):
		bbcode += "[color=#55FF77]Sentry Mode: ON[/color]\n"
	if info.get("is_manual_fire", false):
		bbcode += "[color=#FFaa44]Manual Fire: ON[/color]\n"
	if info.get("is_disabled", false):
		bbcode += "[color=#FF4444]DISABLED (%d turns remaining)[/color]\n" % info.get("disabled_turns", 0)
	if info.get("is_dated", false):
		bbcode += "[color=#AAAA44]DATED (can be upgraded)[/color]\n"

	# Experience (commando)
	var rank_name: String = info.get("rank_name", "")
	if rank_name != "":
		bbcode += "Rank: [b]%s[/b] (Level %d)\n" % [rank_name, info.get("rank", 0)]

	# Cargo
	var stored: int = info.get("stored_units", 0)
	if stored > 0:
		bbcode += "\nStored units: %d\n" % stored
	var res: int = info.get("stored_resources", 0)
	if res > 0:
		bbcode += "Stored resources: %d\n" % res

	# Version
	bbcode += "\n[color=#666688]Version: %d[/color]\n" % info.get("version", 0)

	# Description
	var desc: String = info.get("description", "")
	if desc != "":
		bbcode += "\n[i][color=#778899]%s[/color][/i]\n" % desc

	_unit_info_content.text = bbcode
	_unit_info_popup.popup_centered()


func update_resource_display(storage: Dictionary, production: Dictionary, needed: Dictionary, energy: Dictionary, credits: int) -> void:
	# Metal
	var metal_s: int = storage.get("metal", 0)
	var metal_max: int = storage.get("metal_max", 0)
	var metal_p: int = production.get("metal", 0)
	var metal_n: int = needed.get("metal", 0)
	var metal_net: int = metal_p - metal_n
	metal_label.text = "Metal: %d/%d  %s%d" % [metal_s, metal_max, "+" if metal_net >= 0 else "", metal_net]
	metal_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85) if metal_net >= 0 else Color(1.0, 0.5, 0.4))

	# Oil
	var oil_s: int = storage.get("oil", 0)
	var oil_max: int = storage.get("oil_max", 0)
	var oil_p: int = production.get("oil", 0)
	var oil_n: int = needed.get("oil", 0)
	var oil_net: int = oil_p - oil_n
	oil_label.text = "Oil: %d/%d  %s%d" % [oil_s, oil_max, "+" if oil_net >= 0 else "", oil_net]
	oil_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85) if oil_net >= 0 else Color(1.0, 0.5, 0.4))

	# Gold
	var gold_s: int = storage.get("gold", 0)
	var gold_max: int = storage.get("gold_max", 0)
	var gold_p: int = production.get("gold", 0)
	var gold_n: int = needed.get("gold", 0)
	var gold_net: int = gold_p - gold_n
	gold_label.text = "Gold: %d/%d  %s%d" % [gold_s, gold_max, "+" if gold_net >= 0 else "", gold_net]
	gold_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.3) if gold_net >= 0 else Color(1.0, 0.5, 0.4))

	# Energy
	var e_prod: int = energy.get("production", 0)
	var e_need: int = energy.get("need", 0)
	var e_net: int = e_prod - e_need
	energy_label.text = "Energy: %d/%d  %s%d" % [e_prod, e_need, "+" if e_net >= 0 else "", e_net]
	energy_label.add_theme_color_override("font_color", Color(0.3, 0.85, 1.0) if e_net >= 0 else Color(1.0, 0.4, 0.3))

	# Credits
	credits_label.text = "Credits: %d" % credits
	credits_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.3))


func update_selected_unit(info: Dictionary) -> void:
	unit_panel.visible = true

	# Icon
	if _sprite_cache and unit_icon:
		var type_name: String = info.get("type_name", info.get("name", ""))
		var is_vehicle: bool = not info.get("is_building", false)
		var icon: Texture2D = null
		if is_vehicle:
			icon = _sprite_cache.get_unit_icon(type_name, true)
			if not icon:
				icon = _sprite_cache.get_unit_info_icon(type_name, true)
		else:
			icon = _sprite_cache.get_unit_icon(type_name, false)
		if icon:
			unit_icon.texture = icon
		else:
			unit_icon.texture = null

	# Name and ID
	unit_name.text = info.get("name", "Unknown")
	unit_id_label.text = "ID: %d" % info.get("id", 0)

	# Stats line 1: HP, Armor, Speed
	var hp: int = info.get("hp", 0)
	var hp_max: int = info.get("hp_max", 0)
	var armor: int = info.get("armor", 0)
	var speed: int = info.get("speed", 0)
	var speed_max: int = info.get("speed_max", 0)
	unit_stats.text = "HP: %d/%d   Armor: %d   Speed: %d/%d" % [hp, hp_max, armor, speed, speed_max]

	# Color-code HP
	var hp_ratio := float(hp) / maxf(float(hp_max), 1.0)
	if hp_ratio > 0.6:
		unit_stats.add_theme_color_override("font_color", Color(0.7, 0.85, 0.75))
	elif hp_ratio > 0.3:
		unit_stats.add_theme_color_override("font_color", Color(0.9, 0.8, 0.3))
	else:
		unit_stats.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3))

	# Combat stats line
	var damage: int = info.get("damage", 0)
	var attack_range: int = info.get("range", 0)
	var shots: int = info.get("shots", 0)
	var shots_max: int = info.get("shots_max", 0)
	var ammo: int = info.get("ammo", 0)
	var ammo_max: int = info.get("ammo_max", 0)

	if damage > 0 or attack_range > 0:
		unit_combat.visible = true
		unit_combat.text = "Dmg: %d   Range: %d   Shots: %d/%d   Ammo: %d/%d" % [damage, attack_range, shots, shots_max, ammo, ammo_max]
		unit_combat.add_theme_color_override("font_color", Color(1.0, 0.6, 0.5))
	else:
		unit_combat.visible = false

	# Position
	unit_pos.text = "(%d, %d)" % [info.get("pos_x", 0), info.get("pos_y", 0)]

	# Extra info
	var extra: String = info.get("extra_info", "")
	if extra != "":
		unit_extra.visible = true
		unit_extra.text = extra
		unit_extra.add_theme_color_override("font_color", Color(0.6, 0.7, 0.9))
	else:
		unit_extra.visible = false

	# Build button
	build_button.visible = info.get("is_constructor", false)

	# --- Phase 20: Experience / dated status line ---
	if _unit_status_label:
		var status_parts: PackedStringArray = PackedStringArray()
		var rank_name: String = info.get("rank_name", "")
		if rank_name != "":
			status_parts.append("Rank: %s" % rank_name)
		if info.get("is_dated", false):
			status_parts.append("DATED")
		if info.get("is_disabled", false):
			status_parts.append("DISABLED")
		if status_parts.size() > 0:
			_unit_status_label.visible = true
			_unit_status_label.text = " | ".join(status_parts)
			if info.get("is_disabled", false):
				_unit_status_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3))
			elif info.get("is_dated", false):
				_unit_status_label.add_theme_color_override("font_color", Color(0.85, 0.8, 0.3))
			else:
				_unit_status_label.add_theme_color_override("font_color", Color(0.6, 0.85, 0.7))
		else:
			_unit_status_label.visible = false

	# --- Command buttons visibility ---
	var caps: Dictionary = info.get("capabilities", {})
	var is_own: bool = info.get("is_own", false)
	var is_bldg: bool = info.get("is_building", false)
	var is_sentry: bool = info.get("is_sentry", false)
	var is_mfire: bool = info.get("is_manual_fire", false)
	var is_working: bool = info.get("is_working", false)
	var stored_count: int = info.get("stored_units", 0)

	# Hide all command buttons first
	for btn in _cmd_buttons.values():
		btn.visible = false

	if is_own:
		# Combat toggles (for units with weapons)
		if caps.get("has_weapon", false):
			_show_cmd("sentry", "SENTRY ON" if is_sentry else "SENTRY", is_sentry)
			_show_cmd("manual_fire", "MANUAL ON" if is_mfire else "MANUAL", is_mfire)

		# Stop (if working or moving) / Cancel Build (if constructing)
		if info.get("is_constructing", false):
			_show_cmd("stop", "CANCEL BUILD", false)
		elif is_working:
			_show_cmd("stop", "STOP", false)

		# Phase 26: Path building (road/bridge/platform)
		if info.get("can_build_path", false) and not info.get("is_constructing", false):
			_show_cmd("path_build", "PATH BUILD", false)

		# Phase 31: Resume interrupted move
		if info.get("has_pending_move", false):
			_show_cmd("resume_move", "RESUME (F)", false)

		# Phase 31: Drive-and-fire indicator
		if info.get("can_drive_and_fire", false) and caps.get("has_weapon", false):
			pass  # Indicated in extra_info text rather than a separate button

		# Survey (auto-move for surveyors)
		if caps.get("can_survey", false):
			_show_cmd("survey", "SURVEY", false)

		# Mine layer/sweeper
		if caps.get("can_place_mines", false):
			_show_cmd("lay_mines", "MINES", false)
			_show_cmd("clear_mines", "SWEEP", false)

		# Clear rubble
		if caps.get("can_clear_area", false):
			_show_cmd("clear", "CLEAR", false)

		# Infiltrator
		if caps.get("can_capture", false) or caps.get("can_disable", false):
			if caps.get("can_capture", false):
				_show_cmd("steal", "STEAL", false)
			if caps.get("can_disable", false):
				_show_cmd("disable", "DISABLE", false)

		# Transport: load/unload
		if caps.get("can_store_units", false):
			_show_cmd("load", "LOAD", false)
			if stored_count > 0:
				_show_cmd("activate", "UNLOAD (%d)" % stored_count, false)

		# Supply: repair/reload
		if caps.get("can_repair", false):
			_show_cmd("repair", "REPAIR", false)
		if caps.get("can_rearm", false):
			_show_cmd("reload", "RELOAD", false)

		# Resources: transfer
		if caps.get("can_store_resources", false) and info.get("stored_resources", 0) > 0:
			_show_cmd("transfer", "TRANSFER", false)

		# Survey (for surveyor vehicles)
		if not is_bldg and caps.get("can_survey", false):
			_show_cmd("survey", "SURVEY", false)

		# Mining allocation (for mine buildings)
		if is_bldg and info.get("is_mine", false):
			_show_cmd("mining", "MINING", false)

		# Self-destruct (buildings only)
		if is_bldg and caps.get("can_self_destroy", false):
			_show_cmd("self_destroy", "DESTROY", false)

		# Upgrade (Phase 21) — shown if the unit can be upgraded (is_dated)
		if info.get("is_dated", false):
			if is_bldg:
				_show_cmd("upgrade_unit", "UPGRADE", false)
				_show_cmd("upgrade_all", "UPGRADE ALL", false)
			else:
				_show_cmd("upgrade_unit", "UPGRADE", false)

		# Rename (always available for own units)
		_show_cmd("rename", "RENAME", false)

	# Info button (always visible when any unit is selected)
	_show_cmd("info", "INFO", false)

	# --- Cargo display ---
	var cargo: Array = info.get("cargo_list", [])
	if cargo.size() > 0:
		_cargo_panel.visible = true
		_cargo_label.text = "Cargo (%d/%d):" % [cargo.size(), caps.get("storage_units_max", 0)]
		# Rebuild cargo list
		for child in _cargo_list.get_children():
			child.queue_free()
		for entry in cargo:
			var row := HBoxContainer.new()
			var name_lbl := Label.new()
			name_lbl.text = "%s" % entry.get("type_name", "?")
			name_lbl.add_theme_font_size_override("font_size", 11)
			name_lbl.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
			name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(name_lbl)
			var hp_lbl := Label.new()
			hp_lbl.text = "HP:%d/%d" % [entry.get("hp", 0), entry.get("hp_max", 0)]
			hp_lbl.add_theme_font_size_override("font_size", 10)
			hp_lbl.add_theme_color_override("font_color", Color(0.6, 0.7, 0.65))
			row.add_child(hp_lbl)
			_cargo_list.add_child(row)
	else:
		_cargo_panel.visible = false


func _show_cmd(cmd_name: String, label: String, active: bool) -> void:
	## Show a command button with the given label. If active, highlight it.
	var btn: Button = _cmd_buttons.get(cmd_name)
	if not btn:
		return
	btn.visible = true
	btn.text = label
	if active:
		btn.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
	else:
		btn.remove_theme_color_override("font_color")


func clear_selected_unit() -> void:
	unit_panel.visible = false
	if unit_icon:
		unit_icon.texture = null
	# Hide all command buttons
	for btn in _cmd_buttons.values():
		btn.visible = false
	if _cargo_panel:
		_cargo_panel.visible = false


func update_tile_info(tile: Vector2i, terrain: String) -> void:
	tile_label.text = "(%d, %d) %s" % [tile.x, tile.y, terrain]


func set_end_turn_enabled(enabled: bool) -> void:
	end_turn_button.disabled = not enabled


# =============================================================================
# DIALOG HELPERS (called by main_game.gd)
# =============================================================================

func show_rename_dialog(current_name: String) -> void:
	_rename_input.text = current_name
	_rename_dialog.popup_centered()
	_rename_input.grab_focus()
	_rename_input.select_all()


func show_transfer_dialog(max_amount: int) -> void:
	_transfer_slider.max_value = max_amount
	_transfer_slider.value = max_amount / 2
	_transfer_amount_label.text = "Amount: %d" % int(_transfer_slider.value)
	_transfer_dialog.popup_centered()


# =============================================================================
# PHASE 28: REPORTS & STATISTICS
# =============================================================================

# --- 28.1: Casualties Report Screen ---

func _create_casualties_panel() -> void:
	_casualties_panel = Window.new()
	_casualties_panel.title = "Casualties Report"
	_casualties_panel.size = Vector2i(580, 500)
	_casualties_panel.visible = false
	_casualties_panel.transient = true
	add_child(_casualties_panel)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_casualties_panel.add_child(margin)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 6)
	margin.add_child(main_vbox)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(scroll)

	_casualties_list = VBoxContainer.new()
	_casualties_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_casualties_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_casualties_list)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(100, 32)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.pressed.connect(func(): _casualties_panel.visible = false)
	main_vbox.add_child(close_btn)

	_casualties_panel.close_requested.connect(func(): _casualties_panel.visible = false)


func show_casualties_report(report: Array, player_names: Dictionary) -> void:
	## Populate and show the casualties report panel.
	## report: Array of {unit_type_id, unit_name, is_building, losses: [{player_id, player_name, count}], total_losses}
	## player_names: {player_id: {name, color}}
	if not _casualties_panel:
		return

	for child in _casualties_list.get_children():
		child.queue_free()

	if report.is_empty():
		var lbl := Label.new()
		lbl.text = "No casualties recorded yet."
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))
		_casualties_list.add_child(lbl)
		_casualties_panel.popup_centered()
		return

	# Header row
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	var h_type := Label.new()
	h_type.text = "Type"
	h_type.add_theme_font_size_override("font_size", 12)
	h_type.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
	h_type.custom_minimum_size.x = 100
	header.add_child(h_type)
	var h_name := Label.new()
	h_name.text = "Unit"
	h_name.add_theme_font_size_override("font_size", 12)
	h_name.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
	h_name.custom_minimum_size.x = 140
	h_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(h_name)
	var h_total := Label.new()
	h_total.text = "Total"
	h_total.add_theme_font_size_override("font_size", 12)
	h_total.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
	h_total.custom_minimum_size.x = 50
	header.add_child(h_total)
	var h_detail := Label.new()
	h_detail.text = "By Player"
	h_detail.add_theme_font_size_override("font_size", 12)
	h_detail.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
	h_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(h_detail)
	_casualties_list.add_child(header)

	# Separator
	var sep := HSeparator.new()
	_casualties_list.add_child(sep)

	for entry in report:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var type_lbl := Label.new()
		type_lbl.text = "Building" if entry.get("is_building", false) else "Vehicle"
		type_lbl.add_theme_font_size_override("font_size", 12)
		type_lbl.add_theme_color_override("font_color",
			Color(0.7, 0.5, 0.3) if entry.get("is_building", false) else Color(0.3, 0.7, 0.5))
		type_lbl.custom_minimum_size.x = 100
		row.add_child(type_lbl)

		var name_lbl := Label.new()
		name_lbl.text = entry.get("unit_name", "Unknown")
		name_lbl.add_theme_font_size_override("font_size", 12)
		name_lbl.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
		name_lbl.custom_minimum_size.x = 140
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_lbl)

		var total_lbl := Label.new()
		total_lbl.text = str(entry.get("total_losses", 0))
		total_lbl.add_theme_font_size_override("font_size", 12)
		total_lbl.add_theme_color_override("font_color", Color(1.0, 0.5, 0.4))
		total_lbl.custom_minimum_size.x = 50
		row.add_child(total_lbl)

		# Per-player breakdown
		var detail_lbl := Label.new()
		var parts: PackedStringArray = PackedStringArray()
		for loss in entry.get("losses", []):
			var pid: int = loss.get("player_id", -1)
			var pname: String = loss.get("player_name", "P%d" % pid)
			parts.append("%s: %d" % [pname, loss.get("count", 0)])
		detail_lbl.text = "  |  ".join(parts)
		detail_lbl.add_theme_font_size_override("font_size", 11)
		detail_lbl.add_theme_color_override("font_color", Color(0.65, 0.7, 0.75))
		detail_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(detail_lbl)

		_casualties_list.add_child(row)

	_casualties_panel.popup_centered()


# --- 28.2: Player Statistics Panel ---

func _create_player_stats_panel() -> void:
	_player_stats_panel = Window.new()
	_player_stats_panel.title = "Player Statistics"
	_player_stats_panel.size = Vector2i(620, 480)
	_player_stats_panel.visible = false
	_player_stats_panel.transient = true
	add_child(_player_stats_panel)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_player_stats_panel.add_child(margin)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 6)
	margin.add_child(main_vbox)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(scroll)

	_player_stats_list = VBoxContainer.new()
	_player_stats_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_player_stats_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_player_stats_list)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(100, 32)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.pressed.connect(func(): _player_stats_panel.visible = false)
	main_vbox.add_child(close_btn)

	_player_stats_panel.close_requested.connect(func(): _player_stats_panel.visible = false)


func show_player_stats(players: Array) -> void:
	## Populate and show the player statistics panel.
	## players: Array of Dictionaries with keys:
	##   name, color, score, built_vehicles, lost_vehicles, built_buildings, lost_buildings,
	##   vehicles_alive, buildings_alive, eco_spheres, total_upgrade_cost, is_defeated
	if not _player_stats_panel:
		return

	for child in _player_stats_list.get_children():
		child.queue_free()

	for p in players:
		var frame := PanelContainer.new()
		_player_stats_list.add_child(frame)

		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 3)
		frame.add_child(vbox)

		# Player header
		var header := Label.new()
		var defeated_str: String = "  [DEFEATED]" if p.get("is_defeated", false) else ""
		header.text = "%s%s" % [p.get("name", "Unknown"), defeated_str]
		header.add_theme_font_size_override("font_size", 15)
		header.add_theme_color_override("font_color", p.get("color", Color(0.8, 0.85, 0.9)))
		vbox.add_child(header)

		# Score
		var score_lbl := Label.new()
		score_lbl.text = "Score: %d" % p.get("score", 0)
		score_lbl.add_theme_font_size_override("font_size", 13)
		score_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
		vbox.add_child(score_lbl)

		# Built / Lost
		var tally_lbl := Label.new()
		tally_lbl.text = "Vehicles: +%d built / -%d lost  |  Buildings: +%d built / -%d lost" % [
			p.get("built_vehicles", 0), p.get("lost_vehicles", 0),
			p.get("built_buildings", 0), p.get("lost_buildings", 0)]
		tally_lbl.add_theme_font_size_override("font_size", 12)
		tally_lbl.add_theme_color_override("font_color", Color(0.7, 0.8, 0.85))
		vbox.add_child(tally_lbl)

		# Alive
		var alive_lbl := Label.new()
		alive_lbl.text = "Alive: %d vehicles, %d buildings" % [
			p.get("vehicles_alive", 0), p.get("buildings_alive", 0)]
		alive_lbl.add_theme_font_size_override("font_size", 12)
		alive_lbl.add_theme_color_override("font_color", Color(0.5, 0.8, 0.6))
		vbox.add_child(alive_lbl)

		# Extra details
		var extra_parts: PackedStringArray = PackedStringArray()
		var eco: int = p.get("eco_spheres", 0)
		if eco > 0:
			extra_parts.append("Eco Spheres: %d" % eco)
		var upg: int = p.get("total_upgrade_cost", 0)
		if upg > 0:
			extra_parts.append("Upgrade Cost: %d gold" % upg)
		var factories: int = p.get("built_factories", 0)
		if factories > 0:
			extra_parts.append("Factories Built: %d" % factories)
		var mines: int = p.get("built_mines", 0)
		if mines > 0:
			extra_parts.append("Mines Built: %d" % mines)
		if extra_parts.size() > 0:
			var extra_lbl := Label.new()
			extra_lbl.text = "  |  ".join(extra_parts)
			extra_lbl.add_theme_font_size_override("font_size", 11)
			extra_lbl.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))
			vbox.add_child(extra_lbl)

	_player_stats_panel.popup_centered()


# --- 28.3: Army Overview (Filterable Unit List) ---

func _create_army_panel() -> void:
	_army_panel = Window.new()
	_army_panel.title = "Army Overview"
	_army_panel.size = Vector2i(640, 520)
	_army_panel.visible = false
	_army_panel.transient = true
	add_child(_army_panel)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_army_panel.add_child(margin)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 6)
	margin.add_child(main_vbox)

	# Filter bar
	var filter_bar := HBoxContainer.new()
	filter_bar.add_theme_constant_override("separation", 8)
	main_vbox.add_child(filter_bar)

	var filter_label := Label.new()
	filter_label.text = "Filter:"
	filter_label.add_theme_font_size_override("font_size", 13)
	filter_bar.add_child(filter_label)

	_army_filter_option = OptionButton.new()
	_army_filter_option.add_item("All Units", 0)
	_army_filter_option.add_item("Vehicles Only", 1)
	_army_filter_option.add_item("Buildings Only", 2)
	_army_filter_option.add_item("Combat Units", 3)
	_army_filter_option.add_item("Damaged", 4)
	_army_filter_option.add_item("Idle", 5)
	_army_filter_option.add_theme_font_size_override("font_size", 12)
	_army_filter_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	filter_bar.add_child(_army_filter_option)

	# Totals row
	var _army_total_label := Label.new()
	_army_total_label.name = "TotalLabel"
	_army_total_label.add_theme_font_size_override("font_size", 12)
	_army_total_label.add_theme_color_override("font_color", Color(0.5, 0.65, 0.75))
	main_vbox.add_child(_army_total_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(scroll)

	_army_list = VBoxContainer.new()
	_army_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_army_list.add_theme_constant_override("separation", 2)
	scroll.add_child(_army_list)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	main_vbox.add_child(btn_row)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(100, 32)
	close_btn.pressed.connect(func(): _army_panel.visible = false)
	btn_row.add_child(close_btn)

	_army_panel.close_requested.connect(func(): _army_panel.visible = false)


func show_army_overview(units: Array) -> void:
	## Populate and show the army overview.
	## units: Array of Dictionaries with keys:
	##   id, name, type_name, is_building, hp, hp_max, ammo, ammo_max, position,
	##   is_working, is_disabled, is_sentry, can_attack, damage, armor, speed
	if not _army_panel:
		return

	# Store units for filtering
	_army_panel.set_meta("all_units", units)

	# Connect filter change if not already
	if not _army_filter_option.is_connected("item_selected", _on_army_filter_changed):
		_army_filter_option.item_selected.connect(_on_army_filter_changed)

	_army_filter_option.select(0)
	_populate_army_list(units)
	_army_panel.popup_centered()


func _on_army_filter_changed(_index: int) -> void:
	if not _army_panel or not _army_panel.has_meta("all_units"):
		return
	var all_units: Array = _army_panel.get_meta("all_units")
	var filter_id: int = _army_filter_option.get_selected_id()

	var filtered: Array = []
	for u in all_units:
		match filter_id:
			0:  # All
				filtered.append(u)
			1:  # Vehicles
				if not u.get("is_building", false):
					filtered.append(u)
			2:  # Buildings
				if u.get("is_building", false):
					filtered.append(u)
			3:  # Combat
				if u.get("can_attack", false):
					filtered.append(u)
			4:  # Damaged
				if u.get("hp", 0) < u.get("hp_max", 1):
					filtered.append(u)
			5:  # Idle
				if not u.get("is_working", false) and not u.get("is_sentry", false) and not u.get("is_disabled", false):
					filtered.append(u)
	_populate_army_list(filtered)


func _populate_army_list(units: Array) -> void:
	if not _army_list:
		return

	for child in _army_list.get_children():
		child.queue_free()

	# Update totals label
	var total_lbl = _army_panel.find_child("TotalLabel", true, false)
	if total_lbl:
		var vehicles := 0
		var buildings := 0
		for u in units:
			if u.get("is_building", false):
				buildings += 1
			else:
				vehicles += 1
		total_lbl.text = "Showing %d units (%d vehicles, %d buildings)" % [units.size(), vehicles, buildings]

	if units.is_empty():
		var lbl := Label.new()
		lbl.text = "No units match the current filter."
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))
		_army_list.add_child(lbl)
		return

	# Header
	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 4)
	for col in [["Name", 160], ["HP", 70], ["Dmg", 40], ["Arm", 40], ["Ammo", 55], ["Spd", 40], ["Status", 80], ["Pos", 70]]:
		var l := Label.new()
		l.text = col[0]
		l.add_theme_font_size_override("font_size", 11)
		l.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
		l.custom_minimum_size.x = col[1]
		if col[0] == "Name":
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hdr.add_child(l)
	_army_list.add_child(hdr)
	_army_list.add_child(HSeparator.new())

	for u in units:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)

		# Name
		var name_lbl := Label.new()
		var display_name: String = u.get("name", u.get("type_name", "?"))
		if display_name.is_empty():
			display_name = u.get("type_name", "?")
		name_lbl.text = display_name
		name_lbl.add_theme_font_size_override("font_size", 11)
		name_lbl.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
		name_lbl.custom_minimum_size.x = 160
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.clip_text = true
		row.add_child(name_lbl)

		# HP bar
		var hp: int = u.get("hp", 0)
		var hp_max: int = u.get("hp_max", 1)
		var hp_lbl := Label.new()
		hp_lbl.text = "%d/%d" % [hp, hp_max]
		hp_lbl.add_theme_font_size_override("font_size", 11)
		var hp_ratio: float = float(hp) / max(hp_max, 1)
		if hp_ratio > 0.6:
			hp_lbl.add_theme_color_override("font_color", Color(0.4, 0.85, 0.5))
		elif hp_ratio > 0.3:
			hp_lbl.add_theme_color_override("font_color", Color(0.9, 0.8, 0.3))
		else:
			hp_lbl.add_theme_color_override("font_color", Color(1.0, 0.4, 0.35))
		hp_lbl.custom_minimum_size.x = 70
		row.add_child(hp_lbl)

		# Damage
		var dmg_lbl := Label.new()
		dmg_lbl.text = str(u.get("damage", 0))
		dmg_lbl.add_theme_font_size_override("font_size", 11)
		dmg_lbl.add_theme_color_override("font_color", Color(0.75, 0.65, 0.6))
		dmg_lbl.custom_minimum_size.x = 40
		row.add_child(dmg_lbl)

		# Armor
		var arm_lbl := Label.new()
		arm_lbl.text = str(u.get("armor", 0))
		arm_lbl.add_theme_font_size_override("font_size", 11)
		arm_lbl.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
		arm_lbl.custom_minimum_size.x = 40
		row.add_child(arm_lbl)

		# Ammo
		var ammo_lbl := Label.new()
		var ammo: int = u.get("ammo", 0)
		var ammo_max: int = u.get("ammo_max", 0)
		ammo_lbl.text = "%d/%d" % [ammo, ammo_max] if ammo_max > 0 else "-"
		ammo_lbl.add_theme_font_size_override("font_size", 11)
		ammo_lbl.add_theme_color_override("font_color", Color(0.65, 0.7, 0.75))
		ammo_lbl.custom_minimum_size.x = 55
		row.add_child(ammo_lbl)

		# Speed
		var spd_lbl := Label.new()
		spd_lbl.text = str(u.get("speed", 0))
		spd_lbl.add_theme_font_size_override("font_size", 11)
		spd_lbl.add_theme_color_override("font_color", Color(0.65, 0.75, 0.7))
		spd_lbl.custom_minimum_size.x = 40
		row.add_child(spd_lbl)

		# Status
		var status_lbl := Label.new()
		var status_parts: PackedStringArray = PackedStringArray()
		if u.get("is_disabled", false):
			status_parts.append("DIS")
		if u.get("is_sentry", false):
			status_parts.append("SNT")
		if u.get("is_working", false):
			status_parts.append("WRK")
		status_lbl.text = " ".join(status_parts) if status_parts.size() > 0 else "OK"
		status_lbl.add_theme_font_size_override("font_size", 10)
		if u.get("is_disabled", false):
			status_lbl.add_theme_color_override("font_color", Color(1.0, 0.4, 0.35))
		elif status_parts.size() > 0:
			status_lbl.add_theme_color_override("font_color", Color(0.8, 0.7, 0.3))
		else:
			status_lbl.add_theme_color_override("font_color", Color(0.5, 0.7, 0.55))
		status_lbl.custom_minimum_size.x = 80
		row.add_child(status_lbl)

		# Position + jump button
		var pos: Vector2i = u.get("position", Vector2i(-1, -1))
		var pos_lbl := Label.new()
		pos_lbl.text = "(%d,%d)" % [pos.x, pos.y]
		pos_lbl.add_theme_font_size_override("font_size", 10)
		pos_lbl.add_theme_color_override("font_color", Color(0.55, 0.6, 0.65))
		pos_lbl.custom_minimum_size.x = 55
		row.add_child(pos_lbl)

		if pos != Vector2i(-1, -1):
			var jump_btn := Button.new()
			jump_btn.text = ">"
			jump_btn.custom_minimum_size = Vector2(24, 20)
			jump_btn.add_theme_font_size_override("font_size", 10)
			jump_btn.tooltip_text = "Jump to unit"
			var pos_copy := pos
			jump_btn.pressed.connect(func(): jump_to_position.emit(pos_copy))
			row.add_child(jump_btn)

		_army_list.add_child(row)


# --- 28.4: Economy Summary ---

func _create_economy_panel() -> void:
	_economy_panel = Window.new()
	_economy_panel.title = "Economy Summary"
	_economy_panel.size = Vector2i(500, 420)
	_economy_panel.visible = false
	_economy_panel.transient = true
	add_child(_economy_panel)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_economy_panel.add_child(margin)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 6)
	margin.add_child(main_vbox)

	_economy_content = VBoxContainer.new()
	_economy_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_economy_content.add_theme_constant_override("separation", 8)
	main_vbox.add_child(_economy_content)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(100, 32)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.pressed.connect(func(): _economy_panel.visible = false)
	main_vbox.add_child(close_btn)

	_economy_panel.close_requested.connect(func(): _economy_panel.visible = false)


func show_economy_summary(economy: Dictionary) -> void:
	## Populate and show the economy summary panel.
	## economy: Dictionary from GamePlayer.get_economy_summary()
	##   {credits, resources: {metal, oil, gold, metal_max, oil_max, gold_max},
	##    production: {metal, oil, gold}, needed: {metal, oil, gold},
	##    energy: {production, need, max_production, max_need},
	##    humans: {production, need, max_need},
	##    research: {attack, shots, range, armor, hitpoints, speed, scan, cost}}
	if not _economy_panel:
		return

	for child in _economy_content.get_children():
		child.queue_free()

	# Title
	var title := Label.new()
	title.text = "Economy Overview"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.3, 0.85, 1.0))
	_economy_content.add_child(title)

	# Credits
	var credits_lbl := Label.new()
	credits_lbl.text = "Credits: %d" % economy.get("credits", 0)
	credits_lbl.add_theme_font_size_override("font_size", 14)
	credits_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	_economy_content.add_child(credits_lbl)

	_economy_content.add_child(HSeparator.new())

	# Resources section
	var res: Dictionary = economy.get("resources", {})
	var prod: Dictionary = economy.get("production", {})
	var need: Dictionary = economy.get("needed", {})

	var res_header := Label.new()
	res_header.text = "Resources"
	res_header.add_theme_font_size_override("font_size", 14)
	res_header.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	_economy_content.add_child(res_header)

	for rtype in ["metal", "oil", "gold"]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)

		var type_lbl := Label.new()
		type_lbl.text = rtype.capitalize()
		type_lbl.add_theme_font_size_override("font_size", 13)
		type_lbl.custom_minimum_size.x = 60
		row.add_child(type_lbl)

		var storage_lbl := Label.new()
		storage_lbl.text = "Storage: %d / %d" % [res.get(rtype, 0), res.get(rtype + "_max", 0)]
		storage_lbl.add_theme_font_size_override("font_size", 12)
		storage_lbl.add_theme_color_override("font_color", Color(0.7, 0.8, 0.85))
		storage_lbl.custom_minimum_size.x = 150
		row.add_child(storage_lbl)

		var net_val: int = prod.get(rtype, 0) - need.get(rtype, 0)
		var net_lbl := Label.new()
		net_lbl.text = "Net: %s%d  (P:%d / N:%d)" % [
			"+" if net_val >= 0 else "", net_val,
			prod.get(rtype, 0), need.get(rtype, 0)]
		net_lbl.add_theme_font_size_override("font_size", 12)
		net_lbl.add_theme_color_override("font_color",
			Color(0.4, 0.85, 0.5) if net_val >= 0 else Color(1.0, 0.5, 0.4))
		net_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(net_lbl)

		_economy_content.add_child(row)

	_economy_content.add_child(HSeparator.new())

	# Energy
	var energy: Dictionary = economy.get("energy", {})
	var e_prod: int = energy.get("production", 0)
	var e_need: int = energy.get("need", 0)
	var e_net: int = e_prod - e_need
	var energy_lbl := Label.new()
	energy_lbl.text = "Energy:  Production %d  |  Need %d  |  Net %s%d" % [
		e_prod, e_need, "+" if e_net >= 0 else "", e_net]
	energy_lbl.add_theme_font_size_override("font_size", 13)
	energy_lbl.add_theme_color_override("font_color",
		Color(0.3, 0.85, 1.0) if e_net >= 0 else Color(1.0, 0.4, 0.35))
	_economy_content.add_child(energy_lbl)

	# Humans
	var humans: Dictionary = economy.get("humans", {})
	var h_prod: int = humans.get("production", 0)
	var h_need: int = humans.get("need", 0)
	var h_net: int = h_prod - h_need
	var humans_lbl := Label.new()
	humans_lbl.text = "Humans:  Available %d  |  Need %d  |  Net %s%d" % [
		h_prod, h_need, "+" if h_net >= 0 else "", h_net]
	humans_lbl.add_theme_font_size_override("font_size", 13)
	humans_lbl.add_theme_color_override("font_color",
		Color(0.5, 0.8, 0.6) if h_net >= 0 else Color(1.0, 0.5, 0.4))
	_economy_content.add_child(humans_lbl)

	_economy_content.add_child(HSeparator.new())

	# Research levels
	var research: Dictionary = economy.get("research", {})
	if not research.is_empty():
		var research_header := Label.new()
		research_header.text = "Research Levels"
		research_header.add_theme_font_size_override("font_size", 14)
		research_header.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
		_economy_content.add_child(research_header)

		var areas := ["attack", "shots", "range", "armor", "hitpoints", "speed", "scan", "cost"]
		var res_grid := GridContainer.new()
		res_grid.columns = 4
		res_grid.add_theme_constant_override("h_separation", 16)
		res_grid.add_theme_constant_override("v_separation", 4)
		for area in areas:
			var lbl := Label.new()
			lbl.text = "%s: %d" % [area.capitalize(), research.get(area, 0)]
			lbl.add_theme_font_size_override("font_size", 12)
			lbl.add_theme_color_override("font_color", Color(0.65, 0.75, 0.8))
			res_grid.add_child(lbl)
		_economy_content.add_child(res_grid)

	_economy_panel.popup_centered()
