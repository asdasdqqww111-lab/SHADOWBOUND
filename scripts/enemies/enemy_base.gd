class_name EnemyBase
extends CharacterBody2D
## Unified base class for SHADOWBOUND enemies and bosses across Side-Scroll & Top-Down modes.
## Handles EnemyStats, hurtbox damage resolution, front-shield/break logic, parry stagger,
## knockback, overhead health bar rendering, non-destructive defeat, and arena reset.

signal enemy_damaged(enemy: EnemyBase, amount: float, remaining_hp: float)
signal enemy_defeated(enemy: EnemyBase, enemy_stats: EnemyStats)

enum AIState {
	IDLE = 0,
	PATROL = 1,
	CHASE = 2,
	TELEGRAPH = 3,
	ATTACK = 4,
	COOLDOWN = 5,
	STAGGER = 6,
	PHASE_SHIFT = 7,
}

const LAYER_WORLD_SS: int = 1
const LAYER_WORLD_TD: int = 2
const LAYER_ENEMIES: int = 8
const LAYER_WORLD_ONEWAY: int = 128
const ENEMY_GRAVITY: float = 1180.0
const MAX_ENEMY_FALL: float = 760.0

@export var stats: EnemyStats = null
@export_enum("SideScroll:0", "TopDown:1") var gameplay_mode: int = 0
@export var patrol_half_span: float = 110.0
@export var hovers: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var hurtbox: Area2D = $Hurtbox
@onready var hurtbox_shape: CollisionShape2D = $Hurtbox/CollisionShape2D

var current_hp: float = 60.0
var ai_state: int = AIState.PATROL
var facing_vector: Vector2 = Vector2.LEFT
var shield_broken_timer: float = 0.0

var _spawn_position: Vector2 = Vector2.ZERO
var _patrol_sign: float = 1.0
var _state_timer: float = 0.0
var _cooldown_timer: float = 0.0
var _hit_flash_timer: float = 0.0
var _knockback_vel: Vector2 = Vector2.ZERO
var _attack_did_hit: bool = false
var _is_defeated: bool = false
var _invulnerable_phase: bool = false
var _base_tint: Color = Color.WHITE


func _ready() -> void:
	add_to_group("enemies")
	if stats == null:
		stats = EnemyStats.new()
	_spawn_position = global_position
	current_hp = stats.max_hp
	if hurtbox != null and not hurtbox.is_in_group("enemy_hurtbox"):
		hurtbox.add_to_group("enemy_hurtbox")
	_configure_mode_physics()
	_on_enemy_ready()
	_play_anim(&"idle")


func _on_enemy_ready() -> void:
	pass


func _configure_mode_physics() -> void:
	collision_layer = LAYER_ENEMIES
	if gameplay_mode == GameState.GameplayMode.TOP_DOWN:
		collision_mask = LAYER_WORLD_TD
		motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
		floor_snap_length = 0.0
	else:
		collision_mask = 0 if hovers else (LAYER_WORLD_SS | LAYER_WORLD_ONEWAY)
		motion_mode = (
			CharacterBody2D.MOTION_MODE_FLOATING if hovers else CharacterBody2D.MOTION_MODE_GROUNDED
		)
		up_direction = Vector2.UP
		floor_snap_length = 0.0 if hovers else 6.0


func _physics_process(delta: float) -> void:
	if _is_defeated or stats == null:
		return

	_cooldown_timer = maxf(0.0, _cooldown_timer - delta)
	_hit_flash_timer = maxf(0.0, _hit_flash_timer - delta)
	shield_broken_timer = maxf(0.0, shield_broken_timer - delta)
	_knockback_vel = _knockback_vel.move_toward(Vector2.ZERO, 920.0 * delta)

	var target: PlayerCharacter = _find_live_player()
	_step_ai(target, delta)
	_apply_gravity_if_needed(delta)
	move_and_slide()
	_update_visual_tint()
	queue_redraw()


