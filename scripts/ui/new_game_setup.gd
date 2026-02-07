extends Control
## New Game Setup -- Configure map, players, game type, victory, resources, and more.

@onready var map_list: ItemList = %MapList
@onready var map_preview_label: Label = %MapPreviewLabel
@onready var player_container: VBoxContainer = %PlayerContainer
@onready var credits_spinbox: SpinBox = %CreditsSpinBox
@onready var start_button: Button = %StartButton
@onready var back_button: Button = %BackButton
@onready var status_label: Label = %StatusLabel

# These nodes are created programmatically in _setup_game_settings_ui()
var _game_type_option: OptionButton = null
var _victory_option: OptionButton = null
var _victory_turns_spin: SpinBox = null
var _victory_points_spin: SpinBox = null
var _bridgehead_option: OptionButton = null
var _alien_check: CheckBox = null
var _metal_option: OptionButton = null
var _oil_option: OptionButton = null
var _gold_option: OptionButton = null
var _density_option: OptionButton = null
var _turn_limit_check: CheckBox = null
var _turn_limit_spin: SpinBox = null
var _turn_deadline_check: CheckBox = null
var _turn_deadline_spin: SpinBox = null
var _title_label: Label = null

# Data loaded from engine
var _available_maps: Array = []
var _available_clans: Array = []
var _player_rows: Array = []  # Array of dictionaries with UI references

# Temporary engine instance for data loading
var _temp_engine: Node = null

# Game type preset from GameManager (e.g. "hotseat" from main menu)
var _preset_game_type: String = ""

const MAX_PLAYERS := 8
const DEFAULT_CREDITS := 150
const PLAYER_COLORS := [
	Color(0.2, 0.4, 1.0),    # Blue
	Color(1.0, 0.2, 0.2),    # Red
	Color(0.2, 0.8, 0.2),    # Green
	Color(1.0, 0.8, 0.0),    # Yellow
	Color(0.8, 0.2, 0.8),    # Purple
	Color(1.0, 0.5, 0.0),    # Orange
	Color(0.0, 0.8, 0.8),    # Cyan
	Color(0.6, 0.6, 0.6),    # Gray
]
const PLAYER_COLOR_NAMES := ["Blue", "Red", "Green", "Yellow", "Purple", "Orange", "Cyan", "Gray"]

const RESOURCE_AMOUNTS := ["limited", "normal", "high", "toomuch"]
const RESOURCE_AMOUNT_LABELS := ["Limited", "Normal", "High", "Maximum"]
const DENSITY_VALUES := ["sparse", "normal", "dense", "toomuch"]
const DENSITY_LABELS := ["Sparse", "Normal", "Dense", "Maximum"]


func _ready() -> void:
	start_button.pressed.connect(_on_start)
	back_button.pressed.connect(_on_back)
	map_list.item_selected.connect(_on_map_selected)

	credits_spinbox.min_value = 0
	credits_spinbox.max_value = 9999
	credits_spinbox.step = 50
	credits_spinbox.value = DEFAULT_CREDITS

	# Get preset game type from GameManager
	if GameManager:
		_preset_game_type = GameManager.setup_game_type

	# Update the title
	_title_label = get_node_or_null("Title")
	if _title_label:
		if _preset_game_type == "hotseat":
			_title_label.text = "Hot Seat Game"
		else:
			_title_label.text = "New Game"

	# Build extended game settings UI
	_setup_game_settings_ui()

	# Load game data using a temporary engine
	_load_game_data()


func _load_game_data() -> void:
	status_label.text = "Loading game data..."

	# Create a temporary GameEngine to load data
	_temp_engine = ClassDB.instantiate("GameEngine")
	if _temp_engine == null:
		status_label.text = "ERROR: Could not create GameEngine. Is the GDExtension loaded?"
		start_button.disabled = true
		return

	add_child(_temp_engine)
	var loaded: bool = _temp_engine.load_game_data()
	if not loaded:
		status_label.text = "ERROR: Failed to load game data from JSON files."
		start_button.disabled = true
		return

	# Get available maps
	_available_maps = _temp_engine.get_available_maps()
	if _available_maps.size() == 0:
		status_label.text = "WARNING: No maps found in data/maps/"
	else:
		for map_name in _available_maps:
			# Strip .wrl extension for display
			var display_name: String = map_name
			if display_name.ends_with(".wrl"):
				display_name = display_name.substr(0, display_name.length() - 4)
			map_list.add_item(display_name)
		map_list.select(0)
		_on_map_selected(0)

	# Get available clans
	_available_clans = _temp_engine.get_available_clans()

	# Set up player rows
	_setup_player_rows()

	var mode_name := "Single Player"
	if _preset_game_type == "hotseat":
		mode_name = "Hot Seat"
	status_label.text = "%d maps, %d clans loaded. Configure your %s game and press START." % [
		_available_maps.size(), _available_clans.size(), mode_name]


