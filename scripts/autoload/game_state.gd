extends Node
## Global unified session, mode, shared player profile, settings, and Android lifecycle manager.
## Persists lightweight user settings to Android-compatible `user://settings.cfg`.

signal gameplay_mode_changed(new_mode: int)
signal pause_state_changed(is_paused: bool)
signal settings_changed
signal profile_updated
signal enemy_defeated_recorded(enemy_id: String, is_boss: bool, total_count: int)

enum GameplayMode {
	SIDE_SCROLL = 0,
	TOP_DOWN = 1,
}

enum TouchControlsMode {
	AUTO = 0,
	ALWAYS_ON = 1,
	HIDDEN = 2,
}

enum CameraZoomPreset {
	STANDARD = 0,
	WIDE = 1,
}

const MAIN_MENU_SCENE: String = "res://scenes/ui/main_menu.tscn"
const PLAYABLE_LEVEL_SCENE: String = "res://scenes/levels/twilight_sanctum.tscn"
const DEFAULT_PROFILE_PATH: String = "res://resources/player/default_player_profile.tres"
const MOVEMENT_CONFIG_PATH: String = "res://data/config/movement_config.json"
const COMBAT_CONFIG_PATH: String = "res://data/config/combat_config.json"
const SETTINGS_SAVE_PATH: String = "user://settings.cfg"

var current_mode: int = GameplayMode.SIDE_SCROLL
var touch_controls_mode: int = TouchControlsMode.ALWAYS_ON
var camera_smoothing_enabled: bool = true
var camera_zoom_preset: int = CameraZoomPreset.STANDARD
var is_in_gameplay: bool = false
var player_profile: PlayerProfile = null
var movement_config: Dictionary = {}
var combat_config: Dictionary = {}
var defeated_enemy_counts: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().set_auto_accept_quit(true)
	_load_movement_config()
	_load_combat_config()
	_ensure_player_profile()
	load_settings()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		if is_in_gameplay and not get_tree().paused:
			set_paused(true)
		save_settings()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if is_in_gameplay:
			toggle_pause()


func _load_movement_config() -> void:
	if not FileAccess.file_exists(MOVEMENT_CONFIG_PATH):
		push_warning("GameState: Missing movement config at %s" % MOVEMENT_CONFIG_PATH)
		movement_config = {}
		return
	var raw: String = FileAccess.get_file_as_string(MOVEMENT_CONFIG_PATH)
	var parsed: Variant = JSON.parse_string(raw)
	if parsed is Dictionary:
		movement_config = parsed
	else:
		movement_config = {}


func get_config_section(section_name: String) -> Dictionary:
	if movement_config.is_empty():
		_load_movement_config()
	if movement_config.has(section_name) and movement_config[section_name] is Dictionary:
		var section: Dictionary = movement_config[section_name]
		return section
	return {}


func _load_combat_config() -> void:
	if not FileAccess.file_exists(COMBAT_CONFIG_PATH):
		push_warning("GameState: Missing combat config at %s" % COMBAT_CONFIG_PATH)
		combat_config = {}
		return
	var raw: String = FileAccess.get_file_as_string(COMBAT_CONFIG_PATH)
	var parsed: Variant = JSON.parse_string(raw)
	if parsed is Dictionary:
		combat_config = parsed
	else:
		combat_config = {}


func get_combat_config_section(section_name: String) -> Dictionary:
	if combat_config.is_empty():
		_load_combat_config()
	if combat_config.has(section_name) and combat_config[section_name] is Dictionary:
		var section: Dictionary = combat_config[section_name]
		return section
	return {}


func record_enemy_defeated(enemy_id: String, is_boss: bool = false) -> int:
	_ensure_player_profile()
	player_profile.session_enemies_defeated += 1
	if is_boss:
		player_profile.session_bosses_defeated += 1
	var prev: int = int(defeated_enemy_counts.get(enemy_id, 0))
	var updated: int = prev + 1
	defeated_enemy_counts[enemy_id] = updated
	profile_updated.emit()
	enemy_defeated_recorded.emit(enemy_id, is_boss, updated)
	return updated


func get_enemy_defeat_count(enemy_id: String) -> int:
	return int(defeated_enemy_counts.get(enemy_id, 0))


func _ensure_player_profile() -> void:
	if player_profile != null:
		return
	var loaded: Resource = load(DEFAULT_PROFILE_PATH)
	if loaded is PlayerProfile:
		player_profile = loaded.duplicate(true) as PlayerProfile
	else:
		player_profile = PlayerProfile.new()


func get_player_profile() -> PlayerProfile:
	_ensure_player_profile()
	return player_profile


func notify_profile_updated() -> void:
	profile_updated.emit()


