class_name SideScrollController
extends MovementControllerBase
## Dedicated Side-Scrolling action-platformer movement controller (Phase 2).
## Handles horizontal acceleration with turn-snap, asymmetric & apex-hang gravity,
## ground/coyote/buffered jump, variable jump height, double jump, wall slide & wall jump,
## one-way bridge drop-through, ground/air shadow dodge with i-frames, guard blocking with
## perfect-parry window, and ground/air sword slashes.

var move_speed: float = 310.0
var ground_acceleration: float = 2250.0
var ground_friction: float = 2450.0
var air_acceleration: float = 1600.0
var air_friction: float = 650.0
var turn_acceleration_multiplier: float = 1.65
var gravity: float = 1320.0
var fall_gravity_multiplier: float = 1.32
var apex_hang_threshold: float = 75.0
var apex_gravity_multiplier: float = 0.76
var max_fall_speed: float = 880.0
var jump_velocity: float = -520.0
var double_jump_velocity: float = -465.0
var jump_cut_multiplier: float = 0.52
var max_jumps: int = 2
var coyote_time: float = 0.12
var jump_buffer_time: float = 0.13
var wall_slide_max_speed: float = 155.0
var wall_jump_velocity_x: float = 340.0
var wall_jump_velocity_y: float = -495.0
var wall_jump_lock_time: float = 0.13
var dodge_speed: float = 640.0
var dodge_duration: float = 0.2
var dodge_iframe_duration: float = 0.18
var dodge_cooldown: float = 0.52
var dodge_stamina_cost: float = 22.0
var max_air_dodges: int = 1
var block_move_factor: float = 0.28
var block_stamina_drain_per_sec: float = 10.0
var block_min_stamina: float = 8.0
var perfect_block_window: float = 0.18
var attack_duration: float = 0.3
var attack_cooldown: float = 0.1
var attack_lunge_speed: float = 135.0

var _facing_dir: float = 1.0
var _jumps_used: int = 0
var _air_dodges_used: int = 0
var _last_air_jump_state: String = "jump"
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _wall_jump_lock_timer: float = 0.0
var _dodge_timer: float = 0.0
var _iframe_timer: float = 0.0
var _dodge_cooldown_timer: float = 0.0
var _block_elapsed: float = 0.0
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
	turn_acceleration_multiplier = float(cfg.get("turn_acceleration_multiplier", turn_acceleration_multiplier))
	gravity = float(cfg.get("gravity", gravity))
	fall_gravity_multiplier = float(cfg.get("fall_gravity_multiplier", fall_gravity_multiplier))
	apex_hang_threshold = float(cfg.get("apex_hang_threshold", apex_hang_threshold))
	apex_gravity_multiplier = float(cfg.get("apex_gravity_multiplier", apex_gravity_multiplier))
	max_fall_speed = float(cfg.get("max_fall_speed", max_fall_speed))
	jump_velocity = float(cfg.get("jump_velocity", jump_velocity))
	double_jump_velocity = float(cfg.get("double_jump_velocity", double_jump_velocity))
	jump_cut_multiplier = float(cfg.get("jump_cut_multiplier", jump_cut_multiplier))
	max_jumps = maxi(1, int(cfg.get("max_jumps", max_jumps)))
	coyote_time = float(cfg.get("coyote_time", coyote_time))
	jump_buffer_time = float(cfg.get("jump_buffer_time", jump_buffer_time))
	wall_slide_max_speed = float(cfg.get("wall_slide_max_speed", wall_slide_max_speed))
	wall_jump_velocity_x = float(cfg.get("wall_jump_velocity_x", wall_jump_velocity_x))
	wall_jump_velocity_y = float(cfg.get("wall_jump_velocity_y", wall_jump_velocity_y))
	wall_jump_lock_time = float(cfg.get("wall_jump_lock_time", wall_jump_lock_time))
	dodge_speed = float(cfg.get("dodge_speed", dodge_speed))
	dodge_duration = float(cfg.get("dodge_duration", dodge_duration))
	dodge_iframe_duration = float(cfg.get("dodge_iframe_duration", dodge_iframe_duration))
	dodge_cooldown = float(cfg.get("dodge_cooldown", dodge_cooldown))
	dodge_stamina_cost = float(cfg.get("dodge_stamina_cost", dodge_stamina_cost))
	max_air_dodges = maxi(0, int(cfg.get("max_air_dodges", max_air_dodges)))
	block_move_factor = float(cfg.get("block_move_factor", block_move_factor))
	block_stamina_drain_per_sec = float(cfg.get("block_stamina_drain_per_sec", block_stamina_drain_per_sec))
	block_min_stamina = float(cfg.get("block_min_stamina", block_min_stamina))
	perfect_block_window = float(cfg.get("perfect_block_window", perfect_block_window))
	attack_duration = float(cfg.get("attack_duration", attack_duration))
	attack_cooldown = float(cfg.get("attack_cooldown", attack_cooldown))
	attack_lunge_speed = float(cfg.get("attack_lunge_speed", attack_lunge_speed))


