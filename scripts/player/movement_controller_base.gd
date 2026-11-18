class_name MovementControllerBase
extends Node
## Abstract base contract for modular SHADOWBOUND player movement controllers.
## Both SideScrollController and TopDownController implement this interface so one
## unified PlayerCharacter shares profile, stamina, animations, camera, and combat hooks.

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


func apply_config(_cfg: Dictionary) -> void:
	pass


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


func get_camera_hints() -> Dictionary:
	return {
		"blocking": _block_active,
		"dodging": _dodge_active,
		"sprinting": _sprint_active,
		"wall_sliding": _wall_slide_active,
	}
