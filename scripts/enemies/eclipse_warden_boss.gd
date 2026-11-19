class_name EclipseWardenBoss
extends EnemyBase
## Multi-Phase Sanctum Boss: Vaelor, Warden of the Eclipse (Phase 3).
##
## Phase 1 (100% -> 65% HP) — Sealed Blade:
##   Methodical advance, heavy Eclipse Greatsword Cleave, and aimed single Rift Orb.
## Phase 2 (65% -> 30% HP) — Shattered Halo:
##   Phase-shift shockwave, +28% move speed, +15% damage, Phantom Dash-Strike & 3-Orb Fan.
## Phase 3 (<= 30% HP) — Eternal Eclipse:
##   Golden-crimson overdrive, +48% move speed, +30% damage, rapid Dash-Cleave,
##   3-Orb Fan Volley, and 8-Orb Radial Eclipse Nova.

signal boss_engaged(boss: EclipseWardenBoss)
signal boss_hp_changed(current_hp: float, max_hp: float, phase: int)
signal boss_phase_changed(new_phase: int)
signal boss_vanquished(boss: EclipseWardenBoss)

enum BossAttackKind {
	CLEAVE = 0,
	DASH_STRIKE = 1,
	ORB_FAN = 2,
	ECLIPSE_NOVA = 3,
}

const ORB_SCENE: PackedScene = preload("res://scenes/combat/shadow_orb_projectile.tscn")

@export var dash_strike_speed: float = 435.0
@export var boss_orb_speed: float = 285.0

var current_phase: int = 1
var is_engaged: bool = false

var _phase_2_ratio: float = 0.65
var _phase_3_ratio: float = 0.30
var _phase_shift_duration: float = 0.95
var _p2_speed_mult: float = 1.28
var _p3_speed_mult: float = 1.48
var _p2_dmg_mult: float = 1.15
var _p3_dmg_mult: float = 1.30
var _fan_count: int = 3
var _fan_spread_deg: float = 38.0
var _nova_count: int = 8

var _queued_attack: int = BossAttackKind.CLEAVE
var _pattern_index: int = 0
var _dash_dir: Vector2 = Vector2.DOWN


func _on_enemy_ready() -> void:
	add_to_group("bosses")
	var bcfg: Dictionary = GameState.get_combat_config_section("boss")
	_phase_2_ratio = float(bcfg.get("phase_2_hp_ratio", _phase_2_ratio))
	_phase_3_ratio = float(bcfg.get("phase_3_hp_ratio", _phase_3_ratio))
	_phase_shift_duration = float(bcfg.get("phase_transition_duration", _phase_shift_duration))
	_p2_speed_mult = float(bcfg.get("phase_2_speed_multiplier", _p2_speed_mult))
	_p3_speed_mult = float(bcfg.get("phase_3_speed_multiplier", _p3_speed_mult))
	_p2_dmg_mult = float(bcfg.get("phase_2_damage_multiplier", _p2_dmg_mult))
	_p3_dmg_mult = float(bcfg.get("phase_3_damage_multiplier", _p3_dmg_mult))
	_fan_count = int(bcfg.get("fan_orb_count", _fan_count))
	_fan_spread_deg = float(bcfg.get("fan_spread_degrees", _fan_spread_deg))
	_nova_count = int(bcfg.get("nova_orb_count", _nova_count))
	_apply_phase_aura(1)


func _step_ai(target: PlayerCharacter, delta: float) -> void:
	if ai_state == AIState.PHASE_SHIFT:
		_state_timer = maxf(0.0, _state_timer - delta)
		_apply_desired_move(Vector2.ZERO)
		_play_anim(&"phase_shift")
		if _state_timer <= 0.0:
			_invulnerable_phase = false
			ai_state = AIState.CHASE
			_cooldown_timer = 0.25
			# In Phase 3 awakening, immediately release a signature Eclipse Nova!
			if current_phase == 3:
				spawn_radial_nova(_nova_count)
		return

	super._step_ai(target, delta)


