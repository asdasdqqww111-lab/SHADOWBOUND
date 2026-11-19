extends Node
## Phase 4 actual Godot regression tests, isolated from the player's normal progression file.

var _passed: int = 0
var _failed: int = 0
var _manager: ProgressionManager = ProgressionManager.new()
const TEST_SAVE: String = "user://phase4_test_progress.json"


func _ready() -> void:
	_run.call_deferred()


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("[PASS] %s" % label)
	else:
		_failed += 1
		push_error("[FAIL] %s" % label)


func _profile() -> PlayerProfile:
	var profile: PlayerProfile = PlayerProfile.new()
	_manager.prepare_profile(profile)
	return profile


func _run() -> void:
	_manager.autosave_enabled = false
	_manager.save_path = TEST_SAVE
	_cleanup()
	_test_xp_and_rank()
	_test_wallet()
	_test_inventory()
	_test_consumables_and_rewards()
	_test_persistence()
	await _test_live_level()
	_cleanup()
	print("RESULTS: %d passed, %d failed" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _test_xp_and_rank() -> void:
	var cfg: Dictionary = _manager.config
	_check(not cfg.is_empty() and _manager.catalog.size() == 14, "Progression config and fourteen items load")
	_check(ProgressionRules.xp_for_level(1, cfg) == 100, "Level 1 needs 100 XP")
	_check(ProgressionRules.xp_for_level(2, cfg) == 140, "Level 2 needs 140 XP")
	var below: Dictionary = ProgressionRules.describe(99, cfg)
	var boundary: Dictionary = ProgressionRules.describe(100, cfg)
	_check(int(below.level) == 1 and int(below.xp) == 99, "XP below threshold remains in level")
	_check(int(boundary.level) == 2 and int(boundary.xp) == 0, "Exact threshold advances with zero remainder")
	var accumulated: int = 0
	var ranks: Array = cfg.ranks
	for rank_data: Dictionary in ranks:
		accumulated = 0
		for value: int in range(1, int(rank_data.level)):
			accumulated += ProgressionRules.xp_for_level(value, cfg)
		var result: Dictionary = ProgressionRules.describe(accumulated, cfg)
		_check(str(result.rank) == str(rank_data.code), "Rank boundary: %s" % rank_data.code)
	var profile: PlayerProfile = _profile()
	profile.total_xp = 500
	var summary: Dictionary = profile.apply_progression(cfg, true)
	_check(profile.level == 4 and int(summary.levels_gained) == 3, "One award supports multiple level-ups")
	_check(profile.max_hp == 156 and profile.base_attack == 24 and profile.defense == 5.5, "Stats derive from level")
	_check(profile.current_hp == profile.max_hp, "Living level-up refills vitals")
	profile.current_hp = 0
	profile.total_xp = 800
	profile.apply_progression(cfg, false)
	_check(profile.current_hp == 0, "Derived progression does not revive a fallen player")
	profile.total_xp = 999999999
	profile.apply_progression(cfg)
	_check(profile.level == 60 and profile.rank_code == "SSS", "Level cap is 60 / SSS")
	var old_attack: float = profile.base_attack
	profile.apply_progression(cfg)
	_check(profile.base_attack == old_attack, "Reapplying derived stats never compounds growth")


func _test_wallet() -> void:
	var wallet: CurrencyWallet = CurrencyWallet.new()
	_check(wallet.credit("gold", 100) and wallet.balance("gold") == 100, "Credit gold")
	_check(not wallet.credit("gold", -1) and not wallet.credit("unknown", 5), "Reject invalid credits")
	_check(not wallet.spend({"gold": 20, "diamonds": 1}) and wallet.balance("gold") == 100,
		"Unaffordable multi-currency spend is atomic")
	_check(not wallet.spend({"gold": 1.5}) and not wallet.spend({"gold": -1}), "Reject fractional/negative costs")
	_check(wallet.credit("diamonds", 5) and wallet.credit("magic_crystals", 8), "All three currencies supported")
	_check(wallet.spend({"gold": 20, "diamonds": 2}) and wallet.balance("diamonds") == 3,
		"Affordable multi-currency spend commits")
	var copied: Dictionary = wallet.to_dictionary()
	copied.gold = 999
	_check(wallet.balance("gold") == 80, "Wallet serialization cannot mutate balances")
	wallet.load_dictionary({"gold": -1, "diamonds": "999", "magic_crystals": 2.5})
	_check(wallet.balance("gold") == 0 and wallet.balance("diamonds") == 0
		and wallet.balance("magic_crystals") == 0, "Malformed wallet balances sanitize to zero")
	wallet.limit = 10
	_check(wallet.credit("gold", 10) and not wallet.credit("gold", 1), "Wallet cap cannot overflow")


func _test_inventory() -> void:
	var inventory: InventoryState = _profile().inventory
	inventory.capacity = 2
	_check(inventory.add("health_potion", 20) and inventory.used_slots() == 1, "A full stack occupies one slot")
	_check(inventory.add("health_potion", 1) and inventory.used_slots() == 2, "Overflow starts a second stack")
	_check(not inventory.add("mana_potion", 1) and inventory.count("mana_potion") == 0,
		"Full inventory rejects entire addition")
	_check(not inventory.add("unknown", 1) and not inventory.add("health_potion", -1), "Reject unknown/negative items")
	_check(inventory.remove("health_potion", 1) and inventory.used_slots() == 1, "Removing overflow releases slot")
	_check(not inventory.remove("health_potion", 30) and inventory.count("health_potion") == 20,
		"Cannot remove more than owned")
	_check(inventory.remove("health_potion", 20) and inventory.used_slots() == 0, "Empty stacks disappear")
	inventory.load_dictionary({"unknown": 99, "mana_potion": -1, "health_potion": "5", "shadow_fragment": 2})
	_check(inventory.count("shadow_fragment") == 2 and inventory.used_slots() == 1, "Load validates item IDs/counts")
	inventory.load_dictionary({"health_potion": 40, "mana_potion": 1})
	_check(inventory.used_slots() == 2 and inventory.count("mana_potion") == 0, "Load respects slot capacity")


func _test_consumables_and_rewards() -> void:
	var profile: PlayerProfile = _profile()
	profile.inventory.add("health_potion", 2)
	_check(_manager.use_item(profile, "health_potion") == "inventory.already_full"
		and profile.inventory.count("health_potion") == 2, "Full HP never wastes potion")
	profile.current_hp = 100
	_check(_manager.use_item(profile, "health_potion") == "inventory.used"
		and profile.current_hp == 120 and profile.inventory.count("health_potion") == 1,
		"Health potion clamps restoration and consumes exactly one")
	profile.current_hp = 0
	_check(_manager.use_item(profile, "health_potion") == "inventory.cannot_use_fallen", "Fallen players cannot consume")
	profile.restore_all()
	for item_id: String in ["mana_potion", "stamina_draught"]:
		profile.inventory.add(item_id)
		profile.current_mp = 10
		profile.current_stamina = 10
		_check(_manager.use_item(profile, item_id) == "inventory.used", "Consumable works: %s" % item_id)
	profile.inventory.add("shadow_fragment")
	_check(_manager.use_item(profile, "shadow_fragment") == "inventory.cannot_use", "Materials are not consumables")
	_check(_manager.discard_item(profile, "shadow_fragment") and profile.inventory.count("shadow_fragment") == 0,
		"Discard removes exactly one item")
	_check(not _manager.discard_item(profile, "unknown"), "Discard rejects missing items")
	profile.inventory.add("shadow_fragment")
	var stats: EnemyStats = load("res://resources/combat/umbral_hound_stats.tres") as EnemyStats
	var reward: Dictionary = _manager.award_enemy(profile, stats)
	_check(int(reward.xp_awarded) == 24 and profile.wallet.balance("gold") == 12, "Enemy awards configured XP/gold")
	_check(profile.inventory.count("shadow_fragment") == 2, "Regular foe grants deterministic material")
	var boss_stats: EnemyStats = load("res://resources/combat/eclipse_warden_stats.tres") as EnemyStats
	_manager.award_enemy(profile, boss_stats)
	_check(profile.wallet.balance("diamonds") == 3 and profile.wallet.balance("magic_crystals") == 5,
		"Boss grants diamonds and magic crystals")
	_check(profile.inventory.count("eclipse_sigil") == 1, "Boss trophy goes to inventory")
	profile.inventory.capacity = profile.inventory.used_slots()
	profile.inventory.load_dictionary({"health_potion": 20 * profile.inventory.capacity})
	reward = _manager.award_enemy(profile, stats)
	_check(not bool(reward.item_added) and int(reward.gold_awarded) == 12, "Full bag preserves currency and XP rewards")
	profile.total_xp = ProgressionRules.max_total_xp(_manager.config)
	profile.apply_progression(_manager.config)
	reward = _manager.award_enemy(profile, stats)
	_check(int(reward.xp_awarded) == 0 and profile.level == 60, "XP capped without stopping other rewards")


func _write_save(text: String) -> void:
	var file: FileAccess = FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _test_persistence() -> void:
	var profile: PlayerProfile = _profile()
	profile.total_xp = 500
	profile.apply_progression(_manager.config)
	profile.wallet.credit("gold", 88)
	profile.inventory.add("mana_potion", 4)
	_check(_manager.save_progress(profile) == OK, "Progress writes atomically to user directory")
	var loaded: PlayerProfile = _profile()
	_check(_manager.load_progress(loaded) and loaded.total_xp == 500 and loaded.level == 4
		and loaded.wallet.balance("gold") == 88 and loaded.inventory.count("mana_potion") == 4,
		"Progression round trip restores derived stats/wallet/items")
	profile.total_xp = 700
	_manager.save_progress(profile)
	_write_save("{broken")
	_check(_manager.load_progress(loaded) and loaded.total_xp == 500, "Corrupt primary recovers previous backup")
	DirAccess.remove_absolute(TEST_SAVE + ".bak")
	_write_save('{"version":1,"total_xp":-1,"wallet":{},"inventory":{}}')
	_check(not _manager.load_progress(loaded), "Negative XP invalidates save")
	_write_save('{"version":1,"total_xp":0,"wallet":[],"inventory":{}}')
	_check(not _manager.load_progress(loaded), "Wrong save containers are rejected")
	_write_save(" ".repeat(65537))
	_check(not _manager.load_progress(loaded), "Oversize save is rejected before JSON parsing")
	_write_save('{"version":3,"total_xp":10,"wallet":{},"inventory":{}}')
	_check(not _manager.load_progress(loaded) and _manager.save_progress(profile) == ERR_FILE_UNRECOGNIZED,
		"Newer save schema is neither loaded nor overwritten")
	_cleanup()
	var path_before: String = _manager.save_path
	_manager.save_path = "user://nonexistent_phase4_directory/progress.json"
	_check(_manager.save_progress(profile) != OK, "Save failure is returned rather than reported as success")
	_manager.save_path = path_before
	_manager.initialize(loaded)
	_check(loaded.inventory.count("health_potion") == 3, "Fresh save grants starter supplies")
	loaded.inventory.remove("health_potion", 3)
	_manager.save_progress(loaded)
	var reloaded: PlayerProfile = _profile()
	_manager.initialize(reloaded)
	_check(reloaded.inventory.count("health_potion") == 0, "Reload never duplicates starter supplies")


func _test_live_level() -> void:
	var old_profile: PlayerProfile = GameState.player_profile
	GameState.player_profile = _profile()
	GameState.progression.prepare_profile(GameState.player_profile)
	var old_autosave: bool = GameState.progression.autosave_enabled
	GameState.progression.autosave_enabled = false
	GameState.current_mode = GameState.GameplayMode.TOP_DOWN
	var level: Node2D = load("res://scenes/levels/twilight_sanctum.tscn").instantiate() as Node2D
	add_child(level)
	level.set_physics_process(false)
	var player: PlayerCharacter = level.get_node("Player") as PlayerCharacter
	player.set_physics_process(false)
	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
	var hound: EnemyBase = level.get_node("TopDownZone/UmbralHoundCourtyard") as EnemyBase
	hound.receive_player_strike({"damage": 99999})
	hound.receive_player_strike({"damage": 99999})
	_check(player.profile.total_xp == 24 and player.profile.wallet.balance("gold") == 12,
		"Actual enemy defeat grants rewards exactly once")
	var hud: Node = level.get_node("GameHUD")
	_check(str(hud.get("reward_label").text).contains("24"), "HUD shows actual earned XP")
	level.call("reset_sanctum_trial")
	_check(player.profile.total_xp == 24 and player.profile.inventory.count("shadow_fragment") == 1,
		"Trial retry preserves progression without duplicating rewards")
	player.profile.inventory.add("health_potion", 2)
	player.profile.current_hp = 60
	GameState.set_paused(false)
	GameState.progression.last_save_error = ERR_CANT_CREATE
	GameState.set_inventory_open(true)
	var panel: Node = level.get_node("InventoryPanel")
	_check(get_tree().paused and panel.get("root").visible, "Satchel pauses combat and opens modal")
	_check(panel.get("_feedback_key") == "inventory.save_failed", "Prior autosave failure remains visible on opening")
	GameState.progression.last_save_error = OK
	panel.set("_selected_id", "health_potion")
	panel.call("_use_selected")
	_check(player.profile.current_hp == 110 and player.profile.inventory.count("health_potion") == 1,
		"Inventory Use button applies real consumable")
	LocalizationManager.set_locale("ar", true)
	_check(panel.get("root").layout_direction == Control.LAYOUT_DIRECTION_RTL, "Inventory mirrors in Arabic")
	_check(str(panel.get("item_name").text) == LocalizationManager.translate_key("item.health_potion"),
		"Selected item remains localized after locale change")
	GameState.toggle_pause()
	_check(not GameState.inventory_open and not get_tree().paused, "Back closes modal and restores gameplay")
	GameState.set_paused(true)
	GameState.set_inventory_open(true)
	GameState.set_inventory_open(false)
	_check(get_tree().paused, "Opening from Pause preserves previous paused state")
	GameState.set_paused(false)
	_check(InputMap.has_action("inventory"), "Inventory shortcut action is registered")
	var xp_before: int = player.profile.total_xp
	GameState.toggle_gameplay_mode()
	_check(player.profile.total_xp == xp_before and player.profile.inventory.count("health_potion") == 1,
		"Mode switching preserves XP and inventory")
	GameState.set_inventory_open(true)
	panel.set("_selected_id", "shadow_fragment")
	panel.call("_request_discard")
	var dialog: ConfirmationDialog = panel.get("discard_dialog") as ConfirmationDialog
	_check(dialog.visible and player.profile.inventory.count("shadow_fragment") == 1,
		"Discard requires explicit confirmation before mutating inventory")
	dialog.hide()
	_check(player.profile.inventory.count("shadow_fragment") == 1, "Cancelling discard keeps item")
	panel.call("_confirm_discard")
	_check(player.profile.inventory.count("shadow_fragment") == 0, "Confirmed discard removes one selected item")
	GameState.set_inventory_open(false)
	LocalizationManager.set_locale("en", true)
	level.free()
	GameState.player_profile = old_profile
	GameState.progression.autosave_enabled = old_autosave
	await get_tree().process_frame


func _cleanup() -> void:
	for suffix: String in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(TEST_SAVE + suffix):
			DirAccess.remove_absolute(TEST_SAVE + suffix)
