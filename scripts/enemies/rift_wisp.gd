class_name RiftWisp
extends EnemyBase
## Archetype 2: Rift Arcanist (Hovering Ranged Spellcaster).
## Levitates above hazards, kites backward if crowded, maintains spellcasting distance,
## and fires aimed ShadowOrbProjectiles that players can dodge, guard, or Parry-reflect.

const ORB_SCENE: PackedScene = preload("res://scenes/combat/shadow_orb_projectile.tscn")

@export var projectile_speed: float = 290.0

var _hover_phase: float = 0.0
var _fired_this_cast: bool = false


func _on_enemy_ready() -> void:
	hovers = true
	_configure_mode_physics()


func _tick_engage(target: PlayerCharacter, dist: float, delta: float) -> void:
	_hover_phase += delta * 2.8
	ai_state = AIState.CHASE
	_face_toward(target.global_position)

	var toward: Vector2 = (target.global_position - global_position).normalized()
	var move_vec: Vector2 = Vector2.ZERO

	if dist < stats.preferred_min_range:
		# Kite smoothly backward while staying inside leash radius
		if global_position.distance_to(_spawn_position) < stats.leash_range * 0.72:
			move_vec = -toward * _get_effective_move_speed() * 0.85
	elif dist > stats.attack_range * 0.88:
		move_vec = toward * _get_effective_move_speed()
	else:
		# Gentle lateral arcane weave
		var perp: Vector2 = Vector2(-toward.y, toward.x)
		move_vec = perp * sin(_hover_phase) * (_get_effective_move_speed() * 0.42)

	if gameplay_mode == GameState.GameplayMode.SIDE_SCROLL:
		move_vec.y = (_spawn_position.y - global_position.y) * 2.2 + sin(_hover_phase) * 22.0

	_apply_desired_move(move_vec)
	_play_anim(&"move")

	if dist <= stats.attack_range and _cooldown_timer <= 0.0:
		_begin_telegraph()


func _begin_attack(target: PlayerCharacter) -> void:
	super._begin_attack(target)
	_fired_this_cast = false
	if target != null:
		spawn_orb_toward(target.global_position + Vector2(0.0, -30.0))
		_fired_this_cast = true


func _tick_attack(_target: PlayerCharacter, _delta: float) -> void:
	_apply_desired_move(Vector2.ZERO)


func spawn_orb_toward(aim_world_pos: Vector2) -> ShadowOrbProjectile:
	var host: Node = get_parent()
	if host == null or ORB_SCENE == null:
		return null
	var origin: Vector2 = global_position + Vector2(0.0, -36.0) + facing_vector.normalized() * 22.0
	var dir: Vector2 = (aim_world_pos - origin).normalized()
	if dir.length_squared() < 0.001:
		dir = facing_vector
	var orb: ShadowOrbProjectile = ORB_SCENE.instantiate() as ShadowOrbProjectile
	host.add_child(orb)
	orb.launch(origin, dir, _get_effective_attack_damage(), projectile_speed, self)
	return orb
