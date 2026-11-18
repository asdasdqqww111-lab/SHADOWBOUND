class_name PlayerCharacter
extends CharacterBody2D
## Unified SHADOWBOUND Stickman Player entity (Phase 3).

signal mode_applied(active_mode: int)
signal interact_requested
signal slash_landed(target: Node, total_hits: int)
signal combo_hit_landed(combo_step: int, damage_dealt: int, total_hits: int)
signal player_action(action_name: String)
signal movement_state_updated(state_key: String, compass_dir: String)
signal player_combat_event(outcome: String, amount: float)
signal player_defeated
signal riposte_changed(active: bool)

const LAYER_WORLD_SIDESCROLL: int = 1
const LAYER_WORLD_TOPDOWN: int = 2
const LAYER_PLAYER: int = 4
const LAYER_WORLD_ONEWAY: int = 128
const MASK_SIDESCROLL_DEFAULT: int = LAYER_WORLD_SIDESCROLL | LAYER_WORLD_ONEWAY
const BASE_SLASH_RADIUS: float = 34.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var side_controller: SideScrollController = $SideScrollController
@onready var top_controller: TopDownController = $TopDownController
@onready var camera: DualModeCamera = $DualModeCamera
@onready var slash_hitbox: Area2D = $SlashHitbox
@onready var slash_shape: CollisionShape2D = $SlashHitbox/CollisionShape2D

var profile: PlayerProfile = null
var active_mode: int = 0
var active_controller: MovementControllerBase = null
var _controllers: Dictionary = {}
var _player_combat_cfg: Dictionary = {}
var _defense_cfg: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _ss_shape: CapsuleShape2D = CapsuleShape2D.new()
var _td_shape: CapsuleShape2D = CapsuleShape2D.new()

# Touch control state merged seamlessly with keyboard/gamepad inputs
var _touch_move_vector: Vector2 = Vector2.ZERO
var _touch_jump_just_pressed: bool = false
var _touch_jump_held: bool = false
var _touch_jump_just_released: bool = false
var _touch_dodge_just_pressed: bool = false
var _touch_attack_just_pressed: bool = false
var _touch_block_held: bool = false
var _touch_interact_just_pressed: bool = false

var _stamina_regen_per_sec: float = 30.0
var _stamina_regen_delay: float = 0.35
var _stamina_delay_timer: float = 0.0
var _drop_through_duration: float = 0.18
var _drop_through_timer: float = 0.0
var _hurt_invuln_timer: float = 0.0
var _hurt_flash_timer: float = 0.0
var _riposte_timer: float = 0.0
var _riposte_window: float = 1.6
var _is_dead: bool = false

var _hit_targets_this_swing: Array[int] = []
var _last_swing_id: int = -1
var _was_attacking: bool = false
var _nearby_interactable_count: int = 0
var _last_emitted_state: String = ""
var _last_emitted_compass: String = ""


func _ready() -> void:
	_rng.randomize()
	add_to_group("player")
	_configure_collision_shapes()
	profile = GameState.get_player_profile()
	_controllers = {
		GameState.GameplayMode.SIDE_SCROLL: side_controller,
		GameState.GameplayMode.TOP_DOWN: top_controller,
	}
	_apply_all_configs()

	side_controller.action_triggered.connect(_on_controller_action)
	top_controller.action_triggered.connect(_on_controller_action)
	slash_hitbox.area_entered.connect(_on_slash_hitbox_area_entered)
	slash_shape.disabled = true

	set_mode(GameState.current_mode, true)


func _configure_collision_shapes() -> void:
	_ss_shape.radius = 13.0
	_ss_shape.height = 66.0
	_td_shape.radius = 13.0
	_td_shape.height = 28.0


