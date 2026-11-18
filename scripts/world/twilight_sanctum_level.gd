extends Node2D
## Twilight Sanctum — Phase 1 unified playable fantasy environment.
## Hosts both the Side-Scrolling Cliffside Ruins and the Top-Down Sanctum Courtyard,
## coordinating seamless camera/mode transitions while keeping one shared Player instance.

const SIDESCROLL_BOUNDS: Rect2i = Rect2i(-160, -560, 2760, 940)
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
var _has_ss_pos: bool = false
var _has_td_pos: bool = false
var _abyss_y: float = 380.0
var _active_gate: Area2D = null
var _fade_tween: Tween = null


func _ready() -> void:
	GameState.is_in_gameplay = true
	var shared_cfg: Dictionary = GameState.get_config_section("shared")
	_abyss_y = float(shared_cfg.get("abyss_respawn_y", _abyss_y))

	_saved_ss_pos = ss_spawn.global_position
	_saved_td_pos = td_spawn.global_position
	_has_ss_pos = true
	_has_td_pos = true

	# Bind touch controls to unified player + mode switch
	if touch_controls.has_method("bind_player"):
		touch_controls.call("bind_player", player)
	if touch_controls.has_signal("mode_switch_pressed"):
		touch_controls.connect("mode_switch_pressed", _on_request_mode_toggle)

	# Bind HUD requests
	if hud.has_signal("mode_switch_requested"):
		hud.connect("mode_switch_requested", _on_request_mode_toggle)
	if hud.has_signal("respawn_requested"):
		hud.connect("respawn_requested", respawn_in_current_zone)

	# Bind player interactions and feedback
	player.connect("interact_requested", _on_player_interact)
	player.connect("slash_landed", _on_player_slash_landed)

	# Bind all Shadow Rift portals in both zones
	for gate_node: Node in get_tree().get_nodes_in_group("rift_gates"):
		if gate_node is Area2D and gate_node.has_signal("player_proximity_changed"):
			gate_node.connect("player_proximity_changed", _on_rift_proximity_changed)

	# Listen to global mode changes
	GameState.gameplay_mode_changed.connect(_on_gameplay_mode_changed)

	# Apply initial active zone cleanly without transition flash
	_apply_zone_for_mode(GameState.current_mode, false)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		GameState.toggle_pause()
		get_viewport().set_input_as_handled()
	elif not get_tree().paused and event.is_action_pressed("switch_mode"):
		_on_request_mode_toggle()
		get_viewport().set_input_as_handled()


func _physics_process(_delta: float) -> void:
	if GameState.current_mode == GameState.GameplayMode.SIDE_SCROLL:
		if player.global_position.y > _abyss_y:
			respawn_in_current_zone()


func _on_request_mode_toggle() -> void:
	_store_current_zone_position()
	GameState.toggle_gameplay_mode()


func _on_gameplay_mode_changed(new_mode: int) -> void:
	_apply_zone_for_mode(new_mode, true)


func _store_current_zone_position() -> void:
	if player.active_mode == GameState.GameplayMode.SIDE_SCROLL:
		if player.global_position.y < _abyss_y - 60.0:
			_saved_ss_pos = player.global_position
			_has_ss_pos = true
	else:
		_saved_td_pos = player.global_position
		_has_td_pos = true


func _apply_zone_for_mode(mode_value: int, play_flash: bool) -> void:
	var is_top_down: bool = mode_value == GameState.GameplayMode.TOP_DOWN
	_active_gate = null

	parallax_bg.visible = not is_top_down
	side_scroll_zone.visible = not is_top_down
	top_down_zone.visible = is_top_down
	side_scroll_zone.process_mode = Node.PROCESS_MODE_DISABLED if is_top_down else Node.PROCESS_MODE_INHERIT
	top_down_zone.process_mode = Node.PROCESS_MODE_INHERIT if is_top_down else Node.PROCESS_MODE_DISABLED

	if is_top_down:
		player.global_position = _saved_td_pos if _has_td_pos else td_spawn.global_position
		player.set_mode(GameState.GameplayMode.TOP_DOWN, true)
		player.camera.apply_world_limits(TOPDOWN_BOUNDS)
	else:
		player.global_position = _saved_ss_pos if _has_ss_pos else ss_spawn.global_position
		player.set_mode(GameState.GameplayMode.SIDE_SCROLL, true)
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

	var near_rift: bool = _active_gate != null
	if hud.has_method("set_rift_hint_active"):
		hud.call("set_rift_hint_active", near_rift)
	if touch_controls.has_method("refresh_for_mode"):
		touch_controls.call("refresh_for_mode", GameState.current_mode, near_rift)


func _on_player_interact() -> void:
	if _active_gate != null:
		_store_current_zone_position()
		GameState.toggle_gameplay_mode()


func _on_player_slash_landed(_target: Node, total_hits: int) -> void:
	if hud.has_method("show_combo_feedback"):
		hud.call("show_combo_feedback", total_hits)


func _play_rift_flash() -> void:
	if fade_rect == null:
		return
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	fade_rect.color = Color(0.45, 0.28, 0.92, 0.42)
	_fade_tween = create_tween()
	_fade_tween.tween_property(fade_rect, "color:a", 0.0, 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
