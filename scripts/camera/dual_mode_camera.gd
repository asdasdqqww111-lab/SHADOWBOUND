class_name DualModeCamera
extends Camera2D
## Unified Camera2D supporting seamless transitions between Side-Scrolling platformer
## framing (horizontal lookahead + raised horizon) and Top-Down 8-direction exploration.

var side_scroll_zoom: float = 1.15
var top_down_zoom: float = 1.1
var side_scroll_lookahead_x: float = 85.0
var side_scroll_offset_y: float = -44.0
var top_down_lookahead: float = 36.0
var base_smoothing_speed: float = 7.5
var zoom_transition_speed: float = 6.0

var _camera_mode: int = 0
var _target_zoom: Vector2 = Vector2(1.15, 1.15)
var _target_offset: Vector2 = Vector2(0.0, -44.0)
var _trauma: float = 0.0
var _shake_phase: float = 0.0


func _ready() -> void:
	enabled = true
	position_smoothing_enabled = GameState.camera_smoothing_enabled
	position_smoothing_speed = base_smoothing_speed
	GameState.settings_changed.connect(_on_settings_changed)


func apply_config(cfg: Dictionary) -> void:
	if cfg.is_empty():
		return
	side_scroll_zoom = float(cfg.get("side_scroll_zoom", side_scroll_zoom))
	top_down_zoom = float(cfg.get("top_down_zoom", top_down_zoom))
	side_scroll_lookahead_x = float(cfg.get("side_scroll_lookahead_x", side_scroll_lookahead_x))
	side_scroll_offset_y = float(cfg.get("side_scroll_offset_y", side_scroll_offset_y))
	top_down_lookahead = float(cfg.get("top_down_lookahead", top_down_lookahead))
	base_smoothing_speed = float(cfg.get("position_smoothing_speed", base_smoothing_speed))
	zoom_transition_speed = float(cfg.get("zoom_transition_speed", zoom_transition_speed))
	position_smoothing_speed = base_smoothing_speed


func set_camera_mode(new_mode: int) -> void:
	_camera_mode = new_mode
	if _camera_mode == GameState.GameplayMode.TOP_DOWN:
		_target_zoom = Vector2(top_down_zoom, top_down_zoom)
		_target_offset = Vector2.ZERO
		drag_horizontal_enabled = false
		drag_vertical_enabled = false
	else:
		_target_zoom = Vector2(side_scroll_zoom, side_scroll_zoom)
		_target_offset = Vector2(0.0, side_scroll_offset_y)
		drag_horizontal_enabled = false
		drag_vertical_enabled = true
		drag_top_margin = 0.24
		drag_bottom_margin = 0.16


func apply_world_limits(bounds: Rect2i) -> void:
	limit_left = bounds.position.x
	limit_top = bounds.position.y
	limit_right = bounds.position.x + bounds.size.x
	limit_bottom = bounds.position.y + bounds.size.y


func snap_immediately() -> void:
	zoom = _target_zoom
	offset = _target_offset
	reset_smoothing()


func update_focus(player_velocity: Vector2, facing_vec: Vector2, delta: float) -> void:
	if _camera_mode == GameState.GameplayMode.TOP_DOWN:
		var vel_factor: float = clampf(player_velocity.length() / 220.0, 0.0, 1.0)
		_target_offset = facing_vec.normalized() * (top_down_lookahead * vel_factor)
	else:
		var dir_x: float = signf(facing_vec.x) if absf(facing_vec.x) > 0.1 else 1.0
		var move_bias: float = 1.0 if absf(player_velocity.x) > 35.0 else 0.55
		_target_offset = Vector2(dir_x * side_scroll_lookahead_x * move_bias, side_scroll_offset_y)

	var shake_vec: Vector2 = Vector2.ZERO
	if _trauma > 0.0:
		_trauma = maxf(0.0, _trauma - delta * 2.4)
		_shake_phase += delta * 52.0
		var mag: float = _trauma * _trauma * 9.0
		shake_vec = Vector2(cos(_shake_phase) * mag, sin(_shake_phase * 1.37) * mag)

	var follow_rate: float = clampf(delta * 6.0, 0.0, 1.0)
	var base_off: Vector2 = offset.lerp(_target_offset, follow_rate)
	offset = base_off + shake_vec
	zoom = zoom.lerp(_target_zoom, clampf(delta * zoom_transition_speed, 0.0, 1.0))


func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


func get_camera_mode() -> int:
	return _camera_mode


func _on_settings_changed() -> void:
	position_smoothing_enabled = GameState.camera_smoothing_enabled
