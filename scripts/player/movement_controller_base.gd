class_name MovementControllerBase
extends Node
## Abstract base contract for modular SHADOWBOUND player movement & combo controllers.
## Both SideScrollController and TopDownController inherit this contract so one unified
## PlayerCharacter shares profile, stamina, 3-hit combos, guard/parry, i-frames, and camera.

signal action_triggered(action_name: String)
signal state_changed(new_state_key: String)

var _state_key: String = "idle"
var _compass_dir: String = "E"
var _desired_animation: StringName = &"idle"
var _animation_speed_scale: float = 1.0
var _flip_h: bool = false
var _facing_vector: Vector2 = Vector2.RIGHT
var _attack_active: bool = false
var _dodge_active: bool = false
var _block_active: bool = false
var _perfect_block_active: bool = false
var _invulnerable_active: bool = false
var _sprint_active: bool = false
var _wall_slide_active: bool = false

# Shared 3-hit sword combo & stagger state (driven by data/config/combat_config.json)
var _combat_cfg: Dictionary = {}
var _combo_step: int = 0
var _attack_swing_id: int = 0
var _active_attack_timer: float = 0.0
var _active_attack_cooldown: float = 0.0
var _combo_chain_timer: float = 0.0
var _combo_chain_window: float = 0.52
var _combo_buffer_window: float = 0.18
var _finisher_cooldown: float = 0.26
var _combo_queued: bool = false
var _current_combo_spec: Dictionary = {}
var _hurt_stun_timer: float = 0.0


func apply_config(_cfg: Dictionary) -> void:
	pass


func apply_combat_config(combat_cfg: Dictionary) -> void:
	_combat_cfg = combat_cfg
	_combo_chain_window = float(combat_cfg.get("combo_chain_window", _combo_chain_window))
	_combo_buffer_window = float(combat_cfg.get("combo_buffer_window", _combo_buffer_window))
	_finisher_cooldown = float(combat_cfg.get("finisher_cooldown", _finisher_cooldown))


func activate(_body: CharacterBody2D) -> void:
	_reset_transient_flags()


func deactivate() -> void:
	_reset_transient_flags()


func _reset_transient_flags() -> void:
	_attack_active = false
	_dodge_active = false
	_block_active = false
	_perfect_block_active = false
	_invulnerable_active = false
	_sprint_active = false
	_wall_slide_active = false
	_animation_speed_scale = 1.0
	_combo_step = 0
	_active_attack_timer = 0.0
	_active_attack_cooldown = 0.0
	_combo_chain_timer = 0.0
	_combo_queued = false
	_hurt_stun_timer = 0.0


func _tick_combat_timers(delta: float) -> void:
	_hurt_stun_timer = maxf(0.0, _hurt_stun_timer - delta)
	_active_attack_cooldown = maxf(0.0, _active_attack_cooldown - delta)
	if _active_attack_timer > 0.0:
		_active_attack_timer = maxf(0.0, _active_attack_timer - delta)
		if _active_attack_timer <= 0.0:
			if _combo_step > 0 and _combo_step < 3:
				_combo_chain_timer = _combo_chain_window
			else:
				_combo_step = 0
				_combo_chain_timer = 0.0
				_combo_queued = false
				_active_attack_cooldown = _finisher_cooldown
	elif _combo_chain_timer > 0.0:
		_combo_chain_timer = maxf(0.0, _combo_chain_timer - delta)
		if _combo_chain_timer <= 0.0:
			_combo_step = 0
			_combo_queued = false