func _apply_all_configs() -> void:
	var ss_cfg: Dictionary = GameState.get_config_section("side_scroll")
	side_controller.apply_config(ss_cfg)
	top_controller.apply_config(GameState.get_config_section("top_down"))
	camera.apply_config(GameState.get_config_section("camera"))
	_drop_through_duration = float(ss_cfg.get("drop_through_duration", _drop_through_duration))

	var shared_cfg: Dictionary = GameState.get_config_section("shared")
	_stamina_regen_per_sec = float(shared_cfg.get("stamina_regen_per_sec", _stamina_regen_per_sec))
	_stamina_regen_delay = float(shared_cfg.get("stamina_regen_delay", _stamina_regen_delay))

	_player_combat_cfg = GameState.get_combat_config_section("player_combat")
	_defense_cfg = GameState.get_combat_config_section("defense")
	_riposte_window = float(_player_combat_cfg.get("riposte_window", _riposte_window))
	side_controller.apply_combat_config(_player_combat_cfg)
	top_controller.apply_combat_config(_player_combat_cfg)


func set_mode(new_mode: int, force: bool = false) -> void:
	if not force and active_mode == new_mode and active_controller != null:
		return

	if active_controller != null:
		active_controller.deactivate()

	active_mode = new_mode
	collision_layer = LAYER_PLAYER
	_nearby_interactable_count = 0
	_drop_through_timer = 0.0
	_touch_block_held = false
	_touch_jump_held = false
	_clear_transient_touch_edges()
	_hit_targets_this_swing.clear()
	_last_swing_id = -1
	_was_attacking = false
	slash_shape.set_deferred("disabled", true)

	if active_mode == GameState.GameplayMode.TOP_DOWN:
		collision_mask = LAYER_WORLD_TOPDOWN
		collision_shape.shape = _td_shape
		collision_shape.position = Vector2(0.0, -10.0)
		sprite.position = Vector2(0.0, -44.0)
	else:
		collision_mask = MASK_SIDESCROLL_DEFAULT
		collision_shape.shape = _ss_shape
		collision_shape.position = Vector2(0.0, -33.0)
		sprite.position = Vector2(0.0, -52.0)

	active_controller = _controllers.get(active_mode, side_controller) as MovementControllerBase
	active_controller.activate(self)
	camera.set_camera_mode(active_mode)
	_sync_sprite()
	_emit_state_if_changed(true)
	mode_applied.emit(active_mode)


func _physics_process(delta: float) -> void:
	if active_controller == null or _is_dead:
		return

	_tick_combat_status(delta)
	_update_drop_through_mask(delta)
	var input_frame: Dictionary = _gather_input_frame()
	_clear_transient_touch_edges()

	if bool(input_frame.get("interact_just_pressed", false)):
		interact_requested.emit()

	var step_result: Dictionary = active_controller.physics_step(self, profile, input_frame, delta)
	if bool(step_result.get("drop_through", false)):
		_begin_drop_through()

	if bool(step_result.get("stamina_spent", false)):
		_stamina_delay_timer = _stamina_regen_delay
		GameState.notify_profile_updated()
	else:
		_tick_stamina_regen(delta)

	_update_slash_hitbox()
	_sync_sprite()
	_emit_state_if_changed(false)
	camera.update_focus(
		velocity,
		active_controller.get_facing_vector(),
		delta,
		active_controller.get_camera_hints()
	)


func _tick_combat_status(delta: float) -> void:
	_hurt_invuln_timer = maxf(0.0, _hurt_invuln_timer - delta)
	_hurt_flash_timer = maxf(0.0, _hurt_flash_timer - delta)
	if _riposte_timer > 0.0:
		_riposte_timer = maxf(0.0, _riposte_timer - delta)
		if _riposte_timer <= 0.0:
			riposte_changed.emit(false)


func _begin_drop_through() -> void:
	if active_mode != GameState.GameplayMode.SIDE_SCROLL:
		return
	_drop_through_timer = _drop_through_duration
	collision_mask = LAYER_WORLD_SIDESCROLL


