extends Node
## GameManager -- Autoload singleton that persists across scene changes.
## Holds game configuration, settings, and manages scene transitions.

# --- Game configuration (set by New Game Setup, read by Main Game) ---
var game_config: Dictionary = {}

# --- Settings (persisted to user://settings.cfg) ---
var settings: Dictionary = {
	"audio_master": 80,
	"audio_music": 60,
	"audio_sfx": 80,
	"display_fullscreen": false,
	"display_vsync": true,
	"display_shadows": true,
	"display_animations": true,
	"display_effects": true,
	"display_tracks": true,
	"camera_edge_scroll": true,
	"camera_scroll_speed": 600,
	"autosave_enabled": true,
}

const SETTINGS_PATH := "user://settings.cfg"
const SCENE_MAIN_MENU := "res://scenes/menus/main_menu.tscn"
const SCENE_NEW_GAME := "res://scenes/menus/new_game_setup.tscn"
const SCENE_CHOOSE_UNITS := "res://scenes/menus/choose_units.tscn"
const SCENE_CHOOSE_LANDING := "res://scenes/menus/choose_landing.tscn"
const SCENE_HOST_GAME := "res://scenes/menus/host_game.tscn"
const SCENE_JOIN_GAME := "res://scenes/menus/join_game.tscn"
const SCENE_LOBBY := "res://scenes/menus/lobby.tscn"
const SCENE_GAME := "res://scenes/game/main_game.tscn"

# --- Multiplayer state ---
var lobby: Node = null      # GameLobby instance (persists between scenes)
var lobby_role: String = ""  # "host" or "client"


func _ready() -> void:
	# Apply polished global theme
	var ThemeSetup := preload("res://scripts/autoloads/theme_setup.gd")
	var global_theme := ThemeSetup.create_theme()
	get_tree().root.theme = global_theme

	load_settings()


# --- Scene transitions ---

func go_to_main_menu() -> void:
	game_config.clear()
	get_tree().change_scene_to_file(SCENE_MAIN_MENU)


## Preset game type for the new game setup screen: "", "hotseat", etc.
var setup_game_type: String = ""


func go_to_new_game_setup(preset_game_type: String = "") -> void:
	setup_game_type = preset_game_type
	get_tree().change_scene_to_file(SCENE_NEW_GAME)


func go_to_host_game() -> void:
	get_tree().change_scene_to_file(SCENE_HOST_GAME)


func go_to_join_game() -> void:
	get_tree().change_scene_to_file(SCENE_JOIN_GAME)


func go_to_lobby() -> void:
	get_tree().change_scene_to_file(SCENE_LOBBY)


## --- Pre-game flow state ---
## In hot seat, tracks which player is currently shopping.
var pregame_current_player := 0
## Per-player landing units (Array of Arrays of Dicts: {id_first, id_second, cargo, cost})
var pregame_landing_units: Array = []
## Per-player landing positions (Array of Vector2i)
var pregame_landing_positions: Array = []


func start_pregame(config: Dictionary) -> void:
	## Begin the pre-game flow: unit purchasing → landing selection → game start.
	## This replaces the old direct start_game() call from new_game_setup.
	game_config = config
	var player_count: int = config.get("player_names", []).size()
	pregame_current_player = 0
	pregame_landing_units.clear()
	pregame_landing_positions.clear()
	pregame_landing_units.resize(player_count)
	pregame_landing_positions.resize(player_count)
	for i in range(player_count):
		pregame_landing_units[i] = []
		pregame_landing_positions[i] = Vector2i(-1, -1)
	# Go to the unit purchase screen for the first player
	get_tree().change_scene_to_file(SCENE_CHOOSE_UNITS)


func advance_pregame_to_landing() -> void:
	## Called after unit purchasing is done for this player.
	## In hot seat: if more players remain, loop back. Otherwise go to landing.
	get_tree().change_scene_to_file(SCENE_CHOOSE_LANDING)


func advance_pregame_to_game() -> void:
	## Called after all players have chosen landing positions. Start the real game.
	# Inject the pre-game data into the config
	game_config["player_landing_units"] = pregame_landing_units
	game_config["player_landing_positions"] = pregame_landing_positions
	get_tree().change_scene_to_file(SCENE_GAME)


func start_game(config: Dictionary) -> void:
	## Start a game with the given configuration dictionary.
	## For single-player: map_name, player_names, player_colors, player_clans, start_credits
	## For multiplayer: multiplayer=true, lobby_role="host"/"client"
	game_config = config
	get_tree().change_scene_to_file(SCENE_GAME)


func load_saved_game(slot: int) -> void:
	## Load a saved game from the given slot number.
	## Sets up the game config with load_mode and transitions to the game scene.
	game_config = {"load_mode": true, "load_slot": slot}
	get_tree().change_scene_to_file(SCENE_GAME)


func quit_game() -> void:
	# Clean up lobby if active
	if lobby:
		lobby.disconnect_lobby()
		lobby.queue_free()
		lobby = null
	lobby_role = ""
	get_tree().quit()


# --- Settings persistence ---

func save_settings() -> void:
	var config := ConfigFile.new()
	for key in settings:
		config.set_value("settings", key, settings[key])
	config.save(SETTINGS_PATH)


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return  # Use defaults
	for key in settings:
		if config.has_section_key("settings", key):
			settings[key] = config.get_value("settings", key)
	_apply_settings()


func update_setting(key: String, value: Variant) -> void:
	settings[key] = value
	_apply_settings()
	save_settings()


func _apply_settings() -> void:
	# Apply display settings
	if settings.get("display_fullscreen", false):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

	if settings.get("display_vsync", true):
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

	# Apply audio settings (AudioManager may not be ready yet on first call)
	var audio = get_node_or_null("/root/AudioManager")
	if audio:
		audio.set_master_volume(settings.get("audio_master", 80))
		audio.set_music_volume(settings.get("audio_music", 60))
		audio.set_sfx_volume(settings.get("audio_sfx", 80))
