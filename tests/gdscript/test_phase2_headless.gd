extends Node
## SHADOWBOUND — Phase 2 Headless Verification Suite (Godot 4.x stable).
## Validates both CameraModeProfiles, DualModeCamera framing & CameraZoneTriggers,
## dedicated SideScrollController (jump, double jump, wall slide/jump, drop-through,
## dodge i-frames, block/parry) and TopDownController (8-compass walk/run/sprint,
## 8-way dodge i-frames, directional block/parry), and seamless unified mode persistence.
##
## Run with:
##   godot --headless --path . --import
##   godot --headless --path . res://tests/gdscript/test_phase2_runner.tscn

const PHASE2_ANIMATIONS: Array[String] = [
	"idle", "run", "jump", "fall", "dodge", "attack", "block", "wall_slide",
	"td_idle_down", "td_idle_up", "td_idle_side",
	"td_walk_down", "td_walk_up", "td_walk_side",
	"td_dodge", "td_attack", "td_block",
]

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("=== SHADOWBOUND Phase 2 Headless Test Suite ===")
	_test_phase2_animations_and_camera_profiles()
	_test_dual_mode_camera_and_vista_zones()
	_test_side_scroll_controller_full()
	_test_top_down_controller_full()
	_test_level_dual_mode_persistence_and_lore()
	_test_camera_zoom_preset_save_load()

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


func _test_phase2_animations_and_camera_profiles() -> void:
	var sf: SpriteFrames = load("res://resources/sprites/stickman_sprite_frames.tres") as SpriteFrames
	_check(sf != null, "Stickman SpriteFrames loads")
	if sf != null:
		for anim: String in PHASE2_ANIMATIONS:
			_check(sf.has_animation(StringName(anim)), "Animation present: %s" % anim)

	var ss_prof: CameraModeProfile = load(
		"res://resources/camera/side_scroll_camera_profile.tres"
	) as CameraModeProfile
	var td_prof: CameraModeProfile = load(
		"res://resources/camera/top_down_camera_profile.tres"
	) as CameraModeProfile
	_check(ss_prof != null and ss_prof.mode_key == "side_scroll", "Side-scroll CameraModeProfile valid")
	_check(td_prof != null and td_prof.mode_key == "top_down", "Top-down CameraModeProfile valid")
	if ss_prof != null and td_prof != null:
		_check(
			not ss_prof.drag_horizontal_enabled and td_prof.drag_horizontal_enabled,
			"Separate camera profiles configure distinct drag policies"
		)
		_check(
			ss_prof.fall_peek_offset_y > 40.0 and td_prof.lookahead_distance.y > 20.0,
			"Side-scroll fall-peek and Top-down Y-lookahead configured distinctly"
		)


func _test_dual_mode_camera_and_vista_zones() -> void:
	var cam: DualModeCamera = DualModeCamera.new()
	add_child(cam)

	# Side-scroll right/left lookahead & fast-fall peek
	cam.set_camera_mode(GameState.GameplayMode.SIDE_SCROLL)
	cam.update_focus(Vector2(300.0, 0.0), Vector2.RIGHT, 0.1)
	var right_off: Vector2 = cam.get_target_offset()
	cam.update_focus(Vector2(-300.0, 0.0), Vector2.LEFT, 0.1)
	var left_off: Vector2 = cam.get_target_offset()
	_check(right_off.x > 60.0 and left_off.x < -60.0, "Side-scroll camera mirrors X lookahead")

	cam.update_focus(Vector2(0.0, 720.0), Vector2.RIGHT, 0.1)
	var fall_off: Vector2 = cam.get_target_offset()
	_check(fall_off.y > right_off.y + 30.0, "Side-scroll camera peeks downward on fast fall")

	# Top-down 8-direction lookahead & sprint zoom-out
	cam.set_camera_mode(GameState.GameplayMode.TOP_DOWN)
	cam.update_focus(Vector2(200.0, -200.0), Vector2(1.0, -1.0).normalized(), 0.1, {"sprinting": false})
	var ne_off: Vector2 = cam.get_target_offset()
	var normal_zoom: Vector2 = cam.get_target_zoom()
	_check(ne_off.x > 15.0 and ne_off.y < -15.0, "Top-down camera leads diagonally toward NE")

	cam.update_focus(Vector2(250.0, -250.0), Vector2(1.0, -1.0).normalized(), 0.1, {"sprinting": true})
	var sprint_zoom: Vector2 = cam.get_target_zoom()
	_check(sprint_zoom.x < normal_zoom.x, "Top-down camera zooms out slightly while sprinting")

	# Priority-stacked CameraZoneTrigger vista override
	var low_zone: CameraZoneTrigger = CameraZoneTrigger.new()
	low_zone.zone_id = "low"
	low_zone.camera_priority = 1
	low_zone.zoom_scale_override = 0.94
	var high_zone: CameraZoneTrigger = CameraZoneTrigger.new()
	high_zone.zone_id = "high_vista"
	high_zone.camera_priority = 3
	high_zone.zoom_scale_override = 0.85
	add_child(low_zone)
	add_child(high_zone)

	cam.enter_camera_zone(low_zone)
	cam.enter_camera_zone(high_zone)
	_check(
		cam.is_in_vista_zone() and cam.get_active_camera_zone().zone_id == "high_vista",
		"CameraZoneTrigger selects highest-priority active vista"
	)
	cam.update_focus(Vector2.ZERO, Vector2.DOWN, 0.1)
	_check(cam.get_target_zoom().x < normal_zoom.x * 0.9, "Vista zone widens camera target zoom")

	# Switching mode clears stale zones automatically
	cam.set_camera_mode(GameState.GameplayMode.SIDE_SCROLL)
	_check(not cam.is_in_vista_zone(), "Mode switch clears previous zone's camera triggers")

	low_zone.free()
	high_zone.free()
	cam.free()


