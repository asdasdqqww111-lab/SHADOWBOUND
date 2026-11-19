extends Node
## SHADOWBOUND — Phase 1 Headless Verification Suite (Godot 4.x stable).
## Run with:
##   godot --headless --path . --import
##   godot --headless --path . res://tests/gdscript/test_phase1_runner.tscn

const REQUIRED_ANIMATIONS: Array[String] = [
	"idle",
	"run",
	"jump",
	"fall",
	"dodge",
	"attack",
	"td_idle_down",
	"td_idle_up",
	"td_idle_side",
	"td_walk_down",
	"td_walk_up",
	"td_walk_side",
	"td_dodge",
	"td_attack",
]

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("=== SHADOWBOUND Phase 1 Headless Test Suite ===")
	_test_resources_and_animations()
	_test_localization_and_rtl()
	_test_settings_save_load()
	_test_main_menu_scene()
	_test_side_scroll_and_top_down_controllers()
	_test_level_mode_and_camera_switching()
	_test_pause_and_totem_interaction()

	print("-----------------------------------------------")
	print("RESULTS: %d passed, %d failed" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("[PASS] %s" % label)
	else:
		_failed += 1
		push_error("[FAIL] %s" % label)
		print("[FAIL] %s" % label)


func _test_resources_and_animations() -> void:
	var theme_res: Resource = load("res://resources/themes/fantasy_ui_theme.tres")
	_check(theme_res is Theme, "Fantasy UI theme loads as Theme")

	var profile_res: Resource = load("res://resources/player/default_player_profile.tres")
	_check(profile_res is PlayerProfile, "Default player profile loads as PlayerProfile")

	var frames_res: Resource = load("res://resources/sprites/stickman_sprite_frames.tres")
	_check(frames_res is SpriteFrames, "Stickman SpriteFrames resource loads")
	if frames_res is SpriteFrames:
		var sf: SpriteFrames = frames_res
		for anim_name: String in REQUIRED_ANIMATIONS:
			var exists: bool = sf.has_animation(StringName(anim_name))
			var count: int = sf.get_frame_count(StringName(anim_name)) if exists else 0
			_check(exists and count >= 4, "Animation '%s' present with %d frames" % [anim_name, count])


func _test_localization_and_rtl() -> void:
	LocalizationManager.set_locale("en", true)
	_check(not LocalizationManager.is_rtl(), "English locale reports LTR")
	var en_play: String = LocalizationManager.translate_key("menu.play_sidescroll")
	_check(en_play.length() > 3 and en_play != "menu.play_sidescroll", "English key resolves")

	LocalizationManager.set_locale("ar", true)
	_check(LocalizationManager.is_rtl(), "Arabic locale reports RTL")
	var ar_play: String = LocalizationManager.translate_key("menu.play_sidescroll")
	_check(ar_play.length() > 3 and ar_play != en_play, "Arabic key resolves distinctly")

	var ctrl: Control = Control.new()
	LocalizationManager.apply_layout_direction(ctrl)
	_check(ctrl.layout_direction == Control.LAYOUT_DIRECTION_RTL, "Control switches to RTL in Arabic")
	ctrl.free()

	var combo_txt: String = LocalizationManager.translate_key("hud.totem_hit", {"count": 5})
	_check(combo_txt.contains("5"), "Localized string parameter substitution works")

	LocalizationManager.set_locale("en", true)


func _test_settings_save_load() -> void:
	GameState.set_camera_smoothing(false)
	var save_err: Error = GameState.save_settings()
	_check(save_err == OK, "Settings save cleanly to user://settings.cfg")
	GameState.camera_smoothing_enabled = true
	GameState.load_settings()
	_check(not GameState.camera_smoothing_enabled, "Settings reload restores saved value")
	GameState.set_camera_smoothing(true)


func _test_main_menu_scene() -> void:
	var packed: PackedScene = load("res://scenes/ui/main_menu.tscn") as PackedScene
	_check(packed != null, "Main menu PackedScene loads")
	if packed == null:
		return
	var menu: Control = packed.instantiate() as Control
	add_child(menu)
	var play_btn: Node = menu.get_node_or_null(
		"SafeMargin/MainLayout/MenuPanel/MenuVBox/PlaySideScrollBtn"
	)
	_check(play_btn != null, "Main menu Play button exists")
	menu.free()


func _test_side_scroll_and_top_down_controllers() -> void:
	var body: CharacterBody2D = CharacterBody2D.new()
	add_child(body)
	var profile: PlayerProfile = PlayerProfile.new()

	var ss: SideScrollController = SideScrollController.new()
	ss.activate(body)
	_check(body.motion_mode == CharacterBody2D.MOTION_MODE_GROUNDED, "SideScroll sets MOTION_MODE_GROUNDED")

	ss.physics_step(body, profile, {"move_vector": Vector2(1.0, 0.0)}, 0.05)
	_check(body.velocity.x > 0.0 and body.velocity.y > 0.0, "SideScroll applies horizontal speed and gravity")

	ss.physics_step(body, profile, {"move_vector": Vector2.ZERO, "jump_just_pressed": true}, 0.016)
	_check(body.velocity.y < -400.0, "SideScroll double jump imparts upward velocity")

	var before_sp: float = profile.current_stamina
	ss.physics_step(body, profile, {"move_vector": Vector2(1.0, 0.0), "dodge_just_pressed": true}, 0.016)
	_check(profile.current_stamina < before_sp and ss.is_dodging(), "SideScroll dodge consumes shared stamina")

	var td: TopDownController = TopDownController.new()
	td.activate(body)
	_check(body.motion_mode == CharacterBody2D.MOTION_MODE_FLOATING, "TopDown sets MOTION_MODE_FLOATING")

	for _i: int in range(12):
		td.physics_step(body, profile, {"move_vector": Vector2(1.0, 1.0)}, 0.05)
	_check(body.velocity.length() <= td.move_speed + 0.5, "TopDown diagonal velocity is normalized")
	_check(body.velocity.x > 100.0 and body.velocity.y > 100.0, "TopDown moves diagonally across both axes")

	ss.free()
	td.free()
	body.free()


func _test_level_mode_and_camera_switching() -> void:
	var packed: PackedScene = load("res://scenes/levels/twilight_sanctum.tscn") as PackedScene
	_check(packed != null, "Twilight Sanctum level scene loads")
	if packed == null:
		return

	GameState.current_mode = GameState.GameplayMode.SIDE_SCROLL
	var level: Node2D = packed.instantiate() as Node2D
	add_child(level)

	var player: PlayerCharacter = level.get_node("Player") as PlayerCharacter
	var ss_zone: Node2D = level.get_node("SideScrollZone") as Node2D
	var td_zone: Node2D = level.get_node("TopDownZone") as Node2D

	_check(ss_zone.visible and not td_zone.visible, "Level starts in SideScrollZone")
	_check(player.camera.get_camera_mode() == GameState.GameplayMode.SIDE_SCROLL, "Camera starts in SIDE_SCROLL")

	player.profile.session_slash_hits = 7

	# Switch to Top-Down mode and verify unified profile preservation
	GameState.toggle_gameplay_mode()
	_check(td_zone.visible and not ss_zone.visible, "Mode switch activates TopDownZone")
	_check(player.camera.get_camera_mode() == GameState.GameplayMode.TOP_DOWN, "Camera switches to TOP_DOWN")
	_check(player.collision_mask == 2, "Player switches collision mask to world_topdown")
	_check(player.profile.session_slash_hits == 7, "Shared PlayerProfile persists across mode switch")

	# Switch back to Side-Scroll mode
	GameState.toggle_gameplay_mode()
	_check(ss_zone.visible and not td_zone.visible, "Mode switch returns cleanly to SideScrollZone")
	_check(
		player.camera.get_camera_mode() == GameState.GameplayMode.SIDE_SCROLL
		and (player.collision_mask & 1) == 1,
		"Camera and collision restore to SIDE_SCROLL"
	)

	level.free()


func _test_pause_and_totem_interaction() -> void:
	GameState.set_paused(true)
	_check(get_tree().paused, "GameState pauses SceneTree")
	GameState.set_paused(false)
	_check(not get_tree().paused, "GameState resumes SceneTree")

	var totem_scene: PackedScene = load("res://scenes/props/training_totem.tscn") as PackedScene
	var totem: Area2D = totem_scene.instantiate() as Area2D
	add_child(totem)
	totem.call("receive_slash", Vector2.RIGHT)
	_check(int(totem.get("hit_count")) == 1, "TrainingTotem registers sword slash hits")
	totem.free()