func activate(body: CharacterBody2D) -> void:
	super.activate(body)
	body.motion_mode = CharacterBody2D.MOTION_MODE_GROUNDED
	body.up_direction = Vector2.UP
	body.floor_snap_length = 6.0
	body.floor_max_angle = 0.82
	body.velocity = Vector2.ZERO
	_jumps_used = 0
	_air_dodges_used = 0
	_last_air_jump_state = "jump"
	_coyote_timer = 0.0
	_jump_buffer_timer = 0.0
	_wall_jump_lock_timer = 0.0
	_dodge_timer = 0.0
	_iframe_timer = 0.0
	_block_elapsed = 0.0
	_attack_timer = 0.0
	_desired_animation = &"idle"
	_update_facing_from_dir(_facing_dir)
	_set_state_key("idle")


func set_facing_direction(dir_x: float) -> void:
	if absf(dir_x) > 0.05:
		_update_facing_from_dir(1.0 if dir_x > 0.0 else -1.0)


func _update_facing_from_dir(dir_sign: float) -> void:
	_facing_dir = 1.0 if dir_sign >= 0.0 else -1.0
	_flip_h = _facing_dir < 0.0
	_facing_vector = Vector2(_facing_dir, 0.0)
	_compass_dir = "E" if _facing_dir > 0.0 else "W"


