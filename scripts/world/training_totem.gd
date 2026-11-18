extends Area2D
## Interactive fantasy training totem that responds to sword slashes in both
## Side-Scrolling and Top-Down camera modes with hit-flash and recoil wobble.

signal totem_struck(hit_count: int)

@onready var sprite: Sprite2D = $Sprite2D

var hit_count: int = 0
var _recoil_tween: Tween = null


func receive_slash(direction: Vector2) -> void:
	hit_count += 1
	if sprite != null:
		var tilt_sign: float = 1.0 if direction.x >= 0.0 else -1.0
		if _recoil_tween != null and _recoil_tween.is_valid():
			_recoil_tween.kill()
		sprite.modulate = Color(1.8, 2.1, 2.4, 1.0)
		sprite.rotation = 0.2 * tilt_sign
		sprite.scale = Vector2(1.12, 0.9)
		_recoil_tween = create_tween()
		_recoil_tween.set_parallel(true)
		_recoil_tween.tween_property(sprite, "modulate", Color.WHITE, 0.22)
		_recoil_tween.tween_property(sprite, "rotation", 0.0, 0.26).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		_recoil_tween.tween_property(sprite, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	totem_struck.emit(hit_count)
