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


func _ready() -> void:
	end_turn_button.pressed.connect(func(): end_turn_pressed.emit())
	build_button.pressed.connect(func(): build_pressed.emit())
	unit_panel.visible = false
	_create_command_buttons()
	_create_cargo_panel()
	_create_rename_dialog()
	_create_transfer_dialog()


func set_sprite_cache(cache) -> void:
	_sprite_cache = cache


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

		# Rename (always available for own units)
		_show_cmd("rename", "RENAME", false)

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
