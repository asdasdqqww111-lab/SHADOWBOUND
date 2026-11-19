extends CanvasLayer
## SHADOWBOUND Fantasy HUD, Multi-Phase Boss Bar, and Pause Overlay (Phase 3).
## Displays shared PlayerProfile vitals & slain counter, active camera/movement/riposte badges,
## live 3-phase Boss health bar, bilingual EN/AR RTL combat & lore banners, and Pause menu.

signal mode_switch_requested
signal respawn_requested

@onready var reward_label: Label = $HudRoot/RewardLabel
@onready var skill_btn: Button = $HudRoot/TopBar/RightCluster/SkillBtn
@onready var hud_root: Control = $HudRoot
@onready var name_label: Label = $HudRoot/TopBar/StatusPanel/HBox/StatsVBox/HeaderRow/NameLabel
@onready var rank_label: Label = $HudRoot/TopBar/StatusPanel/HBox/StatsVBox/HeaderRow/RankLabel
@onready var hp_label: Label = $HudRoot/TopBar/StatusPanel/HBox/StatsVBox/HpRow/HpLabel
@onready var hp_bar: ProgressBar = $HudRoot/TopBar/StatusPanel/HBox/StatsVBox/HpRow/HpBar
@onready var mp_label: Label = $HudRoot/TopBar/StatusPanel/HBox/StatsVBox/MpRow/MpLabel
@onready var mp_bar: ProgressBar = $HudRoot/TopBar/StatusPanel/HBox/StatsVBox/MpRow/MpBar
@onready var sp_label: Label = $HudRoot/TopBar/StatusPanel/HBox/StatsVBox/SpRow/SpLabel
@onready var xp_label: Label = $HudRoot/TopBar/StatusPanel/HBox/StatsVBox/XpLabel
@onready var xp_bar: ProgressBar = $HudRoot/TopBar/StatusPanel/HBox/StatsVBox/XpBar
@onready var wallet_label: Label = $HudRoot/TopBar/StatusPanel/HBox/StatsVBox/WalletLabel
@onready var sp_bar: ProgressBar = $HudRoot/TopBar/StatusPanel/HBox/StatsVBox/SpRow/SpBar

@onready var zone_label: Label = $HudRoot/TopBar/RightCluster/ZonePanel/VBox/ZoneLabel
@onready var mode_label: Label = $HudRoot/TopBar/RightCluster/ZonePanel/VBox/ModeLabel
@onready var state_label: Label = $HudRoot/TopBar/RightCluster/ZonePanel/VBox/StateLabel
@onready var switch_mode_btn: Button = $HudRoot/TopBar/RightCluster/ButtonRow/SwitchModeBtn
@onready var inventory_btn: Button = $HudRoot/TopBar/RightCluster/ButtonRow/InventoryBtn
@onready var pause_inventory_btn: Button = $PauseOverlay/CenterContainer/PausePanel/VBox/InventoryBtn
@onready var pause_btn: Button = $HudRoot/TopBar/RightCluster/ButtonRow/PauseBtn

@onready var boss_panel: PanelContainer = $HudRoot/BossPanel
@onready var boss_name_label: Label = $HudRoot/BossPanel/VBox/BossNameLabel
@onready var boss_phase_label: Label = $HudRoot/BossPanel/VBox/BossPhaseLabel
@onready var boss_hp_bar: ProgressBar = $HudRoot/BossPanel/VBox/BossHpBar
@onready var hint_label: Label = $HudRoot/HintBanner/HintLabel

