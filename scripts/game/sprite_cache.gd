extends RefCounted
## SpriteCache -- Lazy-loads and caches all game textures.
##
## Supports:
##   - Vehicle directional sprites (img0-7.png, 8 directions)
##   - Vehicle shadow sprites (shw0-7.png)
##   - Vehicle animation frames (img0-7_00-12.png for infantry/commando)
##   - Building sprites (img.png) and shadows (shw.png)
##   - Building effect overlays (effect.png)
##   - Unit icons (store.png for vehicles, info.png for buildings)
##   - FX sprites (explosions, muzzle flashes, projectiles, etc.)
##   - GFX / UI assets (HUD elements, logos, etc.)

const VEHICLES_BASE := "res://data/vehicles/"
const BUILDINGS_BASE := "res://data/buildings/"
const FX_BASE := "res://data/fx/"
const GFX_BASE := "res://data/gfx/"
const DATA_BASE := "res://data/"

# Phase 33: Team colour mask — magenta #FF00FF pixels replaced with player colour
const MASK_COLOR := Color(1.0, 0.0, 1.0, 1.0)  # Magenta #FF00FF
const MASK_TOLERANCE := 2  # Per-channel tolerance (0-255 integer)

# Caches -- keyed by full path string
var _texture_cache: Dictionary = {}  # path -> ImageTexture or _MISSING
var _recolored_cache: Dictionary = {}  # "path:RRGGBB" -> ImageTexture (per-player)
var _MISSING := RefCounted.new()     # Sentinel for "tried, not found"

# --- Vehicle Textures ---

func get_vehicle_texture(type_name: String, direction: int = 0) -> Texture2D:
	## Load a vehicle sprite for the given direction (0-7).
	## 0=North, 1=NE, 2=East, 3=SE, 4=South, 5=SW, 6=West, 7=NW
	direction = clampi(direction, 0, 7)
	var path := VEHICLES_BASE + type_name + "/img%d.png" % direction
	return _load_texture(path)


func get_vehicle_shadow(type_name: String, direction: int = 0) -> Texture2D:
	## Load a vehicle shadow sprite for the given direction (0-7).
	direction = clampi(direction, 0, 7)
	var path := VEHICLES_BASE + type_name + "/shw%d.png" % direction
	return _load_texture(path)


func get_vehicle_anim_frame(type_name: String, direction: int, frame: int) -> Texture2D:
	## Load an animated vehicle frame (for infantry, commando).
	## Pattern: img{dir}_{frame:02d}.png
	direction = clampi(direction, 0, 7)
	var path := VEHICLES_BASE + type_name + "/img%d_%02d.png" % [direction, frame]
	return _load_texture(path)


func get_vehicle_overlay(type_name: String) -> Texture2D:
	## Load a vehicle overlay sprite (e.g. AWAC/scanner scan range circle).
	var path := VEHICLES_BASE + type_name + "/overlay.png"
	return _load_texture(path)


# --- Building Textures ---

func get_building_texture(type_name: String) -> Texture2D:
	## Load a building's main sprite (img.png).
	var path := BUILDINGS_BASE + type_name + "/img.png"
	return _load_texture(path)


func get_building_shadow(type_name: String) -> Texture2D:
	## Load a building shadow sprite (shw.png).
	var path := BUILDINGS_BASE + type_name + "/shw.png"
	return _load_texture(path)


func get_building_effect(type_name: String) -> Texture2D:
	## Load a building effect overlay (effect.png -- animated working indicator).
	var path := BUILDINGS_BASE + type_name + "/effect.png"
	return _load_texture(path)


func get_building_video(type_name: String) -> Texture2D:
	## Load a building video/info image (video.png).
	var path := BUILDINGS_BASE + type_name + "/video.png"
	return _load_texture(path)


# --- Unit Icons ---

func get_unit_icon(type_name: String, is_vehicle: bool) -> Texture2D:
	## Load the store/info icon for a unit.
	## Vehicles use store.png, buildings use info.png.
	var base := VEHICLES_BASE if is_vehicle else BUILDINGS_BASE
	var filename := "store.png" if is_vehicle else "info.png"
	var path := base + type_name + "/" + filename
	return _load_texture(path)


func get_unit_info_icon(type_name: String, is_vehicle: bool) -> Texture2D:
	## Load the info icon for any unit type.
	var base := VEHICLES_BASE if is_vehicle else BUILDINGS_BASE
	var path := base + type_name + "/info.png"
	return _load_texture(path)


# --- FX Sprites ---

func get_fx_texture(fx_name: String) -> Texture2D:
	## Load an FX sprite by name (without extension).
	## e.g. "explo_big", "muzzle_big", "rocket", "torpedo", "hit", "smoke"
	var path := FX_BASE + fx_name + ".png"
	return _load_texture(path)


# --- GFX / UI Assets ---

func get_gfx_texture(gfx_name: String) -> Texture2D:
	## Load a UI/GFX asset by name (without extension).
	## e.g. "logo", "main", "hud_left", "hud_right", "hud_top"
	var path := GFX_BASE + gfx_name + ".png"
	return _load_texture(path)


func get_data_texture(relative_path: String) -> Texture2D:
	## Load any texture from the data directory by relative path.
	var path := DATA_BASE + relative_path
	return _load_texture(path)


# --- Animated Unit Queries ---

func has_animation_frames(type_name: String) -> bool:
	## Check if a vehicle type has animation frames (infantry/commando style).
	## Tests for the existence of img0_00.png.
	var path := VEHICLES_BASE + type_name + "/img0_00.png"
	return FileAccess.file_exists(path)


