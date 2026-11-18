extends Node
## Native Godot integration regression suite. Run test_phase3_runner.tscn after --import.

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	_run.call_deferred()


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("[PASS] %s" % label)
	else:
		_failed += 1
		push_error("[FAIL] %s" % label)


func _run() -> void:
	_test_resolver()
	_test_combo_controllers()
	await _test_arena()
	print("RESULTS: %d passed, %d failed" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _test_resolver() -> void:
	var profile: PlayerProfile = PlayerProfile.new()
	var cfg: Dictionary = GameState.get_combat_config_section("player_combat")
	var defense: Dictionary = GameState.get_combat_config_section("defense")
	var normal: Dictionary = CombatResolver.compute_player_strike(profile, cfg, 1, false, 1.0)
	var critical: Dictionary = CombatResolver.compute_player_strike(profile, cfg, 1, false, 0.0)
	var riposte: Dictionary = CombatResolver.compute_player_strike(profile, cfg, 3, true, 1.0)
	_check(is_equal_approx(float(normal.damage), 18.0), "Base sword damage is 18")
	_check(is_equal_approx(float(critical.damage), 27.0), "Deterministic critical damage is 27")
	_check(float(riposte.damage) > 48.0 and bool(riposte.breaks_shield), "Riposte finisher multiplies damage")
	var shield: Dictionary = CombatResolver.compute_enemy_damage_taken(18, 6, true, true, 0.55, false)
	var broken: Dictionary = CombatResolver.compute_enemy_damage_taken(18, 6, true, true, 0.55, true)
	_check(bool(shield.shielded) and float(shield.damage) == 6.0, "Front shield reduces normal slash")
	_check(bool(broken.shield_broken) and float(broken.damage) == 16.0, "Finisher breaks front shield")
	var outcomes: Array[String] = ["dodged", "parried", "blocked", "guard_broken", "hit"]
	for outcome: String in outcomes:
		profile.current_stamina = 5.0 if outcome == "guard_broken" else 100.0
		var incoming: Dictionary = CombatResolver.resolve_incoming_player_hit(
			24, profile, Vector2.RIGHT, Vector2.RIGHT,
			outcome == "dodged", outcome != "hit", outcome == "parried", defense
		)
		_check(str(incoming.outcome) == outcome, "Defense resolves %s" % outcome)
	var rear: Dictionary = CombatResolver.resolve_incoming_player_hit(
		24, profile, Vector2.RIGHT, Vector2.LEFT, false, true, true, defense
	)
	_check(str(rear.outcome) == "hit", "Rear attacks bypass directional perfect guard")


func _test_combo_controllers() -> void:
	var body: CharacterBody2D = CharacterBody2D.new()
	add_child(body)
	var controllers: Array[MovementControllerBase] = [SideScrollController.new(), TopDownController.new()]
	for controller: MovementControllerBase in controllers:
		var profile: PlayerProfile = PlayerProfile.new()
		controller.apply_combat_config(GameState.get_combat_config_section("player_combat"))
		controller.activate(body)
		var result: Dictionary = controller._try_process_combo_attack(true, true, profile, 0.25)
		_check(bool(result.started) and controller.get_combo_step() == 1, "Combo opens at step 1")
		var first_id: int = controller.get_attack_swing_id()
		controller._tick_combat_timers(0.10)
		controller._try_process_combo_attack(true, true, profile, 0.25)
		controller._tick_combat_timers(0.16)
		controller._try_process_combo_attack(false, true, profile, 0.25)
		_check(controller.get_combo_step() == 2, "Buffered follow-up starts step 2")
		controller._tick_combat_timers(0.27)
		controller._try_process_combo_attack(true, true, profile, 0.25)
		_check(controller.get_combo_step() == 3, "Third input starts Eclipse Finisher")
		_check(controller.get_attack_swing_id() == first_id + 2, "Each combo step has a unique swing id")
		_check(is_equal_approx(profile.current_stamina, 86.0), "Steps 2 and 3 cost 5 + 9 stamina")
		controller._tick_combat_timers(0.35)
		result = controller._try_process_combo_attack(true, true, profile, 0.25)
		_check(not bool(result.started), "Finisher recovery rejects immediate restart")
		controller._tick_combat_timers(0.27)
		controller._try_process_combo_attack(true, true, profile, 0.25)
		_check(controller.get_combo_step() == 1, "Combo restarts after finisher recovery")
		controller.trigger_hurt_stun(0.2)
		_check(controller.is_hurt_stunned() and not controller.is_attacking(), "Hurt stun cancels attack")
		controller.free()
	body.free()


func _test_arena() -> void:
	GameState.current_mode = GameState.GameplayMode.TOP_DOWN
	GameState.get_player_profile().restore_all()
	var level: Node2D = load("res://scenes/levels/twilight_sanctum.tscn").instantiate() as Node2D
	add_child(level)
	level.set_physics_process(false)
	var player: PlayerCharacter = level.get_node("Player") as PlayerCharacter
	player.set_physics_process(false)
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	_check(enemies.size() == 8, "Arena contains seven enemies and one boss")
	for enemy_node: Node in enemies:
		enemy_node.set_physics_process(false)
		var enemy: EnemyBase = enemy_node as EnemyBase
		_check(enemy.stats != null and enemy.hurtbox.collision_layer == 16, "EnemyStats and hurtbox load")

	var sentinel: EnemyBase = level.get_node("TopDownZone/ObsidianSentinelCourtyard") as EnemyBase
	sentinel.facing_vector = Vector2.RIGHT
	var small_hit: float = sentinel.receive_player_strike({
		"damage": 18, "attacker_position": sentinel.global_position + Vector2(40, 0)
	})
	var breaker_hit: float = sentinel.receive_player_strike({
		"damage": 32, "breaks_shield": true, "attacker_position": sentinel.global_position + Vector2(40, 0)
	})
	_check(breaker_hit > small_hit and sentinel.shield_broken_timer > 0, "Sentinel shield breaks in scene")

	var hound: EnemyBase = level.get_node("TopDownZone/UmbralHoundCourtyard") as EnemyBase
	var slain_before: int = player.profile.session_enemies_defeated
	hound.receive_player_strike({"damage": 9999})
	hound.receive_player_strike({"damage": 9999})
	_check(hound.is_defeated() and not hound.visible, "Enemy defeat is non-destructive")
	_check(player.profile.session_enemies_defeated == slain_before + 1, "Defeat is recorded exactly once")

	# Freeze the world but exercise actual signal wiring, physics area callbacks, and resources.
	var orb_scene: PackedScene = load("res://scenes/combat/shadow_orb_projectile.tscn") as PackedScene
	var orb: ShadowOrbProjectile = orb_scene.instantiate() as ShadowOrbProjectile
	level.add_child(orb)
	orb.set_physics_process(false)
	player.restore_facing_vector(Vector2.RIGHT)
	player.top_controller.physics_step(player, player.profile, {"block_held": true}, 0.016)
	player.profile.current_mp = 20
	orb.launch(player.global_position + Vector2(30, -10), Vector2.LEFT, 13, 200, sentinel)
	orb._on_body_entered(player)
	_check(orb.is_reflected and orb.collision_layer == 32, "Perfect guard reflects hostile projectile")
	_check(player.has_riposte_ready() and player.profile.current_mp == 28, "Parry grants Riposte and MP")
	var shield_hp: float = sentinel.current_hp
	orb._on_area_entered(sentinel.hurtbox)
	_check(sentinel.current_hp < shield_hp, "Reflected orb damages enemy hurtbox")

	# One target per swing, but every combo step can hit a continuously overlapping hurtbox.
	player.top_controller._clear_block()
	player.top_controller._active_attack_timer = 0.0
	player.top_controller._try_process_combo_attack(true, true, player.profile, 0.25)
	player.top_controller._attack_active = true
	player._last_swing_id = -1
	player._update_slash_hitbox()
	var hp_before: float = sentinel.current_hp
	player._on_slash_hitbox_area_entered(sentinel.hurtbox)
	var hp_after: float = sentinel.current_hp
	player._on_slash_hitbox_area_entered(sentinel.hurtbox)
	_check(hp_after < hp_before and sentinel.current_hp == hp_after, "Hurtbox is hit once per sword swing")
	_check(not player.has_riposte_ready(), "Successful Riposte consumes the readiness window")
	player.top_controller._tick_combat_timers(0.26)
	player.top_controller._try_process_combo_attack(true, true, player.profile, 0.25)
	player._update_slash_hitbox()
	player._on_slash_hitbox_area_entered(sentinel.hurtbox)
	_check(sentinel.current_hp < hp_after, "Next combo step can hit the same hurtbox again")

	var boss: EclipseWardenBoss = level.get_node("TopDownZone/VaelorEclipseBoss") as EclipseWardenBoss
	boss.receive_player_strike({"damage": 116.0})
	_check(boss.current_phase == 2 and boss.is_engaged, "Boss enters phase II at 65 percent")
	var phase_hp: float = boss.current_hp
	boss.receive_player_strike({"damage": 999})
	_check(boss.current_hp == phase_hp, "Phase-shift invulnerability rejects damage")
	boss._step_ai(player, 1.0)
	boss.receive_player_strike({"damage": 116.0})
	_check(boss.current_phase == 3, "Boss enters phase III at 30 percent")
	boss._step_ai(player, 1.0)
	_check(get_tree().get_nodes_in_group("projectiles").size() >= 8, "Phase III emits radial nova")
	boss.receive_player_strike({"damage": 9999})
	_check(boss.is_defeated() and not level.get_node("GameHUD").get("_boss_visible"), "Victory hides boss HUD")

	# Reset cleans up queued projectiles and revives all enemies, including the boss.
	level.call("reset_sanctum_trial")
	await get_tree().process_frame
	_check(get_tree().get_nodes_in_group("projectiles").is_empty(), "Trial reset removes projectiles")
	_check(not hound.is_defeated() and boss.current_phase == 1, "Trial reset restores enemies and boss phase I")
	_check(player.profile.current_hp == player.profile.max_hp, "Trial reset restores player vitals")

	player._hurt_invuln_timer = 0
	player.top_controller._clear_block()
	player.receive_attack({"damage": 9999})
	_check(player.is_defeated() and float(level.get("_revive_timer")) > 0, "Player defeat schedules auto-revive")
	level.call("_physics_process", 2.0)
	_check(not player.is_defeated() and player.profile.current_hp > 0, "Auto-revive restores playable state")

	LocalizationManager.set_locale("ar", true)
	var hud_root: Control = level.get_node("GameHUD/HudRoot") as Control
	_check(hud_root.layout_direction == Control.LAYOUT_DIRECTION_RTL, "Combat HUD switches to Arabic RTL")
	LocalizationManager.set_locale("en", true)
	level.free()
	await get_tree().process_frame