func _setup_game_settings_ui() -> void:
	## Create game settings controls in the right panel, below the player list.
	# Find the right panel (parent of PlayerContainer)
	var right_panel: VBoxContainer = player_container.get_parent() as VBoxContainer
	if not right_panel:
		return

	# -- Game Type --
	var type_row := HBoxContainer.new()
	var type_label := Label.new()
	type_label.text = "Game Type:"
	type_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	type_row.add_child(type_label)
	_game_type_option = OptionButton.new()
	_game_type_option.add_item("Simultaneous", 0)
	_game_type_option.add_item("Turn-Based", 1)
	_game_type_option.add_item("Hot Seat", 2)
	_game_type_option.custom_minimum_size = Vector2(160, 0)
	type_row.add_child(_game_type_option)
	right_panel.add_child(type_row)

	# Pre-select based on preset
	if _preset_game_type == "hotseat":
		_game_type_option.select(2)
	else:
		_game_type_option.select(0)

	# -- Victory Condition --
	var vic_row := HBoxContainer.new()
	var vic_label := Label.new()
	vic_label.text = "Victory:"
	vic_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vic_row.add_child(vic_label)
	_victory_option = OptionButton.new()
	_victory_option.add_item("Elimination", 0)
	_victory_option.add_item("Turn Limit", 1)
	_victory_option.add_item("Points", 2)
	_victory_option.custom_minimum_size = Vector2(160, 0)
	_victory_option.item_selected.connect(_on_victory_type_changed)
	vic_row.add_child(_victory_option)
	right_panel.add_child(vic_row)

	# Victory turns / points (initially hidden)
	var vic_detail_row := HBoxContainer.new()
	vic_detail_row.name = "VictoryDetailRow"
	var vic_turns_label := Label.new()
	vic_turns_label.text = "Turn Limit:"
	vic_turns_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vic_detail_row.add_child(vic_turns_label)
	_victory_turns_spin = SpinBox.new()
	_victory_turns_spin.min_value = 50
	_victory_turns_spin.max_value = 999
	_victory_turns_spin.step = 10
	_victory_turns_spin.value = 200
	_victory_turns_spin.custom_minimum_size = Vector2(100, 0)
	vic_detail_row.add_child(_victory_turns_spin)
	right_panel.add_child(vic_detail_row)
	vic_detail_row.visible = false

	var vic_points_row := HBoxContainer.new()
	vic_points_row.name = "VictoryPointsRow"
	var vic_pts_label := Label.new()
	vic_pts_label.text = "Points Target:"
	vic_pts_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vic_points_row.add_child(vic_pts_label)
	_victory_points_spin = SpinBox.new()
	_victory_points_spin.min_value = 50
	_victory_points_spin.max_value = 9999
	_victory_points_spin.step = 50
	_victory_points_spin.value = 400
	_victory_points_spin.custom_minimum_size = Vector2(100, 0)
	vic_points_row.add_child(_victory_points_spin)
	right_panel.add_child(vic_points_row)
	vic_points_row.visible = false

	# -- Separator --
	var sep := HSeparator.new()
	right_panel.add_child(sep)

	# -- Bridgehead Type --
	var bridge_row := HBoxContainer.new()
	var bridge_label := Label.new()
	bridge_label.text = "Bridgehead:"
	bridge_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bridge_row.add_child(bridge_label)
	_bridgehead_option = OptionButton.new()
	_bridgehead_option.add_item("Mobile (CV only)", 0)
	_bridgehead_option.add_item("Definite (Base)", 1)
	_bridgehead_option.custom_minimum_size = Vector2(160, 0)
	_bridgehead_option.select(0)
	bridge_row.add_child(_bridgehead_option)
	right_panel.add_child(bridge_row)

	# -- Alien Tech --
	_alien_check = CheckBox.new()
	_alien_check.text = "Enable Alien Technology"
	_alien_check.button_pressed = false
	right_panel.add_child(_alien_check)

	# -- Resource Amounts --
	var res_sep := HSeparator.new()
	right_panel.add_child(res_sep)

	var res_title := Label.new()
	res_title.text = "Resources"
	res_title.add_theme_font_size_override("font_size", 16)
	right_panel.add_child(res_title)

	# Metal
	var metal_row := HBoxContainer.new()
	var metal_label := Label.new()
	metal_label.text = "Metal:"
	metal_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	metal_row.add_child(metal_label)
	_metal_option = _create_resource_option()
	metal_row.add_child(_metal_option)
	right_panel.add_child(metal_row)

	# Oil
	var oil_row := HBoxContainer.new()
	var oil_label := Label.new()
	oil_label.text = "Oil:"
	oil_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	oil_row.add_child(oil_label)
	_oil_option = _create_resource_option()
	oil_row.add_child(_oil_option)
	right_panel.add_child(oil_row)

	# Gold
	var gold_row := HBoxContainer.new()
	var gold_label := Label.new()
	gold_label.text = "Gold:"
	gold_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gold_row.add_child(gold_label)
	_gold_option = _create_resource_option()
	gold_row.add_child(_gold_option)
	right_panel.add_child(gold_row)

	# Density
	var dens_row := HBoxContainer.new()
	var dens_label := Label.new()
	dens_label.text = "Density:"
	dens_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dens_row.add_child(dens_label)
	_density_option = OptionButton.new()
	for i in range(DENSITY_LABELS.size()):
		_density_option.add_item(DENSITY_LABELS[i], i)
	_density_option.select(1)  # Normal
	_density_option.custom_minimum_size = Vector2(130, 0)
	dens_row.add_child(_density_option)
	right_panel.add_child(dens_row)

	# -- Turn Time Limits --
	var time_sep := HSeparator.new()
	right_panel.add_child(time_sep)

	_turn_limit_check = CheckBox.new()
	_turn_limit_check.text = "Turn Time Limit"
	_turn_limit_check.button_pressed = false
	_turn_limit_check.toggled.connect(_on_turn_limit_toggled)
	right_panel.add_child(_turn_limit_check)

	var tl_row := HBoxContainer.new()
	tl_row.name = "TurnLimitRow"
	var tl_label := Label.new()
	tl_label.text = "  Seconds per turn:"
	tl_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tl_row.add_child(tl_label)
	_turn_limit_spin = SpinBox.new()
	_turn_limit_spin.min_value = 30
	_turn_limit_spin.max_value = 600
	_turn_limit_spin.step = 30
	_turn_limit_spin.value = 120
	_turn_limit_spin.custom_minimum_size = Vector2(100, 0)
	tl_row.add_child(_turn_limit_spin)
	right_panel.add_child(tl_row)
	tl_row.visible = false

	_turn_deadline_check = CheckBox.new()
	_turn_deadline_check.text = "End-Turn Deadline"
	_turn_deadline_check.button_pressed = false
	_turn_deadline_check.toggled.connect(_on_turn_deadline_toggled)
	right_panel.add_child(_turn_deadline_check)

	var td_row := HBoxContainer.new()
	td_row.name = "TurnDeadlineRow"
	var td_label := Label.new()
	td_label.text = "  Deadline seconds:"
	td_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	td_row.add_child(td_label)
	_turn_deadline_spin = SpinBox.new()
	_turn_deadline_spin.min_value = 10
	_turn_deadline_spin.max_value = 300
	_turn_deadline_spin.step = 10
	_turn_deadline_spin.value = 60
	_turn_deadline_spin.custom_minimum_size = Vector2(100, 0)
	td_row.add_child(_turn_deadline_spin)
	right_panel.add_child(td_row)
	td_row.visible = false


