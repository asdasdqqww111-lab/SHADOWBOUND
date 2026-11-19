class_name ShadowOrbProjectile
extends Area2D
## Arcane Shadow Orb projectile fired by Rift Arcanists and Vaelor, Warden of the Eclipse.
## Collides cleanly with world geometry & PlayerCharacter, and can be reflected back at
## enemies with bonus damage via a timed Perfect Guard (Parry) or sliced by a Combo Finisher.

const LAYER_WORLD_SS: int = 1
const LAYER_WORLD_TD: int = 2
const LAYER_PLAYER: int = 4
const LAYER_INTERACTABLES: int = 16
const LAYER_PLAYER_HITBOX: int = 32
const LAYER_ENEMY_HITBOX: int = 64

@onready var sprite: Sprite2D = $Sprite2D

var direction: Vector2 = Vector2.RIGHT
var speed: float = 295.0
var damage: float = 13.0
var knockback: float = 195.0
var lifetime: float = 4.2
var source_node: Node = null
var is_reflected: bool = false
var _reflect_speed_mult: float = 1.45
var _reflect_damage_mult: float = 1.6
var _age: float = 0.0


func _ready() -> void:
	add_to_group("projectiles")
	var proj_cfg: Dictionary = GameState.get_combat_config_section("projectile")
	var def_cfg: Dictionary = GameState.get_combat_config_section("defense")
	_reflect_speed_mult = float(proj_cfg.get("reflected_speed_multiplier", _reflect_speed_mult))
	_reflect_damage_mult = float(def_cfg.get("parry_reflect_damage_multiplier", _reflect_damage_mult))
	lifetime = float(proj_cfg.get("lifetime", lifetime))

	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	_apply_hostile_collision()


func launch(
	origin: Vector2,
	dir: Vector2,
	orb_damage: float,
	orb_speed: float = 295.0,
	shooter: Node = null
) -> void:
	global_position = origin
	direction = dir.normalized() if dir.length_squared() > 0.0001 else Vector2.RIGHT
	damage = orb_damage
	speed = orb_speed
	source_node = shooter
	is_reflected = false
	_age = 0.0


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	global_position += direction * speed * delta
	if sprite != null:
		sprite.rotation += 6.5 * delta


func _apply_hostile_collision() -> void:
	collision_layer = LAYER_ENEMY_HITBOX
	collision_mask = LAYER_WORLD_SS | LAYER_WORLD_TD | LAYER_PLAYER


func reflect_from_parry(new_dir: Vector2 = Vector2.ZERO) -> void:
	if is_reflected:
		return
	is_reflected = true
	_age = 0.0
	if new_dir.length_squared() > 0.0001:
		direction = new_dir.normalized()
	elif source_node is Node2D and is_instance_valid(source_node):
		var shooter_2d: Node2D = source_node as Node2D
		var toward_src: Vector2 = shooter_2d.global_position + Vector2(0.0, -34.0) - global_position
		direction = toward_src.normalized() if toward_src.length_squared() > 1.0 else -direction
	else:
		direction = -direction

	speed *= _reflect_speed_mult
	damage *= _reflect_damage_mult
	collision_layer = LAYER_PLAYER_HITBOX
	collision_mask = LAYER_WORLD_SS | LAYER_WORLD_TD | LAYER_INTERACTABLES
	if sprite != null:
		sprite.modulate = Color(0.65, 1.35, 1.55, 1.0)
		sprite.scale = Vector2(0.82, 0.82)


func slice_projectile() -> void:
	if not is_reflected:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body == source_node and not is_reflected:
		return
	if not is_reflected and body is PlayerCharacter:
		var player: PlayerCharacter = body as PlayerCharacter
		var res: Dictionary = player.receive_attack(
			{
				"damage": damage,
				"knockback": knockback,
				"source_position": global_position,
				"source": self,
				"is_projectile": true,
			}
		)
		var outcome: String = str(res.get("outcome", "hit"))
		if outcome == "parried":
			reflect_from_parry()
			return
		if outcome == "dodged":
			return
		queue_free()
		return

	# Solid platform or sanctum wall stops the orb
	if body is StaticBody2D:
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	if not is_reflected:
		return
	if area.is_in_group("enemy_hurtbox"):
		var enemy_owner: Node = area.get_parent()
		if enemy_owner != null and enemy_owner.has_method("receive_player_strike"):
			enemy_owner.call(
				"receive_player_strike",
				{
					"damage": damage,
					"combo_step": 3,
					"is_crit": false,
					"is_riposte": true,
					"knockback": knockback * 1.15,
					"poise_damage": 2.0,
					"breaks_shield": true,
					"hit_direction": direction,
					"attacker_position": global_position,
				}
			)
			queue_free()
