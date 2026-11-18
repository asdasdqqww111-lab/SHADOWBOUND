class_name DualModeCamera
extends Camera2D
## Modular Phase 2 camera controller managing separate CameraModeProfile resources
## for Side-Scrolling (platform horizon, horizontal lookahead, fast-fall peek, vertical deadzone)
## and Top-Down (omnidirectional 8-way lookahead, sprint sightline zoom, POI landmark pull),
## plus priority-stacked CameraZoneTrigger vista volumes and trauma screen-shake.

signal camera_mode_changed(new_mode: int, profile_key: String)
signal vista_state_changed(is_active: bool, zone_id: String)

const DEFAULT_SS_PROFILE_PATH: String = "res://resources/camera/side_scroll_camera_profile.tres"
const DEFAULT_TD_PROFILE_PATH: String = "res://resources/camera/top_down_camera_profile.tres"

@export var side_scroll_profile: CameraModeProfile = null
@export var top_down_profile: CameraModeProfile = null

var poi_max_offset: float = 120.0
var _user_zoom_multiplier: float = 1.0

var _camera_mode: int = 0
var _active_profile: CameraModeProfile = null
var _target_zoom: Vector2 = Vector2(1.14, 1.14)
var _target_offset: Vector2 = Vector2(0.0, -48.0)
var _smoothed_offset: Vector2 = Vector2(0.0, -48.0)
var _active_zones: Array[CameraZoneTrigger] = []
var _was_in_vista: bool = false
var _trauma: float = 0.0
var _shake_phase: float = 0.0


func _ready() -> void:
	enabled = true
	_ensure_profiles()
	_user_zoom_multiplier = GameState.get_camera_zoom_multiplier()
	position_smoothing_enabled = GameState.camera_smoothing_enabled
	GameState.settings_changed.connect(_on_settings_changed)
	set_camera_mode(_camera_mode)


func _ensure_profiles() -> void:
	if side_scroll_profile == null:
		var loaded_ss: Resource = load(DEFAULT_SS_PROFILE_PATH)
		if loaded_ss is CameraModeProfile:
			side_scroll_profile = loaded_ss
		else:
			side_scroll_profile = CameraModeProfile.new()
	if top_down_profile == null:
		var loaded_td: Resource = load(DEFAULT_TD_PROFILE_PATH)
		if loaded_td is CameraModeProfile:
			top_down_profile = loaded_td
		else:
			top_down_profile = CameraModeProfile.new()
			top_down_profile.mode_id = 1
			top_down_profile.mode_key = "top_down"


func apply_config(cfg: Dictionary) -> void:
	_ensure_profiles()
	if cfg.is_empty():
		return
	poi_max_offset = float(cfg.get("poi_max_offset", poi_max_offset))
	_user_zoom_multiplier = GameState.get_camera_zoom_multiplier()


func set_camera_mode(new_mode: int) -> void:
	_ensure_profiles()
	_camera_mode = new_mode
	clear_camera_zones()

	if _camera_mode == GameState.GameplayMode.TOP_DOWN:
		_active_profile = top_down_profile
	else:
		_active_profile = side_scroll_profile

	position_smoothing_speed = _active_profile.position_smoothing_speed
	drag_horizontal_enabled = _active_profile.drag_horizontal_enabled
	drag_vertical_enabled = _active_profile.drag_vertical_enabled
	drag_left_margin = _active_profile.drag_left_margin
	drag_right_margin = _active_profile.drag_right_margin
	drag_top_margin = _active_profile.drag_top_margin
	drag_bottom_margin = _active_profile.drag_bottom_margin

	_target_zoom = _active_profile.get_clamped_zoom(1.0) * _user_zoom_multiplier
	_target_offset = _active_profile.base_offset
	camera_mode_changed.emit(_camera_mode, _active_profile.mode_key)


func apply_world_limits(bounds: Rect2i) -> void:
	limit_left = bounds.position.x
	limit_top = bounds.position.y
	limit_right = bounds.position.x + bounds.size.x
	limit_bottom = bounds.position.y + bounds.size.y


func snap_immediately() -> void:
	zoom = _target_zoom
	_smoothed_offset = _target_offset
	offset = _target_offset
	reset_smoothing()


func enter_camera_zone(zone: CameraZoneTrigger) -> void:
	if zone == null or _active_zones.has(zone):
		return
	_active_zones.append(zone)
	_emit_vista_if_changed()


func exit_camera_zone(zone: CameraZoneTrigger) -> void:
	if _active_zones.has(zone):
		_active_zones.erase(zone)
		_emit_vista_if_changed()


func clear_camera_zones() -> void:
	if _active_zones.is_empty() and not _was_in_vista:
		return
	_active_zones.clear()
	_emit_vista_if_changed()


func get_active_camera_zone() -> CameraZoneTrigger:
	var best: CameraZoneTrigger = null
	for z: CameraZoneTrigger in _active_zones:
		if is_instance_valid(z):
			if best == null or z.priority >= best.priority:
				best = z
	return best


func is_in_vista_zone() -> bool:
	return get_active_camera_zone() != null


func _emit_vista_if_changed() -> void:
	var top_zone: CameraZoneTrigger = get_active_camera_zone()
	var now_active: bool = top_zone != null
	var zid: String = top_zone.zone_id if top_zone != null else ""
	if now_active != _was_in_vista or now_active:
		_was_in_vista = now_active
		vista_state_changed.emit(now_active, zid)