func _step_ai(target: PlayerCharacter, delta: float) -> void:
	if ai_state == AIState.STAGGER:
		_state_timer = maxf(0.0, _state_timer - delta)
		_apply_desired_move(Vector2.ZERO)
		_play_anim(&"hurt")
		if _state_timer <= 0.0:
			ai_state = AIState.CHASE
		return

	if ai_state == AIState.TELEGRAPH:
		_state_timer = maxf(0.0, _state_timer - delta)
		_apply_desired_move(Vector2.ZERO)
		if target != null:
			_face_toward(target.global_position)
		_play_anim(&"idle")
		if _state_timer <= 0.0:
			_begin_attack(target)
		return

	if ai_state == AIState.ATTACK:
		_state_timer = maxf(0.0, _state_timer - delta)
		_tick_attack(target, delta)
		if _state_timer <= 0.0:
			_finish_attack()
		return

	if target == null:
		_tick_patrol(delta)
		return

	var dist: float = _combat_distance_to(target.global_position)
	var home_dist: float = global_position.distance_to(_spawn_position)
	if dist <= stats.aggro_range and home_dist <= stats.leash_range:
		_tick_engage(target, dist, delta)
	else:
		_tick_patrol(delta)


func _tick_patrol(_delta: float) -> void:
	ai_state = AIState.PATROL
	if patrol_half_span <= 8.0:
		_apply_desired_move(Vector2.ZERO)
		_play_anim(&"idle")
		return

	var offset_x: float = global_position.x - _spawn_position.x
	if offset_x > patrol_half_span:
		_patrol_sign = -1.0
	elif offset_x < -patrol_half_span:
		_patrol_sign = 1.0
	elif is_on_wall():
		_patrol_sign = -_patrol_sign

	var patrol_dir: Vector2 = Vector2(_patrol_sign, 0.0)
	if gameplay_mode == GameState.GameplayMode.TOP_DOWN:
		var target_pt: Vector2 = _spawn_position + Vector2(_patrol_sign * patrol_half_span, 0.0)
		var diff: Vector2 = target_pt - global_position
		patrol_dir = diff.normalized() if diff.length() > 6.0 else Vector2(_patrol_sign, 0.0)

	_set_facing(patrol_dir)
	_apply_desired_move(patrol_dir * stats.move_speed * 0.55)
	_play_anim(&"move")


func _tick_engage(target: PlayerCharacter, dist: float, _delta: float) -> void:
	ai_state = AIState.CHASE
	_face_toward(target.global_position)

	if dist <= stats.attack_range and _cooldown_timer <= 0.0:
		_begin_telegraph()
		return

	var dir: Vector2 = _move_dir_toward(target.global_position)
	# Keep side-scroll ground foes within their platform patrol bounds
	if gameplay_mode == GameState.GameplayMode.SIDE_SCROLL and not hovers:
		var next_off: float = (global_position.x - _spawn_position.x) + dir.x * 14.0
		if absf(next_off) > patrol_half_span + 28.0:
			_apply_desired_move(Vector2.ZERO)
			_play_anim(&"idle")
			return

	_apply_desired_move(dir * _get_effective_move_speed())
	_play_anim(&"move")


func _begin_telegraph() -> void:
	ai_state = AIState.TELEGRAPH
	_state_timer = stats.telegraph_duration
	_attack_did_hit = false


func _begin_attack(_target: PlayerCharacter) -> void:
	ai_state = AIState.ATTACK
	_state_timer = stats.attack_active_duration
	_attack_did_hit = false
	_play_anim(&"attack", true)


func _tick_attack(target: PlayerCharacter, _delta: float) -> void:
	_apply_desired_move(Vector2.ZERO)
	if not _attack_did_hit and target != null:
		_try_deliver_melee_hit(target, stats.attack_range + 16.0, _get_effective_attack_damage())


func _finish_attack() -> void:
	ai_state = AIState.COOLDOWN
	_cooldown_timer = stats.attack_cooldown
	_apply_desired_move(Vector2.ZERO)
	_play_anim(&"idle")


