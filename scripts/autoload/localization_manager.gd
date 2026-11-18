extends Node
## Manages offline bilingual localization (English LTR and Arabic RTL).
## Loads string tables from `res://data/localization/*.json` and broadcasts locale updates.

signal locale_changed(new_locale: String)

const SUPPORTED_LOCALES: Array[String] = ["en", "ar"]
const DEFAULT_LOCALE: String = "en"
const LOCALIZATION_DIR: String = "res://data/localization"

var _current_locale: String = DEFAULT_LOCALE
var _tables: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_all_tables()
	set_locale(_current_locale, false)


func _load_all_tables() -> void:
	_tables.clear()
	for loc: String in SUPPORTED_LOCALES:
		var path: String = "%s/%s.json" % [LOCALIZATION_DIR, loc]
		_tables[loc] = _load_json_dictionary(path)


func _load_json_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("LocalizationManager: Missing translation file: %s" % path)
		return {}
	var raw: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(raw)
	if parsed is Dictionary:
		var result: Dictionary = parsed
		return result
	push_warning("LocalizationManager: Invalid JSON format in %s" % path)
	return {}


func set_locale(locale_code: String, emit_update: bool = true) -> void:
	var normalized: String = locale_code.strip_edges().to_lower()
	if normalized.begins_with("ar"):
		normalized = "ar"
	elif not SUPPORTED_LOCALES.has(normalized):
		normalized = DEFAULT_LOCALE

	_current_locale = normalized
	TranslationServer.set_locale(_current_locale)
	if emit_update:
		locale_changed.emit(_current_locale)


func toggle_locale() -> String:
	var next_locale: String = "ar" if _current_locale == "en" else "en"
	set_locale(next_locale, true)
	return _current_locale


func get_locale() -> String:
	return _current_locale


func is_rtl() -> bool:
	return _current_locale == "ar"


func translate_key(key: String, params: Dictionary = {}) -> String:
	if _tables.is_empty():
		_load_all_tables()

	var text: String = key
	if _tables.has(_current_locale):
		var active_table: Dictionary = _tables[_current_locale]
		if active_table.has(key):
			text = str(active_table[key])
		elif _tables.has(DEFAULT_LOCALE):
			var fallback_table: Dictionary = _tables[DEFAULT_LOCALE]
			if fallback_table.has(key):
				text = str(fallback_table[key])

	for param_key: Variant in params.keys():
		text = text.replace("{%s}" % str(param_key), str(params[param_key]))
	return text


func apply_layout_direction(control: Control) -> void:
	if control == null:
		return
	if is_rtl():
		control.layout_direction = Control.LAYOUT_DIRECTION_RTL
	else:
		control.layout_direction = Control.LAYOUT_DIRECTION_LTR