func _update_drop_through_mask(delta: float) -> void:
	if _drop_through_timer <= 0.0:
		return
	_drop_through_timer = maxf(0.0, _drop_through_timer - delta)
	if _drop_through_timer <= 0.0 and active_mode == GameState.GameplayMode.SIDE_SCROLL:
		collision_mask = MASK_SIDESCROLL_DEFAULT


func _gather_input_frame() -> Dictionary:
	var kb_vec: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var combined_move: Vector2 = (
		_touch_move_vector if _touch_move_vector.length() > kb_vec.length() else kb_vec
	)

	var jump_pressed: bool = Input.is_action_just_pressed("jump") or _touch_jump_just_pressed
	var jump_released: bool = Input.is_action_just_released("jump") or _touch_jump_just_released
	var interact_pressed: bool = (
		Input.is_action_just_pressed("interact") or _touch_interact_just_pressed
	)

	if active_mode == GameState.GameplayMode.TOP_DOWN and jump_pressed:
		interact_pressed = true
		jump_pressed = false
	elif (
		active_mode == GameState.GameplayMode.SIDE_SCROLL
		and _nearby_interactable_count > 0
		and _touch_interact_just_pressed
	):
		jump_pressed = false

	return {
		"move_vector": combined_move,
		"jump_just_pressed": jump_pressed,
		"jump_just_released": jump_released,
		"jump_held": Input.is_action_pressed("jump") or _touch_jump_held,
		"dodge_just_pressed": Input.is_action_just_pressed("dodge") or _touch_dodge_just_pressed,
		"attack_just_pressed": Input.is_action_just_pressed("attack") or _touch_attack_just_pressed,
		"block_held": Input.is_action_pressed("block") or _touch_block_held,
		"sprint_held": Input.is_action_pressed("sprint"),
		"interact_just_pressed": interact_pressed,
	}


func _clear_transient_touch_edges() -> void:
	_touch_jump_just_pressed = false
	_touch_jump_just_released = false
	_touch_dodge_just_pressed = false
	_touch_attack_just_pressed = false
	_touch_interact_just_pressed = false


func _tick_stamina_regen(delta: float) -> void:
	if profile == null:
		return
	if _stamina_delay_timer > 0.0:
		_stamina_delay_timer = maxf(0.0, _stamina_delay_timer - delta)
		return
	if profile.current_stamina < profile.max_stamina:
		profile.regenerate_stamina(_stamina_regen_per_sec * delta)
		GameState.notify_profile_updated()


func _update_slash_hitbox() -> void:
	var attacking_now: bool = active_controller.is_attacking()
	var swing_id: int = active_controller.get_attack_swing_id()
	if attacking_now and swing_id != _last_swing_id:
		_last_swing_id = swing_id
		_hit_targets_this_swing.clear()

	if attacking_now:
		var face: Vector2 = active_controller.get_facing_vector().normalized()
		var hscale: float = active_controller.get_hitbox_scale()
		if slash_shape.shape is CircleShape2D:
			(slash_shape.shape as CircleShape2D).radius = BASE_SLASH_RADIUS * hscale
		var base_y: float = -34.0 if active_mode == GameState.GameplayMode.SIDE_SCROLL else -22.0
		var reach: float = 38.0 + (hscale - 1.0) * 26.0
		slash_hitbox.position = Vector2(0.0, base_y) + face * reach
		slash_shape.disabled = false
		for area: Area2D in slash_hitbox.get_overlapping_areas():
			_on_slash_hitbox_area_entered(area)
	elif _was_attacking:
		slash_shape.disabled = true
		_hit_targets_this_swing.clear()

	_was_attacking = attacking_now


