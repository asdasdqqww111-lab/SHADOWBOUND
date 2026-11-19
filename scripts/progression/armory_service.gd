class_name ArmoryService
extends RefCounted
## Equipment, class selection, talent unlocks, atomic smith transactions and weighted gear loot.

signal modified(profile: PlayerProfile)

var definitions: Dictionary = {}
var progression_config: Dictionary = {}


func equip(profile: PlayerProfile, item_id: String) -> String:
	var spec: Dictionary = profile.inventory.catalog.get(item_id, {})
	if spec.get("kind") != "equipment" or profile.inventory.count(item_id) < 1:
		return "build.invalid"
	var slot: String = str(spec.slot)
	profile.build.equipped[slot] = "" if profile.build.is_equipped(item_id) else item_id
	_finish(profile)
	return "build.equipped"


func select_class(profile: PlayerProfile, class_id: String) -> String:
	var classes: Dictionary = definitions.get("classes", {})
	if not classes.has(class_id):
		return "build.invalid"
	profile.class_id = class_id
	_finish(profile)
	return "build.class_changed"


func unlock(profile: PlayerProfile, node_id: String) -> String:
	var classes: Dictionary = definitions.get("classes", {})
	var current: Dictionary = classes.get(profile.class_id, {})
	for node: Dictionary in current.get("nodes", []):
		if str(node.id) != node_id:
			continue
		var prereq: String = str(node.get("requires", ""))
		if profile.build.talents.has(node_id):
			return "build.learned"
		if profile.level < int(node.level) or (not prereq.is_empty() and not profile.build.talents.has(prereq)):
			return "build.locked"
		if profile.level - BuildRules.points_spent(profile, definitions) < int(node.cost):
			return "build.no_points"
		profile.build.talents.append(node_id)
		_finish(profile)
		return "build.learned"
	return "build.invalid"


func upgrade_cost(profile: PlayerProfile, item_id: String) -> Dictionary:
	var next_level: int = int(profile.build.upgrades.get(item_id, 0)) + 1
	return {
		"gold": next_level * int(definitions.get("upgrade_gold_base", 25)),
		"fragments": next_level * int(definitions.get("upgrade_material_base", 2)),
		"crystals": 1 if next_level >= 4 else 0,
	}


func upgrade(profile: PlayerProfile, item_id: String) -> String:
	var spec: Dictionary = profile.inventory.catalog.get(item_id, {})
	if spec.get("kind") != "equipment" or profile.inventory.count(item_id) < 1:
		return "build.invalid"
	if int(profile.build.upgrades.get(item_id, 0)) >= int(definitions.get("upgrade_cap", 5)):
		return "build.max_upgrade"
	var cost: Dictionary = upgrade_cost(profile, item_id)
	if profile.inventory.count("shadow_fragment") < int(cost.fragments):
		return "build.no_resources"
	if not profile.wallet.spend({"gold": cost.gold, "magic_crystals": cost.crystals}):
		return "build.no_resources"
	# Both inventories were prevalidated; no partial charges on any rejection above.
	profile.inventory.remove("shadow_fragment", int(cost.fragments))
	profile.build.upgrades[item_id] = int(profile.build.upgrades.get(item_id, 0)) + 1
	_finish(profile)
	return "build.upgraded"


func roll_loot(profile: PlayerProfile, is_boss: bool, chance_roll: float, selection_roll: float) -> Dictionary:
	var loot: Dictionary = definitions.get("loot", {})
	if not is_boss and chance_roll >= float(loot.get("chance", 0.35)):
		return {"outcome": "none", "item_id": ""}
	var pool: Array = loot.get("boss" if is_boss else "regular", [])
	var weight_sum: float = 0.0
	for entry: Dictionary in pool:
		weight_sum += float(entry.weight)
	var pick: float = clampf(selection_roll, 0.0, 0.999999) * weight_sum
	var item_id: String = ""
	for entry: Dictionary in pool:
		pick -= float(entry.weight)
		if pick < 0.0:
			item_id = str(entry.id)
			break
	if item_id.is_empty():
		return {"outcome": "none", "item_id": ""}
	if profile.inventory.count(item_id) > 0:
		var gold: int = mini(int(loot.get("duplicate_gold", 15)), profile.wallet.limit - profile.wallet.balance("gold"))
		profile.wallet.credit("gold", gold)
		return {"outcome": "duplicate", "item_id": item_id, "gold": gold}
	var added: bool = profile.inventory.add(item_id)
	return {"outcome": "added" if added else "full", "item_id": item_id}


func _finish(profile: PlayerProfile) -> void:
	profile.apply_progression(progression_config)
	modified.emit(profile)