@onready var pause_overlay: Control = $PauseOverlay
@onready var pause_title: Label = $PauseOverlay/CenterContainer/PausePanel/VBox/PauseTitle
@onready var resume_btn: Button = $PauseOverlay/CenterContainer/PausePanel/VBox/ResumeBtn
@onready var pause_mode_btn: Button = $PauseOverlay/CenterContainer/PausePanel/VBox/PauseModeBtn
@onready var pause_zoom_btn: Button = $PauseOverlay/CenterContainer/PausePanel/VBox/PauseZoomBtn
@onready var respawn_btn: Button = $PauseOverlay/CenterContainer/PausePanel/VBox/RespawnBtn
@onready var pause_lang_btn: Button = $PauseOverlay/CenterContainer/PausePanel/VBox/PauseLangBtn
@onready var main_menu_btn: Button = $PauseOverlay/CenterContainer/PausePanel/VBox/MainMenuBtn

var _reward_timer: float = 0.0
var _last_reward: Dictionary = {}

var _displayed_mode: int = 0
var _state_key: String = "idle"
var _compass_dir: String = "E"
var _vista_active: bool = false
var _riposte_active: bool = false
var _proximity_kind: String = ""

var _boss_visible: bool = false
var _boss_name_key: String = "boss.eclipse_warden"
var _boss_hp: float = 320.0
var _boss_max_hp: float = 320.0
var _boss_phase: int = 1

var _banner_timer: float = 0.0
var _banner_mode: String = ""
var _banner_key: String = ""
var _banner_params: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	pause_overlay.visible = false
	boss_panel.visible = false

	switch_mode_btn.pressed.connect(_on_switch_mode_pressed)
	pause_btn.pressed.connect(_on_pause_pressed)
	resume_btn.pressed.connect(_on_resume_pressed)
	pause_mode_btn.pressed.connect(_on_pause_switch_mode_pressed)
	pause_zoom_btn.pressed.connect(_on_pause_zoom_pressed)
	respawn_btn.pressed.connect(_on_respawn_pressed)
	pause_lang_btn.pressed.connect(_on_pause_lang_pressed)
	main_menu_btn.pressed.connect(_on_main_menu_pressed)

	skill_btn.pressed.connect(_on_skill_pressed)
	inventory_btn.pressed.connect(_on_inventory_pressed)
	pause_inventory_btn.pressed.connect(_on_inventory_pressed)
	GameState.progression.rewards_granted.connect(_on_rewards_granted)
	GameState.profile_updated.connect(_refresh_profile_bars)
	GameState.pause_state_changed.connect(_on_pause_state_changed)
	GameState.settings_changed.connect(_refresh_button_texts)
	LocalizationManager.locale_changed.connect(_on_locale_changed)

	_displayed_mode = GameState.current_mode
	_refresh_all()


func _process(delta: float) -> void:
	_refresh_skill_button()
	if get_tree().paused:
		return
	if _reward_timer > 0.0:
		_reward_timer = maxf(0.0, _reward_timer - delta)
		reward_label.visible = _reward_timer > 0.0
	if _banner_timer > 0.0:
		_banner_timer = maxf(0.0, _banner_timer - delta)
		if _banner_timer <= 0.0:
			_banner_mode = ""
			_banner_key = ""
			_banner_params.clear()
			_refresh_hint_text()


func refresh_mode_display(mode_value: int) -> void:
	_displayed_mode = mode_value
	_proximity_kind = ""
	_vista_active = false
	_banner_timer = 0.0
	_banner_mode = ""
	if mode_value != GameState.GameplayMode.TOP_DOWN:
		hide_boss_bar()
	_refresh_mode_labels()
	_refresh_hint_text()


func update_movement_state(state_key: String, compass_dir: String) -> void:
	_state_key = state_key
	_compass_dir = compass_dir
	_refresh_state_label()


func set_vista_active(active: bool) -> void:
	_vista_active = active
	_refresh_state_label()


func set_riposte_active(active: bool) -> void:
	_riposte_active = active
	_refresh_state_label()


func set_proximity_hint(kind: String) -> void:
	_proximity_kind = kind
	_refresh_hint_text()


func show_boss_bar(name_key: String, current_hp: float, max_hp: float, phase: int) -> void:
	_boss_visible = true
	_boss_name_key = name_key
	_boss_hp = current_hp
	_boss_max_hp = maxf(1.0, max_hp)
	_boss_phase = clampi(phase, 1, 3)
	_refresh_boss_panel()