func _tick_engage(target: PlayerCharacter, dist: float, _delta: float) -> void:
	if not is_engaged:
		is_engaged = true
		boss_engaged.emit(self)
		boss_hp_changed.emit(current_hp, stats.max_hp, current_phase)

	ai_state = AIState.CHASE
	_face_toward(target.global_position)

	if _cooldown_timer <= 0.0:
		var chosen: int = _select_next_attack(dist)
		if chosen >= 0:
			_queued_attack = chosen
			_begin_telegraph()
			if current_phase >= 3:
				_state_timer *= 0.82
			return

	var dir: Vector2 = _move_dir_toward(target.global_position)
	_apply_desired_move(dir * _get_effective_move_speed())
	_play_anim(&"move")


func _select_next_attack(dist: float) -> int:
	var chosen: int = -1
	if current_phase == 1:
		if dist <= stats.attack_range:
			chosen = BossAttackKind.CLEAVE
		elif dist <= 390.0 and (dist >= 250.0 or (dist >= 165.0 and _pattern_index % 2 == 1)):
			chosen = BossAttackKind.ORB_FAN
	elif current_phase == 2:
		var slot2: int = _pattern_index % 3
		if dist <= stats.attack_range:
			chosen = BossAttackKind.CLEAVE
		elif slot2 == 1 and dist <= 320.0:
			chosen = BossAttackKind.DASH_STRIKE
		elif slot2 == 2 and dist <= 400.0:
			chosen = BossAttackKind.ORB_FAN
	else:
		var slot3: int = _pattern_index % 4
		if slot3 == 3 and dist <= 360.0:
			chosen = BossAttackKind.ECLIPSE_NOVA
		elif dist <= stats.attack_range:
			chosen = BossAttackKind.CLEAVE
		elif slot3 in [0, 2] and dist <= 350.0:
			chosen = BossAttackKind.DASH_STRIKE
		elif slot3 == 1 and dist <= 420.0:
			chosen = BossAttackKind.ORB_FAN
	return chosen


func _begin_attack(target: PlayerCharacter) -> void:
	super._begin_attack(target)
	_pattern_index += 1
	var aim_pos: Vector2 = (
		target.global_position + Vector2(0.0, -26.0)
		if target != null
		else global_position + facing_vector * 160.0
	)
	match _queued_attack:
		BossAttackKind.DASH_STRIKE:
			_dash_dir = (
				_move_dir_toward(target.global_position)
				if target != null
				else facing_vector.normalized()
			)
			_set_facing(_dash_dir)
			_state_timer = 0.3
		BossAttackKind.ORB_FAN:
			var count: int = 1 if current_phase == 1 else _fan_count
			spawn_orb_fan(aim_pos, count, _fan_spread_deg)
			_attack_did_hit = true
		BossAttackKind.ECLIPSE_NOVA:
			_play_anim(&"phase_shift", true)
			spawn_radial_nova(_nova_count)
			_attack_did_hit = true
		_:
			pass


func _tick_attack(target: PlayerCharacter, _delta: float) -> void:
	if _queued_attack == BossAttackKind.DASH_STRIKE:
		_apply_desired_move(_dash_dir * dash_strike_speed)
		if not _attack_did_hit and target != null:
			_try_deliver_melee_hit(target, 72.0, _get_effective_attack_damage() * 1.1)
	elif _queued_attack == BossAttackKind.CLEAVE:
		_apply_desired_move(facing_vector * 85.0)
		if not _attack_did_hit and target != null:
			_try_deliver_melee_hit(target, stats.attack_range + 22.0, _get_effective_attack_damage())
	else:
		_apply_desired_move(Vector2.ZERO)


func _finish_attack() -> void:
	super._finish_attack()
	if current_phase == 2:
		_cooldown_timer = stats.attack_cooldown * 0.82
	elif current_phase >= 3:
		_cooldown_timer = stats.attack_cooldown * 0.66


