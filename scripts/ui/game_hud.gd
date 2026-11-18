extends CanvasLayer
## SHADOWBOUND Fantasy HUD and Pause Overlay (Phase 2).
## Displays shared player portrait, name/rank/level, HP/MP/Stamina bars, active camera mode,
## real-time controller state + 8-compass badge, vista indicator, bilingual RTL/LTR lore &
## hint banners, quick mode switch, and pause menu with camera preset toggle.

signal mode_switch_requested
signal respawn_requested

@onready var hud_root: Control = $HudRoot
@onready var name_label: Label = $HudRoot/TopBar/StatusPanel/HBox/StatsVBox/HeaderRow/NameLabel
@onready var rank_label: Label = $HudRoot/TopBar/StatusPanel/HBox/StatsVBox/HeaderRow/RankLabel
@onready var hp_label: Label = $HudRoot/TopBar/StatusPanel/HBox/StatsVBox/HpRow/HpLabel
@onready var hp_bar: ProgressBar = $HudRoot/TopBar/StatusPanel/HBox/StatsVBox/HpRow/HpBar
@onready var mp_label: Label = $HudRoot/TopBar/StatusPanel/HBox/StatsVBox/MpRow/MpLabel
@onready var mp_bar: ProgressBar = $HudRoot/TopBar/StatusPanel/HBox/StatsVBox/MpRow/MpBar
@onready var sp_label: Label = $HudRoot/TopBar/StatusPanel/HBox/StatsVBox/SpRow/SpLabel
@onready var sp_bar: ProgressBar = $HudRoot/TopBar/StatusPanel/HBox/StatsVBox/SpRow/SpBar

@onready var zone_label: Label = $HudRoot/TopBar/RightCluster/ZonePanel/VBox/ZoneLabel
@onready var mode_label: Label = $HudRoot/TopBar/RightCluster/ZonePanel/VBox/ModeLabel
@onready var state_label: Label = $HudRoot/TopBar/RightCluster/ZonePanel/VBox/StateLabel
@onready var switch_mode_btn: Button = $HudRoot/TopBar/RightCluster/ButtonRow/SwitchModeBtn
@onready var pause_btn: Button = $HudRoot/TopBar/RightCluster/ButtonRow/PauseBtn
@onready var hint_label: Label = $HudRoot/HintBanner/HintLabel

@onready var pause_overlay: Control = $PauseOverlay
@onready var pause_title: Label = $PauseOverlay/CenterContainer/PausePanel/VBox/PauseTitle
@onready var resume_btn: Button = $PauseOverlay/CenterContainer/PausePanel/VBox/ResumeBtn
@onready var pause_mode_btn: Button = $PauseOverlay/CenterContainer/PausePanel/VBox/PauseModeBtn
@onready var pause_zoom_btn: Button = $PauseOverlay/CenterContainer/PausePanel/VBox/PauseZoomBtn
@onready var respawn_btn: Button = $PauseOverlay/CenterContainer/PausePanel/VBox/RespawnBtn
@onready var pause_lang_btn: Button = $PauseOverlay/CenterContainer/PausePanel/VBox/PauseLangBtn
@onready var main_menu_btn: Button = $PauseOverlay/CenterContainer/PausePanel/VBox/MainMenuBtn

var _displayed_mode: int = 0
var _state_key: String = "idle"
var _compass_dir: String = "E"
var _vista_active: bool = false
var _proximity_kind: String = ""
var _banner_timer: float = 0.0
var _banner_mode: String = ""
var _last_combo_count: int = 0
var _active_lore_key: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	pause_overlay.visible = false

	switch_mode_btn.pressed.connect(_on_switch_mode_pressed)
	pause_btn.pressed.connect(_on_pause_pressed)
	resume_btn.pressed.connect(_on_resume_pressed)
	pause_mode_btn.pressed.connect(_on_pause_switch_mode_pressed)
	pause_zoom_btn.pressed.connect(_on_pause_zoom_pressed)
	respawn_btn.pressed.connect(_on_respawn_pressed)
	pause_lang_btn.pressed.connect(_on_pause_lang_pressed)
	main_menu_btn.pressed.connect(_on_main_menu_pressed)

	GameState.profile_updated.connect(_refresh_profile_bars)
	GameState.pause_state_changed.connect(_on_pause_state_changed)
	GameState.settings_changed.connect(_refresh_button_texts)
	LocalizationManager.locale_changed.connect(_on_locale_changed)

	_displayed_mode = GameState.current_mode
	_refresh_all()


