class_name CameraZoneTrigger
extends Area2D
## Contextual camera framing volume for vistas, shrines, portals, and future boss rooms.
## Automatically pushes/pops zoom overrides and soft focal-point attraction on DualModeCamera.

@export var zone_id: String = "vista"
@export var camera_priority: int = 1
@export var zoom_scale_override: float = 0.88
@export var use_focal_pull: bool = false
@export var focal_pull_weight: float = 0.3
@export var focal_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func get_focal_world_position() -> Vector2:
	return global_position + focal_offset


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	var cam: DualModeCamera = body.get_node_or_null("DualModeCamera") as DualModeCamera
	if cam != null:
		cam.enter_camera_zone(self)


func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	var cam: DualModeCamera = body.get_node_or_null("DualModeCamera") as DualModeCamera
	if cam != null:
		cam.exit_camera_zone(self)
