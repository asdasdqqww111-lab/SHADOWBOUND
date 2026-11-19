class_name SpiritCompanion
extends Node2D
## Timed friendly spirit: follows the player and attacks only enemies in the current gameplay mode.

var player: PlayerCharacter = null
var damage: float = 12.0
var duration: float = 6.0
var _age: float = 0.0
var _pulse: float = 0.0
var _beam_end: Vector2 = Vector2.ZERO
var _beam_timer: float = 0.0


func _ready() -> void:
	add_to_group("companions")
	z_index = 15


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player) or player.is_defeated() or is_queued_for_deletion():
		queue_free()
		return
	_age += delta
	_beam_timer = maxf(0.0, _beam_timer - delta)
	if _age >= duration or player.profile.class_id != "summoner":
		queue_free()
		return
	global_position = player.global_position + Vector2(-36, -84 + sin(_age * 4) * 7)
	_pulse -= delta
	if _pulse <= 0:
		_pulse = 0.85
		attack_nearest()
	queue_redraw()


func attack_nearest() -> bool:
	if not is_instance_valid(player) or player.is_defeated():
		return false
	var nearest: EnemyBase = null
	var best: float = 360.0
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		if node is EnemyBase:
			var enemy: EnemyBase = node as EnemyBase
			var dist: float = player.global_position.distance_to(enemy.global_position)
			if enemy.gameplay_mode == player.active_mode and not enemy.is_defeated() and dist < best:
				best = dist
				nearest = enemy
	if nearest == null:
		return false
	# Respect occluding world geometry, even though the spirit's attack is a beam.
	var from: Vector2 = player.global_position + Vector2(0, -20)
	var to: Vector2 = nearest.global_position + Vector2(0, -20)
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
		from, to, 2 if player.active_mode == 1 else 1
	)
	if not get_world_2d().direct_space_state.intersect_ray(query).is_empty():
		return false
	nearest.receive_player_strike({"damage": damage, "attacker_position": player.global_position,
		"hit_direction": (nearest.global_position - player.global_position).normalized(), "knockback": 50})
	_beam_end = to
	_beam_timer = 0.16
	return true


func _draw() -> void:
	draw_circle(Vector2.ZERO, 19, Color(0.3, 0.6, 1, 0.18))
	draw_arc(Vector2.ZERO, 13, 0, TAU, 24, Color(0.5, 1, 1), 2)
	draw_circle(Vector2(-4, -2), 2, Color.WHITE)
	draw_circle(Vector2(4, -2), 2, Color.WHITE)
	if _beam_timer > 0:
		draw_line(Vector2.ZERO, to_local(_beam_end), Color(0.5, 0.9, 1, 0.8), 2)
