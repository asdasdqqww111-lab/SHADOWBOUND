extends Node2D
## Twilight Sanctum — Phase 3 unified dual-mode playable dungeon & boss sanctuary.
## Coordinates Side-Scrolling (platforms, one-way skybridges, wall-jump tower, 3 enemy types)
## and Top-Down (8-direction courtyard, lore runestones, 3 enemy types, and the 3-phase boss
## Vaelor, Warden of the Eclipse) with one unified PlayerCharacter and PlayerProfile.

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
var _saved_td_facing: Vector2 = Vector2.UP
var _has_ss_pos: bool = false
var _has_td_pos: bool = false
var _abyss_y: float = 380.0
var _mode_switch_cooldown: float = 0.28
var _switch_cooldown_timer: float = 0.0
var _revive_delay: float = 1.5
var _revive_timer: float = 0.0

var _active_gate: Area2D = null
var _active_lore_stone: Area2D = null
var _active_boss: EclipseWardenBoss = null
var _fade_tween: Tween = null


func _ready() -> void:
	GameState.is_in_gameplay = true
	var shared_cfg: Dictionary = GameState.get_config_section("shared")
	var cam_cfg: Dictionary = GameState.get_config_section("camera")
	var def_cfg: Dictionary = GameState.get_combat_config_section("defense")
	_abyss_y = float(shared_cfg.get("abyss_respawn_y", _abyss_y))
	_mode_switch_cooldown = float(cam_cfg.get("mode_switch_cooldown", _mode_switch_cooldown))
	_revive_delay = float(def_cfg.get("revive_delay", _revive_delay))

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
		hud.connect("respawn_requested", reset_sanctum_trial)

	player.interact_requested.connect(_on_player_interact)
	player.combo_hit_landed.connect(_on_player_combo_hit)
	player.movement_state_updated.connect(_on_player_movement_state_updated)
	player.riposte_changed.connect(_on_player_riposte_changed)
	player.player_combat_event.connect(_on_player_combat_event)
	player.player_defeated.connect(_on_player_defeated)
	player.camera.vista_state_changed.connect(_on_camera_vista_changed)

	_connect_world_interactables()
	_connect_enemies_and_bosses()

	GameState.gameplay_mode_changed.connect(_on_gameplay_mode_changed)
	_apply_zone_for_mode(GameState.current_mode, false)


func _connect_world_interactables() -> void:
	for gate_node: Node in get_tree().get_nodes_in_group("rift_gates"):
		if gate_node is Area2D and gate_node.has_signal("player_proximity_changed"):
			gate_node.connect("player_proximity_changed", _on_rift_proximity_changed)

	for lore_node: Node in get_tree().get_nodes_in_group("lore_stones"):
		if lore_node is Area2D and lore_node.has_signal("lore_proximity_changed"):
			lore_node.connect("lore_proximity_changed", _on_lore_proximity_changed)


func _connect_enemies_and_bosses() -> void:
	for enode: Node in get_tree().get_nodes_in_group("enemies"):
		if enode is EnemyBase:
			var enemy: EnemyBase = enode as EnemyBase
			enemy.enemy_defeated.connect(_on_enemy_defeated)
		if enode is EclipseWardenBoss:
			var boss: EclipseWardenBoss = enode as EclipseWardenBoss
			_active_boss = boss
			boss.boss_engaged.connect(_on_boss_engaged)
			boss.boss_hp_changed.connect(_on_boss_hp_changed)
			boss.boss_phase_changed.connect(_on_boss_phase_changed)
			boss.boss_vanquished.connect(_on_boss_vanquished)


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
	if _revive_timer > 0.0:
		_revive_timer = maxf(0.0, _revive_timer - delta)
		if _revive_timer <= 0.0:
			reset_sanctum_trial()
		return
	if GameState.current_mode == GameState.GameplayMode.SIDE_SCROLL:
		if player.global_position.y > _abyss_y:
			respawn_in_current_zone()


func _on_request_mode_toggle() -> void:
	if _switch_cooldown_timer > 0.0 or player.is_defeated():
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
	_clear_active_projectiles()

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
	if is_top_down and _active_boss != null and _active_boss.is_engaged and not _active_boss.is_defeated():
		_on_boss_engaged(_active_boss)
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


