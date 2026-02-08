extends Node2D
## CombatEffects -- Renders attack sequences using real FX sprites where available.
##
## Sequence:  Muzzle Flash -> Projectile Travel -> Impact/Explosion -> Damage Number
##
## Uses sprites from data/fx/:
##   muzzle_big.png, muzzle_med.png, muzzle_small.png
##   rocket.png, torpedo.png
##   explo_big.png, explo_small.png, explo_air.png, explo_water.png
##   hit.png, smoke.png, dark_smoke.png
##   corpse.png

signal effect_sequence_finished(attacker_id: int, target_id: int)

const TILE_SIZE := 64

# Effect types
enum FXType { MUZZLE, PROJECTILE, IMPACT, EXPLOSION, DAMAGE_NUMBER, SMOKE, CORPSE }

# Active effect instances
var _effects: Array = []
var _sprite_cache = null  # Set externally
var attacker_type_name := ""  # Set before play_attack_sequence()

# Pre-cached FX textures
var _fx_textures: Dictionary = {}
var _fx_loaded := false

# Weapon type -> FX configuration
const WEAPON_FX := {
	"Big": {"muzzle": "muzzle_big", "projectile": null, "explosion": "explo_big", "color": Color(1.0, 0.7, 0.2)},
	"Rocket": {"muzzle": "muzzle_small", "projectile": "rocket", "explosion": "explo_big", "color": Color(1.0, 0.4, 0.1)},
	"RocketCluster": {"muzzle": "muzzle_small", "projectile": "rocket", "explosion": "explo_big", "color": Color(1.0, 0.3, 0.1)},
	"Small": {"muzzle": "muzzle_small", "projectile": null, "explosion": "explo_small", "color": Color(1.0, 0.9, 0.4)},
	"Med": {"muzzle": "muzzle_med", "projectile": null, "explosion": "explo_small", "color": Color(1.0, 0.8, 0.3)},
	"Torpedo": {"muzzle": "muzzle_small", "projectile": "torpedo", "explosion": "explo_water", "color": Color(0.3, 0.6, 1.0)},
	"Sniper": {"muzzle": "muzzle_small", "projectile": null, "explosion": "hit", "color": Color(0.9, 1.0, 0.5)},
}

class Effect:
	var type: int = 0  # FXType enum
	var position: Vector2 = Vector2.ZERO
	var target_pos: Vector2 = Vector2.ZERO  # For projectiles
	var color: Color = Color.WHITE
	var timer: float = 0.0
	var duration: float = 0.0
	var progress: float = 0.0  # 0..1 interpolation
	var text: String = ""
	var size: float = 1.0
	var attacker_id: int = -1
	var target_id: int = -1
	var sprite_name: String = ""  # FX sprite to use
	var rotation_angle: float = 0.0
	var is_kill: bool = false


func _ready() -> void:
	z_index = 100  # Draw above everything


func _ensure_fx_loaded() -> void:
	## Lazy-load FX textures on first use.
	if _fx_loaded:
		return
	_fx_loaded = true
	if not _sprite_cache:
		return
	for fx_name in ["muzzle_big", "muzzle_med", "muzzle_small",
					 "explo_big", "explo_small", "explo_air", "explo_water",
					 "rocket", "torpedo", "hit", "smoke", "dark_smoke", "corpse"]:
		var tex: Texture2D = _sprite_cache.get_fx_texture(fx_name)
		if tex:
			_fx_textures[fx_name] = tex


