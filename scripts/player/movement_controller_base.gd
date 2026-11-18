class_name MovementControllerBase
extends Node
## Base class for modular SHADOWBOUND player movement controllers.
## Both SideScrollController and TopDownController inherit this interface so the
## unified Player entity shares profile, stamina, animations, and combat hooks.

signal action_triggered(action_name: String)

var _desired_animation: StringName = &"idle"
var _flip_h: bool = false
var _facing_vector: Vector2 = Vector2.RIGHT
var _attack_active: bool = false
var _dodge_active: bool = false


func apply_config(_cfg: Dictionary) -> void:
	pass


func activate(_body: CharacterBody2D) -> void:
	_attack_active = false
	_dodge_active = false


func deactivate() -> void:
	_attack_active = false
	_dodge_active = false


func physics_step(
	_body: CharacterBody2D,
	_profile: PlayerProfile,
	_input_frame: Dictionary,
	_delta: float
) -> Dictionary:
	return {"stamina_spent": false}


func get_desired_animation() -> StringName:
	return _desired_animation


func get_flip_h() -> bool:
	return _flip_h


func get_facing_vector() -> Vector2:
	return _facing_vector


func is_attacking() -> bool:
	return _attack_active


func is_dodging() -> bool:
	return _dodge_active
