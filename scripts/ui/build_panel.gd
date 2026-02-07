extends PanelContainer
## Build Panel -- Shows buildable structures when a Constructor is selected.
## Each entry shows the unit icon (store.png/info.png), name, cost, and size.

signal building_selected(type_id: String, type_name: String, is_big: bool, cost: int)
signal panel_closed

var _buildable_types: Array = []
var _sprite_cache = null

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

	_buildable_types = unit.get_buildable_types()
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

		var row := HBoxContainer.new()
		row.set("theme_override_constants/separation", 8)
		row.custom_minimum_size = Vector2(280, 40)

		# Icon
		var icon_rect := TextureRect.new()
		icon_rect.custom_minimum_size = Vector2(36, 36)
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		if _sprite_cache:
			var icon_tex: Texture2D = _sprite_cache.get_unit_icon(type_id, false)
			if icon_tex:
				icon_rect.texture = icon_tex
		row.add_child(icon_rect)

		# Info VBox (name + cost)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var name_label := Label.new()
		name_label.text = type_name
		name_label.add_theme_font_size_override("font_size", 13)
		info.add_child(name_label)

		var cost_label := Label.new()
		var size_str := "2x2" if is_big else "1x1"
		cost_label.text = "%d metal  [%s]" % [cost, size_str]
		cost_label.add_theme_font_size_override("font_size", 11)
		cost_label.add_theme_color_override("font_color", Color(0.6, 0.65, 0.8))
		info.add_child(cost_label)

		row.add_child(info)

		# Make the row clickable
		var btn := Button.new()
		btn.flat = true
		btn.custom_minimum_size = Vector2(280, 40)
		btn.pressed.connect(_on_building_clicked.bind(type_id, type_name, is_big, cost))
		btn.tooltip_text = "%s - %d metal (%s)" % [type_name, cost, size_str]

		# Use a MarginContainer to overlay the button on the row
		var container := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0, 0, 0, 0)
		container.add_theme_stylebox_override("panel", style)
		container.custom_minimum_size = Vector2(280, 40)

		row.mouse_filter = Control.MOUSE_FILTER_PASS
		container.add_child(row)

		# Actually, simpler approach: make each entry a Button with an icon
		var entry_btn := Button.new()
		entry_btn.icon = _get_icon_for_type(type_id)
		entry_btn.text = "  %s  (%d metal) [%s]" % [type_name, cost, size_str]
		entry_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		entry_btn.custom_minimum_size = Vector2(280, 38)
		entry_btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		entry_btn.pressed.connect(_on_building_clicked.bind(type_id, type_name, is_big, cost))

		building_list.add_child(entry_btn)

		# Clean up unused container
		container.queue_free()

	if _buildable_types.is_empty():
		var lbl := Label.new()
		lbl.text = "No buildings available"
		lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		building_list.add_child(lbl)


func _get_icon_for_type(type_id: String) -> Texture2D:
	if not _sprite_cache:
		return null
	return _sprite_cache.get_unit_icon(type_id, false)


func _on_building_clicked(type_id: String, type_name: String, is_big: bool, cost: int) -> void:
	building_selected.emit(type_id, type_name, is_big, cost)


func _on_close() -> void:
	visible = false
	panel_closed.emit()


func close() -> void:
	visible = false
