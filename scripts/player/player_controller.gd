class_name PlayerCharacter
extends CharacterBody2D
## Unified SHADOWBOUND Stickman Player entity.
## Shares a single PlayerProfile, animation rig, slash hitbox, and camera target while
## delegating physics movement to either SideScrollController or TopDownController.

signal mode_applied(active_mode: int)
signal interact_requested
signal slash_landed(target: Node, total_hits: int)
signal player_action(action_name: String)

const LAYER_WORLD_SIDESCROLL: int = 1
const LAYER_WORLD_TOPDOWN: int = 2
const LAYER_PLAYER: int = 4

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

var _ss_shape: CapsuleShape2D = CapsuleShape2D.new()
var _td_shape: CapsuleShape2D = CapsuleShape2D.new()

# Touch control state merged seamlessly with keyboard/gamepad actions
var _touch_move_vector: Vector2 = Vector2.ZERO
var _touch_jump_just_pressed: bool = false
var _touch_jump_held: bool = false
var _touch_jump_just_released: bool = false
var _touch_dodge_just_pressed: bool = false
var _touch_attack_just_pressed: bool = false
var _touch_interact_just_pressed: bool = false

var _stamina_regen_per_sec: float = 28.0
var _stamina_regen_delay: float = 0.35
var _stamina_delay_timer: float = 0.0
var _hit_targets_this_swing: Array[int] = []
var _was_attacking: bool = false
var _nearby_rift_count: int = 0


func _ready() -> void:
	add_to_group("player")
	_configure_collision_shapes()
	profile = GameState.get_player_profile()
	_apply_movement_configs()

	side_controller.action_triggered.connect(_on_controller_action)
	top_controller.action_triggered.connect(_on_controller_action)
	slash_hitbox.area_entered.connect(_on_slash_hitbox_area_entered)
	slash_shape.disabled = true

	set_mode(GameState.current_mode, true)


func _configure_collision_shapes() -> void:
	# Side-scroll upright body (origin at feet y = 0)
	_ss_shape.radius = 13.0
	_ss_shape.height = 66.0
	# Top-down grounded foot collider for smooth 3/4 wall sliding
	_td_shape.radius = 13.0
	_td_shape.height = 28.0


func _apply_movement_configs() -> void:
	side_controller.apply_config(GameState.get_config_section("side_scroll"))
	top_controller.apply_config(GameState.get_config_section("top_down"))
	camera.apply_config(GameState.get_config_section("camera"))
	var shared_cfg: Dictionary = GameState.get_config_section("shared")
	_stamina_regen_per_sec = float(shared_cfg.get("stamina_regen_per_sec", _stamina_regen_per_sec))
	_stamina_regen_delay = float(shared_cfg.get("stamina_regen_delay", _stamina_regen_delay))


func set_mode(new_mode: int, force: bool = false) -> void:
	if not force and active_mode == new_mode and active_controller != null:
		return

	if active_controller != null:
		active_controller.deactivate()

	active_mode = new_mode
	collision_layer = LAYER_PLAYER
	_nearby_rift_count = 0
	_clear_transient_touch_edges()
	_hit_targets_this_swing.clear()
	slash_shape.set_deferred("disabled", true)

	if active_mode == GameState.GameplayMode.TOP_DOWN:
		collision_mask = LAYER_WORLD_TOPDOWN
		collision_shape.shape = _td_shape
		collision_shape.position = Vector2(0.0, -10.0)
		sprite.position = Vector2(0.0, -44.0)
		active_controller = top_controller
	else:
		collision_mask = LAYER_WORLD_SIDESCROLL
		collision_shape.shape = _ss_shape
		collision_shape.position = Vector2(0.0, -33.0)
		sprite.position = Vector2(0.0, -52.0)
		active_controller = side_controller

	active_controller.activate(self)
	camera.set_camera_mode(active_mode)
	_sync_sprite()
	mode_applied.emit(active_mode)


