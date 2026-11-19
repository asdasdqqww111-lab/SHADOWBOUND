class_name TopDownController
extends MovementControllerBase
## Dedicated 8-direction Top-Down exploration and action controller (Phase 2).
## Supports exact 8-compass direction tracking (E, SE, S, SW, W, NW, N, NE), unit-clamped
## analog Walk / Run / Sprint speeds, crisp turn-snap acceleration, 8-way Shadow Dodge
## with invulnerability frames, directional Shadow Guard with perfect-parry window,
## and 8-direction sword slashes.

const COMPASS_LABELS: Array[String] = ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]

var move_speed: float = 265.0
var walk_speed_factor: float = 0.52
var walk_threshold: float = 0.55
var sprint_speed_multiplier: float = 1.36
var sprint_stamina_drain_per_sec: float = 15.0
var sprint_min_stamina: float = 10.0
var acceleration: float = 2150.0
var friction: float = 2350.0
var turn_acceleration_multiplier: float = 1.55
var dodge_speed: float = 585.0
var dodge_duration: float = 0.18
var dodge_iframe_duration: float = 0.16
var dodge_cooldown: float = 0.48
var dodge_stamina_cost: float = 20.0
var block_move_factor: float = 0.25
var block_stamina_drain_per_sec: float = 9.5
var block_min_stamina: float = 8.0
var perfect_block_window: float = 0.18
var attack_duration: float = 0.28
var attack_cooldown: float = 0.12
var attack_step_speed: float = 95.0

var _cardinal_facing: String = "down"
var _dodge_dir: Vector2 = Vector2.DOWN
var _dodge_timer: float = 0.0
var _iframe_timer: float = 0.0
var _dodge_cooldown_timer: float = 0.0
var _block_elapsed: float = 0.0


static func vector_to_compass_8(vec: Vector2) -> String:
	if vec.length_squared() < 0.0001:
		return "S"
	var octant: int = posmod(roundi(atan2(vec.y, vec.x) / (PI * 0.25)), 8)
	return COMPASS_LABELS[octant]


static func compass_8_to_vector(compass_code: String) -> Vector2:
	var idx: int = COMPASS_LABELS.find(compass_code)
	if idx < 0:
		return Vector2.DOWN
	var angle: float = float(idx) * (PI * 0.25)
	return Vector2(cos(angle), sin(angle)).normalized()


func apply_config(cfg: Dictionary) -> void:
	if cfg.is_empty():
		return
	move_speed = float(cfg.get("move_speed", move_speed))
	walk_speed_factor = float(cfg.get("walk_speed_factor", walk_speed_factor))
	walk_threshold = float(cfg.get("walk_threshold", walk_threshold))
	sprint_speed_multiplier = float(cfg.get("sprint_speed_multiplier", sprint_speed_multiplier))
	sprint_stamina_drain_per_sec = float(cfg.get("sprint_stamina_drain_per_sec", sprint_stamina_drain_per_sec))
	sprint_min_stamina = float(cfg.get("sprint_min_stamina", sprint_min_stamina))
	acceleration = float(cfg.get("acceleration", acceleration))
	friction = float(cfg.get("friction", friction))
	turn_acceleration_multiplier = float(cfg.get("turn_acceleration_multiplier", turn_acceleration_multiplier))
	dodge_speed = float(cfg.get("dodge_speed", dodge_speed))
	dodge_duration = float(cfg.get("dodge_duration", dodge_duration))
	dodge_iframe_duration = float(cfg.get("dodge_iframe_duration", dodge_iframe_duration))
	dodge_cooldown = float(cfg.get("dodge_cooldown", dodge_cooldown))
	dodge_stamina_cost = float(cfg.get("dodge_stamina_cost", dodge_stamina_cost))
	block_move_factor = float(cfg.get("block_move_factor", block_move_factor))
	block_stamina_drain_per_sec = float(cfg.get("block_stamina_drain_per_sec", block_stamina_drain_per_sec))
	block_min_stamina = float(cfg.get("block_min_stamina", block_min_stamina))
	perfect_block_window = float(cfg.get("perfect_block_window", perfect_block_window))
	attack_duration = float(cfg.get("attack_duration", attack_duration))
	attack_cooldown = float(cfg.get("attack_cooldown", attack_cooldown))
	attack_step_speed = float(cfg.get("attack_step_speed", attack_step_speed))


func activate(body: CharacterBody2D) -> void:
	super.activate(body)
	body.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	body.floor_snap_length = 0.0
	body.velocity = Vector2.ZERO
	_dodge_timer = 0.0
	_iframe_timer = 0.0
	_block_elapsed = 0.0
	_cardinal_facing = "down"
	_facing_vector = Vector2.DOWN
	_compass_dir = "S"
	_flip_h = false
	_desired_animation = &"td_idle_down"
	_set_state_key("idle")


