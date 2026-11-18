class_name SideScrollController
extends MovementControllerBase
## Modular side-scrolling action-platformer movement controller.
## Supports horizontal movement, gravity, coyote time, jump buffering, variable jump height,
## double jump, shadow dodge, and sword slash with forward lunge.

var move_speed: float = 310.0
var ground_acceleration: float = 2200.0
var ground_friction: float = 2400.0
var air_acceleration: float = 1550.0
var air_friction: float = 650.0
var gravity: float = 1320.0
var fall_gravity_multiplier: float = 1.32
var max_fall_speed: float = 880.0
var jump_velocity: float = -520.0
var double_jump_velocity: float = -465.0
var jump_cut_multiplier: float = 0.52
var max_jumps: int = 2
var coyote_time: float = 0.12
var jump_buffer_time: float = 0.13
var dodge_speed: float = 640.0
var dodge_duration: float = 0.2
var dodge_cooldown: float = 0.55
var dodge_stamina_cost: float = 22.0
var attack_duration: float = 0.3
var attack_cooldown: float = 0.1
var attack_lunge_speed: float = 135.0

var _facing_dir: float = 1.0
var _jumps_used: int = 0
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _dodge_timer: float = 0.0
var _dodge_cooldown_timer: float = 0.0
var _attack_timer: float = 0.0
var _attack_cooldown_timer: float = 0.0


func apply_config(cfg: Dictionary) -> void:
	if cfg.is_empty():
		return
	move_speed = float(cfg.get("move_speed", move_speed))
	ground_acceleration = float(cfg.get("ground_acceleration", ground_acceleration))
	ground_friction = float(cfg.get("ground_friction", ground_friction))
	air_acceleration = float(cfg.get("air_acceleration", air_acceleration))
	air_friction = float(cfg.get("air_friction", air_friction))
	gravity = float(cfg.get("gravity", gravity))
	fall_gravity_multiplier = float(cfg.get("fall_gravity_multiplier", fall_gravity_multiplier))
	max_fall_speed = float(cfg.get("max_fall_speed", max_fall_speed))
	jump_velocity = float(cfg.get("jump_velocity", jump_velocity))
	double_jump_velocity = float(cfg.get("double_jump_velocity", double_jump_velocity))
	jump_cut_multiplier = float(cfg.get("jump_cut_multiplier", jump_cut_multiplier))
	max_jumps = maxi(1, int(cfg.get("max_jumps", max_jumps)))
	coyote_time = float(cfg.get("coyote_time", coyote_time))
	jump_buffer_time = float(cfg.get("jump_buffer_time", jump_buffer_time))
	dodge_speed = float(cfg.get("dodge_speed", dodge_speed))
	dodge_duration = float(cfg.get("dodge_duration", dodge_duration))
	dodge_cooldown = float(cfg.get("dodge_cooldown", dodge_cooldown))
	dodge_stamina_cost = float(cfg.get("dodge_stamina_cost", dodge_stamina_cost))
	attack_duration = float(cfg.get("attack_duration", attack_duration))
	attack_cooldown = float(cfg.get("attack_cooldown", attack_cooldown))
	attack_lunge_speed = float(cfg.get("attack_lunge_speed", attack_lunge_speed))


func activate(body: CharacterBody2D) -> void:
	super.activate(body)
	body.motion_mode = CharacterBody2D.MOTION_MODE_GROUNDED
	body.up_direction = Vector2.UP
	body.floor_snap_length = 6.0
	body.velocity = Vector2.ZERO
	_jumps_used = 0
	_coyote_timer = 0.0
	_jump_buffer_timer = 0.0
	_dodge_timer = 0.0
	_attack_timer = 0.0
	_desired_animation = &"idle"
	_facing_vector = Vector2(_facing_dir, 0.0)


