class_name EnemyStats
extends Resource
## Data-driven combat & progression Resource for SHADOWBOUND enemies and bosses (Phase 3).
## Ready for Phase 4 XP/currency rewards and Phase 6 Monster Encyclopedia integration.

@export var enemy_id: String = "umbral_hound"
@export var archetype: String = "melee_rusher"
@export var name_key: String = "enemy.umbral_hound"
@export var is_boss: bool = false

@export_group("Vitals & Defense")
@export var max_hp: float = 68.0
@export var defense: float = 2.0
@export var knockback_resistance: float = 0.0
@export var has_front_shield: bool = false
@export var front_shield_reduction: float = 0.55

@export_group("Offense & AI")
@export var attack_damage: float = 14.0
@export var attack_knockback: float = 240.0
@export var move_speed: float = 175.0
@export var aggro_range: float = 340.0
@export var leash_range: float = 520.0
@export var attack_range: float = 64.0
@export var preferred_min_range: float = 0.0
@export var telegraph_duration: float = 0.36
@export var attack_active_duration: float = 0.24
@export var attack_cooldown: float = 1.05
@export var hurt_stun_duration: float = 0.22

@export_group("Progression Hooks (Phase 4+)")
@export var xp_reward: int = 24
@export var gold_reward: int = 12