func _on_slash_hitbox_area_entered(area: Area2D) -> void:
	if active_controller == null or not active_controller.is_attacking() or _is_dead:
		return
	var id: int = area.get_instance_id()
	if _hit_targets_this_swing.has(id):
		return

	var step: int = active_controller.get_combo_step()
	var face: Vector2 = active_controller.get_facing_vector().normalized()

	# Eclipse Finisher (step 3) and Riposte slashes can slice incoming projectiles
	if area is ShadowOrbProjectile:
		if step >= 3 or has_riposte_ready():
			_hit_targets_this_swing.append(id)
			(area as ShadowOrbProjectile).slice_projectile()
			camera.add_trauma(0.18)
		return

	# Enemy / Multi-Phase Boss Hurtbox
	if area.is_in_group("enemy_hurtbox"):
		var enemy_node: Node = area.get_parent()
		if enemy_node != null and enemy_node.has_method("receive_player_strike"):
			_hit_targets_this_swing.append(id)
			var use_riposte: bool = has_riposte_ready()
			var strike: Dictionary = CombatResolver.compute_player_strike(
				profile,
				_player_combat_cfg,
				step,
				use_riposte,
				_rng.randf()
			)
			strike["hit_direction"] = face
			strike["attacker_position"] = global_position
			var dealt: float = float(enemy_node.call("receive_player_strike", strike))
			if dealt > 0.0:
				if use_riposte:
					_riposte_timer = 0.0
					riposte_changed.emit(false)
				if profile != null:
					profile.session_slash_hits += 1
					GameState.notify_profile_updated()
					slash_landed.emit(enemy_node, profile.session_slash_hits)
					combo_hit_landed.emit(step, int(roundf(dealt)), profile.session_slash_hits)
				camera.add_trauma(float(strike.get("hit_shake", 0.2)))
		return

	# Guild Training Totem
	if area.has_method("receive_slash"):
		_hit_targets_this_swing.append(id)
		area.call("receive_slash", face)
		if profile != null:
			profile.session_slash_hits += 1
			GameState.notify_profile_updated()
			slash_landed.emit(area, profile.session_slash_hits)
			combo_hit_landed.emit(step, int(roundf(profile.base_attack * step * 0.6)), profile.session_slash_hits)
		camera.add_trauma(0.2 + float(step) * 0.06)


