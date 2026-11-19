class_name PlayerProfile
extends Resource
## Shared player profile Resource persisted across Side-Scrolling and Top-Down modes.
## Serves as the unified data backbone for combat (Phase 3) and RPG progression (Phases 4–7).

@export var character_name_en: String = "Kael"
@export var character_name_ar: String = "كايل"
@export var class_id: String = "warrior"
@export var rank_code: String = "F"
@export var level: int = 1

@export var max_hp: float = 120.0
@export var current_hp: float = 120.0
@export var max_mp: float = 80.0
@export var current_mp: float = 80.0
@export var max_stamina: float = 100.0
@export var current_stamina: float = 100.0

@export var base_attack: float = 18.0
@export var defense: float = 4.0
@export var crit_chance: float = 0.12
@export var crit_multiplier: float = 1.5

var build: BuildState = BuildState.new()
var total_xp: int = 0
var wallet: CurrencyWallet = CurrencyWallet.new()
var inventory: InventoryState = InventoryState.new()

var session_slash_hits: int = 0
var session_mode_switches: int = 0
var session_enemies_defeated: int = 0
var session_bosses_defeated: int = 0
var session_parries: int = 0


func get_display_name(locale: String) -> String:
	if locale.begins_with("ar"):
		return character_name_ar
	return character_name_en


func apply_damage(amount: float) -> float:
	var clamped: float = maxf(0.0, amount)
	var before: float = current_hp
	current_hp = maxf(0.0, current_hp - clamped)
	return before - current_hp


func heal(amount: float) -> float:
	var before: float = current_hp
	current_hp = minf(max_hp, current_hp + maxf(0.0, amount))
	return current_hp - before


func consume_mp(amount: float) -> bool:
	if amount < 0.0 or not is_finite(amount) or current_mp < amount:
		return false
	current_mp = maxf(0.0, current_mp - amount)
	return true


func restore_mp(amount: float) -> void:
	current_mp = minf(max_mp, current_mp + maxf(0.0, amount))


func consume_stamina(amount: float) -> bool:
	if amount <= 0.0:
		return true
	if current_stamina < amount:
		return false
	current_stamina = maxf(0.0, current_stamina - amount)
	return true


func regenerate_stamina(amount: float) -> void:
	current_stamina = minf(max_stamina, current_stamina + maxf(0.0, amount))


func is_defeated() -> bool:
	return current_hp <= 0.0


func restore_all() -> void:
	current_hp = max_hp
	current_mp = max_mp
	current_stamina = max_stamina


func apply_progression(cfg: Dictionary, refill_on_level_up: bool = false) -> Dictionary:
	var old_level: int = level
	var old_rank: String = rank_code
	total_xp = clampi(total_xp, 0, ProgressionRules.max_total_xp(cfg))
	var state: Dictionary = ProgressionRules.describe(total_xp, cfg)
	level = int(state.level)
	rank_code = str(state.rank)
	var growth: Dictionary = cfg.get("growth", {})
	var steps: int = level - 1
	max_hp = 120.0 + steps * float(growth.get("hp", 12.0))
	max_mp = 80.0 + steps * float(growth.get("mp", 6.0))
	max_stamina = 100.0 + steps * float(growth.get("stamina", 2.0))
	base_attack = 18.0 + steps * float(growth.get("attack", 2.0))
	defense = 4.0 + steps * float(growth.get("defense", 0.5))
	var modifiers: Dictionary = BuildRules.bonuses(self, cfg.get("builds", {}), inventory.catalog)
	max_hp = maxf(1.0, max_hp + float(modifiers.hp))
	max_mp = maxf(1.0, max_mp + float(modifiers.mp))
	max_stamina = maxf(1.0, max_stamina + float(modifiers.stamina))
	base_attack = maxf(1.0, base_attack + float(modifiers.attack))
	defense = maxf(0.0, defense + float(modifiers.defense))
	crit_chance = clampf(0.12 + float(modifiers.crit), 0.0, 0.75)
	if refill_on_level_up and level > old_level:
		restore_all()
	else:
		current_hp = minf(current_hp, max_hp)
		current_mp = minf(current_mp, max_mp)
		current_stamina = minf(current_stamina, max_stamina)
	state["levels_gained"] = maxi(0, level - old_level)
	state["rank_changed"] = rank_code != old_rank
	return state


func to_dictionary() -> Dictionary:
	return {
		"character_name_en": character_name_en,
		"character_name_ar": character_name_ar,
		"class_id": class_id,
		"rank_code": rank_code,
		"level": level,
		"max_hp": max_hp,
		"current_hp": current_hp,
		"max_mp": max_mp,
		"current_mp": current_mp,
		"max_stamina": max_stamina,
		"current_stamina": current_stamina,
		"base_attack": base_attack,
		"defense": defense,
		"crit_chance": crit_chance,
		"crit_multiplier": crit_multiplier,
		"build": build.to_dictionary(),
		"total_xp": total_xp,
		"wallet": wallet.to_dictionary(),
		"inventory": inventory.to_dictionary(),
		"session_slash_hits": session_slash_hits,
		"session_mode_switches": session_mode_switches,
		"session_enemies_defeated": session_enemies_defeated,
		"session_bosses_defeated": session_bosses_defeated,
		"session_parries": session_parries,
	}
