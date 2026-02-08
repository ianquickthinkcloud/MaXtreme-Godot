extends PanelContainer
## Build Panel -- Shows buildable structures when a Constructor is selected.
## Enhanced for Phase 26: Shows turbo build costs/turns, speed selector, and
## path-building option for road/bridge/platform constructors.

signal building_selected(type_id: String, type_name: String, is_big: bool, cost: int)
signal building_selected_ex(type_id: String, type_name: String, is_big: bool, cost: int, build_speed: int)
signal panel_closed

var _buildable_types: Array = []
var _sprite_cache = null
var _constructor_unit = null  ## The constructor unit (for turbo build queries)
var _selected_speed := 0  ## 0=normal, 1=2x, 2=4x

@onready var title_label: Label = $VBox/TitleLabel
@onready var building_list: VBoxContainer = $VBox/ScrollContainer/BuildingList
@onready var close_button: Button = $VBox/CloseButton


func _ready() -> void:
	close_button.pressed.connect(_on_close)
	visible = false


func set_sprite_cache(cache) -> void:
	_sprite_cache = cache


func open_for_unit(unit) -> void:
	if not unit or not unit.is_constructor():
		visible = false
		return

	_constructor_unit = unit
	_buildable_types = unit.get_buildable_types()
	_selected_speed = 0
	title_label.text = "Build (%s)" % unit.get_name()
	_populate_list()
	visible = true


func _populate_list() -> void:
	for child in building_list.get_children():
		child.queue_free()

	for entry in _buildable_types:
		var type_name: String = entry.get("name", "Unknown")
		var type_id: String = entry.get("id", "")
		var cost: int = entry.get("cost", 0)
		var is_big: bool = entry.get("is_big", false)

		# Get turbo build info from the constructor
		var turbo_info: Dictionary = {}
		if _constructor_unit:
			turbo_info = _constructor_unit.get_turbo_build_info(type_id)

		var size_str := "2x2" if is_big else "1x1"

		# Build the entry button with cost and time info
		var entry_container := VBoxContainer.new()
		entry_container.add_theme_constant_override("separation", 2)

		var entry_btn := Button.new()
		entry_btn.icon = _get_icon_for_type(type_id)
		entry_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		entry_btn.custom_minimum_size = Vector2(320, 38)
		entry_btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT

		# Show cost and turns for normal speed
		var turns_0: int = turbo_info.get("turns_0", 0) if turbo_info else 0
		var cost_0: int = turbo_info.get("cost_0", cost) if turbo_info else cost
		entry_btn.text = "  %s  (%d metal, %d turns) [%s]" % [type_name, cost_0, turns_0, size_str]
		entry_btn.tooltip_text = "%s - %d metal, %d turns (%s)" % [type_name, cost_0, turns_0, size_str]

		# Check if turbo speeds are available
		var has_turbo_1: bool = turbo_info.get("turns_1", 0) > 0
		var has_turbo_2: bool = turbo_info.get("turns_2", 0) > 0

		if has_turbo_1 or has_turbo_2:
			# Show turbo options as sub-labels
			var turbo_row := HBoxContainer.new()
			turbo_row.add_theme_constant_override("separation", 8)

			# Normal speed button
			var btn_normal := Button.new()
			btn_normal.text = "1x: %dM %dT" % [turbo_info.get("cost_0", cost), turbo_info.get("turns_0", 0)]
			btn_normal.custom_minimum_size = Vector2(95, 26)
			btn_normal.add_theme_font_size_override("font_size", 10)
			btn_normal.pressed.connect(_on_building_clicked.bind(type_id, type_name, is_big, turbo_info.get("cost_0", cost), 0))
			turbo_row.add_child(btn_normal)

			if has_turbo_1:
				var btn_2x := Button.new()
				btn_2x.text = "2x: %dM %dT" % [turbo_info.get("cost_1", 0), turbo_info.get("turns_1", 0)]
				btn_2x.custom_minimum_size = Vector2(95, 26)
				btn_2x.add_theme_font_size_override("font_size", 10)
				btn_2x.add_theme_color_override("font_color", Color(0.9, 0.8, 0.3))
				btn_2x.pressed.connect(_on_building_clicked.bind(type_id, type_name, is_big, turbo_info.get("cost_1", 0), 1))
				turbo_row.add_child(btn_2x)

			if has_turbo_2:
				var btn_4x := Button.new()
				btn_4x.text = "4x: %dM %dT" % [turbo_info.get("cost_2", 0), turbo_info.get("turns_2", 0)]
				btn_4x.custom_minimum_size = Vector2(95, 26)
				btn_4x.add_theme_font_size_override("font_size", 10)
				btn_4x.add_theme_color_override("font_color", Color(1.0, 0.5, 0.3))
				btn_4x.pressed.connect(_on_building_clicked.bind(type_id, type_name, is_big, turbo_info.get("cost_2", 0), 2))
				turbo_row.add_child(btn_4x)

			entry_container.add_child(entry_btn)
			entry_container.add_child(turbo_row)

			# The main button uses normal speed
			entry_btn.pressed.connect(_on_building_clicked.bind(type_id, type_name, is_big, turbo_info.get("cost_0", cost), 0))
		else:
			entry_container.add_child(entry_btn)
			entry_btn.pressed.connect(_on_building_clicked.bind(type_id, type_name, is_big, cost, 0))

		building_list.add_child(entry_container)

	if _buildable_types.is_empty():
		var lbl := Label.new()
		lbl.text = "No buildings available"
		lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		building_list.add_child(lbl)


func _get_icon_for_type(type_id: String) -> Texture2D:
	if not _sprite_cache:
		return null
	return _sprite_cache.get_unit_icon(type_id, false)


func _on_building_clicked(type_id: String, type_name: String, is_big: bool, cost: int, speed: int) -> void:
	_selected_speed = speed
	building_selected.emit(type_id, type_name, is_big, cost)
	building_selected_ex.emit(type_id, type_name, is_big, cost, speed)


func get_selected_speed() -> int:
	return _selected_speed


func _on_close() -> void:
	visible = false
	panel_closed.emit()


func close() -> void:
	visible = false
