class_name InventoryState
extends RefCounted
## Bounded slot/stack inventory. Additions are atomic, never silently discard partial stacks.

var capacity: int = 24
var catalog: Dictionary = {}
var _items: Dictionary = {}


func count(item_id: String) -> int:
	return int(_items.get(item_id, 0))


func used_slots() -> int:
	var total: int = 0
	for item_id: String in _items:
		total += ceili(float(count(item_id)) / stack_limit(item_id))
	return total


func stack_limit(item_id: String) -> int:
	var spec: Dictionary = catalog.get(item_id, {})
	return maxi(1, int(spec.get("stack_limit", 1)))


func add(item_id: String, amount: int = 1) -> bool:
	if not catalog.has(item_id) or amount <= 0 or amount > capacity * stack_limit(item_id):
		return false
	var old_slots: int = ceili(float(count(item_id)) / stack_limit(item_id))
	var new_slots: int = ceili(float(count(item_id) + amount) / stack_limit(item_id))
	if used_slots() - old_slots + new_slots > capacity:
		return false
	_items[item_id] = count(item_id) + amount
	return true


func remove(item_id: String, amount: int = 1) -> bool:
	if amount <= 0 or amount > count(item_id):
		return false
	var remaining: int = count(item_id) - amount
	if remaining == 0:
		_items.erase(item_id)
	else:
		_items[item_id] = remaining
	return true


func to_dictionary() -> Dictionary:
	return _items.duplicate()


func load_dictionary(data: Dictionary) -> void:
	_items.clear()
	# Catalog order makes recovery deterministic and ignores unknown IDs, regardless of file size/order.
	for item_id: String in catalog:
		var amount: int = ProgressionRules.safe_int(data.get(item_id, 0), 0, 0, capacity * stack_limit(item_id))
		if amount > 0:
			add(item_id, amount)