func _try_deliver_melee_hit(target: PlayerCharacter, reach: float, dmg: float) -> bool:
	if target == null or target.is_defeated():
		return false
	var to_player: Vector2 = target.global_position - global_position
	if gameplay_mode == GameState.GameplayMode.SIDE_SCROLL:
		if absf(to_player.x) > reach or absf(to_player.y) > 68.0:
			return false
	else:
		if to_player.length() > reach:
			return false

	_attack_did_hit = true
	target.receive_attack(
		{
			"damage": dmg,
			"knockback": stats.attack_knockback,
			"source_position": global_position,
			"source": self,
			"is_projectile": false,
		}
	)
	return true


func is_front_shield_active() -> bool:
	if stats == null or not stats.has_front_shield:
		return false
	if shield_broken_timer > 0.0:
		return false
	return ai_state != AIState.ATTACK and ai_state != AIState.STAGGER


func receive_player_strike(strike_data: Dictionary) -> float:
	if _is_defeated or _invulnerable_phase or stats == null:
		return 0.0

	var raw_dmg: float = float(strike_data.get("damage", 12.0))
	var breaks_shield: bool = bool(strike_data.get("breaks_shield", false))
	var is_crit: bool = bool(strike_data.get("is_crit", false))
	var is_riposte: bool = bool(strike_data.get("is_riposte", false))
	var kb: float = float(strike_data.get("knockback", 180.0))
	var hit_dir: Vector2 = strike_data.get("hit_direction", Vector2.RIGHT)
	var attacker_pos: Vector2 = strike_data.get(
		"attacker_position",
		global_position - hit_dir * 40.0
	)

	var to_attacker: Vector2 = attacker_pos - global_position
	if gameplay_mode == GameState.GameplayMode.SIDE_SCROLL:
		to_attacker = Vector2(signf(to_attacker.x) if absf(to_attacker.x) > 0.5 else 1.0, 0.0)
	var front_hit: bool = CombatResolver.is_attack_in_guard_arc(facing_vector, to_attacker, 0.0)

	var taken: Dictionary = CombatResolver.compute_enemy_damage_taken(
		raw_dmg,
		stats.defense,
		front_hit,
		is_front_shield_active(),
		stats.front_shield_reduction,
		breaks_shield
	)
	var final_dmg: float = float(taken.get("damage", 1.0))
	var was_shielded: bool = bool(taken.get("shielded", false))
	var broke_shield: bool = bool(taken.get("shield_broken", false))

	if broke_shield:
		shield_broken_timer = 3.2

	current_hp = maxf(0.0, current_hp - final_dmg)
	_hit_flash_timer = 0.16

	var kb_factor: float = clampf(1.0 - stats.knockback_resistance, 0.0, 1.0)
	if was_shielded:
		kb_factor *= 0.35
	var push_dir: Vector2 = hit_dir.normalized() if hit_dir.length_squared() > 0.01 else Vector2.RIGHT
	if gameplay_mode == GameState.GameplayMode.SIDE_SCROLL:
		push_dir = Vector2(signf(push_dir.x) if absf(push_dir.x) > 0.05 else 1.0, 0.0)
	_knockback_vel = push_dir * kb * kb_factor

	if (broke_shield or not was_shielded) and stats.hurt_stun_duration > 0.0:
		if ai_state != AIState.PHASE_SHIFT and not stats.is_boss:
			ai_state = AIState.STAGGER
			_state_timer = stats.hurt_stun_duration * (1.8 if broke_shield else 1.0)

	_spawn_damage_popup(int(roundf(final_dmg)), is_crit, is_riposte, was_shielded, broke_shield)
	enemy_damaged.emit(self, final_dmg, current_hp)
	_on_after_damage_taken(final_dmg)

	if current_hp <= 0.0 and not _invulnerable_phase:
		_handle_defeat()
	return final_dmg


