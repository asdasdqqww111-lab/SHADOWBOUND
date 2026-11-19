extends CanvasLayer
## Responsive bilingual inventory. This modal owns no gameplay state; GameState owns pause restoration.

@onready var tabs: TabContainer = $Root/Panel/VBox/Tabs
@onready var upgrade_button: Button = $Root/Panel/VBox/Tabs/Satchel/Body/Details/Actions/Upgrade
@onready var root: Control = $Root
@onready var title: Label = $Root/Panel/VBox/Header/Title
@onready var close_button: Button = $Root/Panel/VBox/Header/Close
@onready var profile_label: Label = $Root/Panel/VBox/Profile
@onready var xp_bar: ProgressBar = $Root/Panel/VBox/XP
@onready var wallet_label: Label = $Root/Panel/VBox/Wallet
@onready var items: ItemList = $Root/Panel/VBox/Tabs/Satchel/Body/Items
@onready var item_name: Label = $Root/Panel/VBox/Tabs/Satchel/Body/Details/Name
@onready var description: Label = $Root/Panel/VBox/Tabs/Satchel/Body/Details/Description
@onready var vitals: Label = $Root/Panel/VBox/Tabs/Satchel/Body/Details/Vitals
@onready var use_button: Button = $Root/Panel/VBox/Tabs/Satchel/Body/Details/Actions/Use
@onready var discard_button: Button = $Root/Panel/VBox/Tabs/Satchel/Body/Details/Actions/Discard
@onready var discard_dialog: ConfirmationDialog = $Root/DiscardDialog
@onready var feedback: Label = $Root/Panel/VBox/Feedback
@onready var capacity_label: Label = $Root/Panel/VBox/Capacity

