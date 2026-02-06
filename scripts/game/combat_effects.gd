extends Node2D
## Renders combat visual effects: muzzle flashes, projectiles,
## impacts, floating damage numbers, and destruction explosions.

signal effect_sequence_finished(attacker_id: int, target_id: int)

const TILE_SIZE := 64

# Active effects
var _effects: Array = []

# Effect types
enum EffectType {
	MUZZLE_FLASH,
	PROJECTILE,
	IMPACT,
	DAMAGE_NUMBER,
	EXPLOSION
}

class Effect:
	var type: int  # EffectType
	var pos: Vector2
	var target_pos: Vector2
	var color: Color
	var timer: float = 0.0
	var duration: float
	var text: String = ""
	var size: float = 1.0
	var progress: float = 0.0
	var attacker_id: int = -1
	var target_id: int = -1
	var is_sequence_end: bool = false  # True for the last effect in an attack sequence


func play_attack_sequence(attacker_pos: Vector2i, target_pos: Vector2i,
		damage: int, will_destroy: bool, muzzle_type: String,
		attacker_id: int, target_id: int) -> void:
	## Play a full attack sequence: muzzle flash -> projectile -> impact/explosion + damage number

	var from = _tile_center(attacker_pos)
	var to = _tile_center(target_pos)

	# 1. Muzzle flash (immediate)
	var flash = Effect.new()
	flash.type = EffectType.MUZZLE_FLASH
	flash.pos = from
	flash.target_pos = to
	flash.color = _muzzle_color(muzzle_type)
	flash.duration = 0.15
	flash.size = _muzzle_size(muzzle_type)
	flash.attacker_id = attacker_id
	flash.target_id = target_id
	_effects.append(flash)

	# 2. Projectile (starts at 0.05s)
	var proj = Effect.new()
	proj.type = EffectType.PROJECTILE
	proj.pos = from
	proj.target_pos = to
	proj.color = _projectile_color(muzzle_type)
	proj.duration = _projectile_duration(from, to)
	proj.timer = -0.05  # Delayed start
	proj.size = 4.0 if muzzle_type == "Rocket" else 3.0
	proj.attacker_id = attacker_id
	proj.target_id = target_id
	_effects.append(proj)

	# 3. Impact / explosion (after projectile arrives)
	var impact_delay = proj.duration + 0.05
	if will_destroy:
		var explosion = Effect.new()
		explosion.type = EffectType.EXPLOSION
		explosion.pos = to
		explosion.color = Color(1.0, 0.6, 0.1)
		explosion.duration = 0.6
		explosion.timer = -impact_delay
		explosion.size = TILE_SIZE * 0.8
		explosion.attacker_id = attacker_id
		explosion.target_id = target_id
		explosion.is_sequence_end = true
		_effects.append(explosion)
	else:
		var impact = Effect.new()
		impact.type = EffectType.IMPACT
		impact.pos = to
		impact.color = Color(1.0, 0.8, 0.3)
		impact.duration = 0.3
		impact.timer = -impact_delay
		impact.size = 16.0
		impact.attacker_id = attacker_id
		impact.target_id = target_id
		impact.is_sequence_end = true
		_effects.append(impact)

	# 4. Floating damage number (appears at impact)
	if damage > 0:
		var dmg_num = Effect.new()
		dmg_num.type = EffectType.DAMAGE_NUMBER
		dmg_num.pos = to + Vector2(0, -10)
		dmg_num.color = Color.RED if will_destroy else Color.YELLOW
		dmg_num.duration = 1.0
		dmg_num.timer = -impact_delay
		dmg_num.text = "-" + str(damage)
		dmg_num.size = 18.0 if will_destroy else 14.0
		_effects.append(dmg_num)


func _process(delta: float) -> void:
	if _effects.is_empty():
		return

	var finished: Array = []

	for i in range(_effects.size()):
		var fx: Effect = _effects[i]
		fx.timer += delta

		if fx.timer < 0:
			continue  # Delayed, not started yet

		fx.progress = clampf(fx.timer / fx.duration, 0.0, 1.0)

		if fx.timer >= fx.duration:
			finished.append(i)

	# Remove finished effects (reverse order)
	for i in range(finished.size() - 1, -1, -1):
		var idx = finished[i]
		var fx: Effect = _effects[idx]
		if fx.is_sequence_end:
			effect_sequence_finished.emit(fx.attacker_id, fx.target_id)
		_effects.remove_at(idx)

	queue_redraw()


func _draw() -> void:
	for fx in _effects:
		if fx.timer < 0:
			continue  # Not started yet

		match fx.type:
			EffectType.MUZZLE_FLASH:
				_draw_muzzle_flash(fx)
			EffectType.PROJECTILE:
				_draw_projectile(fx)
			EffectType.IMPACT:
				_draw_impact(fx)
			EffectType.DAMAGE_NUMBER:
				_draw_damage_number(fx)
			EffectType.EXPLOSION:
				_draw_explosion(fx)


func _draw_muzzle_flash(fx: Effect) -> void:
	var alpha = 1.0 - fx.progress
	var color = fx.color
	color.a = alpha
	var radius = fx.size * (1.0 + fx.progress * 0.5)
	draw_circle(fx.pos, radius, color)
	# Bright core
	draw_circle(fx.pos, radius * 0.5, Color(1, 1, 0.9, alpha * 0.8))