func _try_process_combo_attack(
	attack_pressed: bool,
	can_attack: bool,
	profile: PlayerProfile,
	default_duration: float
) -> Dictionary:
	if attack_pressed and _active_attack_timer > 0.0 and _combo_step < 3:
		if _active_attack_timer <= _combo_buffer_window:
			_combo_queued = true
		return {"started": false, "stamina_spent": false, "lunge_multiplier": 1.0, "step": _combo_step}

	var wants_swing: bool = attack_pressed or _combo_queued
	if not can_attack or not wants_swing:
		return {"started": false, "stamina_spent": false, "lunge_multiplier": 1.0, "step": _combo_step}
	if _active_attack_timer > 0.0 or _active_attack_cooldown > 0.0:
		return {"started": false, "stamina_spent": false, "lunge_multiplier": 1.0, "step": _combo_step}

	var next_step: int = 1
	if _combo_chain_timer > 0.0 and _combo_step > 0 and _combo_step < 3:
		next_step = _combo_step + 1

	var spec: Dictionary = CombatResolver.get_combo_spec(_combat_cfg, next_step)
	var sp_cost: float = float(spec.get("stamina_cost", 0.0))
	var spent: bool = false
	if sp_cost > 0.0 and profile != null:
		if profile.consume_stamina(sp_cost):
			spent = true
		else:
			next_step = 1
			spec = CombatResolver.get_combo_spec(_combat_cfg, 1)

	_combo_step = next_step
	_current_combo_spec = spec
	_active_attack_timer = float(spec.get("duration", default_duration))
	_combo_chain_timer = 0.0
	_combo_queued = false
	_attack_swing_id += 1
	var evt_name: String = "attack" if next_step == 1 else ("attack_%d" % next_step)
	action_triggered.emit(evt_name)
	return {
		"started": true,
		"stamina_spent": spent,
		"lunge_multiplier": float(spec.get("lunge_multiplier", 1.0)),
		"step": next_step,
	}


func _cancel_combo_attack(reset_chain: bool = false) -> void:
	_active_attack_timer = 0.0
	_attack_active = false
	_combo_queued = false
	if reset_chain:
		_combo_step = 0
		_combo_chain_timer = 0.0


func trigger_hurt_stun(duration: float) -> void:
	_cancel_combo_attack(true)
	_block_active = false
	_perfect_block_active = false
	_sprint_active = false
	_hurt_stun_timer = maxf(_hurt_stun_timer, duration)


func _get_combo_state_key() -> String:
	if _combo_step == 2:
		return "attack_2"
	if _combo_step >= 3:
		return "attack_3"
	return "attack"


func _get_combo_animation(is_top_down: bool) -> StringName:
	var key: String = "td_anim" if is_top_down else "ss_anim"
	var fallback: String = "td_attack" if is_top_down else "attack"
	return StringName(str(_current_combo_spec.get(key, fallback)))


func _set_state_key(next_key: String) -> void:
	if _state_key == next_key:
		return
	_state_key = next_key
	state_changed.emit(_state_key)


func physics_step(
	_body: CharacterBody2D,
	_profile: PlayerProfile,
	_input_frame: Dictionary,
	_delta: float
) -> Dictionary:
	return {"stamina_spent": false, "drop_through": false}


func get_state_key() -> String:
	return _state_key


func get_compass_direction() -> String:
	return _compass_dir


func get_desired_animation() -> StringName:
	return _desired_animation


func get_animation_speed_scale() -> float:
	return _animation_speed_scale


func get_flip_h() -> bool:
	return _flip_h


func get_facing_vector() -> Vector2:
	return _facing_vector


func get_combo_step() -> int:
	return maxi(1, _combo_step)


func get_attack_swing_id() -> int:
	return _attack_swing_id


func get_hitbox_scale() -> float:
	return float(_current_combo_spec.get("hitbox_scale", 1.0))


func is_attacking() -> bool:
	return _attack_active


func is_dodging() -> bool:
	return _dodge_active


func is_blocking() -> bool:
	return _block_active


func is_perfect_blocking() -> bool:
	return _perfect_block_active


func is_invulnerable() -> bool:
	return _invulnerable_active


func is_sprinting() -> bool:
	return _sprint_active


func is_wall_sliding() -> bool:
	return _wall_slide_active


func is_hurt_stunned() -> bool:
	return _hurt_stun_timer > 0.0


func get_camera_hints() -> Dictionary:
	return {
		"blocking": _block_active,
		"dodging": _dodge_active,
		"sprinting": _sprint_active,
		"wall_sliding": _wall_slide_active,
	}