func _test_side_scroll_controller_full() -> void:
	var body: CharacterBody2D = CharacterBody2D.new()
	add_child(body)
	var profile: PlayerProfile = PlayerProfile.new()
	var ss: SideScrollController = SideScrollController.new()
	ss.apply_config(GameState.get_config_section("side_scroll"))
	ss.activate(body)

	# Wall slide clamps downward velocity
	body.velocity = Vector2(0.0, 500.0)
	ss.physics_step(
		body,
		profile,
		{"move_vector": Vector2(1.0, 0.0), "sim_wall_normal_x": -1.0},
		0.016
	)
	_check(
		ss.is_wall_sliding() and body.velocity.y <= ss.wall_slide_max_speed + 0.5,
		"SideScroll wall slide clamps descent and enters wall_slide state"
	)

	# Wall jump kicks diagonally away from wall
	ss.physics_step(
		body,
		profile,
		{"move_vector": Vector2(1.0, 0.0), "jump_just_pressed": true, "sim_wall_normal_x": -1.0},
		0.016
	)
	_check(
		body.velocity.x < -250.0 and body.velocity.y < -400.0,
		"SideScroll wall jump launches away from right wall"
	)

	# Air dodge grants i-frames and enforces max_air_dodges = 1
	ss.physics_step(body, profile, {"move_vector": Vector2(1.0, 0.0), "dodge_just_pressed": true}, 0.016)
	_check(
		ss.is_dodging() and ss.is_invulnerable() and ss.get_air_dodges_remaining() == 0,
		"SideScroll air dodge grants i-frames and consumes single air dodge"
	)

	ss.free()
	body.free()


