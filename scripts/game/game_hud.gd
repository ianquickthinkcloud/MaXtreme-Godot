extends CanvasLayer
## Game HUD - displays turn info, player status, selected unit info, and end turn button.

signal end_turn_pressed

@onready var turn_label: Label = $TopBar/TurnLabel
@onready var player_label: Label = $TopBar/PlayerLabel
@onready var status_label: Label = $TopBar/StatusLabel
@onready var unit_panel: PanelContainer = $UnitPanel
@onready var unit_name_label: Label = $UnitPanel/VBox/UnitName
@onready var unit_stats_label: Label = $UnitPanel/VBox/UnitStats
@onready var unit_pos_label: Label = $UnitPanel/VBox/UnitPos
@onready var end_turn_button: Button = $BottomBar/EndTurnButton
@onready var tile_label: Label = $BottomBar/TileLabel


func _ready() -> void:
	end_turn_button.pressed.connect(_on_end_turn)
	unit_panel.visible = false


func update_turn_info(turn: int, game_time: int, is_active: bool) -> void:
	turn_label.text = "Turn: %d  |  Time: %d" % [turn, game_time]
	status_label.text = "ACTIVE" if is_active else "Processing..."
	status_label.modulate = Color.GREEN if is_active else Color.YELLOW


func update_player_info(player_name: String, credits: int, vehicles: int, buildings: int) -> void:
	player_label.text = "%s  |  Credits: %d  |  Units: %d  |  Buildings: %d" % [
		player_name, credits, vehicles, buildings
	]


func update_selected_unit(unit_data: Dictionary) -> void:
	if unit_data.is_empty():
		unit_panel.visible = false
		return

	unit_panel.visible = true
	unit_name_label.text = str(unit_data.get("name", "Unknown"))
	unit_stats_label.text = "HP: %d/%d  |  Speed: %d/%d  |  Atk: %d  |  Armor: %d" % [
		unit_data.get("hp", 0), unit_data.get("hp_max", 0),
		unit_data.get("speed", 0), unit_data.get("speed_max", 0),
		unit_data.get("damage", 0), unit_data.get("armor", 0),
	]
	unit_pos_label.text = "Position: (%d, %d)  |  ID: %d" % [
		unit_data.get("pos_x", 0), unit_data.get("pos_y", 0),
		unit_data.get("id", 0),
	]


func update_tile_info(tile: Vector2i, terrain: String) -> void:
	tile_label.text = "Tile: (%d, %d) %s" % [tile.x, tile.y, terrain]


func clear_selected_unit() -> void:
	unit_panel.visible = false


func set_end_turn_enabled(enabled: bool) -> void:
	end_turn_button.disabled = not enabled


func _on_end_turn() -> void:
	end_turn_pressed.emit()