func _create_resource_option() -> OptionButton:
	var opt := OptionButton.new()
	for i in range(RESOURCE_AMOUNT_LABELS.size()):
		opt.add_item(RESOURCE_AMOUNT_LABELS[i], i)
	opt.select(1)  # Normal
	opt.custom_minimum_size = Vector2(130, 0)
	return opt


func _on_victory_type_changed(index: int) -> void:
	var turns_row := _victory_turns_spin.get_parent() if _victory_turns_spin else null
	var points_row := _victory_points_spin.get_parent() if _victory_points_spin else null
	if turns_row:
		turns_row.visible = (index == 1)  # Turn Limit
	if points_row:
		points_row.visible = (index == 2)  # Points


func _on_turn_limit_toggled(toggled_on: bool) -> void:
	var row := _turn_limit_spin.get_parent() if _turn_limit_spin else null
	if row:
		row.visible = toggled_on


func _on_turn_deadline_toggled(toggled_on: bool) -> void:
	var row := _turn_deadline_spin.get_parent() if _turn_deadline_spin else null
	if row:
		row.visible = toggled_on


func _setup_player_rows() -> void:
	# Clear existing
	for child in player_container.get_children():
		child.queue_free()
	_player_rows.clear()

	var default_enabled := 2
	if _preset_game_type == "hotseat":
		default_enabled = 2  # 2 players default for hot seat

	for i in range(MAX_PLAYERS):
		var row := HBoxContainer.new()
		row.set("theme_override_constants/separation", 8)

		# Enable checkbox (player 0 always enabled)
		var enable_check := CheckBox.new()
		enable_check.button_pressed = (i < default_enabled)
		enable_check.disabled = (i == 0)  # Player 1 always active
		enable_check.tooltip_text = "Enable Player %d" % (i + 1)
		row.add_child(enable_check)

		# Name
		var name_edit := LineEdit.new()
		name_edit.text = "Player %d" % (i + 1)
		name_edit.custom_minimum_size = Vector2(120, 0)
		name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_edit)

		# Color label
		var color_label := Label.new()
		color_label.text = PLAYER_COLOR_NAMES[i]
		color_label.modulate = PLAYER_COLORS[i]
		color_label.custom_minimum_size = Vector2(60, 0)
		row.add_child(color_label)

		# Clan dropdown
		var clan_option := OptionButton.new()
		clan_option.add_item("No Clan", -1)
		for c in _available_clans:
			var clan_name: String = c.get("name", "?")
			var clan_idx: int = c.get("index", 0)
			clan_option.add_item(clan_name, clan_idx)
		clan_option.custom_minimum_size = Vector2(100, 0)
		row.add_child(clan_option)

		player_container.add_child(row)
		_player_rows.append({
			"row": row,
			"enabled": enable_check,
			"name": name_edit,
			"color_idx": i,
			"clan": clan_option,
		})


