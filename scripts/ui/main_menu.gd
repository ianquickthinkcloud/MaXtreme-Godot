extends Control
## Main Menu -- Polished entry point with animated background, logo, and styled buttons.

@onready var title_label: Label = %TitleLabel
@onready var subtitle_label: Label = %SubtitleLabel
@onready var version_label: Label = %VersionLabel
@onready var new_game_button: Button = %NewGameButton
@onready var hot_seat_button: Button = %HotSeatButton
@onready var host_game_button: Button = %HostGameButton
@onready var join_game_button: Button = %JoinGameButton
@onready var load_game_button: Button = %LoadGameButton
@onready var settings_button: Button = %SettingsButton
@onready var exit_button: Button = %ExitButton
@onready var settings_panel: PanelContainer = %SettingsPanel
@onready var background: ColorRect = $Background
@onready var logo_texture: TextureRect = $LogoTexture

var _time := 0.0


func _ready() -> void:
	# Wire button signals
	new_game_button.pressed.connect(_on_new_game)
	hot_seat_button.pressed.connect(_on_hot_seat)
	host_game_button.pressed.connect(_on_host_game)
	join_game_button.pressed.connect(_on_join_game)
	load_game_button.pressed.connect(_on_load_game)
	settings_button.pressed.connect(_on_settings)
	exit_button.pressed.connect(_on_exit)

	version_label.text = "MaXtreme v0.6.0 -- Phase 18"

	# Load game button disabled until save/load UI is built
	load_game_button.disabled = true
	load_game_button.tooltip_text = "Save/Load coming soon"

	if settings_panel:
		settings_panel.visible = false

	# Try to load the logo image from data/gfx/
	if logo_texture:
		var SpriteCache = preload("res://scripts/game/sprite_cache.gd")
		var cache := SpriteCache.new()
		var logo := cache.get_gfx_texture("logo")
		if logo:
			logo_texture.texture = logo
		else:
			logo_texture.visible = false

	# Start menu music
	if not AudioManager.is_music_playing():
		AudioManager.play_music("res://data/music/main.ogg")


func _process(delta: float) -> void:
	_time += delta
	# Subtle animated gradient on the background
	if background:
		var shift := sin(_time * 0.3) * 0.015
		background.color = Color(0.04 + shift, 0.06, 0.11 - shift, 1.0)


func _on_new_game() -> void:
	AudioManager.play_sound("click")
	GameManager.go_to_new_game_setup()


func _on_hot_seat() -> void:
	AudioManager.play_sound("click")
	GameManager.go_to_new_game_setup("hotseat")


func _on_host_game() -> void:
	AudioManager.play_sound("click")
	GameManager.go_to_host_game()


func _on_join_game() -> void:
	AudioManager.play_sound("click")
	GameManager.go_to_join_game()


func _on_load_game() -> void:
	AudioManager.play_sound("click")


func _on_settings() -> void:
	AudioManager.play_sound("click")
	if settings_panel:
		settings_panel.visible = not settings_panel.visible


func _on_exit() -> void:
	AudioManager.play_sound("click")
	GameManager.quit_game()
