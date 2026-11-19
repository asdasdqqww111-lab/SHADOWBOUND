extends Node
## Native Phase 5 regression suite. Isolates saves, deterministic loot and live class abilities.

const SAVE: String = "user://phase5_test_progress.json"
var _passed: int = 0
var _failed: int = 0
var _manager: ProgressionManager = ProgressionManager.new()


func _ready() -> void:
	_run.call_deferred()


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("[PASS] %s" % label)
	else:
		_failed += 1
		push_error("[FAIL] %s" % label)


func _new_profile() -> PlayerProfile:
	var profile: PlayerProfile = PlayerProfile.new()
	_manager.prepare_profile(profile)
	return profile


func _run() -> void:
	_manager.autosave_enabled = false
	_manager.save_path = SAVE
	_cleanup()
	_test_equipment()
	_test_upgrades()
	_test_classes_and_talents()
	_test_loot()
	_test_saves()
	await _test_live_skills_and_ui()
	_cleanup()
	print("RESULTS: %d passed, %d failed" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _test_equipment() -> void:
	var profile: PlayerProfile = _new_profile()
	var armory: ArmoryService = _manager.armory
	_check(profile.inventory.add("rust_blade"), "Owned gear occupies one slot")
	_check(not profile.inventory.add("rust_blade") and not profile.inventory.add("dusk_mail", 2),
		"Unique gear cannot be added twice or in bulk")
	_check(armory.equip(profile, "eclipse_blade") == "build.invalid", "Cannot equip unowned gear")
	_check(armory.equip(profile, "health_potion") == "build.invalid", "Cannot equip consumables")
	_check(armory.equip(profile, "rust_blade") == "build.equipped" and profile.base_attack == 21,
		"Equipping owned weapon affects combat attack")
	profile.apply_progression(_manager.config)
	profile.apply_progression(_manager.config)
	_check(profile.base_attack == 21, "Repeated recalculation never compounds gear bonuses")
	_check(not _manager.discard_item(profile, "rust_blade"), "Equipped item cannot be discarded")
	profile.inventory.add("violet_sabre")
	armory.equip(profile, "violet_sabre")
	_check(profile.base_attack == 24 and profile.inventory.count("rust_blade") == 1,
		"Replacing weapon removes old bonus without destroying owned item")
	armory.equip(profile, "violet_sabre")
	_check(profile.base_attack == 18 and profile.build.equipped.weapon == "", "Equip toggle removes stats")
	profile.inventory.add("dusk_mail")
	profile.inventory.add("cyan_charm")
	armory.equip(profile, "dusk_mail")
	armory.equip(profile, "cyan_charm")
	_check(profile.max_hp == 130 and profile.defense == 6 and profile.max_mp == 95,
		"Armor and charm occupy distinct simultaneous slots")
	profile.current_hp = 0
	armory.select_class(profile, "knight")
	armory.equip(profile, "rust_blade")
	_check(profile.is_defeated(), "Class/equipment changes do not resurrect defeated players")
	profile.build.upgrades["violet_sabre"] = 3
	_check(_manager.discard_item(profile, "violet_sabre") and not profile.build.upgrades.has("violet_sabre"),
		"Discarding unequipped upgraded gear clears its enhancement")
	profile.inventory.load_dictionary({"rust_blade": 24, "night_dagger": 2})
	_check(profile.inventory.count("rust_blade") == 1 and profile.inventory.count("night_dagger") == 1,
		"Save import enforces uniqueness")


func _test_upgrades() -> void:
	var profile: PlayerProfile = _new_profile()
	var armory: ArmoryService = _manager.armory
	profile.inventory.add("rust_blade")
	profile.wallet.credit("gold", 1000)
	var before: Dictionary = profile.wallet.to_dictionary()
	_check(armory.upgrade(profile, "rust_blade") == "build.no_resources"
		and profile.wallet.to_dictionary() == before, "Missing fragments never charge currency")
	profile.inventory.add("shadow_fragment", 99)
	profile.wallet.spend({"gold": 1000})
	_check(armory.upgrade(profile, "rust_blade") == "build.no_resources"
		and profile.inventory.count("shadow_fragment") == 99, "Missing gold never consumes fragments")
	_check(armory.upgrade(profile, "eclipse_blade") == "build.invalid", "Cannot upgrade unowned gear")
	_check(armory.upgrade(profile, "shadow_fragment") == "build.invalid", "Cannot upgrade materials")
	profile.wallet.credit("gold", 1000)
	armory.equip(profile, "rust_blade")
	for step: int in range(1, 4):
		var cost: Dictionary = armory.upgrade_cost(profile, "rust_blade")
		_check(int(cost.gold) == step * 25 and int(cost.fragments) == step * 2,
			"Enhancement +%d has configured cost" % step)
		_check(armory.upgrade(profile, "rust_blade") == "build.upgraded",
			"Enhancement +%d succeeds" % step)
	_check(is_equal_approx(profile.base_attack, 22.8), "Equipped enhancement changes attack immediately")
	var fragments: int = profile.inventory.count("shadow_fragment")
	before = profile.wallet.to_dictionary()
	_check(armory.upgrade(profile, "rust_blade") == "build.no_resources"
		and before == profile.wallet.to_dictionary()
		and fragments == profile.inventory.count("shadow_fragment"), "Missing +4 crystal causes no partial charge")
	profile.wallet.credit("magic_crystals", 2)
	_check(armory.upgrade(profile, "rust_blade") == "build.upgraded", "+4 consumes crystal")
	_check(armory.upgrade(profile, "rust_blade") == "build.upgraded", "+5 consumes crystal")
	_check(profile.wallet.balance("gold") == 625 and profile.inventory.count("shadow_fragment") == 69
		and profile.wallet.balance("magic_crystals") == 0,
		"Full smith chain charges exactly 375 gold/30 fragments/2 crystals")
	before = profile.wallet.to_dictionary()
	_check(armory.upgrade(profile, "rust_blade") == "build.max_upgrade"
		and before == profile.wallet.to_dictionary(), "Enhancement cap rejects without charging")
	_check(profile.base_attack == 24, "+5 doubles base item stats, not entire character attack")


func _test_classes_and_talents() -> void:
	var profile: PlayerProfile = _new_profile()
	var armory: ArmoryService = _manager.armory
	_check(armory.select_class(profile, "hacker") == "build.invalid", "Unknown class rejected")
	_check(armory.unlock(profile, "mage.focus") == "build.invalid", "Cannot unlock inactive class talent")
	_check(armory.unlock(profile, "warrior.mastery") == "build.locked", "Talent respects level and prerequisite")
	_check(armory.unlock(profile, "warrior.focus") == "build.learned" and profile.base_attack == 20,
		"First level grants one spendable skill point")
	armory.unlock(profile, "warrior.focus")
	_check(BuildRules.points_spent(profile, armory.definitions) == 1, "Repeat unlock cannot spend points twice")
	armory.select_class(profile, "mage")
	_check(profile.max_mp == 110 and profile.base_attack == 16, "Mage class removes inactive warrior talent bonus")
	_check(armory.unlock(profile, "mage.focus") == "build.no_points", "Points shared across all five class trees")
	profile.total_xp = 2800
	profile.apply_progression(_manager.config)
	_check(profile.level >= 8, "Awakening fixture reaches required level")
	armory.select_class(profile, "warrior")
	_check(armory.unlock(profile, "warrior.mastery") == "build.learned", "Mastery unlocks after focus")
	_check(armory.unlock(profile, "warrior.awakening") == "build.learned", "Awakening unlocks after mastery")
	_check(is_equal_approx(BuildRules.skill_power(profile), 1.62), "Mastery and awakening multiply active skill power")
	var spent: int = BuildRules.points_spent(profile, armory.definitions)
	profile.current_mp = 1
	for class_id: String in armory.definitions.classes:
		armory.select_class(profile, class_id)
		_check(profile.class_id == class_id and profile.current_mp == 1
			and BuildRules.points_spent(profile, armory.definitions) == spent,
			"Switch to %s preserves spent points and never refills MP" % class_id)
	armory.select_class(profile, "assassin")
	_check(is_equal_approx(profile.crit_chance, 0.2), "Assassin grants critical chance")
	_check(BuildRules.skill_power(profile) == 1, "Inactive class mastery cannot boost another skill")


func _test_loot() -> void:
	var profile: PlayerProfile = _new_profile()
	var armory: ArmoryService = _manager.armory
	_check(armory.roll_loot(profile, false, 0.35, 0).outcome == "none", "Regular drop cutoff is exactly 35 percent")
	var loot: Dictionary = armory.roll_loot(profile, false, 0.3499, 0)
	_check(loot.outcome == "added" and loot.item_id == "rust_blade", "Weighted regular loot lower boundary")
	loot = armory.roll_loot(profile, false, 0, 0)
	_check(loot.outcome == "duplicate" and profile.wallet.balance("gold") == 15,
		"Unique duplicates convert to configured gold instead of extra copies")
	profile.wallet.credit("gold", profile.wallet.limit - 15)
	loot = armory.roll_loot(profile, false, 0, 0)
	_check(loot.outcome == "duplicate" and int(loot.gold) == 0, "Duplicate compensation respects wallet cap")
	loot = armory.roll_loot(profile, true, 1, 1)
	_check(loot.outcome == "added" and loot.item_id == "royal_sigil", "Boss guarantees gear at weighted upper boundary")
	profile.inventory.capacity = profile.inventory.used_slots()
	loot = armory.roll_loot(profile, true, 1, 0)
	_check(loot.outcome == "full" and profile.inventory.count("rift_staff") == 0,
		"Full bag returns explicit loot failure, without partial item")
	profile = _new_profile()
	var boss: EnemyStats = load("res://resources/combat/eclipse_warden_stats.tres") as EnemyStats
	var reward: Dictionary = _manager.award_enemy(profile, boss, 1, 0)
	_check(reward.loot.item_id == "rift_staff" and profile.inventory.count("rift_staff") == 1,
		"Actual boss reward integrates deterministic gear roll")
	_check(profile.wallet.balance("diamonds") == 3 and profile.inventory.count("eclipse_sigil") == 1,
		"Gear loot supplements rather than replaces Phase 4 rewards")


func _test_saves() -> void:
	var profile: PlayerProfile = _new_profile()
	var armory: ArmoryService = _manager.armory
	profile.total_xp = 2800
	profile.apply_progression(_manager.config)
	profile.inventory.add("night_dagger")
	profile.build.upgrades["night_dagger"] = 4
	armory.select_class(profile, "assassin")
	armory.equip(profile, "night_dagger")
	armory.unlock(profile, "assassin.focus")
	armory.unlock(profile, "assassin.mastery")
	_check(_manager.save_progress(profile) == OK, "Schema 2 save writes class/equipment/upgrade/talents")
	var restored: PlayerProfile = _new_profile()
	_check(_manager.load_progress(restored) and restored.build.to_dictionary() == profile.build.to_dictionary()
		and restored.class_id == "assassin" and restored.base_attack == profile.base_attack,
		"Schema 2 round-trip rebuilds derived stats exactly")
	_manager.autosave_enabled = true
	armory.equip(profile, "night_dagger")
	_check(_manager.load_progress(restored) and restored.build.equipped.weapon == "",
		"Armory mutation automatically checkpoints through shared progression service")
	_manager.autosave_enabled = false
	_write({"version": 1, "total_xp": 100, "wallet": {"gold": 42}, "inventory": {"mana_potion": 2}})
	_check(_manager.load_progress(restored) and restored.level == 2 and restored.class_id == "warrior"
		and restored.build.talents.is_empty() and restored.build.equipped.weapon == ""
		and restored.wallet.balance("gold") == 42 and restored.inventory.count("mana_potion") == 2,
		"Phase 4 schema 1 migrates without losing progress or retaining stale build")
	_check(_manager.save_progress(restored) == OK
		and JSON.parse_string(FileAccess.get_file_as_string(SAVE)).version == 2,
		"Migrated progress writes schema 2 on next checkpoint")
	_write({"version": 2, "total_xp": 0, "wallet": {}, "inventory": {"rust_blade": 24},
		"class_id": "unknown", "build": {"equipped": {"weapon": "eclipse_blade", "armor": "rust_blade"},
		"upgrades": {"rust_blade": 999, "eclipse_blade": 4},
		"talents": ["warrior.awakening", "warrior.focus", "mage.focus", "unknown"]}})
	_manager.load_progress(restored)
	_check(restored.class_id == "warrior" and restored.build.equipped.weapon == ""
		and restored.build.equipped.armor == "", "Save recovery rejects unknown class, unowned gear and wrong slots")
	_check(restored.inventory.count("rust_blade") == 1 and int(restored.build.upgrades.get("rust_blade")) == 5
		and not restored.build.upgrades.has("eclipse_blade"), "Recovery clamps owned enhancements and removes unowned ones")
	_check(restored.build.talents == ["warrior.focus"],
		"Recovery enforces talent level, prerequisites and global point budget")
	_write({"version": 2, "total_xp": 0, "wallet": {}, "inventory": {}, "class_id": [], "build": []})
	_check(_manager.load_progress(restored) and restored.class_id == "warrior"
		and restored.build.talents.is_empty(), "Malformed optional build data recovers safely")
	_write({"version": 3, "total_xp": 0, "wallet": {}, "inventory": {}})
	_check(_manager.save_progress(restored) == ERR_FILE_UNRECOGNIZED, "Future schema checkpoint cannot be overwritten")
	_write({"version": 999999999999, "total_xp": 0, "wallet": {}, "inventory": {}})
	_check(_manager.save_progress(restored) == ERR_FILE_UNRECOGNIZED, "Very large future schema is also protected")
	_cleanup()


func _test_live_skills_and_ui() -> void:
	var old_profile: PlayerProfile = GameState.player_profile
	var old_autosave: bool = GameState.progression.autosave_enabled
	GameState.progression.autosave_enabled = false
	GameState.player_profile = _new_profile()
	GameState.current_mode = GameState.GameplayMode.TOP_DOWN
	var level: Node2D = load("res://scenes/levels/twilight_sanctum.tscn").instantiate() as Node2D
	add_child(level)
	level.set_physics_process(false)
	var player: PlayerCharacter = level.get_node("Player") as PlayerCharacter
	player.set_physics_process(false)
	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
	var skill: ClassSkillController = player.get_node("ClassSkillController") as ClassSkillController
	skill.set_physics_process(false)
	var enemy: EnemyBase = level.get_node("TopDownZone/UmbralHoundCourtyard") as EnemyBase
	enemy.current_hp = 10000
	player.global_position = Vector2(2800, 500)
	var face: Vector2 = player.get_active_facing_vector()
	enemy.global_position = player.global_position + face * 70
	var before_hp: float = enemy.current_hp
	_check(InputMap.has_action("class_skill"), "Class skill input action exists")
	_check(skill.try_cast() == "skill.cast" and enemy.current_hp < before_hp,
		"Warrior skill damages a real same-mode enemy")
	_check(player.profile.current_mp == 65 and skill.cooldown_remaining == 6,
		"Warrior pays configured MP and starts cooldown")
	_check(skill.try_cast() == "skill.cooldown" and player.profile.current_mp == 65,
		"Cooldown rejection costs no mana")
	skill._physics_process(2)
	_check(skill.cooldown_remaining == 4, "Cooldown decays with gameplay time")
	var armory: ArmoryService = GameState.progression.armory
	armory.select_class(player.profile, "mage")
	_check(skill.try_cast() == "skill.cooldown", "Changing class cannot bypass cooldown")
	skill.cooldown_remaining = 0
	player.profile.current_mp = 0
	_check(skill.try_cast() == "skill.no_mana" and skill.cooldown_remaining == 0,
		"Insufficient MP does not start cooldown")
	player.profile.restore_all()
	_check(skill.try_cast() == "skill.cast", "Mage skill casts")
	var bolts: Array[Node] = get_tree().get_nodes_in_group("projectiles")
	_check(bolts.size() == 3, "Mage spawns three friendly bolts")
	before_hp = enemy.current_hp
	(bolts[1] as ClassSkillBolt).gameplay_mode = GameState.GameplayMode.SIDE_SCROLL
	(bolts[1] as ClassSkillBolt)._on_area_entered(enemy.hurtbox)
	_check(enemy.current_hp == before_hp, "Friendly bolts cannot damage inactive-mode enemies")
	(bolts[0] as ClassSkillBolt)._on_area_entered(enemy.hurtbox)
	_check(enemy.current_hp < before_hp, "Friendly bolt hits actual enemy hurtbox")
	var after_hp: float = enemy.current_hp
	(bolts[0] as ClassSkillBolt)._on_area_entered(enemy.hurtbox)
	_check(enemy.current_hp == after_hp, "Spent bolt cannot hit twice")
	armory.select_class(player.profile, "assassin")
	player.profile.restore_all()
	skill.cooldown_remaining = 0
	var position_before: Vector2 = player.global_position
	_check(skill.try_cast() == "skill.cast" and player.global_position.distance_to(position_before) > 50,
		"Assassin blink moves the actual collision body")
	_check(player.is_invulnerable(), "Assassin gains brief immunity")
	armory.select_class(player.profile, "knight")
	player.profile.restore_all()
	player.profile.current_hp = 40
	skill.cooldown_remaining = 0
	_check(skill.try_cast() == "skill.cast" and player.profile.current_hp > 40,
		"Knight skill heals real profile")
	_check(player.is_invulnerable() and player.profile.current_mp == 60, "Knight ward grants immunity and pays MP")
	armory.select_class(player.profile, "summoner")
	player.profile.restore_all()
	skill.cooldown_remaining = 0
	_check(skill.try_cast() == "skill.cast" and skill.get_child_count() == 1,
		"Summoner creates a real timed spirit")
	var spirit: SpiritCompanion = skill.get_child(0) as SpiritCompanion
	spirit.set_physics_process(false)
	enemy.global_position = player.global_position + Vector2(70, 0)
	before_hp = enemy.current_hp
	_check(spirit.attack_nearest() and enemy.current_hp < before_hp, "Spirit attacks same-mode real enemy")
	skill.cooldown_remaining = 0
	GameState.set_inventory_open(true)
	var mp: float = player.profile.current_mp
	_check(skill.try_cast() == "skill.busy" and player.profile.current_mp == mp,
		"Inventory pause blocks skill casts without payment")
	var panel: Node = level.get_node("InventoryPanel")
	var tabs: TabContainer = panel.get("tabs") as TabContainer
	_check(tabs.get_tab_count() == 2, "Satchel exposes inventory and character tabs")
	var build_panel: Node = tabs.get_node("Builds/Character")
	_check((build_panel.get("class_selector") as OptionButton).item_count == 5,
		"Character tab exposes all five classes")
	LocalizationManager.set_locale("ar", true)
	_check(tabs.is_layout_rtl(), "Character tabs inherit Arabic RTL")
	_check(tabs.get_tab_title(1) == LocalizationManager.translate_key("build.tab"), "Character tab title localizes")
	player.profile.inventory.add("rust_blade")
	panel.set("_selected_id", "rust_blade")
	panel.call("_refresh")
	panel.call("_use_selected")
	_check(player.profile.build.is_equipped("rust_blade") and (panel.get("discard_button") as Button).disabled,
		"Real equip button updates stats and protects equipped discard")
	player.profile.wallet.credit("gold", 100)
	player.profile.inventory.add("shadow_fragment", 10)
	panel.call("_upgrade_selected")
	_check(int(player.profile.build.upgrades.get("rust_blade", 0)) == 1, "Real forge button applies enhancement")
	GameState.set_inventory_open(false)
	skill.cooldown_remaining = 0
	player.active_controller.trigger_hurt_stun(0.5)
	_check(skill.try_cast() == "skill.busy", "Hurt stun blocks class casting")
	player.active_controller.activate(player)
	player.profile.current_hp = 0
	_check(skill.try_cast() == "skill.busy", "Defeated players cannot cast")
	player.profile.restore_all()
	spirit._physics_process(spirit.duration + 0.1)
	_check(spirit.is_queued_for_deletion(), "Companion expires after its configured lifetime")
	armory.select_class(player.profile, "mage")
	skill._physics_process(0)
	_check(spirit.is_queued_for_deletion(), "Changing class removes summoned companion")
	LocalizationManager.set_locale("en", true)
	level.free()
	GameState.player_profile = old_profile
	GameState.progression.autosave_enabled = old_autosave
	await get_tree().process_frame


func _write(data: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(SAVE, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()


func _cleanup() -> void:
	for suffix: String in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(SAVE + suffix):
			DirAccess.remove_absolute(SAVE + suffix)
