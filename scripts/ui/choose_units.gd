extends Control
## Choose Units Screen — Players spend starting credits to buy vehicles.
## For Hot Seat: each player goes through this screen in sequence.
## For single-player / simultaneous: all players shop sequentially before game start.

@onready var title_label: Label = %TitleLabel
@onready var credits_label: Label = %CreditsLabel
@onready var unit_list: ItemList = %UnitList
@onready var unit_info_panel: VBoxContainer = %UnitInfoPanel
@onready var roster_list: ItemList = %RosterList
@onready var add_button: Button = %AddButton
@onready var remove_button: Button = %RemoveButton
@onready var done_button: Button = %DoneButton
@onready var status_label: Label = %StatusLabel
@onready var free_units_label: Label = %FreeUnitsLabel

# Engine instance for data queries
var _engine: Node = null

# All purchasable vehicle data from the engine
var _all_vehicles: Array = []
# Filtered list (excluding aliens if alien tech is off)
var _vehicles: Array = []

# Current player being configured
var _current_player_idx := 0
var _player_count := 0
var _player_names: Array = []
var _player_clans: Array = []
var _is_hotseat := false

# Budget
var _start_credits := 150
var _credits_remaining := 150
var _bridgehead_type := "mobile"

# Free initial units (for Definite bridgehead)
var _free_units: Array = []
# Units the player has purchased (Array of Dictionaries)
var _roster: Array = []

# Info labels in the unit info panel
var _info_labels: Dictionary = {}


func _ready() -> void:
	add_button.pressed.connect(_on_add)
	remove_button.pressed.connect(_on_remove)
	done_button.pressed.connect(_on_done)
	unit_list.item_selected.connect(_on_unit_selected)

	# Read config from GameManager
	var config: Dictionary = GameManager.game_config
	_player_count = config.get("player_names", []).size()
	_player_names = config.get("player_names", [])
	_player_clans = config.get("player_clans", [])
	_start_credits = config.get("start_credits", 150)
	_bridgehead_type = config.get("bridgehead_type", "mobile")
	_is_hotseat = config.get("game_type", "") == "hotseat"
	_current_player_idx = GameManager.pregame_current_player

	# Create engine for data queries
	_engine = ClassDB.instantiate("GameEngine")
	if _engine:
		add_child(_engine)
		_engine.load_game_data()

	_build_info_panel()
	_load_player_data()


func _exit_tree() -> void:
	if _engine:
		_engine.queue_free()
		_engine = null


func _load_player_data() -> void:
	## Set up the screen for the current player.
	var player_name: String = _player_names[_current_player_idx] if _current_player_idx < _player_names.size() else "Player"
	var clan: int = _player_clans[_current_player_idx] if _current_player_idx < _player_clans.size() else -1

	title_label.text = "%s — Choose Your Units" % player_name

	# Get purchasable vehicles from engine
	if _engine:
		_all_vehicles = _engine.get_purchasable_vehicles(clan)

	# Filter: exclude aliens if alien tech is off
	var alien_enabled: bool = GameManager.game_config.get("alien_enabled", false)
	_vehicles.clear()
	for v in _all_vehicles:
		if not alien_enabled and v.get("is_alien", false):
			continue
		_vehicles.append(v)

	# Sort by cost ascending
	_vehicles.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.get("cost", 0) < b.get("cost", 0))

	# Populate unit list
	unit_list.clear()
	for v in _vehicles:
		var cost: int = v.get("cost", 0)
		var unit_name: String = v.get("name", "?")
		unit_list.add_item("%s  (%d)" % [unit_name, cost])

	# Get free units for Definite bridgehead
	_free_units.clear()
	if _engine and _bridgehead_type == "definite":
		_free_units = _engine.get_initial_landing_units(clan, _start_credits, _bridgehead_type)

	# Display free units
	if _free_units.size() > 0:
		var free_text := "Free units: "
		var names: Array = []
		for fu in _free_units:
			names.append(fu.get("name", "?"))
		free_text += ", ".join(names)
		free_units_label.text = free_text
		free_units_label.visible = true
	else:
		free_units_label.text = ""
		free_units_label.visible = false

	# Reset roster and credits
	_roster.clear()
	_credits_remaining = _start_credits
	_refresh_roster_display()
	_update_credits_display()

	if _bridgehead_type == "mobile":
		status_label.text = "Mobile bridgehead: buy all your starting vehicles."
	else:
		status_label.text = "Definite bridgehead: free base units included. Buy additional vehicles."


func _build_info_panel() -> void:
	## Create stat labels inside the info panel.
	for child in unit_info_panel.get_children():
		child.queue_free()
	_info_labels.clear()

	var stats := ["Name", "Cost", "HP", "Armor", "Damage", "Range", "Speed", "Scan", "Shots", "Ammo", "Surface", "Description"]
	for stat_name in stats:
		var row := HBoxContainer.new()
		var key_lbl := Label.new()
		key_lbl.text = stat_name + ":"
		key_lbl.custom_minimum_size = Vector2(90, 0)
		key_lbl.add_theme_font_size_override("font_size", 13)
		row.add_child(key_lbl)

		var val_lbl := Label.new()
		val_lbl.text = "—"
		val_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		val_lbl.add_theme_font_size_override("font_size", 13)
		val_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(val_lbl)

		unit_info_panel.add_child(row)
		_info_labels[stat_name] = val_lbl


