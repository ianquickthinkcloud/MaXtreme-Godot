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


func _ready() -> void:
	end_turn_button.pressed.connect(func(): end_turn_pressed.emit())
	build_button.pressed.connect(func(): build_pressed.emit())
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
	btn.pressed.connect(func(): command_pressed.emit(cmd_name))
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
	cmd_grid_3.add_child(_create_cmd_button("upgrade_unit", "UPGRADE", "Upgrade this unit to the latest version"))
	cmd_grid_3.add_child(_create_cmd_button("upgrade_all", "UPGRADE ALL", "Upgrade all buildings of this type"))
	cmd_grid_3.add_child(_create_cmd_button("info", "INFO", "Open detailed unit information"))


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
	_research_notification_label.visible = true
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
	## Show score in top bar (only for Points victory games).
	if not _score_label:
		return
	if victory_type == "points" and target_points > 0:
		_score_label.text = "Score: %d / %d" % [score, target_points]
		_score_label.visible = true
		if score >= target_points:
			_score_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
		else:
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

		# Stop (if working or moving)
		if is_working:
			_show_cmd("stop", "STOP", false)

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