func update_boss_bar(current_hp: float, max_hp: float, phase: int) -> void:
	if not _boss_visible:
		return
	_boss_hp = maxf(0.0, current_hp)
	_boss_max_hp = maxf(1.0, max_hp)
	_boss_phase = clampi(phase, 1, 3)
	_refresh_boss_panel()


func hide_boss_bar() -> void:
	_boss_visible = false
	if boss_panel != null:
		boss_panel.visible = false


func show_combo_step_feedback(combo_step: int, damage_dealt: int, total_hits: int) -> void:
	if combo_step >= 3:
		_show_timed_banner(
			"hud.combo_finisher",
			{"damage": damage_dealt, "count": total_hits},
			2.1
		)
	else:
		_show_timed_banner(
			"hud.totem_hit",
			{"step": combo_step, "count": total_hits},
			1.5
		)


func show_combat_banner(loc_key: String, params: Dictionary = {}, duration: float = 2.6) -> void:
	_show_timed_banner(loc_key, params, duration)


func show_enemy_slain(enemy_name_key: String, total_slain: int) -> void:
	_banner_mode = "enemy_slain"
	_banner_key = enemy_name_key
	_banner_params = {"count": total_slain}
	_banner_timer = 2.6
	_refresh_hint_text()


func show_lore_feedback(lore_key: String) -> void:
	_show_timed_banner(lore_key, {}, 4.6)


func _show_timed_banner(loc_key: String, params: Dictionary, duration: float) -> void:
	_banner_mode = "keyed"
	_banner_key = loc_key
	_banner_params = params
	_banner_timer = duration
	_refresh_hint_text()


func _refresh_all() -> void:
	LocalizationManager.apply_layout_direction(hud_root)
	LocalizationManager.apply_layout_direction(pause_overlay)
	_refresh_profile_bars()
	_refresh_mode_labels()
	_refresh_boss_panel()
	_refresh_hint_text()
	_refresh_button_texts()
	_refresh_reward_feedback()


func _refresh_profile_bars() -> void:
	var profile: PlayerProfile = GameState.get_player_profile()
	var loc: String = LocalizationManager.get_locale()
	name_label.text = profile.get_display_name(loc)
	var base_rank: String = "%s %s · %s%d" % [
		LocalizationManager.translate_key("hud.rank_prefix"),
		profile.rank_code,
		LocalizationManager.translate_key("hud.level_prefix"),
		profile.level,
	]
	if profile.session_enemies_defeated > 0:
		base_rank += " · %s %d" % [
			LocalizationManager.translate_key("hud.slain_prefix"),
			profile.session_enemies_defeated,
		]
	rank_label.text = base_rank

	hp_label.text = LocalizationManager.translate_key("hud.hp")
	mp_label.text = LocalizationManager.translate_key("hud.mp")
	sp_label.text = LocalizationManager.translate_key("hud.stamina")

	hp_bar.max_value = profile.max_hp
	hp_bar.value = profile.current_hp
	mp_bar.max_value = profile.max_mp
	mp_bar.value = profile.current_mp
	sp_bar.max_value = profile.max_stamina
	sp_bar.value = profile.current_stamina
	var progress: Dictionary = ProgressionRules.describe(profile.total_xp, GameState.progression.config)
	xp_label.text = LocalizationManager.translate_key(
		"progress.max_level" if int(progress.required) == 0 else "progress.xp", progress
	)
	xp_bar.max_value = maxf(1.0, float(progress.required))
	xp_bar.value = float(progress.xp) if int(progress.required) > 0 else 1.0
	wallet_label.text = LocalizationManager.translate_key("progress.wallet_short", profile.wallet.to_dictionary())