func _process(delta: float) -> void:
	if _banner_timer > 0.0:
		_banner_timer = maxf(0.0, _banner_timer - delta)
		if _banner_timer <= 0.0:
			_banner_mode = ""
			_refresh_hint_text()


func refresh_mode_display(mode_value: int) -> void:
	_displayed_mode = mode_value
	_proximity_kind = ""
	_vista_active = false
	_banner_timer = 0.0
	_banner_mode = ""
	_refresh_mode_labels()
	_refresh_hint_text()


func update_movement_state(state_key: String, compass_dir: String) -> void:
	_state_key = state_key
	_compass_dir = compass_dir
	_refresh_state_label()


func set_vista_active(active: bool) -> void:
	_vista_active = active
	_refresh_state_label()


func set_proximity_hint(kind: String) -> void:
	_proximity_kind = kind
	_refresh_hint_text()


func set_rift_hint_active(active: bool) -> void:
	set_proximity_hint("rift" if active else "")


func show_combo_feedback(total_hits: int) -> void:
	_last_combo_count = total_hits
	_banner_mode = "combo"
	_banner_timer = 1.8
	_refresh_hint_text()


func show_lore_feedback(lore_key: String) -> void:
	_active_lore_key = lore_key
	_banner_mode = "lore"
	_banner_timer = 4.6
	_refresh_hint_text()


func _refresh_all() -> void:
	LocalizationManager.apply_layout_direction(hud_root)
	LocalizationManager.apply_layout_direction(pause_overlay)
	_refresh_profile_bars()
	_refresh_mode_labels()
	_refresh_hint_text()
	_refresh_button_texts()


func _refresh_profile_bars() -> void:
	var profile: PlayerProfile = GameState.get_player_profile()
	var loc: String = LocalizationManager.get_locale()
	name_label.text = profile.get_display_name(loc)
	rank_label.text = "%s %s · %s%d" % [
		LocalizationManager.translate_key("hud.rank_prefix"),
		profile.rank_code,
		LocalizationManager.translate_key("hud.level_prefix"),
		profile.level,
	]
	hp_label.text = LocalizationManager.translate_key("hud.hp")
	mp_label.text = LocalizationManager.translate_key("hud.mp")
	sp_label.text = LocalizationManager.translate_key("hud.stamina")

	hp_bar.max_value = profile.max_hp
	hp_bar.value = profile.current_hp
	mp_bar.max_value = profile.max_mp
	mp_bar.value = profile.current_mp
	sp_bar.max_value = profile.max_stamina
	sp_bar.value = profile.current_stamina


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
	if _vista_active:
		text += "  [%s]" % LocalizationManager.translate_key("hud.vista_badge")
	state_label.text = text


func _refresh_hint_text() -> void:
	if _banner_timer > 0.0:
		if _banner_mode == "lore" and _active_lore_key != "":
			hint_label.text = LocalizationManager.translate_key(_active_lore_key)
			return
		if _banner_mode == "combo":
			hint_label.text = LocalizationManager.translate_key(
				"hud.totem_hit", {"count": _last_combo_count}
			)
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
	switch_mode_btn.text = LocalizationManager.translate_key("hud.switch_mode")
	pause_btn.text = LocalizationManager.translate_key("hud.pause")
	pause_title.text = LocalizationManager.translate_key("pause.title")
	resume_btn.text = LocalizationManager.translate_key("pause.resume")
	pause_mode_btn.text = LocalizationManager.translate_key("pause.switch_mode")
	var zoom_key: String = (
		"settings.zoom_wide"
		if GameState.camera_zoom_preset == GameState.CameraZoomPreset.WIDE
		else "settings.zoom_standard"
	)
	pause_zoom_btn.text = "%s: %s" % [
		LocalizationManager.translate_key("settings.camera_zoom"),
		LocalizationManager.translate_key(zoom_key),
	]
	respawn_btn.text = LocalizationManager.translate_key("pause.respawn")
	pause_lang_btn.text = LocalizationManager.translate_key("pause.language")
	main_menu_btn.text = LocalizationManager.translate_key("pause.main_menu")


func _on_locale_changed(_loc: String) -> void:
	_refresh_all()


func _on_pause_state_changed(is_paused: bool) -> void:
	pause_overlay.visible = is_paused


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
	GameState.save_settings()


func _on_main_menu_pressed() -> void:
	GameState.return_to_main_menu()