func _physics_process(delta: float) -> void:
	if active_controller == null:
		return

	var input_frame: Dictionary = _gather_input_frame()
	_clear_transient_touch_edges()

	if bool(input_frame.get("interact_just_pressed", false)):
		interact_requested.emit()

	var step_result: Dictionary = active_controller.physics_step(self, profile, input_frame, delta)
	if bool(step_result.get("stamina_spent", false)):
		_stamina_delay_timer = _stamina_regen_delay
		GameState.notify_profile_updated()
	else:
		_tick_stamina_regen(delta)

	_update_slash_hitbox()
	_sync_sprite()
	camera.update_focus(velocity, active_controller.get_facing_vector(), delta)


func _gather_input_frame() -> Dictionary:
	var kb_vec: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var combined_move: Vector2 = _touch_move_vector if _touch_move_vector.length() > kb_vec.length() else kb_vec

	var jump_pressed: bool = Input.is_action_just_pressed("jump") or _touch_jump_just_pressed
	var jump_released: bool = Input.is_action_just_released("jump") or _touch_jump_just_released
	var interact_pressed: bool = Input.is_action_just_pressed("interact") or _touch_interact_just_pressed

	# When standing inside a Shadow Rift in Top-Down mode, Jump button acts as Rift Interact
	if active_mode == GameState.GameplayMode.TOP_DOWN and jump_pressed:
		interact_pressed = true
		jump_pressed = false
	elif active_mode == GameState.GameplayMode.SIDE_SCROLL and _nearby_rift_count > 0 and _touch_interact_just_pressed:
		jump_pressed = false

	return {
		"move_vector": combined_move,
		"jump_just_pressed": jump_pressed,
		"jump_just_released": jump_released,
		"jump_held": Input.is_action_pressed("jump") or _touch_jump_held,
		"dodge_just_pressed": Input.is_action_just_pressed("dodge") or _touch_dodge_just_pressed,
		"attack_just_pressed": Input.is_action_just_pressed("attack") or _touch_attack_just_pressed,
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
	if attacking_now and not _was_attacking:
		_hit_targets_this_swing.clear()

	if attacking_now:
		var face: Vector2 = active_controller.get_facing_vector()
		var base_y: float = -34.0 if active_mode == GameState.GameplayMode.SIDE_SCROLL else -22.0
		slash_hitbox.position = Vector2(0.0, base_y) + face.normalized() * 38.0
		slash_shape.disabled = false
		for area: Area2D in slash_hitbox.get_overlapping_areas():
			_on_slash_hitbox_area_entered(area)
	elif _was_attacking:
		slash_shape.disabled = true
		_hit_targets_this_swing.clear()

	_was_attacking = attacking_now


func _sync_sprite() -> void:
	if sprite == null or active_controller == null:
		return
	sprite.flip_h = active_controller.get_flip_h()
	var target_anim: StringName = active_controller.get_desired_animation()
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(target_anim):
		if sprite.animation != target_anim or not sprite.is_playing():
			sprite.play(target_anim)


func _on_controller_action(action_name: String) -> void:
	if action_name == "dodge":
		camera.add_trauma(0.18)
	elif action_name == "attack" and sprite != null:
		sprite.frame = 0
	player_action.emit(action_name)


func _on_slash_hitbox_area_entered(area: Area2D) -> void:
	if not active_controller.is_attacking():
		return
	var id: int = area.get_instance_id()
	if _hit_targets_this_swing.has(id):
		return
	if area.has_method("receive_slash"):
		_hit_targets_this_swing.append(id)
		area.call("receive_slash", active_controller.get_facing_vector())
		if profile != null:
			profile.session_slash_hits += 1
			GameState.notify_profile_updated()
			slash_landed.emit(area, profile.session_slash_hits)
		camera.add_trauma(0.28)


# --- Public touch input API (called by TouchControls) ---

func set_touch_move_vector(vec: Vector2) -> void:
	_touch_move_vector = vec.limit_length(1.0)


func trigger_touch_jump(pressed: bool) -> void:
	if pressed:
		if active_mode == GameState.GameplayMode.TOP_DOWN or _nearby_rift_count > 0:
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


func set_nearby_rift(entered: bool) -> void:
	if entered:
		_nearby_rift_count += 1
	else:
		_nearby_rift_count = maxi(0, _nearby_rift_count - 1)


func is_near_rift() -> bool:
	return _nearby_rift_count > 0