func set_facing_vector(vec: Vector2) -> void:
	if vec.length_squared() > 0.01:
		_facing_vector = vec.normalized()
		_compass_dir = vector_to_compass_8(_facing_vector)
		_update_cardinal_facing(_facing_vector)


func physics_step(
	body: CharacterBody2D,
	profile: PlayerProfile,
	input_frame: Dictionary,
	delta: float
) -> Dictionary:
	var stamina_spent: bool = false
	var raw_vec: Vector2 = input_frame.get("move_vector", Vector2.ZERO)
	# Strictly clamp diagonal/analog input to unit circle (zero diagonal speed exploit).
	var move_vec: Vector2 = raw_vec.limit_length(1.0)
	var input_mag: float = move_vec.length()
	var dodge_pressed: bool = bool(input_frame.get("dodge_just_pressed", false))
	var attack_pressed: bool = bool(input_frame.get("attack_just_pressed", false))
	var block_held: bool = bool(input_frame.get("block_held", false))
	var sprint_held: bool = bool(input_frame.get("sprint_held", false))

	_tick_timers(delta)

	if input_mag > 0.1 and _dodge_timer <= 0.0 and _active_attack_timer <= 0.0:
		_facing_vector = move_vec.normalized()
		_compass_dir = vector_to_compass_8(_facing_vector)
		_update_cardinal_facing(_facing_vector)

	# 8-direction Shadow Dodge with invulnerability frames (cancels block & sprint)
	if dodge_pressed and _dodge_timer <= 0.0 and _dodge_cooldown_timer <= 0.0:
		if profile == null or profile.consume_stamina(dodge_stamina_cost):
			_dodge_dir = move_vec.normalized() if input_mag > 0.1 else _facing_vector
			if _dodge_dir.length_squared() < 0.01:
				_dodge_dir = Vector2.DOWN
			_facing_vector = _dodge_dir
			_compass_dir = vector_to_compass_8(_dodge_dir)
			_flip_h = _dodge_dir.x < -0.08
			_dodge_timer = dodge_duration
			_iframe_timer = dodge_iframe_duration
			_dodge_cooldown_timer = dodge_cooldown
			_cancel_combo_attack(false)
			_sprint_active = false
			_clear_block()
			body.velocity = _dodge_dir * dodge_speed
			stamina_spent = true
			action_triggered.emit("dodge")

	if _dodge_timer > 0.0:
		_dodge_timer = maxf(0.0, _dodge_timer - delta)
		_dodge_active = true
		_attack_active = false
		_sprint_active = false
		_invulnerable_active = _iframe_timer > 0.0
		body.velocity = _dodge_dir * dodge_speed
		body.move_and_slide()
		_desired_animation = &"td_dodge"
		_animation_speed_scale = 1.0
		_set_state_key("dodge")
		return {"stamina_spent": stamina_spent, "drop_through": false}

	_dodge_active = false
	_invulnerable_active = _iframe_timer > 0.0

	# Hurt / guard-break stagger recoil
	if _hurt_stun_timer > 0.0:
		_clear_block()
		_attack_active = false
		_sprint_active = false
		body.velocity = body.velocity.move_toward(Vector2.ZERO, friction * 0.7 * delta)
		body.move_and_slide()
		_desired_animation = &"td_hurt"
		_animation_speed_scale = 1.0
		_set_state_key("hurt")
		return {"stamina_spent": stamina_spent, "drop_through": false}

	# Directional Shadow Guard (can pivot in all 8 directions while holding ward)
	stamina_spent = _update_block_state(block_held, profile, delta) or stamina_spent

	# 8-direction 3-Hit Sword Combo (Shadow Cut -> Crescent Reverse -> Eclipse Finisher)
	var combo_res: Dictionary = _try_process_combo_attack(
		attack_pressed,
		not _block_active,
		profile,
		attack_duration
	)
	if bool(combo_res.get("started", false)):
		stamina_spent = bool(combo_res.get("stamina_spent", false)) or stamina_spent
		_sprint_active = false
		var step_mult: float = float(combo_res.get("lunge_multiplier", 1.0))
		body.velocity = _facing_vector * attack_step_speed * step_mult

	if _active_attack_timer > 0.0:
		_attack_active = true
		_sprint_active = false
		body.velocity = body.velocity.move_toward(Vector2.ZERO, friction * 0.65 * delta)
	elif _block_active:
		_attack_active = false
		_sprint_active = false
		var guard_vel: Vector2 = move_vec * (move_speed * block_move_factor)
		body.velocity = body.velocity.move_toward(guard_vel, acceleration * 0.85 * delta)
	else:
		_attack_active = false
		stamina_spent = _apply_exploration_velocity(
			body, move_vec, input_mag, sprint_held, profile, delta
		) or stamina_spent

	body.move_and_slide()
	_update_animation_and_state(body.velocity, input_mag)
	return {"stamina_spent": stamina_spent, "drop_through": false}