func _draw_projectile(fx: Effect) -> void:
	var current_pos = fx.pos.lerp(fx.target_pos, fx.progress)
	var alpha = 1.0
	var color = fx.color
	color.a = alpha

	# Trail
	var trail_start = fx.pos.lerp(fx.target_pos, maxf(0, fx.progress - 0.2))
	draw_line(trail_start, current_pos, Color(color.r, color.g, color.b, 0.3), 2.0)

	# Projectile head
	draw_circle(current_pos, fx.size, color)
	draw_circle(current_pos, fx.size * 0.5, Color(1, 1, 1, 0.9))


func _draw_impact(fx: Effect) -> void:
	var alpha = 1.0 - fx.progress
	var radius = fx.size * (0.5 + fx.progress * 1.5)
	var color = fx.color
	color.a = alpha * 0.8
	draw_circle(fx.pos, radius, color)
	# Bright flash
	var flash_alpha = maxf(0, 1.0 - fx.progress * 3.0)
	draw_circle(fx.pos, radius * 0.6, Color(1, 1, 1, flash_alpha))


func _draw_damage_number(fx: Effect) -> void:
	var alpha = 1.0 - fx.progress * 0.7
	var y_offset = -30.0 * fx.progress  # Float upward
	var pos = fx.pos + Vector2(0, y_offset)
	var color = fx.color
	color.a = alpha

	# Draw text outline
	var font = ThemeDB.fallback_font
	if font:
		var fsize = int(fx.size * (1.0 + fx.progress * 0.3))
		# Shadow
		draw_string(font, pos + Vector2(1, 1), fx.text, HORIZONTAL_ALIGNMENT_CENTER, -1, fsize, Color(0, 0, 0, alpha * 0.6))
		# Main text
		draw_string(font, pos, fx.text, HORIZONTAL_ALIGNMENT_CENTER, -1, fsize, color)


func _draw_explosion(fx: Effect) -> void:
	# Multi-ring explosion
	var phase1 = clampf(fx.progress * 2.0, 0, 1)  # First half: expanding fireball
	var phase2 = clampf((fx.progress - 0.3) * 2.5, 0, 1)  # Second half: fading

	# Outer ring (expanding)
	var outer_r = fx.size * phase1
	var outer_alpha = (1.0 - phase2) * 0.6
	draw_circle(fx.pos, outer_r, Color(1.0, 0.3, 0.0, outer_alpha))

	# Middle ring
	var mid_r = fx.size * 0.7 * phase1
	var mid_alpha = (1.0 - phase2) * 0.8
	draw_circle(fx.pos, mid_r, Color(1.0, 0.6, 0.1, mid_alpha))

	# Bright core
	var core_r = fx.size * 0.3 * maxf(0, 1.0 - fx.progress * 1.5)
	draw_circle(fx.pos, core_r, Color(1.0, 1.0, 0.8, maxf(0, 1.0 - fx.progress * 2.0)))

	# Debris particles (small dots flying outward)
	if fx.progress < 0.8:
		var particle_alpha = 1.0 - fx.progress * 1.3
		for i in range(8):
			var angle = TAU * i / 8.0 + fx.progress * 2.0
			var dist = fx.size * fx.progress * 1.2
			var ppos = fx.pos + Vector2(cos(angle), sin(angle)) * dist
			draw_circle(ppos, 2.0, Color(1.0, 0.5, 0.0, maxf(0, particle_alpha)))


# --- Helper functions ---

func _tile_center(tile: Vector2i) -> Vector2:
	return Vector2(tile.x * TILE_SIZE + TILE_SIZE / 2.0,
				   tile.y * TILE_SIZE + TILE_SIZE / 2.0)


func _muzzle_color(muzzle_type: String) -> Color:
	match muzzle_type:
		"Big": return Color(1.0, 0.7, 0.2)
		"Rocket": return Color(1.0, 0.4, 0.1)
		"Small": return Color(1.0, 0.9, 0.5)
		"Med": return Color(1.0, 0.6, 0.3)
		"RocketCluster": return Color(1.0, 0.3, 0.0)
		"Torpedo": return Color(0.3, 0.7, 1.0)
		"Sniper": return Color(0.9, 0.9, 1.0)
		_: return Color(1.0, 0.8, 0.3)


func _muzzle_size(muzzle_type: String) -> float:
	match muzzle_type:
		"Big": return 12.0
		"Rocket": return 10.0
		"Small": return 6.0
		"Med": return 8.0
		"RocketCluster": return 14.0
		"Torpedo": return 8.0
		"Sniper": return 5.0
		_: return 8.0


func _projectile_color(muzzle_type: String) -> Color:
	match muzzle_type:
		"Big": return Color(1.0, 0.8, 0.2)
		"Rocket": return Color(1.0, 0.5, 0.1)
		"Small": return Color(1.0, 1.0, 0.7)
		"Med": return Color(1.0, 0.7, 0.3)
		"RocketCluster": return Color(1.0, 0.4, 0.0)
		"Torpedo": return Color(0.4, 0.8, 1.0)
		"Sniper": return Color(0.8, 0.8, 1.0)
		_: return Color(1.0, 0.9, 0.4)


func _projectile_duration(from: Vector2, to: Vector2) -> float:
	var dist = from.distance_to(to)
	return clampf(dist / 500.0, 0.15, 0.6)
