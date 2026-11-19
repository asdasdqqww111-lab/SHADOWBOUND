extends Control
## SHADOWBOUND Main Menu controller (Phase 2).
## Provides entry into Side-Scrolling or Top-Down camera mode, Controls & Guide dialog,
## Settings (English / Arabic RTL, Touch Controls, Camera Smoothing, Camera Zoom Preset), and Quit.

@onready var hero_preview: AnimatedSprite2D = $HeroPreview
@onready var content_root: Control = $SafeMargin
@onready var title_label: Label = $SafeMargin/MainLayout/BrandColumn/TitleLabel
@onready var subtitle_label: Label = $SafeMargin/MainLayout/BrandColumn/SubtitleLabel
@onready var version_label: Label = $SafeMargin/MainLayout/BrandColumn/VersionLabel
@onready var play_ss_btn: Button = $SafeMargin/MainLayout/MenuPanel/MenuVBox/PlaySideScrollBtn
@onready var play_td_btn: Button = $SafeMargin/MainLayout/MenuPanel/MenuVBox/PlayTopDownBtn
@onready var controls_btn: Button = $SafeMargin/MainLayout/MenuPanel/MenuVBox/ControlsBtn
@onready var settings_btn: Button = $SafeMargin/MainLayout/MenuPanel/MenuVBox/SettingsBtn
@onready var lang_btn: Button = $SafeMargin/MainLayout/MenuPanel/MenuVBox/LanguageBtn
@onready var quit_btn: Button = $SafeMargin/MainLayout/MenuPanel/MenuVBox/QuitBtn
@onready var footer_label: Label = $FooterLabel

@onready var settings_modal: Control = $SettingsModal
@onready var settings_title: Label = $SettingsModal/Center/Panel/VBox/SettingsTitle
@onready var settings_lang_btn: Button = $SettingsModal/Center/Panel/VBox/SettingsLangBtn
@onready var settings_touch_btn: Button = $SettingsModal/Center/Panel/VBox/SettingsTouchBtn
@onready var settings_cam_btn: Button = $SettingsModal/Center/Panel/VBox/SettingsCamBtn
@onready var settings_zoom_btn: Button = $SettingsModal/Center/Panel/VBox/SettingsZoomBtn
@onready var settings_close_btn: Button = $SettingsModal/Center/Panel/VBox/SettingsCloseBtn

@onready var controls_modal: Control = $ControlsModal
@onready var controls_title: Label = $ControlsModal/Center/Panel/VBox/ControlsTitle
@onready var controls_body: Label = $ControlsModal/Center/Panel/VBox/ControlsBody
@onready var controls_close_btn: Button = $ControlsModal/Center/Panel/VBox/ControlsCloseBtn


func _ready() -> void:
	GameState.is_in_gameplay = false
	GameState.set_paused(false)
	settings_modal.visible = false
	controls_modal.visible = false

	if hero_preview != null and hero_preview.sprite_frames != null:
		hero_preview.play(&"idle")

	play_ss_btn.pressed.connect(_on_play_sidescroll)
	play_td_btn.pressed.connect(_on_play_topdown)
	controls_btn.pressed.connect(_on_open_controls)
	settings_btn.pressed.connect(_on_open_settings)
	lang_btn.pressed.connect(_on_toggle_language)
	quit_btn.pressed.connect(_on_quit)

	settings_lang_btn.pressed.connect(_on_toggle_language)
	settings_touch_btn.pressed.connect(_on_cycle_touch_mode)
	settings_cam_btn.pressed.connect(_on_toggle_camera_smooth)
	settings_zoom_btn.pressed.connect(_on_toggle_camera_zoom)
	settings_close_btn.pressed.connect(_on_close_modals)
	controls_close_btn.pressed.connect(_on_close_modals)

	LocalizationManager.locale_changed.connect(_on_locale_changed)
	GameState.settings_changed.connect(_refresh_texts)

	if OS.get_name() == "Web":
		quit_btn.visible = false

	_refresh_texts()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if settings_modal.visible or controls_modal.visible:
			_on_close_modals()
			get_viewport().set_input_as_handled()