func _tick_timers(delta: float) -> void:
	_iframe_timer = maxf(0.0, _iframe_timer - delta)
	_dodge_cooldown_timer = maxf(0.0, _dodge_cooldown_timer - delta)
	_tick_combat_timers(delta)


func _update_block_state(block_held: bool, profile: PlayerProfile, delta: float) -> bool:
	if not block_held:
		_clear_block()
		return false
	if _active_attack_timer > 0.0:
		_cancel_combo_attack(true)

	var min_req: float = 1.0 if _block_active else block_min_stamina
	if profile != null and profile.current_stamina < min_req:
		_clear_block()
		return false

	var just_started: bool = not _block_active
	_block_active = true
	_block_elapsed = 0.0 if just_started else (_block_elapsed + delta)
	_perfect_block_active = _block_elapsed <= perfect_block_window
	if just_started:
		action_triggered.emit("block")

	if profile != null and block_stamina_drain_per_sec > 0.0:
		var drain: float = minf(profile.current_stamina, block_stamina_drain_per_sec * delta)
		profile.consume_stamina(drain)
		return drain > 0.0
	return false


func _clear_block() -> void:
	_block_active = false
	_perfect_block_active = false
	_block_elapsed = 0.0


func _apply_exploration_velocity(
	body: CharacterBody2D,
	move_vec: Vector2,
	input_mag: float,
	sprint_held: bool,
	profile: PlayerProfile,
	delta: float
) -> bool:
	if input_mag <= 0.08:
		_sprint_active = false
		body.velocity = body.velocity.move_toward(Vector2.ZERO, friction * delta)
		return false

	var stamina_spent: bool = false
	var min_sp: float = 1.0 if _sprint_active else sprint_min_stamina
	var can_sprint: bool = sprint_held and input_mag > 0.35 and (
		profile == null or profile.current_stamina >= min_sp
	)

	var target_vel: Vector2 = move_vec * move_speed
	if can_sprint:
		_sprint_active = true
		target_vel = move_vec.normalized() * (move_speed * sprint_speed_multiplier)
		if profile != null and sprint_stamina_drain_per_sec > 0.0:
			var drain: float = minf(profile.current_stamina, sprint_stamina_drain_per_sec * delta)
			profile.consume_stamina(drain)
			stamina_spent = drain > 0.0
	else:
		_sprint_active = false
		if input_mag < walk_threshold:
			target_vel = move_vec.normalized() * (move_speed * walk_speed_factor)

	var reversing: bool = body.velocity.length() > 25.0 and body.velocity.dot(move_vec) < -0.1
	var eff_accel: float = acceleration * (turn_acceleration_multiplier if reversing else 1.0)
	body.velocity = body.velocity.move_toward(target_vel, eff_accel * delta)
	return stamina_spent


func _update_cardinal_facing(dir: Vector2) -> void:
	# Slight hysteresis prevents flicker along exact 45-degree diagonals (NE/SE/SW/NW).
	var side_bias: float = 0.94 if _cardinal_facing == "side" else 1.08
	if absf(dir.x) > absf(dir.y) * side_bias:
		_cardinal_facing = "side"
		_flip_h = dir.x < 0.0
	elif dir.y < 0.0:
		_cardinal_facing = "up"
		_flip_h = false
	else:
		_cardinal_facing = "down"
		_flip_h = false


func _update_animation_and_state(vel: Vector2, input_mag: float) -> void:
	_animation_speed_scale = 1.0
	if _attack_active:
		_desired_animation = _get_combo_animation(true)
		_set_state_key(_get_combo_state_key())
		return
	if _block_active:
		_desired_animation = &"td_block"
		_set_state_key("parry" if _perfect_block_active else "block")
		return

	var spd: float = vel.length()
	var moving: bool = spd > 18.0 or input_mag > 0.12
	match _cardinal_facing:
		"up":
			_desired_animation = &"td_walk_up" if moving else &"td_idle_up"
		"side":
			_desired_animation = &"td_walk_side" if moving else &"td_idle_side"
		_:
			_desired_animation = &"td_walk_down" if moving else &"td_idle_down"

	if not moving:
		_set_state_key("idle")
	elif _sprint_active:
		_animation_speed_scale = 1.32
		_set_state_key("sprint")
	elif input_mag > 0.08 and input_mag < walk_threshold:
		_animation_speed_scale = 0.72
		_set_state_key("walk")
	else:
		_set_state_key("run")


func get_cardinal_facing() -> String:
	return _cardinal_facing