func apply_parry_stagger(duration: float = 0.9) -> void:
	if _is_defeated or _invulnerable_phase:
		return
	if stats != null and stats.has_front_shield:
		shield_broken_timer = maxf(shield_broken_timer, 2.8)
	var eff_dur: float = duration * (0.45 if (stats != null and stats.is_boss) else 1.0)
	ai_state = AIState.STAGGER
	_state_timer = eff_dur
	_cooldown_timer = maxf(_cooldown_timer, eff_dur + 0.35)
	_hit_flash_timer = 0.22


func _on_after_damage_taken(_amount: float) -> void:
	pass


func _handle_defeat() -> void:
	if _is_defeated:
		return
	_is_defeated = true
	velocity = Vector2.ZERO
	_knockback_vel = Vector2.ZERO
	visible = false
	if body_shape != null:
		body_shape.set_deferred("disabled", true)
	if hurtbox_shape != null:
		hurtbox_shape.set_deferred("disabled", true)
	if stats != null:
		GameState.record_enemy_defeated(stats.enemy_id, stats.is_boss)
	enemy_defeated.emit(self, stats)
	_on_enemy_defeated()


func _on_enemy_defeated() -> void:
	pass


func reset_enemy() -> void:
	_is_defeated = false
	_invulnerable_phase = false
	global_position = _spawn_position
	velocity = Vector2.ZERO
	_knockback_vel = Vector2.ZERO
	current_hp = stats.max_hp if stats != null else 60.0
	shield_broken_timer = 0.0
	_state_timer = 0.0
	_cooldown_timer = 0.0
	_hit_flash_timer = 0.0
	ai_state = AIState.PATROL
	_base_tint = Color.WHITE
	visible = true
	if body_shape != null:
		body_shape.set_deferred("disabled", false)
	if hurtbox_shape != null:
		hurtbox_shape.set_deferred("disabled", false)
	_on_enemy_reset()
	_play_anim(&"idle", true)
	queue_redraw()


func _on_enemy_reset() -> void:
	pass


func is_defeated() -> bool:
	return _is_defeated


func _get_effective_move_speed() -> float:
	return stats.move_speed if stats != null else 140.0


func _get_effective_attack_damage() -> float:
	return stats.attack_damage if stats != null else 12.0


func _apply_desired_move(desired: Vector2) -> void:
	if gameplay_mode == GameState.GameplayMode.SIDE_SCROLL and not hovers:
		velocity.x = desired.x + _knockback_vel.x
	else:
		velocity = desired + _knockback_vel


func _apply_gravity_if_needed(delta: float) -> void:
	if gameplay_mode == GameState.GameplayMode.SIDE_SCROLL and not hovers:
		if not is_on_floor():
			velocity.y = minf(velocity.y + ENEMY_GRAVITY * delta, MAX_ENEMY_FALL)


func _combat_distance_to(pos: Vector2) -> float:
	if gameplay_mode == GameState.GameplayMode.SIDE_SCROLL and not hovers:
		var dx: float = absf(pos.x - global_position.x)
		var dy: float = absf(pos.y - global_position.y)
		return dx + dy * 1.35
	return global_position.distance_to(pos)


func _move_dir_toward(pos: Vector2) -> Vector2:
	var diff: Vector2 = pos - global_position
	if gameplay_mode == GameState.GameplayMode.SIDE_SCROLL and not hovers:
		return Vector2(1.0 if diff.x >= 0.0 else -1.0, 0.0)
	return diff.normalized() if diff.length_squared() > 0.01 else Vector2.RIGHT


func _face_toward(pos: Vector2) -> void:
	_set_facing(pos - global_position)


func _set_facing(vec: Vector2) -> void:
	if vec.length_squared() < 0.001:
		return
	if gameplay_mode == GameState.GameplayMode.SIDE_SCROLL:
		var sx: float = 1.0 if vec.x >= 0.0 else -1.0
		facing_vector = Vector2(sx, 0.0)
		if sprite != null:
			sprite.flip_h = sx < 0.0
	else:
		facing_vector = vec.normalized()
		if sprite != null and absf(vec.x) > 0.08:
			sprite.flip_h = vec.x < 0.0