func reset_sanctum_trial() -> void:
	_revive_timer = 0.0
	_clear_active_projectiles()
	for enode: Node in get_tree().get_nodes_in_group("enemies"):
		if enode is EnemyBase:
			(enode as EnemyBase).reset_enemy()
	if hud.has_method("hide_boss_bar"):
		hud.call("hide_boss_bar")
	var target_spawn: Vector2 = (
		td_spawn.global_position
		if GameState.current_mode == GameState.GameplayMode.TOP_DOWN
		else ss_spawn.global_position
	)
	_saved_ss_pos = ss_spawn.global_position
	_saved_td_pos = td_spawn.global_position
	player.revive_at(target_spawn)
	player.camera.snap_immediately()
	_play_rift_flash()


func _clear_active_projectiles() -> void:
	for companion: Node in get_tree().get_nodes_in_group("companions"):
		companion.queue_free()
	for pnode: Node in get_tree().get_nodes_in_group("projectiles"):
		if is_instance_valid(pnode):
			pnode.queue_free()


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


func _on_player_combo_hit(combo_step: int, damage_dealt: int, total_hits: int) -> void:
	if hud.has_method("show_combo_step_feedback"):
		hud.call("show_combo_step_feedback", combo_step, damage_dealt, total_hits)


func _on_player_movement_state_updated(state_key: String, compass_dir: String) -> void:
	if hud.has_method("update_movement_state"):
		hud.call("update_movement_state", state_key, compass_dir)


func _on_player_riposte_changed(active: bool) -> void:
	if hud.has_method("set_riposte_active"):
		hud.call("set_riposte_active", active)


func _on_player_combat_event(outcome: String, _amount: float) -> void:
	if not hud.has_method("show_combat_banner"):
		return
	if outcome == "parried":
		hud.call("show_combat_banner", "hud.parry_success", {}, 2.3)
	elif outcome == "guard_broken":
		hud.call("show_combat_banner", "hud.guard_break", {}, 2.2)


func _on_player_defeated() -> void:
	_revive_timer = _revive_delay
	if hud.has_method("show_combat_banner"):
		hud.call("show_combat_banner", "hud.player_fallen", {}, _revive_delay + 0.4)


func _on_enemy_defeated(_enemy: EnemyBase, enemy_stats: EnemyStats) -> void:
	if enemy_stats == null or enemy_stats.is_boss:
		return
	var total: int = player.profile.session_enemies_defeated if player.profile != null else 1
	if hud.has_method("show_enemy_slain"):
		hud.call("show_enemy_slain", enemy_stats.name_key, total)


func _on_boss_engaged(boss: EclipseWardenBoss) -> void:
	if boss == null or boss.stats == null:
		return
	if hud.has_method("show_boss_bar"):
		hud.call(
			"show_boss_bar",
			boss.stats.name_key,
			boss.current_hp,
			boss.stats.max_hp,
			boss.get_current_phase()
		)


func _on_boss_hp_changed(cur_hp: float, max_hp: float, phase: int) -> void:
	if hud.has_method("update_boss_bar"):
		hud.call("update_boss_bar", cur_hp, max_hp, phase)


func _on_boss_phase_changed(new_phase: int) -> void:
	player.camera.add_trauma(0.55 if new_phase == 2 else 0.75)
	_play_rift_flash()
	var banner_key: String = "boss.phase_shift_3" if new_phase >= 3 else "boss.phase_shift_2"
	if hud.has_method("show_combat_banner"):
		hud.call("show_combat_banner", banner_key, {}, 3.6)


func _on_boss_vanquished(_boss: EclipseWardenBoss) -> void:
	player.camera.add_trauma(0.8)
	_clear_active_projectiles()
	if player.profile != null:
		player.profile.restore_all()
		GameState.notify_profile_updated()
	if hud.has_method("hide_boss_bar"):
		hud.call("hide_boss_bar")
	if hud.has_method("show_combat_banner"):
		hud.call("show_combat_banner", "boss.defeated", {}, 5.5)
	_play_rift_flash()


func _on_camera_vista_changed(active: bool, _zone_id: String) -> void:
	if hud.has_method("set_vista_active"):
		hud.call("set_vista_active", active)


func _play_rift_flash() -> void:
	if fade_rect == null:
		return
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	fade_rect.color = Color(0.62, 0.42, 1.0, 0.52)
	_fade_tween = create_tween()
	_fade_tween.tween_property(fade_rect, "color:a", 0.0, 0.34).set_trans(Tween.TRANS_QUAD).set_ease(
		Tween.EASE_OUT
	)
