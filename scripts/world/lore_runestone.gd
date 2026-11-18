extends Area2D
## Interactive ancient Lore Runestone for Top-Down exploration testing (Phase 2).
## Emits proximity signals and displays bilingual EN/AR RTL inscriptions on interact.

signal lore_proximity_changed(player_inside: bool, stone: Area2D)

@export var lore_key: String = "lore.west_tablet"

@onready var sprite: Sprite2D = $Sprite2D
@onready var prompt_label: Label = $PromptLabel

var _player_inside: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	LocalizationManager.locale_changed.connect(_on_locale_changed)
	_refresh_prompt()


func get_inscription_text() -> String:
	return LocalizationManager.translate_key(lore_key)


func pulse_highlight() -> void:
	if sprite == null:
		return
	sprite.modulate = Color(1.45, 1.7, 2.0, 1.0)
	var tw: Tween = create_tween()
	tw.tween_property(sprite, "modulate", Color.WHITE, 0.35)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_player_inside = true
	if body.has_method("set_nearby_interactable"):
		body.call("set_nearby_interactable", true)
	_refresh_prompt()
	lore_proximity_changed.emit(true, self)


func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_player_inside = false
	if body.has_method("set_nearby_interactable"):
		body.call("set_nearby_interactable", false)
	_refresh_prompt()
	lore_proximity_changed.emit(false, self)


func _on_locale_changed(_loc: String) -> void:
	_refresh_prompt()


func _refresh_prompt() -> void:
	if prompt_label == null:
		return
	prompt_label.visible = _player_inside
	if _player_inside:
		prompt_label.text = "[E] %s" % LocalizationManager.translate_key("touch.interact")
