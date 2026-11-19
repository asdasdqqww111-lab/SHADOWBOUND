class_name BuildRules
extends RefCounted
## Stateless, non-compounding class / talent / equipment modifiers.


static func bonuses(profile: PlayerProfile, definitions: Dictionary, catalog: Dictionary) -> Dictionary:
	var total: Dictionary = {"attack": 0.0, "defense": 0.0, "hp": 0.0, "mp": 0.0, "stamina": 0.0, "crit": 0.0}
	var classes: Dictionary = definitions.get("classes", {})
	var class_data: Dictionary = classes.get(profile.class_id, {})
	_add(total, class_data.get("stats", {}))
	for node: Dictionary in class_data.get("nodes", []):
		if profile.build.talents.has(str(node.id)):
			_add(total, node.get("stats", {}))
	for item_id: String in profile.build.equipped.values():
		if profile.inventory.count(item_id) <= 0:
			continue
		var item: Dictionary = catalog.get(item_id, {})
		var enhancement: int = int(profile.build.upgrades.get(item_id, 0))
		var multiplier: float = 1.0 + enhancement * float(definitions.get("upgrade_scale", 0.2))
		_add(total, item.get("stats", {}), multiplier)
	return total


static func _add(total: Dictionary, stats: Dictionary, multiplier: float = 1.0) -> void:
	for key: String in total:
		total[key] = float(total[key]) + float(stats.get(key, 0.0)) * multiplier


static func points_spent(profile: PlayerProfile, definitions: Dictionary) -> int:
	var total: int = 0
	var classes: Dictionary = definitions.get("classes", {})
	for class_data: Dictionary in classes.values():
		for node: Dictionary in class_data.get("nodes", []):
			if profile.build.talents.has(str(node.id)):
				total += int(node.cost)
	return total


static func skill_power(profile: PlayerProfile) -> float:
	var power: float = 1.0
	if profile.build.talents.has(profile.class_id + ".mastery"):
		power *= 1.2
	if profile.build.talents.has(profile.class_id + ".awakening"):
		power *= 1.35
	return power
