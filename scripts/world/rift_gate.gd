extends Area2D
## Interactive Shadow Rift portal enabling in-world switching between
## Side-Scrolling and Top-Down gameplay/camera modes.

signal player_proximity_changed(player_inside: bool, gate: Area2D)

@export var target_mode: int = 1

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var prompt_label: Label = $PromptLabel

var _player_inside: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	LocalizationManager.locale_changed.connect(_on_locale_changed)
	if sprite != null:
		sprite.play(&"swirl")
	_refresh_prompt()


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_player_inside = true
	if body.has_method("set_nearby_rift"):
		body.call("set_nearby_rift", true)
	_refresh_prompt()
	player_proximity_changed.emit(true, self)


func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_player_inside = false
	if body.has_method("set_nearby_rift"):
		body.call("set_nearby_rift", false)
	_refresh_prompt()
	player_proximity_changed.emit(false, self)


func _on_locale_changed(_new_locale: String) -> void:
	_refresh_prompt()


func _refresh_prompt() -> void:
	if prompt_label == null:
		return
	prompt_label.visible = _player_inside
	if _player_inside:
		prompt_label.text = "[E] %s" % LocalizationManager.translate_key("hud.switch_mode")


func is_player_inside() -> bool:
	return _player_inside