func _refresh_boss_panel() -> void:
	if boss_panel == null:
		return
	boss_panel.visible = _boss_visible and _displayed_mode == GameState.GameplayMode.TOP_DOWN
	if not boss_panel.visible:
		return
	boss_name_label.text = LocalizationManager.translate_key(_boss_name_key)
	var phase_key: String = "boss.phase_1"
	var phase_col: Color = Color(0.76, 0.68, 1.0, 1.0)
	if _boss_phase == 2:
		phase_key = "boss.phase_2"
		phase_col = Color(1.0, 0.52, 0.68, 1.0)
	elif _boss_phase >= 3:
		phase_key = "boss.phase_3"
		phase_col = Color(1.0, 0.88, 0.45, 1.0)
	boss_phase_label.text = "%s  (%d / %d)" % [
		LocalizationManager.translate_key(phase_key),
		int(ceilf(_boss_hp)),
		int(roundf(_boss_max_hp)),
	]
	boss_phase_label.add_theme_color_override("font_color", phase_col)
	boss_hp_bar.max_value = _boss_max_hp
	boss_hp_bar.value = _boss_hp


func _refresh_mode_labels() -> void:
	var is_td: bool = _displayed_mode == GameState.GameplayMode.TOP_DOWN
	zone_label.text = LocalizationManager.translate_key(
		"hud.zone_topdown" if is_td else "hud.zone_sidescroll"
	)
	mode_label.text = LocalizationManager.translate_key(
		"hud.mode_topdown" if is_td else "hud.mode_sidescroll"
	)
	_refresh_state_label()


func _refresh_state_label() -> void:
	if state_label == null:
		return
	var localized_state: String = LocalizationManager.translate_key("state.%s" % _state_key)
	var text: String = "%s: %s · %s" % [
		LocalizationManager.translate_key("hud.state_prefix"),
		localized_state,
		_compass_dir,
	]
	if _riposte_active:
		text += "  [%s]" % LocalizationManager.translate_key("hud.riposte_badge")
	elif _vista_active:
		text += "  [%s]" % LocalizationManager.translate_key("hud.vista_badge")
	state_label.text = text


func _refresh_hint_text() -> void:
	if _banner_timer > 0.0:
		if _banner_mode == "enemy_slain":
			var ename: String = LocalizationManager.translate_key(_banner_key)
			hint_label.text = LocalizationManager.translate_key(
				"hud.enemy_slain",
				{"name": ename, "count": int(_banner_params.get("count", 1))}
			)
			return
		if _banner_mode == "keyed" and _banner_key != "":
			hint_label.text = LocalizationManager.translate_key(_banner_key, _banner_params)
			return

	if _proximity_kind == "rift":
		hint_label.text = LocalizationManager.translate_key("hud.hint_rift_ready")
		return
	if _proximity_kind == "lore":
		hint_label.text = LocalizationManager.translate_key("hud.hint_lore_ready")
		return

	var is_td: bool = _displayed_mode == GameState.GameplayMode.TOP_DOWN
	hint_label.text = LocalizationManager.translate_key(
		"hud.hint_topdown" if is_td else "hud.hint_sidescroll"
	)


func _refresh_button_texts() -> void:
	inventory_btn.text = LocalizationManager.translate_key("inventory.button")
	pause_inventory_btn.text = LocalizationManager.translate_key("inventory.title")
	switch_mode_btn.text = LocalizationManager.translate_key("hud.switch_mode")
	pause_btn.text = LocalizationManager.translate_key("hud.pause")
	pause_title.text = LocalizationManager.translate_key("pause.title")
	resume_btn.text = LocalizationManager.translate_key("pause.resume")
	pause_mode_btn.text = LocalizationManager.translate_key("pause.switch_mode")
	var zoom_val_key: String = (
		"settings.zoom_wide"
		if GameState.camera_zoom_preset == GameState.CameraZoomPreset.WIDE
		else "settings.zoom_standard"
	)
	pause_zoom_btn.text = "%s: %s" % [
		LocalizationManager.translate_key("pause.camera_zoom"),
		LocalizationManager.translate_key(zoom_val_key),
	]
	respawn_btn.text = LocalizationManager.translate_key("pause.respawn")
	pause_lang_btn.text = LocalizationManager.translate_key("pause.language")
	main_menu_btn.text = LocalizationManager.translate_key("pause.main_menu")