func physics_step(
	body: CharacterBody2D,
	profile: PlayerProfile,
	input_frame: Dictionary,
	delta: float
) -> Dictionary:
	var stamina_spent: bool = false
	var drop_through: bool = false
	var move_vec: Vector2 = input_frame.get("move_vector", Vector2.ZERO)
	var axis_x: float = clampf(move_vec.x, -1.0, 1.0)
	var axis_y: float = clampf(move_vec.y, -1.0, 1.0)
	var jump_pressed: bool = bool(input_frame.get("jump_just_pressed", false))
	var jump_released: bool = bool(input_frame.get("jump_just_released", false))
	var dodge_pressed: bool = bool(input_frame.get("dodge_just_pressed", false))
	var attack_pressed: bool = bool(input_frame.get("attack_just_pressed", false))
	var block_held: bool = bool(input_frame.get("block_held", false))
	var sim_wall_normal_x: float = float(input_frame.get("sim_wall_normal_x", 0.0))

	_tick_timers(delta)

	var on_floor: bool = body.is_on_floor()
	if on_floor:
		_coyote_timer = coyote_time
		_jumps_used = 0
		_air_dodges_used = 0
		_last_air_jump_state = "jump"

	# One-way bridge drop-through when holding Down + pressing Jump while grounded
	if on_floor and axis_y > 0.62 and jump_pressed:
		drop_through = true
		jump_pressed = false
		_coyote_timer = 0.0
		body.velocity.y = maxf(body.velocity.y, 95.0)
		action_triggered.emit("drop_through")

	if jump_pressed:
		_jump_buffer_timer = jump_buffer_time

	if absf(axis_x) > 0.12 and _dodge_timer <= 0.0 and _wall_jump_lock_timer <= 0.0:
		_update_facing_from_dir(axis_x)

	# Shadow Dodge (ground or limited air dodge, with invulnerability frames)
	var can_dodge_air: bool = on_floor or _air_dodges_used < max_air_dodges
	if dodge_pressed and _dodge_timer <= 0.0 and _dodge_cooldown_timer <= 0.0 and can_dodge_air:
		if profile == null or profile.consume_stamina(dodge_stamina_cost):
			_dodge_timer = dodge_duration
			_iframe_timer = dodge_iframe_duration
			_dodge_cooldown_timer = dodge_cooldown
			_attack_timer = 0.0
			_clear_block()
			if not on_floor:
				_air_dodges_used += 1
			body.velocity = Vector2(_facing_dir * dodge_speed, 0.0)
			stamina_spent = true
			action_triggered.emit("dodge")

	if _dodge_timer > 0.0:
		_dodge_timer = maxf(0.0, _dodge_timer - delta)
		_dodge_active = true
		_attack_active = false
		_wall_slide_active = false
		_invulnerable_active = _iframe_timer > 0.0
		body.velocity = Vector2(_facing_dir * dodge_speed, 0.0)
		body.move_and_slide()
		_desired_animation = &"dodge"
		_animation_speed_scale = 1.0
		_set_state_key("dodge")
		return {"stamina_spent": stamina_spent, "drop_through": drop_through}

	_dodge_active = false
	_invulnerable_active = _iframe_timer > 0.0

	# Shadow Guard / Block (grounded defensive stance + perfect-guard window)
	stamina_spent = _update_block_state(on_floor, block_held, jump_pressed, profile, delta) or stamina_spent

	# Sword slash (grounded lunge or momentum-preserving aerial slash)
	if not _block_active and attack_pressed and _attack_timer <= 0.0 and _attack_cooldown_timer <= 0.0:
		_attack_timer = attack_duration
		_attack_cooldown_timer = attack_cooldown
		if on_floor:
			body.velocity.x = _facing_dir * attack_lunge_speed
		action_triggered.emit("attack")

	_attack_active = _attack_timer > 0.0

	# Detect wall slide when descending against a vertical wall
	var wall_normal_x: float = _resolve_wall_normal_x(body, sim_wall_normal_x)
	_wall_slide_active = (
		not on_floor
		and not _attack_active
		and body.velocity.y > 0.0
		and absf(wall_normal_x) > 0.5
		and axis_x * wall_normal_x < -0.2
	)

	# Gravity with apex hang-time smoothing and wall-slide terminal clamp
	if not on_floor:
		var grav_mult: float = 1.0
		if absf(body.velocity.y) < apex_hang_threshold and _jumps_used > 0:
			grav_mult = apex_gravity_multiplier
		elif body.velocity.y > 0.0:
			grav_mult = fall_gravity_multiplier
		body.velocity.y = minf(body.velocity.y + gravity * grav_mult * delta, max_fall_speed)
		if _wall_slide_active:
			body.velocity.y = minf(body.velocity.y, wall_slide_max_speed)
			_air_dodges_used = 0
			_jumps_used = mini(_jumps_used, 1)

	# Handle buffered Ground Jump, Wall Jump, and Airborne Double Jump
	if _jump_buffer_timer > 0.0:
		if _coyote_timer > 0.0 and _jumps_used == 0:
			_clear_block()
			body.velocity.y = jump_velocity
			_jumps_used = 1
			_last_air_jump_state = "jump"
			_coyote_timer = 0.0
			_jump_buffer_timer = 0.0
			on_floor = false
			action_triggered.emit("jump")
		elif _wall_slide_active and absf(wall_normal_x) > 0.5:
			_wall_slide_active = false
			_wall_jump_lock_timer = wall_jump_lock_time
			_update_facing_from_dir(wall_normal_x)
			body.velocity = Vector2(wall_normal_x * wall_jump_velocity_x, wall_jump_velocity_y)
			_jumps_used = 1
			_last_air_jump_state = "wall_jump"
			_jump_buffer_timer = 0.0
			action_triggered.emit("wall_jump")
		elif _jumps_used < max_jumps:
			if _jumps_used == 0:
				_jumps_used = 1
			if _jumps_used < max_jumps:
				body.velocity.y = double_jump_velocity
				_jumps_used += 1
				_last_air_jump_state = "double_jump"
				_jump_buffer_timer = 0.0
				action_triggered.emit("double_jump")

	# Variable jump height on early button release
	if jump_released and body.velocity.y < -80.0:
		body.velocity.y *= jump_cut_multiplier

	# Horizontal acceleration with crisp turn-around boost
	_apply_horizontal_velocity(body, on_floor, axis_x, delta)

	body.move_and_slide()
	_update_animation_and_state(body.is_on_floor(), body.velocity, axis_x, wall_normal_x)
	return {"stamina_spent": stamina_spent, "drop_through": drop_through}


