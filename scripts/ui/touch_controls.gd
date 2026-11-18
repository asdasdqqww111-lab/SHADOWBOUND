extends CanvasLayer
## Responsive Android multi-touch controls overlay.
## Left thumb: VirtualJoystick (horizontal or 8-way).
## Right thumb: Attack, Jump/Rift, Dodge, and Mode-Switch buttons with independent touch indices.

signal mode_switch_pressed

@onready var root_control: Control = $Root
@onready var joystick: VirtualJoystick = $Root/VirtualJoystick
@onready var btn_attack: Control = $Root/ActionCluster/AttackButton
@onready var btn_jump: Control = $Root/ActionCluster/JumpButton
@onready var btn_dodge: Control = $Root/ActionCluster/DodgeButton
@onready var btn_mode: Control = $Root/ActionCluster/ModeButton
@onready var lbl_attack: Label = $Root/ActionCluster/AttackButton/Label
@onready var lbl_jump: Label = $Root/ActionCluster/JumpButton/Label
@onready var lbl_dodge: Label = $Root/ActionCluster/DodgeButton/Label
@onready var lbl_mode: Label = $Root/ActionCluster/ModeButton/Label

var _player: CharacterBody2D = null
var _button_touches: Dictionary = {}
var _current_mode: int = 0
var _near_rift: bool = false


func _ready() -> void:
	# Keep ergonomic left-stick / right-buttons layout regardless of text RTL locale.
	root_control.layout_direction = Control.LAYOUT_DIRECTION_LTR
	joystick.vector_changed.connect(_on_joystick_vector_changed)
	GameState.settings_changed.connect(_update_visibility)
	GameState.pause_state_changed.connect(_on_pause_changed)
	LocalizationManager.locale_changed.connect(_on_locale_changed)
	_refresh_labels()
	_update_visibility()


func bind_player(player_node: CharacterBody2D) -> void:
	_player = player_node


func refresh_for_mode(mode_value: int, near_rift: bool) -> void:
	_current_mode = mode_value
	_near_rift = near_rift
	_refresh_labels()
	if btn_jump != null:
		var is_td: bool = _current_mode == GameState.GameplayMode.TOP_DOWN
		btn_jump.modulate.a = 1.0 if (not is_td or _near_rift) else 0.5


func _input(event: InputEvent) -> void:
	if not root_control.visible or get_tree().paused:
		return
	if not (event is InputEventScreenTouch):
		return

	var touch: InputEventScreenTouch = event
	if touch.pressed:
		var hit_name: String = _find_hit_button(touch.position)
		if hit_name != "":
			_button_touches[touch.index] = hit_name
			_set_button_visual(hit_name, true)
			_dispatch_button_event(hit_name, true)
			get_viewport().set_input_as_handled()
	elif _button_touches.has(touch.index):
		var released_name: String = str(_button_touches[touch.index])
		_button_touches.erase(touch.index)
		_set_button_visual(released_name, false)
		_dispatch_button_event(released_name, false)
		get_viewport().set_input_as_handled()


func _find_hit_button(screen_pos: Vector2) -> String:
	var candidates: Array[Array] = [
		["attack", btn_attack],
		["jump", btn_jump],
		["dodge", btn_dodge],
		["mode", btn_mode],
	]
	for pair: Array in candidates:
		var ctrl: Control = pair[1] as Control
		if ctrl != null and ctrl.visible and ctrl.get_global_rect().grow(6.0).has_point(screen_pos):
			var center: Vector2 = ctrl.get_global_rect().get_center()
			var radius: float = maxf(ctrl.size.x, ctrl.size.y) * 0.56
			if screen_pos.distance_to(center) <= radius:
				return str(pair[0])
	return ""


func _dispatch_button_event(btn_name: String, pressed: bool) -> void:
	match btn_name:
		"attack":
			if pressed and _player != null and _player.has_method("trigger_touch_attack"):
				_player.call("trigger_touch_attack")
		"jump":
			if _player != null and _player.has_method("trigger_touch_jump"):
				_player.call("trigger_touch_jump", pressed)
		"dodge":
			if pressed and _player != null and _player.has_method("trigger_touch_dodge"):
				_player.call("trigger_touch_dodge")
		"mode":
			if pressed:
				mode_switch_pressed.emit()


func _set_button_visual(btn_name: String, pressed: bool) -> void:
	var ctrl: Control = _get_button_control(btn_name)
	if ctrl == null:
		return
	ctrl.scale = Vector2(0.91, 0.91) if pressed else Vector2.ONE
	if btn_name != "jump":
		ctrl.modulate = Color(1.25, 1.25, 1.35, 1.0) if pressed else Color(1.0, 1.0, 1.0, 0.92)


func _get_button_control(btn_name: String) -> Control:
	match btn_name:
		"attack":
			return btn_attack
		"jump":
			return btn_jump
		"dodge":
			return btn_dodge
		"mode":
			return btn_mode
	return null


func _on_joystick_vector_changed(vec: Vector2) -> void:
	if _player != null and _player.has_method("set_touch_move_vector"):
		_player.call("set_touch_move_vector", vec)


func _on_pause_changed(is_paused: bool) -> void:
	if is_paused:
		release_all_inputs()
	_update_visibility()


func _update_visibility() -> void:
	var should_show: bool = GameState.should_show_touch_controls() and not get_tree().paused
	root_control.visible = should_show
	if not should_show:
		release_all_inputs()


func release_all_inputs() -> void:
	joystick.release_stick()
	for idx: Variant in _button_touches.keys():
		var bname: String = str(_button_touches[idx])
		_set_button_visual(bname, false)
	_button_touches.clear()
	if _player != null and _player.has_method("trigger_touch_jump"):
		_player.call("trigger_touch_jump", false)


func _on_locale_changed(_loc: String) -> void:
	_refresh_labels()


func _refresh_labels() -> void:
	if lbl_attack == null:
		return
	lbl_attack.text = LocalizationManager.translate_key("touch.attack")
	var show_rift_key: bool = (_current_mode == GameState.GameplayMode.TOP_DOWN) or _near_rift
	lbl_jump.text = LocalizationManager.translate_key("touch.interact" if show_rift_key else "touch.jump")
	lbl_dodge.text = LocalizationManager.translate_key("touch.dodge")
	lbl_mode.text = LocalizationManager.translate_key("touch.mode")