func _play_anim(anim_name: StringName, restart: bool = false) -> void:
	if sprite == null or sprite.sprite_frames == null:
		return
	var target_anim: StringName = anim_name
	if not sprite.sprite_frames.has_animation(target_anim):
		target_anim = &"idle"
	if restart or sprite.animation != target_anim or not sprite.is_playing():
		sprite.play(target_anim)


func _update_visual_tint() -> void:
	if sprite == null:
		return
	if _hit_flash_timer > 0.0:
		sprite.modulate = Color(1.75, 1.55, 1.75, 1.0)
	elif ai_state == AIState.TELEGRAPH:
		var pulse: float = 1.25 + 0.35 * sin(_state_timer * 26.0)
		sprite.modulate = Color(pulse, 0.68, 0.78, 1.0)
	elif ai_state == AIState.STAGGER:
		sprite.modulate = Color(0.88, 0.78, 1.22, 0.92)
	else:
		sprite.modulate = _base_tint


func _spawn_damage_popup(
	dmg_int: int,
	is_crit: bool,
	is_riposte: bool,
	was_shielded: bool,
	broke_shield: bool
) -> void:
	var txt: String = str(dmg_int)
	var col: Color = Color(0.96, 0.93, 1.0, 1.0)
	var fsize: int = 16
	if broke_shield:
		txt = LocalizationManager.translate_key("combat.popup_shield_break", {"value": dmg_int})
		col = Color(1.0, 0.86, 0.38, 1.0)
		fsize = 18
	elif is_riposte:
		txt = LocalizationManager.translate_key("combat.popup_riposte", {"value": dmg_int})
		col = Color(0.55, 0.96, 1.0, 1.0)
		fsize = 18
	elif is_crit:
		txt = LocalizationManager.translate_key("combat.popup_crit", {"value": dmg_int})
		col = Color(1.0, 0.88, 0.42, 1.0)
		fsize = 18
	elif was_shielded:
		txt = LocalizationManager.translate_key("combat.popup_shielded", {"value": dmg_int})
		col = Color(0.74, 0.8, 0.96, 1.0)
		fsize = 14
	FloatingCombatText.spawn(get_parent(), global_position + Vector2(0.0, -78.0), txt, col, fsize)


func _find_live_player() -> PlayerCharacter:
	if not is_inside_tree():
		return null
	var node: Node = get_tree().get_first_node_in_group("player")
	if node is PlayerCharacter:
		var pc: PlayerCharacter = node as PlayerCharacter
		if not pc.is_defeated() and pc.active_mode == gameplay_mode:
			return pc
	return null


func _draw() -> void:
	if _is_defeated or stats == null or stats.is_boss:
		return
	var show_bar: bool = current_hp < stats.max_hp or ai_state == AIState.TELEGRAPH
	if not show_bar:
		return
	var bar_w: float = 52.0
	var bar_h: float = 6.0
	var top_left: Vector2 = Vector2(-bar_w * 0.5, -74.0)
	var ratio: float = clampf(current_hp / maxf(1.0, stats.max_hp), 0.0, 1.0)
	draw_rect(Rect2(top_left - Vector2(1, 1), Vector2(bar_w + 2, bar_h + 2)), Color(0.06, 0.04, 0.12, 0.92))
	draw_rect(Rect2(top_left, Vector2(bar_w * ratio, bar_h)), Color(0.9, 0.24, 0.44, 0.96))
	var border_col: Color = (
		Color(0.45, 0.92, 1.0, 0.95)
		if is_front_shield_active()
		else Color(0.84, 0.64, 0.28, 0.9)
	)
	draw_rect(Rect2(top_left - Vector2(1, 1), Vector2(bar_w + 2, bar_h + 2)), border_col, false, 1.2)
	if ai_state == AIState.TELEGRAPH:
		draw_circle(Vector2(0.0, -86.0), 4.5, Color(1.0, 0.36, 0.52, 0.95))
