class_name TopDownController
extends MovementControllerBase
## Modular 8-direction top-down exploration and combat movement controller prototype.
## Uses MOTION_MODE_FLOATING with normalized vector velocity, directional animations,
## shadow blink-dodge, and directional sword slash.

var move_speed: float = 265.0
var acceleration: float = 2100.0
var friction: float = 2300.0
var dodge_speed: float = 580.0
var dodge_duration: float = 0.18
var dodge_cooldown: float = 0.5
var dodge_stamina_cost: float = 20.0
var attack_duration: float = 0.28
var attack_cooldown: float = 0.12
var attack_step_speed: float = 95.0

var _cardinal_facing: String = "down"
var _dodge_dir: Vector2 = Vector2.DOWN
var _dodge_timer: float = 0.0
var _dodge_cooldown_timer: float = 0.0
var _attack_timer: float = 0.0
var _attack_cooldown_timer: float = 0.0


func apply_config(cfg: Dictionary) -> void:
	if cfg.is_empty():
		return
	move_speed = float(cfg.get("move_speed", move_speed))
	acceleration = float(cfg.get("acceleration", acceleration))
	friction = float(cfg.get("friction", friction))
	dodge_speed = float(cfg.get("dodge_speed", dodge_speed))
	dodge_duration = float(cfg.get("dodge_duration", dodge_duration))
	dodge_cooldown = float(cfg.get("dodge_cooldown", dodge_cooldown))
	dodge_stamina_cost = float(cfg.get("dodge_stamina_cost", dodge_stamina_cost))
	attack_duration = float(cfg.get("attack_duration", attack_duration))
	attack_cooldown = float(cfg.get("attack_cooldown", attack_cooldown))
	attack_step_speed = float(cfg.get("attack_step_speed", attack_step_speed))


func activate(body: CharacterBody2D) -> void:
	super.activate(body)
	body.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	body.floor_snap_length = 0.0
	body.velocity = Vector2.ZERO
	_dodge_timer = 0.0
	_attack_timer = 0.0
	_cardinal_facing = "down"
	_facing_vector = Vector2.DOWN
	_flip_h = false
	_desired_animation = &"td_idle_down"


func physics_step(
	body: CharacterBody2D,
	profile: PlayerProfile,
	input_frame: Dictionary,
	delta: float
) -> Dictionary:
	var stamina_spent: bool = false
	var raw_vec: Vector2 = input_frame.get("move_vector", Vector2.ZERO)
	# Preserve smooth analog joystick intensity while clamping diagonals to unit length.
	var move_vec: Vector2 = raw_vec.limit_length(1.0)
	var dodge_pressed: bool = bool(input_frame.get("dodge_just_pressed", false))
	var attack_pressed: bool = bool(input_frame.get("attack_just_pressed", false))

	_dodge_cooldown_timer = maxf(0.0, _dodge_cooldown_timer - delta)
	_attack_cooldown_timer = maxf(0.0, _attack_cooldown_timer - delta)

	if move_vec.length() > 0.12 and _dodge_timer <= 0.0:
		_facing_vector = move_vec.normalized()
		_update_cardinal_facing(_facing_vector)

	# Shadow dash in any of 8 directions (or current facing vector if stationary)
	if dodge_pressed and _dodge_timer <= 0.0 and _dodge_cooldown_timer <= 0.0:
		if profile == null or profile.consume_stamina(dodge_stamina_cost):
			_dodge_dir = move_vec.normalized() if move_vec.length() > 0.12 else _facing_vector
			if _dodge_dir.length_squared() < 0.01:
				_dodge_dir = Vector2.DOWN
			_facing_vector = _dodge_dir
			_flip_h = _dodge_dir.x < -0.05
			_dodge_timer = dodge_duration
			_dodge_cooldown_timer = dodge_cooldown
			_attack_timer = 0.0
			body.velocity = _dodge_dir * dodge_speed
			stamina_spent = true
			action_triggered.emit("dodge")

	if _dodge_timer > 0.0:
		_dodge_timer = maxf(0.0, _dodge_timer - delta)
		_dodge_active = true
		_attack_active = false
		body.velocity = _dodge_dir * dodge_speed
		body.move_and_slide()
		_desired_animation = &"td_dodge"
		return {"stamina_spent": stamina_spent}

	_dodge_active = false

	# Directional shadow-blade slash
	if attack_pressed and _attack_timer <= 0.0 and _attack_cooldown_timer <= 0.0:
		_attack_timer = attack_duration
		_attack_cooldown_timer = attack_cooldown
		body.velocity = _facing_vector * attack_step_speed
		action_triggered.emit("attack")

	if _attack_timer > 0.0:
		_attack_timer = maxf(0.0, _attack_timer - delta)
		_attack_active = true
		body.velocity = body.velocity.move_toward(Vector2.ZERO, friction * 0.65 * delta)
	else:
		_attack_active = false
		if move_vec.length() > 0.08:
			body.velocity = body.velocity.move_toward(move_vec * move_speed, acceleration * delta)
		else:
			body.velocity = body.velocity.move_toward(Vector2.ZERO, friction * delta)

	body.move_and_slide()
	_update_animation_state(body.velocity, move_vec)
	return {"stamina_spent": stamina_spent}


func _update_cardinal_facing(dir: Vector2) -> void:
	if absf(dir.x) > absf(dir.y) * 1.05:
		_cardinal_facing = "side"
		_flip_h = dir.x < 0.0
	elif dir.y < 0.0:
		_cardinal_facing = "up"
		_flip_h = false
	else:
		_cardinal_facing = "down"
		_flip_h = false


func _update_animation_state(vel: Vector2, move_vec: Vector2) -> void:
	if _attack_active:
		_desired_animation = &"td_attack"
		return
	var moving: bool = vel.length() > 18.0 or move_vec.length() > 0.14
	match _cardinal_facing:
		"up":
			_desired_animation = &"td_walk_up" if moving else &"td_idle_up"
		"side":
			_desired_animation = &"td_walk_side" if moving else &"td_idle_side"
		_:
			_desired_animation = &"td_walk_down" if moving else &"td_idle_down"


func get_cardinal_facing() -> String:
	return _cardinal_facing