func _on_after_damage_taken(_amount: float) -> void:
	if not is_engaged:
		is_engaged = true
		boss_engaged.emit(self)

	var hp_ratio: float = current_hp / maxf(1.0, stats.max_hp)
	if current_hp > 0.0:
		if current_phase < 3 and hp_ratio <= _phase_3_ratio:
			_enter_phase(3)
		elif current_phase < 2 and hp_ratio <= _phase_2_ratio:
			_enter_phase(2)

	boss_hp_changed.emit(current_hp, stats.max_hp, current_phase)


func _enter_phase(next_phase: int) -> void:
	if next_phase <= current_phase:
		return
	current_phase = next_phase
	ai_state = AIState.PHASE_SHIFT
	_state_timer = _phase_shift_duration
	_invulnerable_phase = true
	_apply_phase_aura(current_phase)
	_play_anim(&"phase_shift", true)
	boss_phase_changed.emit(current_phase)


func _apply_phase_aura(phase_num: int) -> void:
	if phase_num == 2:
		_base_tint = Color(1.16, 0.9, 1.24, 1.0)
	elif phase_num >= 3:
		_base_tint = Color(1.28, 0.95, 0.84, 1.0)
	else:
		_base_tint = Color.WHITE


func _on_enemy_defeated() -> void:
	boss_hp_changed.emit(0.0, stats.max_hp, current_phase)
	boss_vanquished.emit(self)


func _on_enemy_reset() -> void:
	current_phase = 1
	is_engaged = false
	_pattern_index = 0
	_queued_attack = BossAttackKind.CLEAVE
	_apply_phase_aura(1)
	boss_hp_changed.emit(current_hp, stats.max_hp, current_phase)


func get_current_phase() -> int:
	return current_phase


func _get_effective_move_speed() -> float:
	if current_phase >= 3:
		return stats.move_speed * _p3_speed_mult
	if current_phase == 2:
		return stats.move_speed * _p2_speed_mult
	return stats.move_speed


func _get_effective_attack_damage() -> float:
	if current_phase >= 3:
		return stats.attack_damage * _p3_dmg_mult
	if current_phase == 2:
		return stats.attack_damage * _p2_dmg_mult
	return stats.attack_damage


func spawn_orb_fan(aim_pos: Vector2, count: int, total_spread_deg: float) -> int:
	var host: Node = get_parent()
	if host == null or ORB_SCENE == null or count <= 0:
		return 0
	var origin: Vector2 = global_position + Vector2(0.0, -48.0)
	var base_dir: Vector2 = (aim_pos - origin).normalized()
	if base_dir.length_squared() < 0.001:
		base_dir = facing_vector.normalized()

	var spawned: int = 0
	for i: int in range(count):
		var angle_rad: float = 0.0
		if count > 1:
			var t: float = float(i) / float(count - 1) - 0.5
			angle_rad = deg_to_rad(t * total_spread_deg)
		var orb: ShadowOrbProjectile = ORB_SCENE.instantiate() as ShadowOrbProjectile
		host.add_child(orb)
		var spd: float = boss_orb_speed * (1.14 if current_phase >= 3 else 1.0)
		orb.launch(origin, base_dir.rotated(angle_rad), _get_effective_attack_damage() * 0.78, spd, self)
		spawned += 1
	return spawned


func spawn_radial_nova(count: int) -> int:
	var host: Node = get_parent()
	if host == null or ORB_SCENE == null or count <= 0:
		return 0
	var origin: Vector2 = global_position + Vector2(0.0, -48.0)
	var base_offset: float = float(_pattern_index) * 0.35
	var spawned: int = 0
	for i: int in range(count):
		var ang: float = base_offset + (float(i) / float(count)) * TAU
		var dir: Vector2 = Vector2(cos(ang), sin(ang))
		var orb: ShadowOrbProjectile = ORB_SCENE.instantiate() as ShadowOrbProjectile
		host.add_child(orb)
		orb.launch(origin, dir, _get_effective_attack_damage() * 0.72, boss_orb_speed * 0.92, self)
		spawned += 1
	return spawned
