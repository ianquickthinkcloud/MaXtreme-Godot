extends Node
## AudioManager -- Autoload singleton for all game audio.
## Manages SFX playback (pooled AudioStreamPlayers), music, and volume control.
## Loads .ogg files from data/ directories with lazy caching.

# --- Audio buses ---
# We use Godot's default audio bus layout:
#   Master -> Music (bus 1)
#   Master -> SFX (bus 2)
const BUS_MASTER := "Master"
const BUS_MUSIC := "Music"
const BUS_SFX := "SFX"

# --- SFX player pool ---
const SFX_POOL_SIZE := 8
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_index := 0

# --- Music player ---
var _music_player: AudioStreamPlayer = null
var _music_tracks: Array = []  # Available music track paths
var _current_music_index := -1

# --- Sound cache ---
var _sound_cache: Dictionary = {}  # path -> AudioStream
var _MISSING_SOUND := RefCounted.new()  # Sentinel for "tried but not found"

# --- Base paths ---
const SOUNDS_BASE := "res://data/sounds/"
const VEHICLES_BASE := "res://data/vehicles/"
const BUILDINGS_BASE := "res://data/buildings/"
const MUSIC_BASE := "res://data/music/"

# --- Known global sound effects ---
# These map logical names to file paths for easy access
var _global_sounds: Dictionary = {
	"absorb": SOUNDS_BASE + "absorb.ogg",
	"arm": SOUNDS_BASE + "arm.ogg",
	"chat": SOUNDS_BASE + "Chat.ogg",
	"click": SOUNDS_BASE + "arm.ogg",  # Reuse arm.ogg for UI clicks
	"build_place": SOUNDS_BASE + "arm.ogg",
	"turn_end": SOUNDS_BASE + "absorb.ogg",
}


func _ready() -> void:
	_setup_audio_buses()
	_create_sfx_pool()
	_create_music_player()
	_load_music_list()
	_apply_volume_settings()


# --- Setup ---

func _setup_audio_buses() -> void:
	# Ensure Music and SFX buses exist. If they don't, we'll use Master for everything.
	# In a full project you'd create these via the audio bus layout editor,
	# but we can check and work with what's available.
	if AudioServer.get_bus_index(BUS_MUSIC) == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, BUS_MUSIC)
		AudioServer.set_bus_send(AudioServer.get_bus_index(BUS_MUSIC), BUS_MASTER)

	if AudioServer.get_bus_index(BUS_SFX) == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, BUS_SFX)
		AudioServer.set_bus_send(AudioServer.get_bus_index(BUS_SFX), BUS_MASTER)


func _create_sfx_pool() -> void:
	for i in range(SFX_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.bus = BUS_SFX
		add_child(player)
		_sfx_players.append(player)


func _create_music_player() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = BUS_MUSIC
	_music_player.finished.connect(_on_music_finished)
	add_child(_music_player)


func _load_music_list() -> void:
	_music_tracks.clear()
	# Try to load music list from musics.json
	var json_path := MUSIC_BASE + "musics.json"
	if FileAccess.file_exists(json_path):
		var file := FileAccess.open(json_path, FileAccess.READ)
		if file:
			var json := JSON.new()
			var err := json.parse(file.get_as_text())
			file.close()
			if err == OK and json.data is Dictionary:
				var data: Dictionary = json.data
				var backgrounds: Array = data.get("backgrounds", [])
				for track_name in backgrounds:
					var track_path: String = MUSIC_BASE + track_name
					if FileAccess.file_exists(track_path):
						_music_tracks.append(track_path)


# --- Volume control ---

func set_master_volume(percent: int) -> void:
	var db := _percent_to_db(percent)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(BUS_MASTER), db)

func set_music_volume(percent: int) -> void:
	var db := _percent_to_db(percent)
	var idx := AudioServer.get_bus_index(BUS_MUSIC)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, db)

func set_sfx_volume(percent: int) -> void:
	var db := _percent_to_db(percent)
	var idx := AudioServer.get_bus_index(BUS_SFX)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, db)

func _percent_to_db(percent: int) -> float:
	if percent <= 0:
		return -80.0  # Effectively muted
	return linear_to_db(float(percent) / 100.0)