func play_attack_sequence(attacker_tile: Vector2i, target_tile: Vector2i,
		damage: int, will_destroy: bool, muzzle_type: String,
		attacker_id: int, target_id: int) -> void:
	## Play a full attack sequence: muzzle -> projectile -> impact -> damage number.
	_ensure_fx_loaded()

	var att_pos := _tile_center(attacker_tile)
	var tgt_pos := _tile_center(target_tile)
	var distance := att_pos.distance_to(tgt_pos)

	# Determine weapon FX config
	var fx_config: Dictionary = WEAPON_FX.get(muzzle_type, WEAPON_FX["Big"])
	var weapon_color: Color = fx_config["color"]

	# Calculate angle from attacker to target
	var angle := att_pos.angle_to_point(tgt_pos)

	# Play attack sound
	if attacker_type_name != "":
		AudioManager.play_unit_sound(attacker_type_name, "attack")
	else:
		AudioManager.play_sound("arm")

	# 1. Muzzle flash (immediate)
	var muzzle := Effect.new()
	muzzle.type = FXType.MUZZLE
	muzzle.position = att_pos
	muzzle.color = weapon_color
	muzzle.duration = 0.2
	muzzle.size = 1.2
	muzzle.sprite_name = fx_config["muzzle"]
	muzzle.rotation_angle = angle
	_effects.append(muzzle)

	# 2. Projectile (if weapon has one)
	var projectile_duration := clampf(distance / 600.0, 0.15, 0.8)
	var projectile_sprite: String = fx_config.get("projectile", "")

	if projectile_sprite != null and projectile_sprite != "":
		var proj := Effect.new()
		proj.type = FXType.PROJECTILE
		proj.position = att_pos
		proj.target_pos = tgt_pos
		proj.color = weapon_color
		proj.duration = projectile_duration
		proj.timer = -0.05  # Slight delay after muzzle flash
		proj.sprite_name = projectile_sprite
		proj.rotation_angle = angle
		proj.attacker_id = attacker_id
		proj.target_id = target_id
		_effects.append(proj)
	else:
		# Instant hit (no visible projectile) - use a fast tracer line
		var tracer := Effect.new()
		tracer.type = FXType.PROJECTILE
		tracer.position = att_pos
		tracer.target_pos = tgt_pos
		tracer.color = weapon_color
		tracer.duration = 0.12
		tracer.timer = -0.05
		tracer.sprite_name = ""  # Procedural tracer
		tracer.rotation_angle = angle
		tracer.attacker_id = attacker_id
		tracer.target_id = target_id
		_effects.append(tracer)
		projectile_duration = 0.12

	var impact_delay := projectile_duration + 0.05

	# 3. Impact / Explosion (after projectile arrives)
	var explosion := Effect.new()
	explosion.type = FXType.EXPLOSION
	explosion.position = tgt_pos
	explosion.color = weapon_color
	explosion.duration = 0.5 if will_destroy else 0.35
	explosion.timer = -impact_delay
	explosion.size = 1.5 if will_destroy else 1.0
	explosion.sprite_name = fx_config["explosion"]
	explosion.is_kill = will_destroy
	_effects.append(explosion)

	# Phase 33: Play impact/explosion sound after delay
	_play_delayed_sound(impact_delay, "explosion" if not will_destroy else "unit_destroyed")

	# Extra smoke on kill
	if will_destroy:
		var smoke := Effect.new()
		smoke.type = FXType.SMOKE
		smoke.position = tgt_pos + Vector2(0, -8)
		smoke.duration = 1.2
		smoke.timer = -(impact_delay + 0.15)
		smoke.sprite_name = "dark_smoke"
		_effects.append(smoke)

		# Corpse wreckage that lingers
		var corpse := Effect.new()
		corpse.type = FXType.CORPSE
		corpse.position = tgt_pos
		corpse.duration = 3.0
		corpse.timer = -(impact_delay + 0.3)
		corpse.sprite_name = "corpse"
		_effects.append(corpse)

	# 4. Damage number (floats upward)
	var dmg_text := Effect.new()
	dmg_text.type = FXType.DAMAGE_NUMBER
	dmg_text.position = tgt_pos + Vector2(0, -10)
	dmg_text.text = str(damage) if damage > 0 else "MISS"
	dmg_text.color = Color(1.0, 0.15, 0.1) if will_destroy else Color(1.0, 0.9, 0.2)
	dmg_text.duration = 1.2
	dmg_text.timer = -(impact_delay + 0.1)
	dmg_text.is_kill = will_destroy
	dmg_text.attacker_id = attacker_id
	dmg_text.target_id = target_id
	_effects.append(dmg_text)


func _process(delta: float) -> void:
	if _effects.is_empty():
		return

	var finished_effects: Array = []
	var _sequence_done := false

	for i in range(_effects.size()):
		var fx: Effect = _effects[i]
		fx.timer += delta

		if fx.timer < 0:
			continue  # Delayed start

		if fx.timer >= fx.duration:
			finished_effects.append(i)
			# Check if this was the damage number (last in sequence)
			if fx.type == FXType.DAMAGE_NUMBER:
				_sequence_done = true
				effect_sequence_finished.emit(fx.attacker_id, fx.target_id)
			continue

		fx.progress = clampf(fx.timer / fx.duration, 0.0, 1.0)

	# Remove finished effects (reverse order to preserve indices)
	finished_effects.sort()
	for i in range(finished_effects.size() - 1, -1, -1):
		_effects.remove_at(finished_effects[i])

	queue_redraw()