func _on_map_selected(index: int) -> void:
	if index < 0 or index >= _available_maps.size():
		return
	var map_name: String = _available_maps[index]
	map_preview_label.text = map_name


func _on_start() -> void:
	# Gather configuration
	var selected_map_idx: int = map_list.get_selected_items()[0] if map_list.get_selected_items().size() > 0 else 0
	var map_name: String = _available_maps[selected_map_idx] if selected_map_idx < _available_maps.size() else ""

	var player_names: Array = []
	var player_colors: Array = []
	var player_clans: Array = []

	for pr in _player_rows:
		var enabled: bool = pr["enabled"].button_pressed
		if not enabled:
			continue
		player_names.append(pr["name"].text)
		player_colors.append(PLAYER_COLORS[pr["color_idx"]])
		var clan_opt: OptionButton = pr["clan"]
		var clan_id: int = clan_opt.get_item_id(clan_opt.selected)
		player_clans.append(clan_id)

	if player_names.size() < 2:
		status_label.text = "Need at least 2 players!"
		return

	# Determine game type string
	var game_type_idx: int = _game_type_option.selected if _game_type_option else 0
	var game_type_str := "simultaneous"
	if game_type_idx == 1:
		game_type_str = "turns"
	elif game_type_idx == 2:
		game_type_str = "hotseat"

	# Victory condition
	var victory_idx: int = _victory_option.selected if _victory_option else 0
	var victory_str := "death"
	if victory_idx == 1:
		victory_str = "turns"
	elif victory_idx == 2:
		victory_str = "points"

	# Resource amounts
	var metal_idx: int = _metal_option.selected if _metal_option else 1
	var oil_idx: int = _oil_option.selected if _oil_option else 1
	var gold_idx: int = _gold_option.selected if _gold_option else 1
	var density_idx: int = _density_option.selected if _density_option else 1

	# Bridgehead
	var bridgehead_idx: int = _bridgehead_option.selected if _bridgehead_option else 0
	var bridgehead_str := "mobile" if bridgehead_idx == 0 else "definite"

	var config := {
		"map_name": map_name,
		"player_names": player_names,
		"player_colors": player_colors,
		"player_clans": player_clans,
		"start_credits": int(credits_spinbox.value),
		# Extended settings
		"game_type": game_type_str,
		"victory_type": victory_str,
		"victory_turns": int(_victory_turns_spin.value) if _victory_turns_spin else 200,
		"victory_points": int(_victory_points_spin.value) if _victory_points_spin else 400,
		"metal_amount": RESOURCE_AMOUNTS[metal_idx],
		"oil_amount": RESOURCE_AMOUNTS[oil_idx],
		"gold_amount": RESOURCE_AMOUNTS[gold_idx],
		"resource_density": DENSITY_VALUES[density_idx],
		"bridgehead_type": bridgehead_str,
		"alien_enabled": _alien_check.button_pressed if _alien_check else false,
		"clans_enabled": true,
		"turn_limit_active": _turn_limit_check.button_pressed if _turn_limit_check else false,
		"turn_limit_seconds": int(_turn_limit_spin.value) if _turn_limit_spin else 120,
		"turn_deadline_active": _turn_deadline_check.button_pressed if _turn_deadline_check else false,
		"turn_deadline_seconds": int(_turn_deadline_spin.value) if _turn_deadline_spin else 60,
	}

	# Clean up temp engine
	if _temp_engine:
		_temp_engine.queue_free()
		_temp_engine = null

	# Route through the pre-game flow (unit purchasing → landing → game)
	GameManager.start_pregame(config)


func _on_back() -> void:
	if _temp_engine:
		_temp_engine.queue_free()
		_temp_engine = null
	GameManager.go_to_main_menu()