func get_animation_frame_count(type_name: String) -> int:
	## Count how many animation frames exist for direction 0.
	## Returns 0 if no animation frames found.
	var count := 0
	while true:
		var path := VEHICLES_BASE + type_name + "/img0_%02d.png" % count
		if not FileAccess.file_exists(path):
			break
		count += 1
	return count


# --- Internal Loading ---

func _load_texture(path: String) -> Texture2D:
	## Load a texture from disk with caching.
	## Returns null if the file doesn't exist.
	if _texture_cache.has(path):
		var cached = _texture_cache[path]
		if cached == _MISSING:
			return null
		return cached as Texture2D

	if not FileAccess.file_exists(path):
		_texture_cache[path] = _MISSING
		return null

	var img := Image.new()
	var err := img.load(path)
	if err != OK:
		_texture_cache[path] = _MISSING
		return null

	var tex := ImageTexture.create_from_image(img)
	_texture_cache[path] = tex
	return tex


# --- Cache Management ---

func get_cache_stats() -> Dictionary:
	var loaded := 0
	var missing := 0
	for key in _texture_cache:
		if _texture_cache[key] == _MISSING:
			missing += 1
		else:
			loaded += 1
	return {"loaded": loaded, "missing": missing, "total": _texture_cache.size()}


func clear_cache() -> void:
	_texture_cache.clear()
	_recolored_cache.clear()


# =============================================================================
# PHASE 33: TEAM COLOUR MASK RECOLOURING
# =============================================================================

func get_vehicle_texture_recolored(type_name: String, direction: int, player_color: Color) -> Texture2D:
	## Load a vehicle sprite and replace magenta mask pixels with the player colour.
	direction = clampi(direction, 0, 7)
	var path := VEHICLES_BASE + type_name + "/img%d.png" % direction
	return _get_recolored_texture(path, player_color)


func get_building_texture_recolored(type_name: String, player_color: Color) -> Texture2D:
	## Load a building sprite and replace magenta mask pixels with the player colour.
	var path := BUILDINGS_BASE + type_name + "/img.png"
	return _get_recolored_texture(path, player_color)


func get_vehicle_anim_frame_recolored(type_name: String, direction: int, frame: int, player_color: Color) -> Texture2D:
	## Load an animated vehicle frame with magenta mask replaced.
	direction = clampi(direction, 0, 7)
	var path := VEHICLES_BASE + type_name + "/img%d_%02d.png" % [direction, frame]
	return _get_recolored_texture(path, player_color)


func _get_recolored_texture(path: String, player_color: Color) -> Texture2D:
	## Load a texture and replace magenta mask pixels with player_color.
	## Caches per path+color combination.
	var color_key := "%02x%02x%02x" % [int(player_color.r * 255), int(player_color.g * 255), int(player_color.b * 255)]
	var cache_key := path + ":" + color_key

	if _recolored_cache.has(cache_key):
		var cached = _recolored_cache[cache_key]
		if cached == _MISSING:
			return null
		return cached as Texture2D

	# Load the source image
	if not FileAccess.file_exists(path):
		_recolored_cache[cache_key] = _MISSING
		return null

	var img := Image.new()
	var err := img.load(path)
	if err != OK:
		_recolored_cache[cache_key] = _MISSING
		return null

	# Check if this image has any magenta pixels worth recolouring
	var has_mask := _recolor_image(img, player_color)

	var tex := ImageTexture.create_from_image(img)
	_recolored_cache[cache_key] = tex
	return tex


func _recolor_image(img: Image, player_color: Color) -> bool:
	## Replace magenta mask pixels in the image with the given player color.
	## Preserves alpha and blends luminance for shading.
	## Returns true if any pixels were modified.
	var width := img.get_width()
	var height := img.get_height()
	var modified := false

	# Target RGB values for comparison (0-255)
	var mask_r := int(MASK_COLOR.r * 255)
	var mask_g := int(MASK_COLOR.g * 255)
	var mask_b := int(MASK_COLOR.b * 255)

	for y in range(height):
		for x in range(width):
			var pixel: Color = img.get_pixel(x, y)
			if pixel.a < 0.01:
				continue  # Skip transparent pixels

			var pr := int(pixel.r * 255)
			var pg := int(pixel.g * 255)
			var pb := int(pixel.b * 255)

			# Check if pixel is within tolerance of magenta mask
			if absi(pr - mask_r) <= MASK_TOLERANCE and pg <= MASK_TOLERANCE and absi(pb - mask_b) <= MASK_TOLERANCE:
				# Pure magenta — replace entirely with player color
				img.set_pixel(x, y, Color(player_color.r, player_color.g, player_color.b, pixel.a))
				modified = true
			elif pr > 200 and pg < 80 and pb > 200:
				# Near-magenta (shaded magenta) — blend with player color
				# Use the luminance difference from pure magenta to shade the player color
				var luminance := (float(pr) + float(pb)) / (255.0 * 2.0)
				var shaded := Color(
					player_color.r * luminance,
					player_color.g * luminance,
					player_color.b * luminance,
					pixel.a)
				img.set_pixel(x, y, shaded)
				modified = true

	return modified


func preload_vehicle(type_name: String) -> void:
	## Preload all sprites for a vehicle type (all 8 directions + shadows).
	for dir in range(8):
		get_vehicle_texture(type_name, dir)
		get_vehicle_shadow(type_name, dir)
	get_unit_icon(type_name, true)


func preload_building(type_name: String) -> void:
	## Preload all sprites for a building type.
	get_building_texture(type_name)
	get_building_shadow(type_name)
	get_building_effect(type_name)
	get_unit_icon(type_name, false)
