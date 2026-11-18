extends Node2D
## Twilight Sanctum — Phase 2 unified dual-mode fantasy environment.
## Coordinates separate Side-Scrolling (platforms, one-way bridge, wall-jump chimney, vista)
## and Top-Down (8-direction courtyard, alcoves, lore runestones, altar camera zone) areas
## while keeping one unified PlayerCharacter, shared PlayerProfile, and DualModeCamera.

const SIDESCROLL_BOUNDS: Rect2i = Rect2i(-160, -640, 2820, 1020)
const TOPDOWN_BOUNDS: Rect2i = Rect2i(-80, 1480, 1760, 1280)

@onready var parallax_bg: ParallaxBackground = $ParallaxBackground
@onready var side_scroll_zone: Node2D = $SideScrollZone
@onready var top_down_zone: Node2D = $TopDownZone
@onready var ss_spawn: Marker2D = $SideScrollZone/SideScrollSpawn
@onready var td_spawn: Marker2D = $TopDownZone/TopDownSpawn
@onready var player: PlayerCharacter = $Player
@onready var hud: CanvasLayer = $GameHUD
@onready var touch_controls: CanvasLayer = $TouchControls
@onready var transition_layer: CanvasLayer = $TransitionLayer
@onready var fade_rect: ColorRect = $TransitionLayer/FadeRect

var _saved_ss_pos: Vector2 = Vector2.ZERO
var _saved_td_pos: Vector2 = Vector2.ZERO
var _saved_ss_facing: Vector2 = Vector2.RIGHT
var _saved_td_facing: Vector2 = Vector2.DOWN
var _has_ss_pos: bool = false
var _has_td_pos: bool = false
var _abyss_y: float = 380.0
var _mode_switch_cooldown: float = 0.28
var _switch_cooldown_timer: float = 0.0
var _active_gate: Area2D = null
var _active_lore_stone: Area2D = null
var _fade_tween: Tween = null


func _ready() -> void:
	GameState.is_in_gameplay = true
	var shared_cfg: Dictionary = GameState.get_config_section("shared")
	var cam_cfg: Dictionary = GameState.get_config_section("camera")
	_abyss_y = float(shared_cfg.get("abyss_respawn_y", _abyss_y))
	_mode_switch_cooldown = float(cam_cfg.get("mode_switch_cooldown", _mode_switch_cooldown))

	_saved_ss_pos = ss_spawn.global_position
	_saved_td_pos = td_spawn.global_position
	_has_ss_pos = true
	_has_td_pos = true

	if touch_controls.has_method("bind_player"):
		touch_controls.call("bind_player", player)
	if touch_controls.has_signal("mode_switch_pressed"):
		touch_controls.connect("mode_switch_pressed", _on_request_mode_toggle)

	if hud.has_signal("mode_switch_requested"):
		hud.connect("mode_switch_requested", _on_request_mode_toggle)
	if hud.has_signal("respawn_requested"):
		hud.connect("respawn_requested", respawn_in_current_zone)

	player.interact_requested.connect(_on_player_interact)
	player.slash_landed.connect(_on_player_slash_landed)
	player.movement_state_updated.connect(_on_player_movement_state_updated)
	player.camera.vista_state_changed.connect(_on_camera_vista_changed)

	for gate_node: Node in get_tree().get_nodes_in_group("rift_gates"):
		if gate_node is Area2D and gate_node.has_signal("player_proximity_changed"):
			gate_node.connect("player_proximity_changed", _on_rift_proximity_changed)

	for lore_node: Node in get_tree().get_nodes_in_group("lore_stones"):
		if lore_node is Area2D and lore_node.has_signal("lore_proximity_changed"):
			lore_node.connect("lore_proximity_changed", _on_lore_proximity_changed)

	GameState.gameplay_mode_changed.connect(_on_gameplay_mode_changed)
	_apply_zone_for_mode(GameState.current_mode, false)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		GameState.toggle_pause()
		get_viewport().set_input_as_handled()
	elif not get_tree().paused and event.is_action_pressed("switch_mode"):
		_on_request_mode_toggle()
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if _switch_cooldown_timer > 0.0:
		_switch_cooldown_timer = maxf(0.0, _switch_cooldown_timer - delta)
	if GameState.current_mode == GameState.GameplayMode.SIDE_SCROLL:
		if player.global_position.y > _abyss_y:
			respawn_in_current_zone()


func _on_request_mode_toggle() -> void:
	if _switch_cooldown_timer > 0.0:
		return
	_switch_cooldown_timer = _mode_switch_cooldown
	_store_current_zone_state()
	GameState.toggle_gameplay_mode()


func _on_gameplay_mode_changed(new_mode: int) -> void:
	_apply_zone_for_mode(new_mode, true)