func _draw() -> void:
	for fx in _effects:
		if fx.timer < 0:
			continue  # Not started yet

		match fx.type:
			FXType.MUZZLE:
				_draw_muzzle(fx)
			FXType.PROJECTILE:
				_draw_projectile(fx)
			FXType.EXPLOSION:
				_draw_explosion(fx)
			FXType.DAMAGE_NUMBER:
				_draw_damage_number(fx)
			FXType.SMOKE:
				_draw_smoke(fx)
			FXType.CORPSE:
				_draw_corpse(fx)


func _draw_muzzle(fx: Effect) -> void:
	## Draw muzzle flash using FX sprite or procedural.
	var alpha := 1.0 - fx.progress
	var fx_scale := 0.5 + fx.progress * 1.0

	var tex: Texture2D = _fx_textures.get(fx.sprite_name, null)
	if tex:
		var size := tex.get_size() * fx_scale * fx.size
		var draw_pos := fx.position - size / 2.0
		draw_texture_rect(tex, Rect2(draw_pos, size), false,
			Color(1, 1, 1, alpha))
	else:
		# Procedural muzzle flash
		var radius := 12.0 * fx_scale * fx.size
		draw_circle(fx.position, radius, Color(fx.color.r, fx.color.g, fx.color.b, alpha * 0.6))
		draw_circle(fx.position, radius * 0.5, Color(1.0, 1.0, 0.9, alpha))
		# Directional streak
		var streak_end := fx.position + Vector2(cos(fx.rotation_angle + PI), sin(fx.rotation_angle + PI)) * radius * 2.0
		draw_line(fx.position, streak_end, Color(fx.color.r, fx.color.g, fx.color.b, alpha * 0.5), 3.0)


func _draw_projectile(fx: Effect) -> void:
	## Draw projectile traveling from attacker to target.
	var current_pos := fx.position.lerp(fx.target_pos, fx.progress)

	var tex: Texture2D = _fx_textures.get(fx.sprite_name, null)
	if tex and fx.sprite_name != "":
		var size := tex.get_size()
		var _draw_pos := current_pos - size / 2.0
		# Draw with rotation toward target
		draw_set_transform(current_pos, fx.rotation_angle, Vector2.ONE)
		draw_texture_rect(tex, Rect2(-size / 2.0, size), false)
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

		# Trail effect
		var trail_start := fx.position.lerp(fx.target_pos, maxf(fx.progress - 0.15, 0.0))
		draw_line(trail_start, current_pos,
			Color(fx.color.r, fx.color.g, fx.color.b, 0.3), 2.0)
	else:
		# Procedural tracer
		var trail_start := fx.position.lerp(fx.target_pos, maxf(fx.progress - 0.3, 0.0))
		draw_line(trail_start, current_pos, Color(fx.color.r, fx.color.g, fx.color.b, 0.8), 3.0)
		draw_circle(current_pos, 4.0, fx.color)
		draw_circle(current_pos, 2.0, Color(1, 1, 0.9, 0.9))


func _draw_explosion(fx: Effect) -> void:
	## Draw explosion effect using FX sprite or procedural.
	var alpha: float
	if fx.progress < 0.3:
		alpha = fx.progress / 0.3  # Fade in
	else:
		alpha = 1.0 - (fx.progress - 0.3) / 0.7  # Fade out
	alpha = clampf(alpha, 0.0, 1.0)

	var fx_scale := 0.3 + fx.progress * 1.2
	if fx.is_kill:
		fx_scale *= 1.4

	var tex: Texture2D = _fx_textures.get(fx.sprite_name, null)
	if tex:
		var size := tex.get_size() * fx_scale * fx.size
		var draw_pos := fx.position - size / 2.0
		draw_texture_rect(tex, Rect2(draw_pos, size), false,
			Color(1, 1, 1, alpha))
	else:
		# Procedural explosion
		var max_radius := 24.0 * fx.size * fx_scale

		# Outer blast ring
		draw_arc(fx.position, max_radius, 0, TAU, 24,
			Color(fx.color.r, fx.color.g, fx.color.b, alpha * 0.4), 3.0)

		# Inner fireball
		draw_circle(fx.position, max_radius * 0.6,
			Color(1.0, 0.6, 0.1, alpha * 0.6))
		draw_circle(fx.position, max_radius * 0.3,
			Color(1.0, 0.9, 0.5, alpha))

	# Debris particles (procedural, always)
	if fx.is_kill and fx.progress < 0.7:
		var particle_count := 8
		for i in range(particle_count):
			var angle := float(i) / particle_count * TAU + fx.position.x * 0.1
			var particle_dist := fx.progress * 50.0 * fx.size
			var particle_pos := fx.position + Vector2(cos(angle), sin(angle)) * particle_dist
			var particle_alpha := (0.7 - fx.progress) / 0.7
			draw_circle(particle_pos, 2.5, Color(0.6, 0.4, 0.2, particle_alpha))


