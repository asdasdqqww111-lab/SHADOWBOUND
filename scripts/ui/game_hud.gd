extends CanvasLayer
## SHADOWBOUND Fantasy HUD and Pause Overlay.
## Displays shared player portrait, name/rank/level, HP/MP/Stamina bars, current zone
## and camera mode, bilingual RTL/LTR text, quick mode switch, and pause menu.

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
@onready var switch_mode_btn: Button = $HudRoot/TopBar/RightCluster/ButtonRow/SwitchModeBtn
@onready var pause_btn: Button = $HudRoot/TopBar/RightCluster/ButtonRow/PauseBtn
@onready var hint_label: Label = $HudRoot/HintBanner/HintLabel

@onready var pause_overlay: Control = $PauseOverlay
@onready var pause_title: Label = $PauseOverlay/CenterContainer/PausePanel/VBox/PauseTitle
@onready var resume_btn: Button = $PauseOverlay/CenterContainer/PausePanel/VBox/ResumeBtn
@onready var pause_mode_btn: Button = $PauseOverlay/CenterContainer/PausePanel/VBox/PauseModeBtn
@onready var respawn_btn: Button = $PauseOverlay/CenterContainer/PausePanel/VBox/RespawnBtn
@onready var pause_lang_btn: Button = $PauseOverlay/CenterContainer/PausePanel/VBox/PauseLangBtn
@onready var main_menu_btn: Button = $PauseOverlay/CenterContainer/PausePanel/VBox/MainMenuBtn

var _displayed_mode: int = 0
var _rift_hint_active: bool = false
var _combo_banner_timer: float = 0.0
var _last_combo_count: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	pause_overlay.visible = false

	switch_mode_btn.pressed.connect(_on_switch_mode_pressed)
	pause_btn.pressed.connect(_on_pause_pressed)
	resume_btn.pressed.connect(_on_resume_pressed)
	pause_mode_btn.pressed.connect(_on_pause_switch_mode_pressed)
	respawn_btn.pressed.connect(_on_respawn_pressed)
	pause_lang_btn.pressed.connect(_on_pause_lang_pressed)
	main_menu_btn.pressed.connect(_on_main_menu_pressed)

	GameState.profile_updated.connect(_refresh_profile_bars)
	GameState.pause_state_changed.connect(_on_pause_state_changed)
	LocalizationManager.locale_changed.connect(_on_locale_changed)

	_displayed_mode = GameState.current_mode
	_refresh_all()


func _process(delta: float) -> void:
	if _combo_banner_timer > 0.0:
		_combo_banner_timer = maxf(0.0, _combo_banner_timer - delta)
		if _combo_banner_timer <= 0.0:
			_refresh_hint_text()


func refresh_mode_display(mode_value: int) -> void:
	_displayed_mode = mode_value
	_rift_hint_active = false
	_refresh_mode_labels()
	_refresh_hint_text()


func set_rift_hint_active(active: bool) -> void:
	_rift_hint_active = active
	_refresh_hint_text()


func show_combo_feedback(total_hits: int) -> void:
	_last_combo_count = total_hits
	_combo_banner_timer = 1.8
	hint_label.text = LocalizationManager.translate_key("hud.totem_hit", {"count": total_hits})


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


func _refresh_hint_text() -> void:
	if _combo_banner_timer > 0.0:
		hint_label.text = LocalizationManager.translate_key("hud.totem_hit", {"count": _last_combo_count})
		return
	if _rift_hint_active:
		hint_label.text = LocalizationManager.translate_key("hud.hint_rift_ready")
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


func _on_respawn_pressed() -> void:
	GameState.set_paused(false)
	respawn_requested.emit()


func _on_pause_lang_pressed() -> void:
	LocalizationManager.toggle_locale()
	GameState.save_settings()


func _on_main_menu_pressed() -> void:
	GameState.return_to_main_menu()
