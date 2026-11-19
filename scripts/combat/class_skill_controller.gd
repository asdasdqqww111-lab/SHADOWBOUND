class_name ClassSkillController
extends Node
## Five distinct class abilities, shared by both movement modes. Cooldown survives mode/class switches.

signal cast_finished(outcome: String)

var cooldown_remaining: float = 0.0
var _last_class: String = ""
@onready var player: PlayerCharacter = get_parent() as PlayerCharacter


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("class_skill"):
		try_cast()
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	cooldown_remaining = maxf(0.0, cooldown_remaining - delta)
	if player.profile == null:
		return
	if _last_class != player.profile.class_id:
		_clear_companions()
		_last_class = player.profile.class_id
	if player.is_defeated():
		_clear_companions()


func try_cast() -> String:
	var outcome: String = "skill.cast"
	if player == null or player.profile == null or get_tree().paused or player.is_defeated():
		outcome = "skill.busy"
	elif player.active_controller == null or player.active_controller.is_hurt_stunned():
		outcome = "skill.busy"
	elif cooldown_remaining > 0.0:
		outcome = "skill.cooldown"
	else:
		outcome = _cast_paid()
	cast_finished.emit(outcome)
	return outcome


func _cast_paid() -> String:
	var profile: PlayerProfile = player.profile
	var classes: Dictionary = GameState.progression.armory.definitions.get("classes", {})
	var spec: Dictionary = classes.get(profile.class_id, {})
	if spec.is_empty() or not profile.consume_mp(float(spec.get("mp_cost", 20))):
		return "skill.no_mana"
	if _last_class != profile.class_id:
		_clear_companions()
		_last_class = profile.class_id
	cooldown_remaining = float(spec.get("cooldown", 7))
	var power: float = BuildRules.skill_power(profile)
	var damage: float = profile.base_attack * float(spec.get("damage_multiplier", 1.0)) * power
	match profile.class_id:
		"mage":
			for angle: float in [-0.18, 0.0, 0.18]:
				_spawn_bolt(damage, player.get_active_facing_vector().rotated(angle))
		"assassin":
			player.move_and_collide(player.get_active_facing_vector() * 80.0)
			player._hurt_invuln_timer = maxf(player._hurt_invuln_timer, 0.35)
			_strike_nearby(damage, 125.0, false)
		"knight":
			player._hurt_invuln_timer = maxf(player._hurt_invuln_timer, 0.9 * power)
			profile.heal(profile.max_hp * 0.15 * power)
			profile.regenerate_stamina(25.0)
			_strike_nearby(damage, 100.0, true)
		"summoner":
			_clear_companions()
			var companion: SpiritCompanion = SpiritCompanion.new()
			companion.damage = damage
			companion.player = player
			companion.duration = 6.0 * power
			add_child(companion)
		_:
			_strike_nearby(damage, 165.0, true)
	GameState.notify_profile_updated()
	player.camera.add_trauma(0.26)
	FloatingCombatText.spawn(player.get_parent(), player.global_position + Vector2(0, -90),
		LocalizationManager.translate_key(str(spec.get("skill_key", "skill.warrior"))), Color(0.5, 0.9, 1))
	return "skill.cast"


func _strike_nearby(damage: float, reach: float, breaks_shield: bool) -> int:
	var hit_count: int = 0
	var face: Vector2 = player.get_active_facing_vector()
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		if not node is EnemyBase:
			continue
		var enemy: EnemyBase = node as EnemyBase
		if enemy.gameplay_mode != player.active_mode or enemy.is_defeated():
			continue
		var diff: Vector2 = enemy.global_position - player.global_position
		if diff.length() <= reach and (diff.length() < 20 or face.dot(diff.normalized()) >= -0.1):
			var dealt: float = enemy.receive_player_strike({
				"damage": damage, "breaks_shield": breaks_shield, "knockback": 220,
				"attacker_position": player.global_position, "hit_direction": face,
			})
			if dealt > 0:
				hit_count += 1
	return hit_count


func _spawn_bolt(damage: float, direction: Vector2) -> void:
	var bolt: ClassSkillBolt = ClassSkillBolt.new()
	bolt.damage = damage
	bolt.direction = direction.normalized()
	bolt.gameplay_mode = player.active_mode
	player.get_parent().add_child(bolt)
	bolt.global_position = player.global_position + Vector2(0, -30) + direction * 28.0


func _clear_companions() -> void:
	for child: Node in get_children():
		if child is SpiritCompanion:
			child.queue_free()
