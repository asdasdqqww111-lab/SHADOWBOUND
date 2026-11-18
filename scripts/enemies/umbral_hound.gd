class_name UmbralHound
extends EnemyBase
## Archetype 1: Umbral Stalker (Fast Melee Rusher).
## Sprints into range, flashes a sharp crimson telegraph, and executes a high-speed
## Shadow Fang Lunge — rewarding crisp Shadow Dodge i-frames or Perfect Guard parries.

@export var lunge_speed: float = 385.0

var _lunge_direction: Vector2 = Vector2.LEFT


func _begin_attack(target: PlayerCharacter) -> void:
	super._begin_attack(target)
	if target != null:
		_lunge_direction = _move_dir_toward(target.global_position)
		_set_facing(_lunge_direction)
	else:
		_lunge_direction = facing_vector


func _tick_attack(target: PlayerCharacter, _delta: float) -> void:
	var burst: Vector2 = _lunge_direction * lunge_speed
	# Prevent lunging off side-scroll platforms
	if gameplay_mode == GameState.GameplayMode.SIDE_SCROLL:
		var next_off: float = (global_position.x - _spawn_position.x) + _lunge_direction.x * 18.0
		if absf(next_off) > patrol_half_span + 34.0:
			burst = Vector2.ZERO
	_apply_desired_move(burst)

	if not _attack_did_hit and target != null:
		_try_deliver_melee_hit(target, 54.0, _get_effective_attack_damage())