func update_focus(
	player_velocity: Vector2,
	facing_vec: Vector2,
	delta: float,
	state_hints: Dictionary = {}
) -> void:
	_ensure_profiles()
	if _active_profile == null:
		set_camera_mode(_camera_mode)

	var zoom_scale: float = 1.0
	if _camera_mode == GameState.GameplayMode.TOP_DOWN:
		var td_frame: Dictionary = _compute_top_down_framing(player_velocity, facing_vec, state_hints)
		_target_offset = td_frame["offset"]
		zoom_scale = float(td_frame["zoom_scale"])
	else:
		var ss_frame: Dictionary = _compute_side_scroll_framing(player_velocity, facing_vec, state_hints)
		_target_offset = ss_frame["offset"]
		zoom_scale = float(ss_frame["zoom_scale"])

	# Layer priority camera zone override (vista zoom + landmark POI focal pull)
	var active_zone: CameraZoneTrigger = get_active_camera_zone()
	if active_zone != null:
		zoom_scale *= active_zone.zoom_scale_override
		if active_zone.use_focal_pull:
			var to_poi: Vector2 = active_zone.get_focal_world_position() - global_position
			var pull: Vector2 = (to_poi * clampf(active_zone.focal_pull_weight, 0.0, 0.85)).limit_length(
				poi_max_offset
			)
			_target_offset += pull

	_target_zoom = _active_profile.get_clamped_zoom(zoom_scale) * _user_zoom_multiplier

	var shake_vec: Vector2 = _step_shake(delta)
	var off_rate: float = clampf(delta * _active_profile.offset_smoothing_speed, 0.0, 1.0)
	var zoom_rate: float = clampf(delta * _active_profile.zoom_smoothing_speed, 0.0, 1.0)

	_smoothed_offset = _smoothed_offset.lerp(_target_offset, off_rate)
	offset = _smoothed_offset + shake_vec
	zoom = zoom.lerp(_target_zoom, zoom_rate)


func _compute_side_scroll_framing(
	vel: Vector2,
	facing_vec: Vector2,
	hints: Dictionary
) -> Dictionary:
	var p: CameraModeProfile = _active_profile
	var dir_x: float = signf(facing_vec.x) if absf(facing_vec.x) > 0.1 else 1.0
	var speed_ratio: float = clampf(absf(vel.x) / 310.0, 0.0, 1.25)
	var horiz_factor: float = lerpf(p.idle_lookahead_ratio, 1.0, clampf(speed_ratio, 0.0, 1.0))
	var look_x: float = dir_x * p.lookahead_distance.x * horiz_factor

	# Smoothly peek below when descending rapidly so lower landing ledges stay visible
	var look_y: float = p.base_offset.y
	if vel.y > p.fall_peek_speed_threshold:
		var fall_t: float = clampf((vel.y - p.fall_peek_speed_threshold) / 420.0, 0.0, 1.0)
		look_y += p.fall_peek_offset_y * fall_t

	var z_scale: float = 1.0
	if bool(hints.get("blocking", false)):
		z_scale += p.block_zoom_in
	elif bool(hints.get("dodging", false)) or speed_ratio > 0.92:
		z_scale -= p.speed_zoom_out * clampf(speed_ratio, 0.5, 1.0)

	return {"offset": Vector2(look_x, look_y), "zoom_scale": z_scale}


func _compute_top_down_framing(
	vel: Vector2,
	facing_vec: Vector2,
	hints: Dictionary
) -> Dictionary:
	var p: CameraModeProfile = _active_profile
	var norm_face: Vector2 = facing_vec.normalized() if facing_vec.length_squared() > 0.01 else Vector2.DOWN
	var speed_ratio: float = clampf(vel.length() / 265.0, 0.0, 1.4)
	var blend: float = lerpf(p.idle_lookahead_ratio, 1.0, clampf(speed_ratio, 0.0, 1.15))
	var dir_source: Vector2 = vel.normalized() if vel.length() > 35.0 else norm_face
	var look_vec: Vector2 = Vector2(
		dir_source.x * p.lookahead_distance.x * blend,
		dir_source.y * p.lookahead_distance.y * blend
	)

	var z_scale: float = 1.0
	if bool(hints.get("blocking", false)):
		z_scale += p.block_zoom_in
	elif bool(hints.get("sprinting", false)) or bool(hints.get("dodging", false)):
		z_scale -= p.speed_zoom_out

	return {"offset": p.base_offset + look_vec, "zoom_scale": z_scale}


func _step_shake(delta: float) -> Vector2:
	if _trauma <= 0.0:
		return Vector2.ZERO
	_trauma = maxf(0.0, _trauma - delta * 2.5)
	_shake_phase += delta * 54.0
	var mag: float = _trauma * _trauma * 9.0
	return Vector2(cos(_shake_phase) * mag, sin(_shake_phase * 1.37) * mag)


func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


func get_camera_mode() -> int:
	return _camera_mode


func get_active_profile() -> CameraModeProfile:
	return _active_profile


func get_target_offset() -> Vector2:
	return _target_offset


func get_target_zoom() -> Vector2:
	return _target_zoom


func _on_settings_changed() -> void:
	position_smoothing_enabled = GameState.camera_smoothing_enabled
	_user_zoom_multiplier = GameState.get_camera_zoom_multiplier()
