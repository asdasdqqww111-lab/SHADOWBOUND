class_name ProgressionManager
extends RefCounted
## Phase 4 progression service. Saves only progression, never enemy/world/session state.

signal changed
signal rewards_granted(summary: Dictionary)
signal save_failed

const CONFIG_PATH: String = "res://data/config/progression_config.json"
const CATALOG_PATH: String = "res://data/items/item_catalog.json"
const SAVE_VERSION: int = 1
const MAX_SAVE_BYTES: int = 65536

var config: Dictionary = {}
var catalog: Dictionary = {}
var save_path: String = "user://progression.json"
var autosave_enabled: bool = true
var last_save_error: Error = OK


func _init() -> void:
	config = _read_dictionary(CONFIG_PATH)
	catalog = _read_dictionary(CATALOG_PATH)


func _read_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_SAVE_BYTES:
		return {}
	var parser: JSON = JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		return {}
	var data: Variant = parser.data
	return data if data is Dictionary else {}


func prepare_profile(profile: PlayerProfile) -> void:
	profile.inventory.catalog = catalog
	profile.inventory.capacity = int(config.get("inventory_capacity", 24))
	profile.wallet.limit = int(config.get("max_currency", 999999999))
	profile.apply_progression(config)


func initialize(profile: PlayerProfile) -> void:
	prepare_profile(profile)
	if not load_progress(profile):
		var starter: Dictionary = config.get("starter_items", {})
		for item_id: String in starter:
			profile.inventory.add(item_id, int(starter[item_id]))
	profile.restore_all()


func award_enemy(profile: PlayerProfile, stats: EnemyStats) -> Dictionary:
	var was_alive: bool = not profile.is_defeated()
	var max_xp: int = ProgressionRules.max_total_xp(config)
	var awarded_xp: int = mini(maxi(0, stats.xp_reward), max_xp - profile.total_xp)
	profile.total_xp += awarded_xp
	var summary: Dictionary = profile.apply_progression(config, was_alive)
	summary["xp_awarded"] = awarded_xp
	summary["gold_awarded"] = _credit_reward(profile, "gold", maxi(0, stats.gold_reward))
	summary["diamonds_awarded"] = 0
	summary["crystals_awarded"] = 0
	var item_id: String = str(config.get("enemy_material", "shadow_fragment"))
	if stats.is_boss:
		var bonus: Dictionary = config.get("boss_rewards", {})
		summary["diamonds_awarded"] = _credit_reward(profile, "diamonds", int(bonus.get("diamonds", 3)))
		summary["crystals_awarded"] = _credit_reward(profile, "magic_crystals", int(bonus.get("magic_crystals", 5)))
		item_id = str(bonus.get("item", "eclipse_sigil"))
	summary["item_id"] = item_id
	summary["item_added"] = profile.inventory.add(item_id)
	_commit(profile)
	rewards_granted.emit(summary)
	return summary


func _credit_reward(profile: PlayerProfile, currency: String, amount: int) -> int:
	var granted: int = mini(maxi(0, amount), profile.wallet.limit - profile.wallet.balance(currency))
	profile.wallet.credit(currency, granted)
	return granted


func use_item(profile: PlayerProfile, item_id: String) -> String:
	if profile.is_defeated():
		return "inventory.cannot_use_fallen"
	var spec: Dictionary = catalog.get(item_id, {})
	if spec.get("kind", "") != "consumable" or profile.inventory.count(item_id) <= 0:
		return "inventory.cannot_use"
	var stat: String = str(spec.get("stat", ""))
	var restored: float = 0.0
	var amount: float = float(spec.get("amount", 0))
	match stat:
		"hp":
			restored = profile.heal(amount)
		"mp":
			var before: float = profile.current_mp
			profile.restore_mp(amount)
			restored = profile.current_mp - before
		"stamina":
			var before: float = profile.current_stamina
			profile.regenerate_stamina(amount)
			restored = profile.current_stamina - before
	if restored <= 0.0:
		return "inventory.already_full"
	profile.inventory.remove(item_id)
	_commit(profile)
	return "inventory.used"


func discard_item(profile: PlayerProfile, item_id: String) -> bool:
	if not profile.inventory.remove(item_id):
		return false
	_commit(profile)
	return true


func _commit(profile: PlayerProfile) -> void:
	last_save_error = save_progress(profile) if autosave_enabled else OK
	if last_save_error != OK:
		save_failed.emit()
	changed.emit()


func save_progress(profile: PlayerProfile) -> Error:
	var on_disk: Dictionary = _read_dictionary(save_path)
	var disk_version: int = ProgressionRules.safe_int(on_disk.get("version", 0), 0, 0, 999999)
	if disk_version > SAVE_VERSION:
		return ERR_FILE_UNRECOGNIZED
	var data: Dictionary = {
		"version": SAVE_VERSION, "total_xp": profile.total_xp,
		"wallet": profile.wallet.to_dictionary(), "inventory": profile.inventory.to_dictionary(),
	}
	var file: FileAccess = FileAccess.open(save_path + ".tmp", FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data))
	file.flush()
	var error: Error = file.get_error()
	file.close()
	if error != OK:
		return error
	# Keep one known previous checkpoint if the primary becomes corrupt or interrupted.
	var previous: Dictionary = _validated_save(save_path)
	if not previous.is_empty():
		var backup: FileAccess = FileAccess.open(save_path + ".bak", FileAccess.WRITE)
		if backup == null:
			return FileAccess.get_open_error()
		backup.store_string(JSON.stringify(previous))
		backup.close()
	return DirAccess.rename_absolute(save_path + ".tmp", save_path)


func _validated_save(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_SAVE_BYTES:
		return {}
	var data: Dictionary = _read_dictionary(path)
	if data.get("version") != SAVE_VERSION or not data.get("wallet") is Dictionary:
		return {}
	if not data.get("inventory") is Dictionary:
		return {}
	var xp_value: int = ProgressionRules.safe_int(data.get("total_xp"), -1, 0, ProgressionRules.max_total_xp(config))
	return data if xp_value >= 0 else {}


func load_progress(profile: PlayerProfile) -> bool:
	var data: Dictionary = _validated_save(save_path)
	if data.is_empty():
		data = _validated_save(save_path + ".bak")
	if data.is_empty():
		return false
	prepare_profile(profile)
	profile.total_xp = int(data.total_xp)
	profile.wallet.load_dictionary(data.wallet)
	profile.inventory.load_dictionary(data.inventory)
	profile.apply_progression(config)
	return true
