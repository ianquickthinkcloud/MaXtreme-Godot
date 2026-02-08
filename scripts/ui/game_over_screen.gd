extends CanvasLayer
## Game Over Screen -- Shows victory or defeat with full statistics.
## Phase 27: Enhanced with per-player stats, score graph, and proper flow.

@onready var result_label: Label = $Panel/VBox/ResultLabel
@onready var details_label: Label = $Panel/VBox/DetailsLabel
@onready var menu_button: Button = $Panel/VBox/MenuButton
@onready var continue_button: Button = $Panel/VBox/ContinueButton

signal return_to_menu
signal continue_playing

var is_showing := false
var _stats_container: VBoxContainer = null
var _graph_container: Control = null


func _ready() -> void:
	menu_button.pressed.connect(func() -> void: return_to_menu.emit())
	continue_button.pressed.connect(func() -> void:
		is_showing = false
		visible = false
		continue_playing.emit()
	)
	visible = false
	is_showing = false
	layer = 90  # Below pause menu, above game

	# Create stats container below existing elements
	var vbox: VBoxContainer = $Panel/VBox
	if vbox:
		_stats_container = VBoxContainer.new()
		_stats_container.name = "StatsContainer"
		_stats_container.add_theme_constant_override("separation", 4)
		# Insert before buttons
		var idx := vbox.get_child_count() - 2
		vbox.add_child(_stats_container)
		vbox.move_child(_stats_container, idx)

		# Score graph area
		_graph_container = Control.new()
		_graph_container.name = "GraphContainer"
		_graph_container.custom_minimum_size = Vector2(500, 120)
		vbox.add_child(_graph_container)
		vbox.move_child(_graph_container, idx + 1)


func show_victory(player_name: String, details: String = "") -> void:
	result_label.text = "VICTORY!"
	result_label.modulate = Color(1.0, 0.85, 0.0)
	details_label.text = "%s has won the game!" % player_name
	if details != "":
		details_label.text += "\n" + details
	visible = true
	is_showing = true
	# Play victory sound
	AudioManager.play_sound("victory")


func show_defeat(player_name: String, details: String = "") -> void:
	result_label.text = "DEFEAT"
	result_label.modulate = Color(1.0, 0.2, 0.2)
	details_label.text = "%s has been eliminated." % player_name
	if details != "":
		details_label.text += "\n" + details
	visible = true
	is_showing = true
	# Play defeat sound
	AudioManager.play_sound("defeat")


func show_statistics(player_stats: Array) -> void:
	## Display end-game statistics for all players.
	## player_stats: Array of Dictionaries, each:
	##   {name, color, score, built_vehicles, lost_vehicles, built_buildings,
	##    lost_buildings, eco_spheres, is_defeated, vehicles_alive, buildings_alive,
	##    score_history: PackedInt32Array}
	if not _stats_container:
		return

	# Clear previous stats
	for child in _stats_container.get_children():
		child.queue_free()

	# Header
	var header := Label.new()
	header.text = "--- Game Statistics ---"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	_stats_container.add_child(header)

	# Per-player stats grid
	for ps in player_stats:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)

		# Player name with color
		var name_lbl := Label.new()
		name_lbl.text = ps.get("name", "Player")
		name_lbl.custom_minimum_size = Vector2(100, 0)
		name_lbl.add_theme_font_size_override("font_size", 12)
		var pcolor: Color = ps.get("color", Color(0.8, 0.8, 0.8))
		name_lbl.add_theme_color_override("font_color", pcolor)
		if ps.get("is_defeated", false):
			name_lbl.text += " [X]"
		row.add_child(name_lbl)

		# Score
		var score_lbl := Label.new()
		score_lbl.text = "Score: %d" % ps.get("score", 0)
		score_lbl.custom_minimum_size = Vector2(80, 0)
		score_lbl.add_theme_font_size_override("font_size", 11)
		score_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		row.add_child(score_lbl)

		# Built/Lost summary
		var bv: int = ps.get("built_vehicles", 0)
		var lv: int = ps.get("lost_vehicles", 0)
		var bb: int = ps.get("built_buildings", 0)
		var lb: int = ps.get("lost_buildings", 0)
		var tally_lbl := Label.new()
		tally_lbl.text = "V: +%d/-%d  B: +%d/-%d" % [bv, lv, bb, lb]
		tally_lbl.custom_minimum_size = Vector2(180, 0)
		tally_lbl.add_theme_font_size_override("font_size", 11)
		tally_lbl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
		row.add_child(tally_lbl)

		# Alive units
		var alive_lbl := Label.new()
		alive_lbl.text = "Alive: %dV %dB" % [ps.get("vehicles_alive", 0), ps.get("buildings_alive", 0)]
		alive_lbl.add_theme_font_size_override("font_size", 11)
		alive_lbl.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
		row.add_child(alive_lbl)

		_stats_container.add_child(row)

	# Draw score graph if we have history data
	_draw_score_graph(player_stats)


func _draw_score_graph(player_stats: Array) -> void:
	## Draw a simple score history line graph.
	if not _graph_container:
		return

	# Clear previous graph elements
	for child in _graph_container.get_children():
		child.queue_free()

	# Check if anyone has score history
	var has_history := false
	for ps in player_stats:
		var history = ps.get("score_history", PackedInt32Array())
		if history.size() > 1:
			has_history = true
			break

	if not has_history:
		var no_data := Label.new()
		no_data.text = "(No score history to display)"
		no_data.add_theme_font_size_override("font_size", 10)
		no_data.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
		_graph_container.add_child(no_data)
		return

	# Create a Line2D for each player
	var graph_w: float = _graph_container.custom_minimum_size.x
	var graph_h: float = _graph_container.custom_minimum_size.y
	var max_score := 1
	var max_turns := 1

	for ps in player_stats:
		var history = ps.get("score_history", PackedInt32Array())
		if history.size() > max_turns:
			max_turns = history.size()
		for s in history:
			if s > max_score:
				max_score = s

	for ps in player_stats:
		var history = ps.get("score_history", PackedInt32Array())
		if history.size() < 2:
			continue

		var line := Line2D.new()
		line.width = 2.0
		line.default_color = ps.get("color", Color(1, 1, 1))
		line.antialiased = true

		for i in range(history.size()):
			var x: float = (float(i) / float(max_turns - 1)) * graph_w if max_turns > 1 else 0.0
			var y: float = graph_h - (float(history[i]) / float(max_score)) * graph_h if max_score > 0 else graph_h
			line.add_point(Vector2(x, y))

		_graph_container.add_child(line)

	# Add graph label
	var graph_label := Label.new()
	graph_label.text = "Score History (max: %d)" % max_score
	graph_label.position = Vector2(0, -16)
	graph_label.add_theme_font_size_override("font_size", 10)
	graph_label.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))
	_graph_container.add_child(graph_label)