func _store_current_zone_state() -> void:
	if player.active_mode == GameState.GameplayMode.SIDE_SCROLL:
		if player.global_position.y < _abyss_y - 60.0:
			_saved_ss_pos = player.global_position
			_saved_ss_facing = player.get_active_facing_vector()
			_has_ss_pos = true
	else:
		_saved_td_pos = player.global_position
		_saved_td_facing = player.get_active_facing_vector()
		_has_td_pos = true


func _apply_zone_for_mode(mode_value: int, play_flash: bool) -> void:
	var is_top_down: bool = mode_value == GameState.GameplayMode.TOP_DOWN
	_active_gate = null
	_active_lore_stone = null

	parallax_bg.visible = not is_top_down
	side_scroll_zone.visible = not is_top_down
	top_down_zone.visible = is_top_down
	side_scroll_zone.process_mode = (
		Node.PROCESS_MODE_DISABLED if is_top_down else Node.PROCESS_MODE_INHERIT
	)
	top_down_zone.process_mode = (
		Node.PROCESS_MODE_INHERIT if is_top_down else Node.PROCESS_MODE_DISABLED
	)

	if is_top_down:
		player.global_position = _saved_td_pos if _has_td_pos else td_spawn.global_position
		player.set_mode(GameState.GameplayMode.TOP_DOWN, true)
		player.restore_facing_vector(_saved_td_facing)
		player.camera.apply_world_limits(TOPDOWN_BOUNDS)
	else:
		player.global_position = _saved_ss_pos if _has_ss_pos else ss_spawn.global_position
		player.set_mode(GameState.GameplayMode.SIDE_SCROLL, true)
		player.restore_facing_vector(_saved_ss_facing)
		player.camera.apply_world_limits(SIDESCROLL_BOUNDS)

	player.camera.snap_immediately()

	if hud.has_method("refresh_mode_display"):
		hud.call("refresh_mode_display", mode_value)
	if touch_controls.has_method("refresh_for_mode"):
		touch_controls.call("refresh_for_mode", mode_value, false)

	if play_flash:
		_play_rift_flash()


func respawn_in_current_zone() -> void:
	player.velocity = Vector2.ZERO
	if GameState.current_mode == GameState.GameplayMode.TOP_DOWN:
		_saved_td_pos = td_spawn.global_position
		player.global_position = td_spawn.global_position
	else:
		_saved_ss_pos = ss_spawn.global_position
		player.global_position = ss_spawn.global_position
	player.camera.snap_immediately()


func _on_rift_proximity_changed(inside: bool, gate: Area2D) -> void:
	if inside:
		_active_gate = gate
	elif _active_gate == gate:
		_active_gate = null
	_sync_proximity_ui()


func _on_lore_proximity_changed(inside: bool, stone: Area2D) -> void:
	if inside:
		_active_lore_stone = stone
	elif _active_lore_stone == stone:
		_active_lore_stone = null
	_sync_proximity_ui()


func _sync_proximity_ui() -> void:
	var near_rift: bool = _active_gate != null
	var near_lore: bool = _active_lore_stone != null
	if hud.has_method("set_proximity_hint"):
		var kind: String = "rift" if near_rift else ("lore" if near_lore else "")
		hud.call("set_proximity_hint", kind)
	if touch_controls.has_method("refresh_for_mode"):
		touch_controls.call("refresh_for_mode", GameState.current_mode, near_rift or near_lore)


func _on_player_interact() -> void:
	if _active_gate != null:
		_on_request_mode_toggle()
	elif _active_lore_stone != null:
		if _active_lore_stone.has_method("pulse_highlight"):
			_active_lore_stone.call("pulse_highlight")
		var key: String = str(_active_lore_stone.get("lore_key"))
		if hud.has_method("show_lore_feedback"):
			hud.call("show_lore_feedback", key)


func _on_player_slash_landed(_target: Node, total_hits: int) -> void:
	if hud.has_method("show_combo_feedback"):
		hud.call("show_combo_feedback", total_hits)


func _on_player_movement_state_updated(state_key: String, compass_dir: String) -> void:
	if hud.has_method("update_movement_state"):
		hud.call("update_movement_state", state_key, compass_dir)


func _on_camera_vista_changed(is_active: bool, _zone_id: String) -> void:
	if hud.has_method("set_vista_active"):
		hud.call("set_vista_active", is_active)


func _play_rift_flash() -> void:
	if fade_rect == null:
		return
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	fade_rect.color = Color(0.45, 0.28, 0.92, 0.42)
	_fade_tween = create_tween()
	_fade_tween.tween_property(fade_rect, "color:a", 0.0, 0.26).set_trans(
		Tween.TRANS_QUAD
	).set_ease(Tween.EASE_OUT)