func _tick_timers(delta: float) -> void:
	_coyote_timer = maxf(0.0, _coyote_timer - delta)
	_jump_buffer_timer = maxf(0.0, _jump_buffer_timer - delta)
	_wall_jump_lock_timer = maxf(0.0, _wall_jump_lock_timer - delta)
	_iframe_timer = maxf(0.0, _iframe_timer - delta)
	_dodge_cooldown_timer = maxf(0.0, _dodge_cooldown_timer - delta)
	_attack_timer = maxf(0.0, _attack_timer - delta)
	_attack_cooldown_timer = maxf(0.0, _attack_cooldown_timer - delta)


func _update_block_state(
	on_floor: bool,
	block_held: bool,
	jump_pressed: bool,
	profile: PlayerProfile,
	delta: float
) -> bool:
	if not on_floor or not block_held or jump_pressed or _attack_timer > 0.0:
		_clear_block()
		return false

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


func _resolve_wall_normal_x(body: CharacterBody2D, sim_normal_x: float) -> float:
	if absf(sim_normal_x) > 0.5:
		return signf(sim_normal_x)
	if body.is_on_wall_only():
		return body.get_wall_normal().x
	return 0.0


func _apply_horizontal_velocity(
	body: CharacterBody2D,
	on_floor: bool,
	axis_x: float,
	delta: float
) -> void:
	if _wall_jump_lock_timer > 0.0:
		return

	var accel: float = ground_acceleration if on_floor else air_acceleration
	var fric: float = ground_friction if on_floor else air_friction

	if _attack_active and on_floor:
		body.velocity.x = move_toward(body.velocity.x, 0.0, fric * 0.75 * delta)
	elif _block_active:
		var guard_target: float = axis_x * move_speed * block_move_factor
		body.velocity.x = move_toward(body.velocity.x, guard_target, accel * 0.8 * delta)
	elif absf(axis_x) > 0.08:
		var reversing: bool = (axis_x * body.velocity.x) < -12.0
		var eff_accel: float = accel * (turn_acceleration_multiplier if reversing else 1.0)
		body.velocity.x = move_toward(body.velocity.x, axis_x * move_speed, eff_accel * delta)
	else:
		body.velocity.x = move_toward(body.velocity.x, 0.0, fric * delta)


func _update_animation_and_state(
	on_floor: bool,
	vel: Vector2,
	axis_x: float,
	wall_normal_x: float
) -> void:
	_animation_speed_scale = 1.0
	if _attack_active:
		_desired_animation = &"attack"
		_set_state_key("attack")
	elif _block_active:
		_desired_animation = &"block"
		_set_state_key("parry" if _perfect_block_active else "block")
	elif _wall_slide_active:
		# Sprite wall_slide braces right hand on right wall; mirror when wall is on left.
		_flip_h = wall_normal_x > 0.0
		_desired_animation = &"wall_slide"
		_set_state_key("wall_slide")
	elif not on_floor:
		if vel.y < 0.0:
			_desired_animation = &"jump"
			_set_state_key(_last_air_jump_state)
		else:
			_desired_animation = &"fall"
			_set_state_key("fall")
	elif absf(vel.x) > 22.0 or absf(axis_x) > 0.15:
		_desired_animation = &"run"
		_animation_speed_scale = clampf(absf(vel.x) / maxf(1.0, move_speed), 0.65, 1.15)
		_set_state_key("run")
	else:
		_desired_animation = &"idle"
		_set_state_key("idle")


func get_jumps_remaining() -> int:
	return maxi(0, max_jumps - _jumps_used)


func get_air_dodges_remaining() -> int:
	return maxi(0, max_air_dodges - _air_dodges_used)