## Unified incoming attack receiver for melee enemies, boss cleaves, and projectiles.
func receive_attack(attack_data: Dictionary) -> Dictionary:
	if _is_dead or active_controller == null:
		return {"outcome": "ignored", "hp_damage": 0.0}

	var raw_damage: float = float(attack_data.get("damage", 10.0))
	var kb_mag: float = float(attack_data.get("knockback", 220.0))
	var src_pos: Vector2 = attack_data.get("source_position", global_position)
	var src_node: Variant = attack_data.get("source", null)
	var is_proj: bool = bool(attack_data.get("is_projectile", false))

	var to_attacker: Vector2 = src_pos - global_position
	if active_mode == GameState.GameplayMode.SIDE_SCROLL:
		to_attacker = Vector2(signf(to_attacker.x) if absf(to_attacker.x) > 0.5 else 1.0, 0.0)

	var result: Dictionary = CombatResolver.resolve_incoming_player_hit(
		raw_damage,
		profile,
		active_controller.get_facing_vector(),
		to_attacker,
		is_invulnerable(),
		is_blocking(),
		is_perfect_blocking(),
		_defense_cfg
	)
	var outcome: String = str(result.get("outcome", "hit"))
	var away_dir: Vector2 = (
		(-to_attacker).normalized() if to_attacker.length_squared() > 0.01 else Vector2.LEFT
	)

	match outcome:
		"dodged":
			if active_controller.is_dodging():
				_spawn_popup(
					LocalizationManager.translate_key("combat.popup_dodge"),
					Color(0.55, 0.95, 1.0, 1.0),
					15
				)
			player_combat_event.emit("dodged", 0.0)
		"parried":
			if profile != null:
				profile.regenerate_stamina(float(result.get("stamina_restored", 15.0)))
				profile.restore_mp(float(result.get("mp_restored", 8.0)))
				profile.session_parries += 1
				GameState.notify_profile_updated()
			_riposte_timer = _riposte_window
			riposte_changed.emit(true)
			camera.add_trauma(0.32)
			if not is_proj and src_node is Node and (src_node as Node).has_method("apply_parry_stagger"):
				(src_node as Node).call(
					"apply_parry_stagger",
					float(_defense_cfg.get("parry_enemy_stagger", 0.9))
				)
			var pkey: String = "combat.popup_reflect" if is_proj else "combat.popup_parry"
			_spawn_popup(LocalizationManager.translate_key(pkey), Color(1.0, 0.9, 0.45, 1.0), 18)
			player_combat_event.emit("parried", 0.0)
		"blocked", "guard_broken":
			var chip: float = float(result.get("hp_damage", 1.0))
			var sp_cost: float = float(result.get("stamina_cost", 14.0))
			if profile != null:
				profile.current_stamina = maxf(0.0, profile.current_stamina - sp_cost)
				profile.apply_damage(chip)
				_stamina_delay_timer = _stamina_regen_delay
				GameState.notify_profile_updated()
			_apply_knockback(away_dir, kb_mag * float(result.get("knockback_scale", 0.35)))
			if outcome == "guard_broken":
				active_controller.trigger_hurt_stun(
					float(_defense_cfg.get("guard_break_stun", 0.38))
				)
				camera.add_trauma(0.35)
				_spawn_popup(
					LocalizationManager.translate_key("combat.popup_guard_break"),
					Color(1.0, 0.45, 0.55, 1.0),
					17
				)
			else:
				camera.add_trauma(0.16)
				_spawn_popup(
					LocalizationManager.translate_key("combat.popup_block", {"value": int(chip)}),
					Color(0.68, 0.88, 1.0, 1.0),
					15
				)
			player_combat_event.emit(outcome, chip)
			_check_for_defeat()
		_:
			var dmg: float = float(result.get("hp_damage", raw_damage))
			if profile != null:
				profile.apply_damage(dmg)
				GameState.notify_profile_updated()
			_hurt_invuln_timer = float(_defense_cfg.get("hurt_invuln_duration", 0.65))
			_hurt_flash_timer = 0.22
			active_controller.trigger_hurt_stun(float(_defense_cfg.get("hurt_stun_duration", 0.18)))
			_apply_knockback(away_dir, kb_mag)
			camera.add_trauma(0.42)
			_spawn_popup("-%d" % int(roundf(dmg)), Color(1.0, 0.34, 0.48, 1.0), 17)
			player_combat_event.emit("hit", dmg)
			_check_for_defeat()

	return result


func _apply_knockback(away_dir: Vector2, magnitude: float) -> void:
	if active_mode == GameState.GameplayMode.SIDE_SCROLL:
		var sx: float = 1.0 if away_dir.x >= 0.0 else -1.0
		velocity = Vector2(sx * magnitude, minf(velocity.y, -135.0))
	else:
		velocity = away_dir.normalized() * magnitude


func _check_for_defeat() -> void:
	if profile != null and profile.is_defeated() and not _is_dead:
		_is_dead = true
		velocity = Vector2.ZERO
		slash_shape.set_deferred("disabled", true)
		sprite.modulate = Color(0.55, 0.25, 0.45, 0.72)
		player_defeated.emit()


func revive_at(world_pos: Vector2) -> void:
	_is_dead = false
	_hurt_invuln_timer = 1.1
	_hurt_flash_timer = 0.0
	_riposte_timer = 0.0
	riposte_changed.emit(false)
	velocity = Vector2.ZERO
	global_position = world_pos
	if profile != null:
		profile.restore_all()
		GameState.notify_profile_updated()
	if active_controller != null:
		active_controller.activate(self)
	sprite.modulate = Color.WHITE
	_sync_sprite()
	_emit_state_if_changed(true)


func _spawn_popup(msg: String, tint: Color, size_px: int = 16) -> void:
	FloatingCombatText.spawn(get_parent(), global_position + Vector2(0.0, -76.0), msg, tint, size_px)


