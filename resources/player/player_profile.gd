class_name PlayerProfile
extends Resource
## Shared player profile Resource persisted across Side-Scrolling and Top-Down modes.
## Designed as the modular data backbone for future RPG phases (XP, ranks, equipment, guild).

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

var session_slash_hits: int = 0


func get_display_name(locale: String) -> String:
	if locale.begins_with("ar"):
		return character_name_ar
	return character_name_en


func consume_stamina(amount: float) -> bool:
	if current_stamina < amount:
		return false
	current_stamina = maxf(0.0, current_stamina - amount)
	return true


func regenerate_stamina(amount: float) -> void:
	current_stamina = minf(max_stamina, current_stamina + amount)


func restore_all() -> void:
	current_hp = max_hp
	current_mp = max_mp
	current_stamina = max_stamina


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
		"session_slash_hits": session_slash_hits,
	}