func _on_switch_mode_pressed() -> void:
	mode_switch_requested.emit()


func _on_pause_pressed() -> void:
	GameState.toggle_pause()


func _on_resume_pressed() -> void:
	GameState.set_paused(false)


func _on_pause_switch_mode_pressed() -> void:
	GameState.set_paused(false)
	mode_switch_requested.emit()


func _on_pause_zoom_pressed() -> void:
	GameState.toggle_camera_zoom_preset()


func _on_respawn_pressed() -> void:
	GameState.set_paused(false)
	respawn_requested.emit()


func _on_pause_lang_pressed() -> void:
	LocalizationManager.toggle_locale()


func _on_main_menu_pressed() -> void:
	GameState.return_to_main_menu()


func _on_pause_state_changed(paused: bool) -> void:
	pause_overlay.visible = paused
	if paused:
		_refresh_button_texts()


func _on_locale_changed(_new_locale: String) -> void:
	_refresh_all()


func _on_inventory_pressed() -> void:
	GameState.set_inventory_open(true)


func _on_rewards_granted(summary: Dictionary) -> void:
	_last_reward = summary.duplicate()
	_reward_timer = 4.5
	_refresh_reward_feedback()


func _refresh_reward_feedback() -> void:
	reward_label.visible = _reward_timer > 0.0
	if _last_reward.is_empty():
		return
	var summary: Dictionary = _last_reward
	# Separate reward readout persists alongside combat/victory banners.
	var text: String = LocalizationManager.translate_key("progress.reward", {
		"xp": summary.xp_awarded, "gold": summary.gold_awarded,
	})
	if int(summary.levels_gained) > 0:
		text += " · " + LocalizationManager.translate_key("progress.level_up", {
			"level": summary.level, "rank": summary.rank,
		})
	if not bool(summary.item_added):
		text += " · " + LocalizationManager.translate_key("inventory.full")
	if int(summary.diamonds_awarded) > 0:
		text += " · " + LocalizationManager.translate_key("progress.boss_bonus", {
			"diamonds": summary.diamonds_awarded, "crystals": summary.crystals_awarded,
		})
	var loot: Dictionary = summary.get("loot", {})
	if loot.get("outcome") == "added":
		text += " · " + LocalizationManager.translate_key("build.loot", {
			"item": LocalizationManager.translate_key("item." + str(loot.item_id)),
		})
	elif loot.get("outcome") == "duplicate":
		text += " · " + LocalizationManager.translate_key("build.duplicate", {"gold": loot.get("gold", 0)})
	elif loot.get("outcome") == "full":
		text += " · " + LocalizationManager.translate_key("inventory.full")
	reward_label.text = text


func _on_skill_pressed() -> void:
	var node: Node = get_tree().get_first_node_in_group("player")
	if node != null:
		var skill: ClassSkillController = node.get_node_or_null("ClassSkillController") as ClassSkillController
		if skill != null:
			var result: String = skill.try_cast()
			if result != "skill.cast":
				show_combat_banner(result)


func _refresh_skill_button() -> void:
	var node: Node = get_tree().get_first_node_in_group("player")
	if node == null:
		return
	var skill: ClassSkillController = node.get_node_or_null("ClassSkillController") as ClassSkillController
	if skill == null:
		return
	var class_id: String = GameState.get_player_profile().class_id
	skill_btn.text = "%s · Q%s" % [LocalizationManager.translate_key("skill." + class_id),
		" (%ds)" % int(ceilf(skill.cooldown_remaining)) if skill.cooldown_remaining > 0 else ""]
	skill_btn.disabled = get_tree().paused or (node as PlayerCharacter).is_defeated() or skill.cooldown_remaining > 0