func _apply_volume_settings() -> void:
	if GameManager:
		set_master_volume(GameManager.settings.get("audio_master", 80))
		set_music_volume(GameManager.settings.get("audio_music", 60))
		set_sfx_volume(GameManager.settings.get("audio_sfx", 80))


# --- SFX playback ---

func play_sound(sound_name: String) -> void:
	## Play a global sound effect by logical name (e.g. "click", "absorb", "arm").
	var path: String = _global_sounds.get(sound_name, "")
	if path == "":
		return
	_play_sfx_from_path(path)


func play_unit_sound(type_name: String, sound_type: String, is_water: bool = false) -> void:
	## Play a per-unit sound effect.
	## type_name: unit folder name (e.g. "tank", "awac")
	## sound_type: "start", "stop", "drive", "wait", "attack"
	## is_water: if true, tries water variant first (e.g. "drive_water.ogg")
	var base := VEHICLES_BASE + type_name + "/"

	if is_water:
		var water_path := base + sound_type + "_water.ogg"
		if _try_play_sfx(water_path):
			return

	var path := base + sound_type + ".ogg"
	_try_play_sfx(path)


func play_sfx_at_path(path: String) -> void:
	## Play a sound effect from an explicit file path.
	_play_sfx_from_path(path)


func _try_play_sfx(path: String) -> bool:
	var stream := _load_sound(path)
	if stream:
		_play_stream(stream)
		return true
	return false


func _play_sfx_from_path(path: String) -> void:
	var stream := _load_sound(path)
	if stream:
		_play_stream(stream)


func _play_stream(stream: AudioStream) -> void:
	# Round-robin through the SFX pool
	var player := _sfx_players[_sfx_index]
	_sfx_index = (_sfx_index + 1) % SFX_POOL_SIZE

	player.stream = stream
	player.play()


# --- Music playback ---

func play_music(track_path: String = "") -> void:
	## Play a specific music track, or a random one if no path given.
	if track_path == "" and _music_tracks.size() > 0:
		_current_music_index = randi() % _music_tracks.size()
		track_path = _music_tracks[_current_music_index]

	if track_path == "":
		return  # No music available

	var stream := _load_sound(track_path)
	if stream:
		_music_player.stream = stream
		_music_player.play()


func stop_music() -> void:
	_music_player.stop()


func is_music_playing() -> bool:
	return _music_player.playing


func _on_music_finished() -> void:
	# Auto-advance to next track
	if _music_tracks.size() == 0:
		return
	_current_music_index = (_current_music_index + 1) % _music_tracks.size()
	play_music(_music_tracks[_current_music_index])


# --- Sound loading and caching ---

func _load_sound(path: String) -> AudioStream:
	# Check cache first
	if _sound_cache.has(path):
		var cached = _sound_cache[path]
		if cached == _MISSING_SOUND:
			return null
		return cached as AudioStream

	# Try to load the file
	if not FileAccess.file_exists(path):
		_sound_cache[path] = _MISSING_SOUND
		return null

	var stream: AudioStream = null

	if path.ends_with(".ogg"):
		stream = _load_ogg(path)
	elif path.ends_with(".wav"):
		stream = _load_wav(path)

	if stream:
		_sound_cache[path] = stream
	else:
		_sound_cache[path] = _MISSING_SOUND
	return stream


func _load_ogg(path: String) -> AudioStream:
	## Load an OGG Vorbis file as an AudioStreamOggVorbis.
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return null
	var data := file.get_buffer(file.get_length())
	file.close()

	var ogg_stream := AudioStreamOggVorbis.load_from_buffer(data)
	return ogg_stream


func _load_wav(path: String) -> AudioStream:
	## Load a WAV file as an AudioStreamWAV.
	## WAV loading from raw bytes requires parsing the header; for now just
	## use ResourceLoader if the file is imported, otherwise skip.
	if ResourceLoader.exists(path):
		return ResourceLoader.load(path) as AudioStream
	return null


func get_cache_stats() -> Dictionary:
	var loaded := 0
	var missing := 0
	for key in _sound_cache:
		if _sound_cache[key] == _MISSING_SOUND:
			missing += 1
		else:
			loaded += 1
	return {"loaded": loaded, "missing": missing}
