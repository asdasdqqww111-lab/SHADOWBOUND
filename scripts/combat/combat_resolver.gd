class_name CombatResolver
extends RefCounted
## Pure modular combat calculator for SHADOWBOUND (Phase 3).
## Resolves 3-hit sword combos, critical strikes, Perfect-Guard Ripostes, directional
## enemy shields, Shadow Dodge i-frames, Shadow Guard chip/guard-break, and Parry rewards.


static func get_combo_spec(combat_cfg: Dictionary, combo_step: int) -> Dictionary:
	var fallback: Dictionary = {
		"step": 1,
		"id": "slash_1",
		"ss_anim": "attack",
		"td_anim": "td_attack",
		"damage_multiplier": 1.0,
		"duration": 0.25,
		"knockback": 185.0,
		"lunge_multiplier": 1.0,
		"stamina_cost": 0.0,
		"hitbox_scale": 1.0,
		"poise_damage": 1.0,
		"hit_shake": 0.16,
		"breaks_shield": false,
	}
	if not combat_cfg.has("combo_steps"):
		return fallback
	var steps_var: Variant = combat_cfg["combo_steps"]
	if not (steps_var is Array):
		return fallback
	var steps: Array = steps_var
	if steps.is_empty():
		return fallback
	var idx: int = clampi(combo_step - 1, 0, steps.size() - 1)
	if steps[idx] is Dictionary:
		var chosen: Dictionary = steps[idx]
		return chosen
	return fallback


static func compute_player_strike(
	profile: PlayerProfile,
	combat_cfg: Dictionary,
	combo_step: int,
	is_riposte: bool,
	crit_roll: float = 1.0
) -> Dictionary:
	var spec: Dictionary = get_combo_spec(combat_cfg, combo_step)
	var base_atk: float = (
		profile.base_attack
		if profile != null
		else float(combat_cfg.get("base_attack", 18.0))
	)
	var crit_chance: float = (
		profile.crit_chance
		if profile != null
		else float(combat_cfg.get("crit_chance", 0.12))
	)
	var crit_mult: float = (
		profile.crit_multiplier
		if profile != null
		else float(combat_cfg.get("crit_multiplier", 1.5))
	)
	var riposte_mult: float = float(combat_cfg.get("riposte_damage_multiplier", 1.5))
	var dmg_mult: float = float(spec.get("damage_multiplier", 1.0))
	var is_crit: bool = crit_roll < crit_chance

	var total_damage: float = base_atk * dmg_mult
	if is_riposte:
		total_damage *= riposte_mult
	if is_crit:
		total_damage *= crit_mult

	return {
		"damage": roundf(total_damage * 10.0) / 10.0,
		"combo_step": int(spec.get("step", combo_step)),
		"is_crit": is_crit,
		"is_riposte": is_riposte,
		"knockback": float(spec.get("knockback", 185.0)),
		"poise_damage": float(spec.get("poise_damage", 1.0)),
		"hit_shake": float(spec.get("hit_shake", 0.16)),
		"breaks_shield": bool(spec.get("breaks_shield", false)) or is_riposte,
	}


static func compute_enemy_damage_taken(
	raw_damage: float,
	enemy_defense: float,
	is_front_hit: bool,
	shield_active: bool,
	shield_reduction: float,
	breaks_shield: bool
) -> Dictionary:
	var mitigated: float = maxf(1.0, raw_damage - enemy_defense * 0.65)
	var shielded: bool = false
	var shield_broken: bool = false

	if shield_active and is_front_hit:
		if breaks_shield:
			mitigated *= 1.15
			shield_broken = true
		else:
			var keep_ratio: float = clampf(1.0 - shield_reduction, 0.1, 1.0)
			mitigated = maxf(1.0, mitigated * keep_ratio)
			shielded = true

	return {
		"damage": maxf(1.0, roundf(mitigated)),
		"shielded": shielded,
		"shield_broken": shield_broken,
	}


static func is_attack_in_guard_arc(
	defender_facing: Vector2,
	to_attacker: Vector2,
	dot_threshold: float = -0.15
) -> bool:
	if defender_facing.length_squared() < 0.0001 or to_attacker.length_squared() < 0.0001:
		return true
	return defender_facing.normalized().dot(to_attacker.normalized()) >= dot_threshold


static func resolve_incoming_player_hit(
	raw_damage: float,
	profile: PlayerProfile,
	player_facing: Vector2,
	to_attacker: Vector2,
	is_invulnerable: bool,
	is_blocking: bool,
	is_perfect_blocking: bool,
	defense_cfg: Dictionary
) -> Dictionary:
	if is_invulnerable:
		return {
			"outcome": "dodged",
			"hp_damage": 0.0,
			"stamina_cost": 0.0,
			"stamina_restored": 0.0,
			"mp_restored": 0.0,
			"knockback_scale": 0.0,
		}

	var dot_limit: float = float(defense_cfg.get("block_front_dot_threshold", -0.15))
	var in_arc: bool = is_attack_in_guard_arc(player_facing, to_attacker, dot_limit)

	if is_blocking and is_perfect_blocking and in_arc:
		return {
			"outcome": "parried",
			"hp_damage": 0.0,
			"stamina_cost": 0.0,
			"stamina_restored": float(defense_cfg.get("parry_stamina_restore", 15.0)),
			"mp_restored": float(defense_cfg.get("parry_mp_restore", 8.0)),
			"knockback_scale": 0.0,
		}

	var def_val: float = profile.defense if profile != null else 4.0
	var mitigated: float = maxf(1.0, raw_damage - def_val * 0.6)

	if is_blocking and in_arc:
		var reduction: float = clampf(
			float(defense_cfg.get("block_damage_reduction", 0.75)),
			0.0,
			0.95
		)
		var chip_dmg: float = maxf(1.0, roundf(mitigated * (1.0 - reduction)))
		var sp_cost: float = float(defense_cfg.get("block_stamina_cost", 14.0))
		var cur_sp: float = profile.current_stamina if profile != null else sp_cost
		var broke_guard: bool = cur_sp <= sp_cost
		return {
			"outcome": "guard_broken" if broke_guard else "blocked",
			"hp_damage": chip_dmg,
			"stamina_cost": sp_cost,
			"stamina_restored": 0.0,
			"mp_restored": 0.0,
			"knockback_scale": (
				0.75
				if broke_guard
				else float(defense_cfg.get("block_knockback_factor", 0.35))
			),
		}

	return {
		"outcome": "hit",
		"hp_damage": maxf(1.0, roundf(mitigated)),
		"stamina_cost": 0.0,
		"stamina_restored": 0.0,
		"mp_restored": 0.0,
		"knockback_scale": 1.0,
	}
