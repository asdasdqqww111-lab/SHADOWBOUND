class_name BuildState
extends RefCounted
## Owned equipment remains in inventory; each unique item has one persistent enhancement level.

const SLOTS: Array[String] = ["weapon", "armor", "charm"]
var equipped: Dictionary = {"weapon": "", "armor": "", "charm": ""}
var upgrades: Dictionary = {}
var talents: Array[String] = []


func is_equipped(item_id: String) -> bool:
	return not item_id.is_empty() and equipped.values().has(item_id)


func to_dictionary() -> Dictionary:
	return {"equipped": equipped.duplicate(), "upgrades": upgrades.duplicate(), "talents": talents.duplicate()}


func load_dictionary(data: Dictionary, inventory: InventoryState, definitions: Dictionary, level: int) -> void:
	equipped = {"weapon": "", "armor": "", "charm": ""}
	upgrades.clear()
	talents.clear()
	var gear_data: Variant = data.get("equipped", {})
	if gear_data is Dictionary:
		for slot: String in SLOTS:
			var value: Variant = gear_data.get(slot, "")
			var spec: Dictionary = inventory.catalog.get(value, {}) if value is String else {}
			if inventory.count(str(value)) > 0 and spec.get("slot") == slot:
				equipped[slot] = value
	var upgrade_data: Variant = data.get("upgrades", {})
	if upgrade_data is Dictionary:
		for item_id: String in inventory.catalog:
			if inventory.count(item_id) > 0 and inventory.catalog[item_id].get("kind") == "equipment":
				upgrades[item_id] = ProgressionRules.safe_int(
					upgrade_data.get(item_id, 0), 0, 0, int(definitions.get("upgrade_cap", 5))
				)
	var talent_data: Variant = data.get("talents", [])
	if talent_data is Array:
		var remaining: int = level
		var classes: Dictionary = definitions.get("classes", {})
		for class_data: Dictionary in classes.values():
			for node: Dictionary in class_data.get("nodes", []):
				var prereq: String = str(node.get("requires", ""))
				if talent_data.has(node.id) and int(node.level) <= level and int(node.cost) <= remaining:
					if prereq.is_empty() or talents.has(prereq):
						talents.append(str(node.id))
						remaining -= int(node.cost)