func set_gameplay_mode(new_mode: int) -> void:
	if new_mode != GameplayMode.SIDE_SCROLL and new_mode != GameplayMode.TOP_DOWN:
		return
	if current_mode == new_mode:
		return
	current_mode = new_mode
	_ensure_player_profile()
	player_profile.session_mode_switches += 1
	gameplay_mode_changed.emit(current_mode)


func toggle_gameplay_mode() -> int:
	var next_mode: int = (
		GameplayMode.TOP_DOWN
		if current_mode == GameplayMode.SIDE_SCROLL
		else GameplayMode.SIDE_SCROLL
	)
	set_gameplay_mode(next_mode)
	return current_mode


func get_mode_name(mode_value: int = -1) -> String:
	var target: int = current_mode if mode_value < 0 else mode_value
	if target == GameplayMode.TOP_DOWN:
		return "TOP_DOWN"
	return "SIDE_SCROLL"


func start_game(initial_mode: int = GameplayMode.SIDE_SCROLL) -> Error:
	_ensure_player_profile()
	player_profile.restore_all()
	current_mode = initial_mode
	set_paused(false)
	is_in_gameplay = true
	return get_tree().change_scene_to_file(PLAYABLE_LEVEL_SCENE)


func return_to_main_menu() -> Error:
	set_paused(false)
	is_in_gameplay = false
	save_settings()
	return get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func set_paused(paused: bool) -> void:
	if get_tree().paused == paused:
		return
	get_tree().paused = paused
	pause_state_changed.emit(paused)


func toggle_pause() -> bool:
	var next_paused: bool = not get_tree().paused
	set_paused(next_paused)
	return next_paused


func should_show_touch_controls() -> bool:
	if touch_controls_mode == TouchControlsMode.ALWAYS_ON:
		return true
	if touch_controls_mode == TouchControlsMode.HIDDEN:
		return false
	var os_name: String = OS.get_name()
	if os_name == "Android" or os_name == "iOS":
		return true
	return DisplayServer.is_touchscreen_available()


func cycle_touch_controls_mode() -> int:
	touch_controls_mode = (touch_controls_mode + 1) % 3
	save_settings()
	settings_changed.emit()
	return touch_controls_mode


func set_touch_controls_mode(mode_value: int) -> void:
	touch_controls_mode = clampi(mode_value, TouchControlsMode.AUTO, TouchControlsMode.HIDDEN)
	save_settings()
	settings_changed.emit()


func set_camera_smoothing(enabled: bool) -> void:
	camera_smoothing_enabled = enabled
	save_settings()
	settings_changed.emit()


func set_camera_zoom_preset(preset: int) -> void:
	camera_zoom_preset = clampi(preset, CameraZoomPreset.STANDARD, CameraZoomPreset.WIDE)
	save_settings()
	settings_changed.emit()


func toggle_camera_zoom_preset() -> int:
	var next_preset: int = (
		CameraZoomPreset.WIDE
		if camera_zoom_preset == CameraZoomPreset.STANDARD
		else CameraZoomPreset.STANDARD
	)
	set_camera_zoom_preset(next_preset)
	return camera_zoom_preset


func get_camera_zoom_multiplier() -> float:
	var cam_cfg: Dictionary = get_config_section("camera")
	if camera_zoom_preset == CameraZoomPreset.WIDE:
		return float(cam_cfg.get("zoom_preset_wide", 0.88))
	return float(cam_cfg.get("zoom_preset_standard", 1.0))


func save_settings() -> Error:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("general", "locale", LocalizationManager.get_locale())
	cfg.set_value("controls", "touch_mode", touch_controls_mode)
	cfg.set_value("camera", "smoothing", camera_smoothing_enabled)
	cfg.set_value("camera", "zoom_preset", camera_zoom_preset)
	return cfg.save(SETTINGS_SAVE_PATH)


func load_settings() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	var err: Error = cfg.load(SETTINGS_SAVE_PATH)
	if err != OK:
		return
	var saved_locale: String = str(cfg.get_value("general", "locale", "en"))
	touch_controls_mode = int(cfg.get_value("controls", "touch_mode", TouchControlsMode.ALWAYS_ON))
	touch_controls_mode = clampi(touch_controls_mode, TouchControlsMode.AUTO, TouchControlsMode.HIDDEN)
	camera_smoothing_enabled = bool(cfg.get_value("camera", "smoothing", true))
	camera_zoom_preset = int(cfg.get_value("camera", "zoom_preset", CameraZoomPreset.STANDARD))
	camera_zoom_preset = clampi(camera_zoom_preset, CameraZoomPreset.STANDARD, CameraZoomPreset.WIDE)
	LocalizationManager.set_locale(saved_locale, true)
	settings_changed.emit()
