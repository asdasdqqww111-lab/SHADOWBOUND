class_name ProgressionRules
extends RefCounted
## Pure XP/rank math. Total XP is canonical; level, rank and base stats are derived.


static func xp_for_level(level_value: int, cfg: Dictionary) -> int:
	return int(cfg.get("xp_base", 100)) + (maxi(1, level_value) - 1) * int(cfg.get("xp_step", 40))


static func describe(total_xp: int, cfg: Dictionary) -> Dictionary:
	var cap: int = int(cfg.get("level_cap", 60))
	var remaining: int = maxi(0, total_xp)
	var level_value: int = 1
	while level_value < cap and remaining >= xp_for_level(level_value, cfg):
		remaining -= xp_for_level(level_value, cfg)
		level_value += 1
	var rank_value: String = "F"
	var ranks: Array = cfg.get("ranks", [])
	for entry: Dictionary in ranks:
		if level_value >= int(entry.get("level", 1)):
			rank_value = str(entry.get("code", "F"))
	return {
		"level": level_value, "rank": rank_value,
		"xp": remaining if level_value < cap else 0,
		"required": xp_for_level(level_value, cfg) if level_value < cap else 0,
	}


static func max_total_xp(cfg: Dictionary) -> int:
	var total: int = 0
	for level_value: int in range(1, int(cfg.get("level_cap", 60))):
		total += xp_for_level(level_value, cfg)
	return total


static func safe_int(value: Variant, fallback: int, minimum: int, maximum: int) -> int:
	if not (value is int or value is float):
		return fallback
	var number: float = float(value)
	if not is_finite(number) or number < minimum or number > maximum or floorf(number) != number:
		return fallback
	return int(number)
