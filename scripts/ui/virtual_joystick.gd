class_name VirtualJoystick
extends Control
## Multi-touch Android virtual joystick supporting both Side-Scrolling horizontal
## and Top-Down 8-direction analog input with configurable deadzone and radius.

signal vector_changed(output_vector: Vector2)

@export var max_radius: float = 68.0
@export var deadzone: float = 0.14

@onready var base_rect: TextureRect = $Base
@onready var knob_rect: TextureRect = $Knob

var _active_touch_index: int = -1
var _output_vector: Vector2 = Vector2.ZERO


func _ready() -> void:
	_center_knob()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_VISIBILITY_CHANGED:
		if not is_visible_in_tree():
			release_stick()
		else:
			_center_knob()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or get_tree().paused:
		return

	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		if touch.pressed:
			if _active_touch_index == -1 and _is_point_in_zone(touch.position):
				_active_touch_index = touch.index
				_update_from_screen_pos(touch.position)
				modulate.a = 1.0
				get_viewport().set_input_as_handled()
		elif touch.index == _active_touch_index:
			release_stick()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event
		if drag.index == _active_touch_index:
			_update_from_screen_pos(drag.position)
			get_viewport().set_input_as_handled()


func _is_point_in_zone(screen_pos: Vector2) -> bool:
	return get_global_rect().grow(18.0).has_point(screen_pos)


func _update_from_screen_pos(screen_pos: Vector2) -> void:
	var center: Vector2 = get_global_rect().get_center()
	var offset_vec: Vector2 = screen_pos - center
	var clamped: Vector2 = offset_vec.limit_length(max_radius)
	_position_knob_offset(clamped)

	var raw_strength: float = clamped.length() / maxf(1.0, max_radius)
	if raw_strength < deadzone:
		_set_output(Vector2.ZERO)
	else:
		var remapped: float = clampf((raw_strength - deadzone) / (1.0 - deadzone), 0.0, 1.0)
		_set_output(clamped.normalized() * remapped)


func _position_knob_offset(local_offset: Vector2) -> void:
	if knob_rect == null:
		return
	var local_center: Vector2 = size * 0.5
	knob_rect.position = local_center + local_offset - (knob_rect.size * 0.5)


func _center_knob() -> void:
	_position_knob_offset(Vector2.ZERO)
	modulate.a = 0.86


func _set_output(new_vec: Vector2) -> void:
	if _output_vector.is_equal_approx(new_vec):
		return
	_output_vector = new_vec
	vector_changed.emit(_output_vector)


func release_stick() -> void:
	_active_touch_index = -1
	_center_knob()
	_set_output(Vector2.ZERO)


func get_output_vector() -> Vector2:
	return _output_vector


func simulate_drag_offset(offset_vec: Vector2) -> void:
	var center: Vector2 = get_global_rect().get_center()
	_update_from_screen_pos(center + offset_vec)