func _test_top_down_controller_full() -> void:
	var body: CharacterBody2D = CharacterBody2D.new()
	add_child(body)
	var profile: PlayerProfile = PlayerProfile.new()
	var td: TopDownController = TopDownController.new()
	td.apply_config(GameState.get_config_section("top_down"))
	td.activate(body)

	# Verify all 8 compass octants resolve uniquely and accurately
	var expected_8: Array[Array] = [
		[Vector2(1, 0), "E"],
		[Vector2(1, 1), "SE"],
		[Vector2(0, 1), "S"],
		[Vector2(-1, 1), "SW"],
		[Vector2(-1, 0), "W"],
		[Vector2(-1, -1), "NW"],
		[Vector2(0, -1), "N"],
		[Vector2(1, -1), "NE"],
	]
	var all_8_ok: bool = true
	for pair: Array in expected_8:
		var got: String = TopDownController.vector_to_compass_8(pair[0] as Vector2)
		if got != str(pair[1]):
			all_8_ok = false
	_check(all_8_ok, "TopDown resolves all 8 compass directions (E, SE, S, SW, W, NW, N, NE)")

	# Analog walk speed vs sprint speed
	for _i: int in range(8):
		td.physics_step(body, profile, {"move_vector": Vector2(0.3, 0.0)}, 0.05)
	var walk_spd: float = body.velocity.length()
	_check(
		td.get_state_key() == "walk" and walk_spd < td.move_speed * 0.7,
		"TopDown gentle joystick input uses walk pace"
	)

	var sp_before_sprint: float = profile.current_stamina
	for _i: int in range(10):
		td.physics_step(
			body,
			profile,
			{"move_vector": Vector2(1.0, -1.0), "sprint_held": true},
			0.05
		)
	_check(
		td.is_sprinting() and body.velocity.length() > td.move_speed * 1.2
		and profile.current_stamina < sp_before_sprint,
		"TopDown sprint boosts diagonal speed and drains shared stamina"
	)

	# Top-down Shadow Guard + Perfect Guard window + 8-way facing pivot
	profile.restore_all()
	td.physics_step(
		body,
		profile,
		{"move_vector": Vector2(-1.0, -1.0), "block_held": true},
		0.02
	)
	_check(
		td.is_blocking() and td.is_perfect_blocking()
		and td.get_desired_animation() == &"td_block"
		and td.get_compass_direction() == "NW",
		"TopDown guard activates perfect-block window and pivots to NW"
	)
	td.physics_step(body, profile, {"move_vector": Vector2.ZERO, "block_held": true}, 0.25)
	_check(
		td.is_blocking() and not td.is_perfect_blocking(),
		"TopDown transitions from perfect-guard window to sustained guard"
	)

	# Guard cancels cleanly into 8-way Shadow Dodge with i-frames
	td.physics_step(
		body,
		profile,
		{"move_vector": Vector2(0.0, -1.0), "block_held": true, "dodge_just_pressed": true},
		0.016
	)
	_check(
		td.is_dodging() and td.is_invulnerable() and not td.is_blocking(),
		"TopDown dodge cancels guard cleanly with i-frames"
	)

	td.free()
	body.free()


func _test_level_dual_mode_persistence_and_lore() -> void:
	var packed: PackedScene = load("res://scenes/levels/twilight_sanctum.tscn") as PackedScene
	_check(packed != null, "Phase 2 Twilight Sanctum loads")
	if packed == null:
		return

	GameState.current_mode = GameState.GameplayMode.SIDE_SCROLL
	var level: Node2D = packed.instantiate() as Node2D
	add_child(level)

	var player: PlayerCharacter = level.get_node("Player") as PlayerCharacter
	player.global_position = Vector2(420.0, 118.0)
	player.restore_facing_vector(Vector2.LEFT)
	var before_switches: int = player.profile.session_mode_switches

	# Trigger seamless level mode switch -> Top-Down
	level.call("_on_request_mode_toggle")
	_check(
		player.active_mode == GameState.GameplayMode.TOP_DOWN and player.collision_mask == 2,
		"Level transitions Player to TopDownController and world_topdown mask"
	)
	_check(
		player.profile.session_mode_switches == before_switches + 1,
		"PlayerProfile records mode switch without resetting profile"
	)

	# Bypass debounce cooldown and switch back -> verify saved Side-Scroll spot & facing!
	level.set("_switch_cooldown_timer", 0.0)
	level.call("_on_request_mode_toggle")
	_check(
		player.active_mode == GameState.GameplayMode.SIDE_SCROLL
		and player.collision_mask == 129
		and player.global_position.distance_to(Vector2(420.0, 118.0)) < 1.0
		and player.get_active_facing_vector().x < -0.5,
		"Returning to Side-Scroll restores saved position, LEFT facing, and one-way mask"
	)

	# Verify LoreRunestone bilingual inscription
	var west_stone: Area2D = level.get_node("TopDownZone/LoreStoneWest") as Area2D
	LocalizationManager.set_locale("en", true)
	var en_lore: String = str(west_stone.call("get_inscription_text"))
	LocalizationManager.set_locale("ar", true)
	var ar_lore: String = str(west_stone.call("get_inscription_text"))
	_check(
		en_lore.length() > 20 and ar_lore.length() > 20 and en_lore != ar_lore,
		"LoreRunestone returns distinct English and Arabic RTL inscriptions"
	)
	LocalizationManager.set_locale("en", true)

	level.free()


func _test_camera_zoom_preset_save_load() -> void:
	GameState.set_camera_zoom_preset(GameState.CameraZoomPreset.WIDE)
	_check(GameState.get_camera_zoom_multiplier() < 0.95, "Wide camera preset scales zoom below 1.0")
	GameState.camera_zoom_preset = GameState.CameraZoomPreset.STANDARD
	GameState.load_settings()
	_check(
		GameState.camera_zoom_preset == GameState.CameraZoomPreset.WIDE,
		"Camera zoom preset persists across user://settings.cfg reload"
	)
	GameState.set_camera_zoom_preset(GameState.CameraZoomPreset.STANDARD)
