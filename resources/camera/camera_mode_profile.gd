class_name CameraModeProfile
extends Resource
## Data-driven configuration Resource defining one camera mode's full behavior
## (Side-Scrolling platformer framing vs. Top-Down 8-direction exploration framing).

@export var mode_id: int = 0
@export var mode_key: String = "side_scroll"

@export var base_zoom: Vector2 = Vector2(1.15, 1.15)
@export var min_zoom_scale: float = 0.88
@export var max_zoom_scale: float = 1.12
@export var speed_zoom_out: float = 0.06
@export var block_zoom_in: float = 0.05

@export var base_offset: Vector2 = Vector2(0.0, -46.0)
@export var lookahead_distance: Vector2 = Vector2(92.0, 0.0)
@export var idle_lookahead_ratio: float = 0.5
@export var fall_peek_offset_y: float = 62.0
@export var fall_peek_speed_threshold: float = 340.0

@export var position_smoothing_speed: float = 7.8
@export var offset_smoothing_speed: float = 6.2
@export var zoom_smoothing_speed: float = 5.5

@export var drag_horizontal_enabled: bool = false
@export var drag_vertical_enabled: bool = true
@export var drag_left_margin: float = 0.1
@export var drag_right_margin: float = 0.1
@export var drag_top_margin: float = 0.24
@export var drag_bottom_margin: float = 0.15


func get_clamped_zoom(multiplier: float) -> Vector2:
	var clamped_mult: float = clampf(multiplier, min_zoom_scale, max_zoom_scale)
	return base_zoom * clamped_mult