var _discard_id: String = ""
var _ids: Array[String] = []
var _selected_id: String = ""
var _feedback_key: String = "inventory.save_hint"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	root.visible = false
	close_button.pressed.connect(_close)
	upgrade_button.pressed.connect(_upgrade_selected)
	use_button.pressed.connect(_use_selected)
	discard_button.pressed.connect(_request_discard)
	discard_dialog.confirmed.connect(_confirm_discard)
	items.item_selected.connect(_select_item)
	GameState.inventory_visibility_changed.connect(_on_visibility_changed)
	GameState.profile_updated.connect(_refresh_if_open)
	LocalizationManager.locale_changed.connect(_on_locale_changed)
	GameState.progression.save_failed.connect(_on_save_failed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		GameState.set_inventory_open(not GameState.inventory_open)
		get_viewport().set_input_as_handled()
	elif GameState.inventory_open and event.is_action_pressed("pause"):
		_close()
		get_viewport().set_input_as_handled()


func _on_visibility_changed(open: bool) -> void:
	root.visible = open
	if not open:
		discard_dialog.hide()
	if open:
		_feedback_key = (
			"inventory.save_failed" if GameState.progression.last_save_error != OK else "inventory.save_hint"
		)
		_refresh()
		close_button.grab_focus()


func _close() -> void:
	discard_dialog.hide()
	GameState.set_inventory_open(false)


func _refresh_if_open() -> void:
	if root.visible:
		_refresh()


func _on_locale_changed(_locale: String) -> void:
	_refresh_if_open()


func _refresh() -> void:
	var profile: PlayerProfile = GameState.get_player_profile()
	var state: Dictionary = ProgressionRules.describe(profile.total_xp, GameState.progression.config)
	LocalizationManager.apply_layout_direction(root)
	tabs.set_tab_title(0, LocalizationManager.translate_key("inventory.button"))
	tabs.set_tab_title(1, LocalizationManager.translate_key("build.tab"))
	title.text = LocalizationManager.translate_key("inventory.title")
	close_button.text = LocalizationManager.translate_key("inventory.close")
	profile_label.text = LocalizationManager.translate_key("progress.profile", {
		"name": profile.get_display_name(LocalizationManager.get_locale()), "level": profile.level,
		"rank": profile.rank_code, "xp": state.xp, "required": state.required,
	})
	if int(state.required) == 0:
		profile_label.text += " · " + LocalizationManager.translate_key("progress.max_level")
	xp_bar.max_value = maxf(1, float(state.required))
	xp_bar.value = float(state.xp) if int(state.required) > 0 else 1.0
	wallet_label.text = LocalizationManager.translate_key("progress.wallet", profile.wallet.to_dictionary())
	capacity_label.text = LocalizationManager.translate_key("inventory.capacity", {
		"used": profile.inventory.used_slots(), "max": profile.inventory.capacity,
	})
	_ids.clear()
	items.clear()
	for item_id: String in GameState.progression.catalog:
		if profile.inventory.count(item_id) <= 0:
			continue
		var spec: Dictionary = GameState.progression.catalog[item_id]
		_ids.append(item_id)
		var label: String = "%s  ×%d" % [
			LocalizationManager.translate_key(str(spec.name_key)), profile.inventory.count(item_id),
		]
		var icon: Texture2D = load("res://assets/sprites/items/%s.png" % item_id) as Texture2D
		items.add_item(label, icon)
		items.set_item_custom_fg_color(items.item_count - 1, Color(str(spec.color)))
	if not _ids.has(_selected_id):
		_selected_id = _ids[0] if not _ids.is_empty() else ""
	if not _selected_id.is_empty():
		items.select(_ids.find(_selected_id))
	_refresh_details()
	feedback.text = LocalizationManager.translate_key(_feedback_key)


func _select_item(index: int) -> void:
	if index < 0 or index >= _ids.size():
		return
	_selected_id = _ids[index]
	_refresh_details()


func _refresh_details() -> void:
	var profile: PlayerProfile = GameState.get_player_profile()
	var spec: Dictionary = GameState.progression.catalog.get(_selected_id, {})
	item_name.text = LocalizationManager.translate_key(str(spec.get("name_key", "inventory.empty")))
	description.text = LocalizationManager.translate_key(str(spec.get("description_key", "inventory.empty_desc")))
	vitals.text = LocalizationManager.translate_key("inventory.vitals", {
		"hp": int(ceilf(profile.current_hp)), "max_hp": int(profile.max_hp),
		"mp": int(ceilf(profile.current_mp)), "max_mp": int(profile.max_mp),
		"sp": int(ceilf(profile.current_stamina)), "max_sp": int(profile.max_stamina),
	})
	discard_button.text = LocalizationManager.translate_key("inventory.discard")
	discard_button.disabled = _selected_id.is_empty()
	use_button.text = LocalizationManager.translate_key("inventory.use")
	use_button.disabled = spec.get("kind", "") not in ["consumable", "equipment"] or profile.is_defeated()
	upgrade_button.visible = spec.get("kind") == "equipment"
	upgrade_button.text = LocalizationManager.translate_key("build.forge")
	if spec.get("kind") == "equipment":
		use_button.text = LocalizationManager.translate_key(
			"build.unequip" if profile.build.is_equipped(_selected_id) else "build.equip"
		)
		discard_button.disabled = profile.build.is_equipped(_selected_id)
		var cost: Dictionary = GameState.progression.armory.upgrade_cost(profile, _selected_id)
		description.text = LocalizationManager.translate_key("build.gear_details", {
			"rarity": LocalizationManager.translate_key("rarity." + str(spec.rarity)),
			"slot": LocalizationManager.translate_key("slot." + str(spec.slot)),
			"upgrade": int(profile.build.upgrades.get(_selected_id, 0)),
			"stats": _gear_stats_text(spec), "gold": cost.gold, "fragments": cost.fragments,
			"crystals": cost.crystals,
		})
		upgrade_button.disabled = int(profile.build.upgrades.get(_selected_id, 0)) >= 5


func _use_selected() -> void:
	var profile: PlayerProfile = GameState.get_player_profile()
	var spec: Dictionary = GameState.progression.catalog.get(_selected_id, {})
	if spec.get("kind") == "equipment":
		_feedback_key = GameState.progression.armory.equip(profile, _selected_id)
	else:
		_feedback_key = GameState.progression.use_item(profile, _selected_id)
	if GameState.progression.last_save_error != OK:
		_feedback_key = "inventory.save_failed"
	_refresh()


func _on_save_failed() -> void:
	_feedback_key = "inventory.save_failed"
	_refresh_if_open()


func _request_discard() -> void:
	if _selected_id.is_empty():
		return
	_discard_id = _selected_id
	discard_dialog.title = LocalizationManager.translate_key("inventory.discard")
	discard_dialog.dialog_text = LocalizationManager.translate_key("inventory.discard_confirm")
	discard_dialog.ok_button_text = LocalizationManager.translate_key("inventory.discard")
	discard_dialog.cancel_button_text = LocalizationManager.translate_key("inventory.cancel")
	LocalizationManager.apply_layout_direction(discard_dialog.get_label())
	LocalizationManager.apply_layout_direction(discard_dialog.get_ok_button().get_parent() as Control)
	discard_dialog.popup_centered()


func _confirm_discard() -> void:
	_feedback_key = "build.unequip_first"
	if GameState.progression.discard_item(GameState.get_player_profile(), _discard_id):
		_feedback_key = "inventory.discarded"
	if GameState.progression.last_save_error != OK:
		_feedback_key = "inventory.save_failed"
	_discard_id = ""
	_refresh()


func _upgrade_selected() -> void:
	_feedback_key = GameState.progression.armory.upgrade(GameState.get_player_profile(), _selected_id)
	if GameState.progression.last_save_error != OK:
		_feedback_key = "inventory.save_failed"
	_refresh()


func _gear_stats_text(spec: Dictionary) -> String:
	var parts: Array[String] = []
	var stats: Dictionary = spec.get("stats", {})
	var profile: PlayerProfile = GameState.get_player_profile()
	var multiplier: float = 1 + int(profile.build.upgrades.get(_selected_id, 0)) * float(
		GameState.progression.armory.definitions.get("upgrade_scale", 0.2)
	)
	for key: String in stats:
		var value: float = float(stats[key]) * multiplier
		var text: String = "%s%%" % snappedf(value * 100, 0.1) if key == "crit" else str(snappedf(value, 0.1))
		parts.append("%s +%s" % [LocalizationManager.translate_key("stat." + key), text])
	return ", ".join(parts)