func _sync_sprite() -> void:
	if sprite == null or active_controller == null:
		return
	sprite.flip_h = active_controller.get_flip_h()
	sprite.speed_scale = active_controller.get_animation_speed_scale()
	if _hurt_flash_timer > 0.0:
		sprite.modulate = Color(1.65, 0.55, 0.68, 1.0)
	elif active_controller.is_perfect_blocking():
		sprite.modulate = Color(1.25, 1.38, 1.58, 1.0)
	elif has_riposte_ready():
		sprite.modulate = Color(1.28, 1.16, 0.85, 1.0)
	elif active_controller.is_invulnerable():
		sprite.modulate = Color(0.82, 0.95, 1.32, 0.85)
	elif _hurt_invuln_timer > 0.0:
		var blink_alpha: float = 0.58 if int(_hurt_invuln_timer * 16.0) % 2 == 0 else 0.95
		sprite.modulate = Color(1.0, 0.92, 1.0, blink_alpha)
	else:
		sprite.modulate = Color.WHITE

	var target_anim: StringName = active_controller.get_desired_animation()
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(target_anim):
		if sprite.animation != target_anim or not sprite.is_playing():
			sprite.play(target_anim)


func _emit_state_if_changed(force: bool) -> void:
	if active_controller == null:
		return
	var skey: String = active_controller.get_state_key()
	var cdir: String = active_controller.get_compass_direction()
	if force or skey != _last_emitted_state or cdir != _last_emitted_compass:
		_last_emitted_state = skey
		_last_emitted_compass = cdir
		movement_state_updated.emit(skey, cdir)


func _on_controller_action(action_name: String) -> void:
	if action_name == "dodge":
		camera.add_trauma(0.18)
	elif action_name == "wall_jump":
		camera.add_trauma(0.12)
	elif action_name.begins_with("attack") and sprite != null:
		sprite.frame = 0
	player_action.emit(action_name)


func get_active_facing_vector() -> Vector2:
	if active_controller != null:
		return active_controller.get_facing_vector()
	return Vector2.RIGHT

func restore_facing_vector(vec: Vector2) -> void:
	if active_mode == GameState.GameplayMode.TOP_DOWN:
		top_controller.set_facing_vector(vec)
	else:
		side_controller.set_facing_direction(vec.x)
	_sync_sprite()
	_emit_state_if_changed(true)

func has_riposte_ready() -> bool:
	return _riposte_timer > 0.0

func is_defeated() -> bool:
	return _is_dead

func is_blocking() -> bool:
	return active_controller != null and active_controller.is_blocking()

func is_perfect_blocking() -> bool:
	return active_controller != null and active_controller.is_perfect_blocking()

func is_invulnerable() -> bool:
	if _hurt_invuln_timer > 0.0:
		return true
	return active_controller != null and active_controller.is_invulnerable()


# --- Public touch input API (called by TouchControls) ---

func set_touch_move_vector(vec: Vector2) -> void:
	_touch_move_vector = vec.limit_length(1.0)

func trigger_touch_jump(pressed: bool) -> void:
	if pressed:
		if active_mode == GameState.GameplayMode.TOP_DOWN or _nearby_interactable_count > 0:
			_touch_interact_just_pressed = true
		else:
			_touch_jump_just_pressed = true
		_touch_jump_held = true
	else:
		if _touch_jump_held:
			_touch_jump_just_released = true
		_touch_jump_held = false

func trigger_touch_dodge() -> void:
	_touch_dodge_just_pressed = true

func trigger_touch_attack() -> void:
	_touch_attack_just_pressed = true

func trigger_touch_block(pressed: bool) -> void:
	_touch_block_held = pressed

func set_nearby_rift(entered: bool) -> void:
	set_nearby_interactable(entered)

func set_nearby_interactable(entered: bool) -> void:
	if entered:
		_nearby_interactable_count += 1
	else:
		_nearby_interactable_count = maxi(0, _nearby_interactable_count - 1)

func is_near_rift() -> bool:
	return _nearby_interactable_count > 0