func physics_step(
	body: CharacterBody2D,
	profile: PlayerProfile,
	input_frame: Dictionary,
	delta: float
) -> Dictionary:
	var stamina_spent: bool = false
	var move_vec: Vector2 = input_frame.get("move_vector", Vector2.ZERO)
	var axis_x: float = clampf(move_vec.x, -1.0, 1.0)
	var jump_pressed: bool = bool(input_frame.get("jump_just_pressed", false))
	var jump_released: bool = bool(input_frame.get("jump_just_released", false))
	var dodge_pressed: bool = bool(input_frame.get("dodge_just_pressed", false))
	var attack_pressed: bool = bool(input_frame.get("attack_just_pressed", false))

	_dodge_cooldown_timer = maxf(0.0, _dodge_cooldown_timer - delta)
	_attack_cooldown_timer = maxf(0.0, _attack_cooldown_timer - delta)

	var on_floor: bool = body.is_on_floor()
	if on_floor:
		_coyote_timer = coyote_time
		_jumps_used = 0
	else:
		_coyote_timer = maxf(0.0, _coyote_timer - delta)

	if jump_pressed:
		_jump_buffer_timer = jump_buffer_time
	else:
		_jump_buffer_timer = maxf(0.0, _jump_buffer_timer - delta)

	if absf(axis_x) > 0.12 and _dodge_timer <= 0.0:
		_facing_dir = 1.0 if axis_x > 0.0 else -1.0
		_flip_h = _facing_dir < 0.0
		_facing_vector = Vector2(_facing_dir, 0.0)

	# Trigger shadow dodge
	if dodge_pressed and _dodge_timer <= 0.0 and _dodge_cooldown_timer <= 0.0:
		if profile == null or profile.consume_stamina(dodge_stamina_cost):
			_dodge_timer = dodge_duration
			_dodge_cooldown_timer = dodge_cooldown
			_attack_timer = 0.0
			body.velocity = Vector2(_facing_dir * dodge_speed, 0.0)
			stamina_spent = true
			action_triggered.emit("dodge")

	# Active dodge overrides gravity and regular movement
	if _dodge_timer > 0.0:
		_dodge_timer = maxf(0.0, _dodge_timer - delta)
		_dodge_active = true
		_attack_active = false
		body.velocity.x = _facing_dir * dodge_speed
		body.velocity.y = 0.0
		body.move_and_slide()
		_desired_animation = &"dodge"
		return {"stamina_spent": stamina_spent}

	_dodge_active = false

	# Trigger sword attack
	if attack_pressed and _attack_timer <= 0.0 and _attack_cooldown_timer <= 0.0:
		_attack_timer = attack_duration
		_attack_cooldown_timer = attack_cooldown
		if on_floor:
			body.velocity.x = _facing_dir * attack_lunge_speed
		action_triggered.emit("attack")

	if _attack_timer > 0.0:
		_attack_timer = maxf(0.0, _attack_timer - delta)
		_attack_active = true
	else:
		_attack_active = false

	# Apply gravity
	if not on_floor:
		var grav_scale: float = fall_gravity_multiplier if body.velocity.y > 0.0 else 1.0
		body.velocity.y = minf(body.velocity.y + gravity * grav_scale * delta, max_fall_speed)

	# Handle buffered ground/coyote jump and airborne double jump
	if _jump_buffer_timer > 0.0:
		if _coyote_timer > 0.0 and _jumps_used == 0:
			body.velocity.y = jump_velocity
			_jumps_used = 1
			_coyote_timer = 0.0
			_jump_buffer_timer = 0.0
			on_floor = false
			action_triggered.emit("jump")
		elif _jumps_used < max_jumps:
			# If player fell off ledge without jumping first, treat first air jump as jump #2
			if _jumps_used == 0:
				_jumps_used = 1
			if _jumps_used < max_jumps:
				body.velocity.y = double_jump_velocity
				_jumps_used += 1
				_jump_buffer_timer = 0.0
				action_triggered.emit("double_jump")

	# Variable jump height when releasing jump early
	if jump_released and body.velocity.y < -80.0:
		body.velocity.y *= jump_cut_multiplier

	# Horizontal acceleration / friction
	var accel: float = ground_acceleration if on_floor else air_acceleration
	var fric: float = ground_friction if on_floor else air_friction
	if _attack_active and on_floor:
		body.velocity.x = move_toward(body.velocity.x, 0.0, fric * 0.75 * delta)
	elif absf(axis_x) > 0.08:
		body.velocity.x = move_toward(body.velocity.x, axis_x * move_speed, accel * delta)
	else:
		body.velocity.x = move_toward(body.velocity.x, 0.0, fric * delta)

	body.move_and_slide()
	_update_animation_state(body.is_on_floor(), body.velocity, axis_x)
	return {"stamina_spent": stamina_spent}


func _update_animation_state(on_floor: bool, vel: Vector2, axis_x: float) -> void:
	if _attack_active:
		_desired_animation = &"attack"
	elif not on_floor:
		_desired_animation = &"jump" if vel.y < 0.0 else &"fall"
	elif absf(vel.x) > 22.0 or absf(axis_x) > 0.15:
		_desired_animation = &"run"
	else:
		_desired_animation = &"idle"


func get_jumps_remaining() -> int:
	return maxi(0, max_jumps - _jumps_used)