func _on_unit_selected(index: int) -> void:
	if index < 0 or index >= _vehicles.size():
		return
	var v: Dictionary = _vehicles[index]
	_info_labels["Name"].text = v.get("name", "?")
	_info_labels["Cost"].text = str(v.get("cost", 0))
	_info_labels["HP"].text = str(v.get("hitpoints", 0))
	_info_labels["Armor"].text = str(v.get("armor", 0))
	_info_labels["Damage"].text = str(v.get("damage", 0))
	_info_labels["Range"].text = str(v.get("range", 0))
	_info_labels["Speed"].text = str(v.get("speed", 0))
	_info_labels["Scan"].text = str(v.get("scan", 0))
	_info_labels["Shots"].text = str(v.get("shots", 0))
	_info_labels["Ammo"].text = str(v.get("ammo", 0))
	_info_labels["Surface"].text = v.get("surface", "ground")
	_info_labels["Description"].text = v.get("description", "")


func _on_add() -> void:
	var selected := unit_list.get_selected_items()
	if selected.size() == 0:
		status_label.text = "Select a unit type to add."
		return

	var idx: int = selected[0]
	if idx < 0 or idx >= _vehicles.size():
		return

	var v: Dictionary = _vehicles[idx]
	var cost: int = v.get("cost", 0)

	if cost > _credits_remaining:
		status_label.text = "Not enough credits! Need %d, have %d." % [cost, _credits_remaining]
		return

	# Add to roster
	var entry := {
		"id_first": v.get("id_first", 0),
		"id_second": v.get("id_second", 0),
		"name": v.get("name", "?"),
		"cost": cost,
		"cargo": 0,
	}
	_roster.append(entry)
	_credits_remaining -= cost
	_update_credits_display()
	_refresh_roster_display()
	status_label.text = "Added %s. %d credits remaining." % [entry["name"], _credits_remaining]


func _on_remove() -> void:
	var selected := roster_list.get_selected_items()
	if selected.size() == 0:
		status_label.text = "Select a unit from your roster to remove."
		return

	var idx: int = selected[0]
	if idx < 0 or idx >= _roster.size():
		return

	var entry: Dictionary = _roster[idx]
	_credits_remaining += entry.get("cost", 0)
	_roster.remove_at(idx)
	_update_credits_display()
	_refresh_roster_display()
	status_label.text = "Removed %s. %d credits remaining." % [entry.get("name", "?"), _credits_remaining]


func _refresh_roster_display() -> void:
	roster_list.clear()
	for entry in _roster:
		var cost: int = entry.get("cost", 0)
		roster_list.add_item("%s  (%d)" % [entry.get("name", "?"), cost])

	# Show total
	var total_cost := _start_credits - _credits_remaining
	done_button.text = "Done (%d / %d credits spent)" % [total_cost, _start_credits]


func _update_credits_display() -> void:
	credits_label.text = "Credits: %d / %d" % [_credits_remaining, _start_credits]
	if _credits_remaining < 0:
		credits_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	elif _credits_remaining < _start_credits * 0.2:
		credits_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	else:
		credits_label.remove_theme_color_override("font_color")


func _on_done() -> void:
	# Validate: player must have at least one unit (or get free units for definite bridgehead)
	if _roster.size() == 0 and _free_units.size() == 0:
		status_label.text = "You must purchase at least one unit!"
		return

	# Build the full unit list: free units + purchased units
	var full_roster: Array = []

	# Add free units first (Definite bridgehead)
	for fu in _free_units:
		full_roster.append({
			"id_first": fu.get("id_first", 0),
			"id_second": fu.get("id_second", 0),
			"cargo": fu.get("cargo", 0),
			"cost": 0,  # Free units don't cost anything
		})

	# Add purchased units
	for entry in _roster:
		full_roster.append({
			"id_first": entry.get("id_first", 0),
			"id_second": entry.get("id_second", 0),
			"cargo": entry.get("cargo", 0),
			"cost": entry.get("cost", 0),
		})

	# Store in GameManager
	GameManager.pregame_landing_units[_current_player_idx] = full_roster

	# Advance to next player or proceed to landing selection
	_current_player_idx += 1

	if _current_player_idx < _player_count:
		# More players need to shop
		GameManager.pregame_current_player = _current_player_idx
		if _is_hotseat:
			# Show a transition screen before the next player shops
			_show_transition(_current_player_idx)
		else:
			# For non-hotseat (simultaneous/turn-based), just reload for next player
			_load_player_data()
	else:
		# All players done — proceed to landing position selection
		GameManager.pregame_current_player = 0
		GameManager.advance_pregame_to_landing()


func _show_transition(next_player_idx: int) -> void:
	## Show a full-screen transition for hot seat between player shopping turns.
	var overlay := ColorRect.new()
	overlay.color = Color(0.05, 0.05, 0.12, 1.0)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 100
	add_child(overlay)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	overlay.add_child(vbox)

	var next_name: String = _player_names[next_player_idx] if next_player_idx < _player_names.size() else "Player"
	var lbl := Label.new()
	lbl.text = "Pass to %s" % next_name
	lbl.add_theme_font_size_override("font_size", 32)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(lbl)

	var sub := Label.new()
	sub.text = "Choose your starting units"
	sub.add_theme_font_size_override("font_size", 18)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.modulate = Color(0.7, 0.7, 0.7)
	vbox.add_child(sub)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	vbox.add_child(spacer)

	var ready_btn := Button.new()
	ready_btn.text = "READY"
	ready_btn.custom_minimum_size = Vector2(200, 50)
	ready_btn.pressed.connect(func() -> void:
		overlay.queue_free()
		_load_player_data()
	)
	vbox.add_child(ready_btn)
