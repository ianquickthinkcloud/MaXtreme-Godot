extends PanelContainer
## Production Panel -- Factory build queue management with unit icons.

signal production_changed

var _factory = null
var _actions = null
var _current_speed := 1
var _producible_types: Array = []
var _showing_add_list := false
var _sprite_cache = null

@onready var title_label: Label = $VBox/TitleLabel
@onready var queue_list: VBoxContainer = $VBox/QueueScroll/QueueList
@onready var progress_bar: ProgressBar = $VBox/ProgressBar
@onready var progress_label: Label = $VBox/ProgressLabel
@onready var add_button: Button = $VBox/Controls/AddButton
@onready var speed_button: Button = $VBox/Controls/SpeedButton
@onready var repeat_button: Button = $VBox/Controls/RepeatButton
@onready var start_stop_button: Button = $VBox/StartStopButton
@onready var close_button: Button = $VBox/CloseButton
@onready var add_unit_list: VBoxContainer = $VBox/AddUnitScroll/AddUnitList
@onready var add_unit_scroll: ScrollContainer = $VBox/AddUnitScroll


func _ready() -> void:
	add_button.pressed.connect(_on_add_pressed)
	speed_button.pressed.connect(_on_speed_pressed)
	repeat_button.pressed.connect(_on_repeat_pressed)
	start_stop_button.pressed.connect(_on_start_stop_pressed)
	close_button.pressed.connect(_on_close)
	visible = false
	add_unit_scroll.visible = false


func set_sprite_cache(cache) -> void:
	_sprite_cache = cache


func open_for_factory(factory_unit, game_actions) -> void:
	_factory = factory_unit
	_actions = game_actions

	if not _factory or not _factory.is_building():
		visible = false
		return

	var can_build_str = _factory.get_can_build()
	if can_build_str == "":
		visible = false
		return

	_producible_types = _factory.get_producible_types()
	title_label.text = "Production: %s" % _factory.get_name()
	_showing_add_list = false
	add_unit_scroll.visible = false

	_refresh_display()
	visible = true


func _refresh_display() -> void:
	if not _factory:
		return

	_refresh_queue()

	# Progress bar
	var bl = _factory.get_build_list()
	if bl.size() > 0:
		var first = bl[0]
		var remaining: int = first.get("remaining_metal", 0)
		var total: int = first.get("total_cost", 1)
		if total > 0:
			progress_bar.value = 100.0 * (1.0 - float(remaining) / float(total))
		else:
			progress_bar.value = 0
		progress_label.text = "Building: %s (%d/%d)" % [first.get("type_name", "?"), total - remaining, total]
	else:
		progress_bar.value = 0
		progress_label.text = "Queue empty"

	# Speed
	_current_speed = _factory.get_build_speed()
	speed_button.text = "Speed: %dx" % _current_speed

	# Repeat
	var repeat = _factory.get_repeat_build()
	repeat_button.text = "Repeat: ON" if repeat else "Repeat: OFF"
	repeat_button.modulate = Color(0.3, 0.9, 0.4) if repeat else Color.WHITE

	# Start/Stop
	var working = _factory.is_working()
	start_stop_button.text = "STOP" if working else "START"
	start_stop_button.modulate = Color(1.0, 0.4, 0.4) if working else Color(0.4, 1.0, 0.5)


func _refresh_queue() -> void:
	for child in queue_list.get_children():
		child.queue_free()

	var bl = _factory.get_build_list()
	if bl.is_empty():
		var lbl = Label.new()
		lbl.text = "(empty queue)"
		lbl.add_theme_color_override("font_color", Color(0.45, 0.45, 0.55))
		queue_list.add_child(lbl)
		return

	for i in range(bl.size()):
		var item = bl[i]
		var hbox = HBoxContainer.new()
		hbox.set("theme_override_constants/separation", 6)

		# Queue number
		var num_lbl = Label.new()
		num_lbl.text = "%d." % (i + 1)
		num_lbl.custom_minimum_size = Vector2(24, 0)
		num_lbl.add_theme_color_override("font_color", Color(0.5, 0.55, 0.7))
		hbox.add_child(num_lbl)

		# Icon
		var icon_rect := TextureRect.new()
		icon_rect.custom_minimum_size = Vector2(24, 24)
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		if _sprite_cache:
			var type_id: String = item.get("type_id", item.get("type_name", ""))
			var icon: Texture2D = _sprite_cache.get_unit_icon(type_id, true)
			if icon:
				icon_rect.texture = icon
		hbox.add_child(icon_rect)

		# Name
		var lbl = Label.new()
		lbl.text = item.get("type_name", "?")
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(lbl)

		# Cost
		var cost_lbl = Label.new()
		cost_lbl.text = "(%d)" % item.get("remaining_metal", 0)
		cost_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.65))
		hbox.add_child(cost_lbl)

		queue_list.add_child(hbox)


func _on_add_pressed() -> void:
	_showing_add_list = not _showing_add_list
	add_unit_scroll.visible = _showing_add_list
	if _showing_add_list:
		_populate_add_list()
	add_button.text = "Cancel" if _showing_add_list else "Add Unit"


func _populate_add_list() -> void:
	for child in add_unit_list.get_children():
		child.queue_free()

	for entry in _producible_types:
		var unit_name: String = entry.get("name", "Unknown")
		var cost: int = entry.get("cost", 0)
		var type_id: String = entry.get("id", "")

		var btn = Button.new()
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(260, 36)

		# Try to set icon
		if _sprite_cache:
			var icon: Texture2D = _sprite_cache.get_unit_icon(type_id, true)
			if icon:
				btn.icon = icon

		btn.text = "  %s  (%d metal)" % [unit_name, cost]
		btn.pressed.connect(_on_add_unit_clicked.bind(type_id))
		add_unit_list.add_child(btn)


func _on_add_unit_clicked(type_id: String) -> void:
	if not _factory or not _actions:
		return
	var current_bl = _factory.get_build_list()
	var new_list: Array = []
	for item in current_bl:
		new_list.append(item.get("type_id", ""))
	new_list.append(type_id)
	_actions.change_build_list(_factory.get_id(), new_list, _current_speed, _factory.get_repeat_build())
	_showing_add_list = false
	add_unit_scroll.visible = false
	add_button.text = "Add Unit"
	_refresh_display()
	production_changed.emit()


func _on_speed_pressed() -> void:
	if not _factory or not _actions:
		return
	if _current_speed == 1:
		_current_speed = 2
	elif _current_speed == 2:
		_current_speed = 4
	else:
		_current_speed = 1
	var current_bl = _factory.get_build_list()
	var type_ids: Array = []
	for item in current_bl:
		type_ids.append(item.get("type_id", ""))
	_actions.change_build_list(_factory.get_id(), type_ids, _current_speed, _factory.get_repeat_build())
	_refresh_display()
	production_changed.emit()


func _on_repeat_pressed() -> void:
	if not _factory or not _actions:
		return
	var new_repeat = not _factory.get_repeat_build()
	var current_bl = _factory.get_build_list()
	var type_ids: Array = []
	for item in current_bl:
		type_ids.append(item.get("type_id", ""))
	_actions.change_build_list(_factory.get_id(), type_ids, _current_speed, new_repeat)
	_refresh_display()
	production_changed.emit()


func _on_start_stop_pressed() -> void:
	if not _factory or not _actions:
		return
	if _factory.is_working():
		_actions.stop(_factory.get_id())
	else:
		_actions.start_work(_factory.get_id())
	_refresh_display()
	production_changed.emit()


func _on_close() -> void:
	visible = false


func close() -> void:
	visible = false
	_factory = null
	_showing_add_list = false
