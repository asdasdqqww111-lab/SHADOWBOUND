extends HBoxContainer
## Character tab: class selection, three-node class trees and live equipment/stat summary.

var class_selector: OptionButton
var class_description: Label
var points_label: Label
var stats_label: Label
var feedback: Label
var _class_ids: Array[String] = []
var _talent_buttons: Array[Button] = []
var _slot_buttons: Array[Button] = []
var _feedback_key: String = "build.tree_hint"


func _ready() -> void:
	add_theme_constant_override("separation", 24)
	var left: VBoxContainer = VBoxContainer.new()
	var right: VBoxContainer = VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.custom_minimum_size.x = 430
	right.custom_minimum_size.x = 350
	left.add_theme_constant_override("separation", 8)
	right.add_theme_constant_override("separation", 8)
	add_child(left)
	add_child(right)
	class_selector = OptionButton.new()
	class_selector.custom_minimum_size.y = 54
	left.add_child(class_selector)
	class_selector.item_selected.connect(_on_select_class)
	class_description = _label(left)
	points_label = _label(left)
	for index: int in range(3):
		var button: Button = Button.new()
		button.custom_minimum_size.y = 58
		button.add_theme_font_size_override("font_size", 15)
		button.pressed.connect(_on_unlock.bind(index))
		left.add_child(button)
		_talent_buttons.append(button)
	stats_label = _label(right)
	for slot: String in BuildState.SLOTS:
		var button: Button = Button.new()
		button.custom_minimum_size.y = 58
		button.add_theme_font_size_override("font_size", 15)
		button.pressed.connect(_on_unequip.bind(slot))
		right.add_child(button)
		_slot_buttons.append(button)
	feedback = _label(right)
	GameState.profile_updated.connect(refresh)
	LocalizationManager.locale_changed.connect(_on_locale_changed)
	refresh()


func _label(host: Node) -> Label:
	var label: Label = Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 16)
	host.add_child(label)
	return label


func refresh() -> void:
	var profile: PlayerProfile = GameState.get_player_profile()
	var armory: ArmoryService = GameState.progression.armory
	var classes: Dictionary = armory.definitions.get("classes", {})
	class_selector.clear()
	_class_ids.clear()
	for class_id: String in classes:
		_class_ids.append(class_id)
		class_selector.add_item(LocalizationManager.translate_key("class." + class_id))
	class_selector.select(maxi(0, _class_ids.find(profile.class_id)))
	var class_data: Dictionary = classes.get(profile.class_id, {})
	class_description.text = LocalizationManager.translate_key(str(class_data.get("description_key", "build.invalid")))
	points_label.text = LocalizationManager.translate_key("build.points", {
		"points": profile.level - BuildRules.points_spent(profile, armory.definitions),
	})
	var nodes: Array = class_data.get("nodes", [])
	for index: int in range(mini(3, nodes.size())):
		var spec: Dictionary = nodes[index]
		var learned: bool = profile.build.talents.has(str(spec.id))
		_talent_buttons[index].text = "%s\n%s" % [
			LocalizationManager.translate_key(str(spec.name_key)),
			LocalizationManager.translate_key("build.owned" if learned else "build.requirements",
				{"level": spec.level, "points": spec.cost}),
		]
		_talent_buttons[index].disabled = learned
	stats_label.text = LocalizationManager.translate_key("build.stats", {
		"attack": snappedf(profile.base_attack, 0.1), "defense": snappedf(profile.defense, 0.1),
		"hp": int(profile.max_hp), "mp": int(profile.max_mp), "stamina": int(profile.max_stamina),
		"crit": int(roundf(profile.crit_chance * 100)),
	})
	for index: int in range(BuildState.SLOTS.size()):
		var slot: String = BuildState.SLOTS[index]
		var item_id: String = str(profile.build.equipped.get(slot, ""))
		var item_text: String = LocalizationManager.translate_key("build.empty")
		if not item_id.is_empty():
			item_text = "%s +%d" % [LocalizationManager.translate_key("item." + item_id),
				int(profile.build.upgrades.get(item_id, 0))]
		_slot_buttons[index].text = "%s: %s" % [LocalizationManager.translate_key("slot." + slot), item_text]
		_slot_buttons[index].disabled = item_id.is_empty()
	feedback.text = LocalizationManager.translate_key(
		"inventory.save_failed" if GameState.progression.last_save_error != OK else _feedback_key
	)


func _on_select_class(index: int) -> void:
	if index < 0 or index >= _class_ids.size():
		return
	_feedback_key = GameState.progression.armory.select_class(GameState.get_player_profile(), _class_ids[index])
	refresh()


func _on_unlock(index: int) -> void:
	var profile: PlayerProfile = GameState.get_player_profile()
	var classes: Dictionary = GameState.progression.armory.definitions.get("classes", {})
	var nodes: Array = classes[profile.class_id].nodes
	_feedback_key = GameState.progression.armory.unlock(profile, str(nodes[index].id))
	if GameState.progression.last_save_error != OK:
		_feedback_key = "inventory.save_failed"
	refresh()


func _on_unequip(slot: String) -> void:
	var profile: PlayerProfile = GameState.get_player_profile()
	_feedback_key = GameState.progression.armory.equip(profile, str(profile.build.equipped.get(slot, "")))
	refresh()


func _on_locale_changed(_locale: String) -> void:
	refresh()
