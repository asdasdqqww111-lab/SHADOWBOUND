class_name ObsidianSentinel
extends EnemyBase
## Archetype 3: Obsidian Sentinel (Armored Shield Guardian).
## Advances behind a gilded obsidian tower shield that reduces frontal light hits by 55%.
## Counterplay: shatter the shield with Combo Step 3 (Eclipse Finisher), Perfect-Guard
## Riposte, or dodge behind the Sentinel for unshielded full-damage strikes.

@export var cleave_step_speed: float = 115.0
@export var cleave_reach: float = 84.0


func _begin_attack(target: PlayerCharacter) -> void:
	super._begin_attack(target)
	if target != null:
		_face_toward(target.global_position)


func _tick_attack(target: PlayerCharacter, _delta: float) -> void:
	# Short deliberate step forward on opening frames, then grounded halberd cleave
	var step_factor: float = 1.0 if _state_timer > stats.attack_active_duration * 0.5 else 0.0
	var step_vec: Vector2 = facing_vector * cleave_step_speed * step_factor
	if gameplay_mode == GameState.GameplayMode.SIDE_SCROLL:
		var next_off: float = (global_position.x - _spawn_position.x) + facing_vector.x * 16.0
		if absf(next_off) > patrol_half_span + 26.0:
			step_vec = Vector2.ZERO
	_apply_desired_move(step_vec)

	if not _attack_did_hit and _state_timer <= stats.attack_active_duration * 0.65 and target != null:
		_try_deliver_melee_hit(target, cleave_reach, _get_effective_attack_damage())