func _draw_damage_number(fx: Effect) -> void:
	## Draw floating damage number that drifts upward.
	var y_offset := fx.progress * -40.0
	var alpha: float
	if fx.progress < 0.2:
		alpha = fx.progress / 0.2
	elif fx.progress > 0.7:
		alpha = 1.0 - (fx.progress - 0.7) / 0.3
	else:
		alpha = 1.0
	alpha = clampf(alpha, 0.0, 1.0)

	var pos := fx.position + Vector2(0, y_offset)
	var font := ThemeDB.fallback_font
	var font_size := 18 if fx.is_kill else 14

	# Shadow
	draw_string(font, pos + Vector2(1, 1), fx.text, HORIZONTAL_ALIGNMENT_CENTER,
		-1, font_size, Color(0, 0, 0, alpha * 0.7))
	# Text
	var text_color := Color(fx.color.r, fx.color.g, fx.color.b, alpha)
	draw_string(font, pos, fx.text, HORIZONTAL_ALIGNMENT_CENTER,
		-1, font_size, text_color)

	# Extra "DESTROYED" label for kills
	if fx.is_kill and fx.text != "MISS":
		var destroy_pos := pos + Vector2(0, 18)
		draw_string(font, destroy_pos + Vector2(1, 1), "DESTROYED", HORIZONTAL_ALIGNMENT_CENTER,
			-1, 11, Color(0, 0, 0, alpha * 0.5))
		draw_string(font, destroy_pos, "DESTROYED", HORIZONTAL_ALIGNMENT_CENTER,
			-1, 11, Color(1.0, 0.3, 0.1, alpha * 0.8))


func _draw_smoke(fx: Effect) -> void:
	## Draw rising smoke using sprite or procedural.
	var alpha := 1.0 - fx.progress
	alpha = clampf(alpha * 0.7, 0.0, 1.0)
	var rise := fx.progress * -30.0
	var fx_scale := 0.5 + fx.progress * 0.8
	var pos := fx.position + Vector2(0, rise)

	var tex: Texture2D = _fx_textures.get(fx.sprite_name, null)
	if tex:
		var size := tex.get_size() * fx_scale
		draw_texture_rect(tex, Rect2(pos - size / 2.0, size), false,
			Color(1, 1, 1, alpha))
	else:
		draw_circle(pos, 10 * fx_scale, Color(0.3, 0.3, 0.3, alpha * 0.5))
		draw_circle(pos + Vector2(5, -5), 7 * fx_scale, Color(0.25, 0.25, 0.25, alpha * 0.4))


func _draw_corpse(fx: Effect) -> void:
	## Draw unit wreckage that fades out slowly.
	var alpha: float
	if fx.progress < 0.1:
		alpha = fx.progress / 0.1
	elif fx.progress > 0.7:
		alpha = 1.0 - (fx.progress - 0.7) / 0.3
	else:
		alpha = 1.0
	alpha = clampf(alpha * 0.8, 0.0, 1.0)

	var tex: Texture2D = _fx_textures.get("corpse", null)
	if tex:
		var size := tex.get_size()
		draw_texture_rect(tex, Rect2(fx.position - size / 2.0, size), false,
			Color(1, 1, 1, alpha))
	else:
		# Procedural wreckage
		draw_circle(fx.position, 8, Color(0.2, 0.18, 0.15, alpha))
		draw_circle(fx.position + Vector2(4, -2), 5, Color(0.15, 0.13, 0.10, alpha * 0.7))


func _tile_center(tile: Vector2i) -> Vector2:
	return Vector2(tile.x * TILE_SIZE + TILE_SIZE / 2.0, tile.y * TILE_SIZE + TILE_SIZE / 2.0)


func _play_delayed_sound(delay: float, sound_name: String) -> void:
	## Phase 33: Play a sound effect after a delay (for impact/explosion timing).
	if delay <= 0.01:
		AudioManager.play_sound(sound_name)
	else:
		var timer := get_tree().create_timer(delay)
		timer.timeout.connect(func(): AudioManager.play_sound(sound_name))