func _refresh_texts() -> void:
	LocalizationManager.apply_layout_direction(content_root)
	LocalizationManager.apply_layout_direction(settings_modal)
	LocalizationManager.apply_layout_direction(controls_modal)

	title_label.text = LocalizationManager.translate_key("game.title")
	subtitle_label.text = LocalizationManager.translate_key("game.subtitle")
	version_label.text = LocalizationManager.translate_key("game.version")

	play_ss_btn.text = LocalizationManager.translate_key("menu.play_sidescroll")
	play_td_btn.text = LocalizationManager.translate_key("menu.play_topdown")
	controls_btn.text = LocalizationManager.translate_key("menu.controls")
	settings_btn.text = LocalizationManager.translate_key("menu.settings")
	lang_btn.text = LocalizationManager.translate_key("menu.language_toggle")
	quit_btn.text = LocalizationManager.translate_key("menu.quit")
	footer_label.text = LocalizationManager.translate_key("menu.footer")

	settings_title.text = LocalizationManager.translate_key("settings.title")
	settings_lang_btn.text = "%s: %s" % [
		LocalizationManager.translate_key("settings.language"),
		LocalizationManager.translate_key("meta.language_name"),
	]
	settings_touch_btn.text = "%s: %s" % [
		LocalizationManager.translate_key("settings.touch_mode"),
		_get_touch_mode_label(),
	]
	var smooth_key: String = (
		"settings.on" if GameState.camera_smoothing_enabled else "settings.off"
	)
	settings_cam_btn.text = "%s: %s" % [
		LocalizationManager.translate_key("settings.camera_smooth"),
		LocalizationManager.translate_key(smooth_key),
	]
	var zoom_key: String = (
		"settings.zoom_wide"
		if GameState.camera_zoom_preset == GameState.CameraZoomPreset.WIDE
		else "settings.zoom_standard"
	)
	settings_zoom_btn.text = "%s: %s" % [
		LocalizationManager.translate_key("settings.camera_zoom"),
		LocalizationManager.translate_key(zoom_key),
	]
	settings_close_btn.text = LocalizationManager.translate_key("settings.close")

	controls_title.text = LocalizationManager.translate_key("controls.title")
	controls_body.text = LocalizationManager.translate_key("controls.body")
	controls_close_btn.text = LocalizationManager.translate_key("controls.close")

	var rtl_align: HorizontalAlignment = (
		HORIZONTAL_ALIGNMENT_RIGHT
		if LocalizationManager.is_rtl()
		else HORIZONTAL_ALIGNMENT_LEFT
	)
	controls_body.horizontal_alignment = rtl_align


func _get_touch_mode_label() -> String:
	match GameState.touch_controls_mode:
		GameState.TouchControlsMode.AUTO:
			return LocalizationManager.translate_key("settings.touch_auto")
		GameState.TouchControlsMode.HIDDEN:
			return LocalizationManager.translate_key("settings.touch_off")
		_:
			return LocalizationManager.translate_key("settings.touch_on")


func _on_locale_changed(_loc: String) -> void:
	_refresh_texts()


func _on_play_sidescroll() -> void:
	GameState.start_game(GameState.GameplayMode.SIDE_SCROLL)


func _on_play_topdown() -> void:
	GameState.start_game(GameState.GameplayMode.TOP_DOWN)


func _on_open_controls() -> void:
	settings_modal.visible = false
	controls_modal.visible = true


func _on_open_settings() -> void:
	controls_modal.visible = false
	settings_modal.visible = true
	_refresh_texts()


func _on_close_modals() -> void:
	settings_modal.visible = false
	controls_modal.visible = false


func _on_toggle_language() -> void:
	LocalizationManager.toggle_locale()
	GameState.save_settings()


func _on_cycle_touch_mode() -> void:
	GameState.cycle_touch_controls_mode()


func _on_toggle_camera_smooth() -> void:
	GameState.set_camera_smoothing(not GameState.camera_smoothing_enabled)


func _on_toggle_camera_zoom() -> void:
	GameState.toggle_camera_zoom_preset()


func _on_quit() -> void:
	GameState.save_settings()
	get_tree().quit()
