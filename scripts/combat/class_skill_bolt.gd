class_name ClassSkillBolt
extends Area2D
## Friendly arcane bolt. Sweeps world collision each step to avoid tunnelling through thin walls.

var damage: float = 20.0
var direction: Vector2 = Vector2.RIGHT
var gameplay_mode: int = 0
var _age: float = 0.0
var _spent: bool = false


func _ready() -> void:
	add_to_group("projectiles")
	collision_layer = 32
	collision_mask = 16
	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = 13
	shape.shape = circle
	add_child(shape)
	area_entered.connect(_on_area_entered)
	queue_redraw()


func _physics_process(delta: float) -> void:
	_age += delta
	if _age > 2.0:
		queue_free()
		return
	var destination: Vector2 = global_position + direction * 440.0 * delta
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
		global_position, destination, 2 if gameplay_mode == 1 else 1
	)
	if not get_world_2d().direct_space_state.intersect_ray(query).is_empty():
		queue_free()
		return
	global_position = destination


func _on_area_entered(area: Area2D) -> void:
	if _spent or not area.is_in_group("enemy_hurtbox"):
		return
	var enemy: EnemyBase = area.get_parent() as EnemyBase
	if enemy == null or enemy.gameplay_mode != gameplay_mode or enemy.is_defeated():
		return
	_spent = true
	enemy.receive_player_strike({"damage": damage, "knockback": 130,
		"hit_direction": direction, "attacker_position": global_position - direction * 20})
	queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 16, Color(0.4, 0.3, 1, 0.3))
	draw_circle(Vector2.ZERO, 9, Color(0.4, 0.9, 1, 0.95))
	draw_circle(Vector2.ZERO, 4, Color.WHITE)
