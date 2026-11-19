class_name CurrencyWallet
extends RefCounted
## All-or-nothing wallet transactions. Unknown, negative and fractional costs are rejected.

const CURRENCIES: Array[String] = ["gold", "diamonds", "magic_crystals"]
var limit: int = 999999999
var _balances: Dictionary = {"gold": 0, "diamonds": 0, "magic_crystals": 0}


func balance(currency: String) -> int:
	return int(_balances.get(currency, 0))


func credit(currency: String, amount: int) -> bool:
	if not CURRENCIES.has(currency) or amount < 0 or amount > limit - balance(currency):
		return false
	_balances[currency] = balance(currency) + amount
	return true


func spend(costs: Dictionary) -> bool:
	if costs.is_empty():
		return false
	for currency: Variant in costs:
		if not CURRENCIES.has(str(currency)):
			return false
		var amount: int = ProgressionRules.safe_int(costs[currency], -1, 0, limit)
		if amount < 0 or amount > balance(str(currency)):
			return false
	for currency: Variant in costs:
		_balances[currency] = balance(str(currency)) - int(costs[currency])
	return true


func to_dictionary() -> Dictionary:
	return _balances.duplicate()


func load_dictionary(data: Dictionary) -> void:
	for currency: String in CURRENCIES:
		_balances[currency] = ProgressionRules.safe_int(data.get(currency, 0), 0, 0, limit)
