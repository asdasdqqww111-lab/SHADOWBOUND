class_name FloatingCombatText
extends Node2D
## Lightweight floating combat damage & status popup (CRIT, PARRY, BLOCK, DODGE).
## Uses the bundled Cairo Arabic/Latin font for crisp bilingual RTL/LTR rendering.

const FONT_PATH: String = "res://assets/fonts/Cairo-VariableFont.ttf"
const LIFETIME: float = 0.72
const RISE_SPEED: float = 48.0

var _elapsed: float = 0.0
var _drift_x: float = 0.0
var _label: Label = null


static func spawn(
	parent_node: Node,
	world_pos: Vector2,
	message: String,
	tint: Color = Color(1.0, 0.94, 0.82, 1.0),
	font_px: int = 16
) -> FloatingCombatText:
	if parent_node == null or not parent_node.is_inside_tree():
		return null
	var popup: FloatingCombatText = FloatingCombatText.new()
	popup.global_position = world_pos
	popup.z_index = 45
	popup._setup_label(message, tint, font_px)
	parent_node.add_child(popup)
	return popup


func _setup_label(message: String, tint: Color, font_px: int) -> void:
	_label = Label.new()
	_label.text = message
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.position = Vector2(-90.0, -14.0)
	_label.custom_minimum_size = Vector2(180.0, 28.0)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font_res: Font = load(FONT_PATH) as Font
	if font_res != null:
		_label.add_theme_font_override("font", font_res)
	_label.add_theme_font_size_override("font_size", font_px)
	_label.add_theme_color_override("font_color", tint)
	_label.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.1, 0.95))
	_label.add_theme_constant_override("outline_size", 5)
	add_child(_label)


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= LIFETIME:
		queue_free()
		return
	var t: float = _elapsed / LIFETIME
	position.y -= RISE_SPEED * (1.0 - t * 0.45) * delta
	position.x += _drift_x * delta
	if t > 0.55:
		modulate.a = clampf(1.0 - (t - 0.55) / 0.45, 0.0, 1.0)
