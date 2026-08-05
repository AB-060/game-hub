class_name Localization

# Phase 5: lightweight, fully code-driven translation lookup - NOT Godot's
# TranslationServer/.tres pipeline, since that requires the CSV-to-Translation
# import step to run inside the Editor, which isn't available while building
# this headless. Loaded once (following DataLoader's existing JSON-loading
# pattern) from assets/json/translations.json: {key: {locale: text}}.
#
# LOCALES lists every locale selectable in the Settings screen's language
# picker, for structural completeness. Real, hand-checked translations only
# exist for "en" (source) and "fr". "es"/"pt" get simple/common UI words
# translated with reasonable confidence. "ar" is listed as selectable but
# intentionally NOT translated and NOT right-to-left laid out - RTL requires
# mirroring the whole UI layout, a much bigger and riskier change than a
# string swap, and shipping a half-mirrored or mistranslated Arabic UI would
# read as broken rather than unfinished. Selecting "ar" falls back to English
# text via get_text()'s fallback below.
const LOCALES : Array[String] = ["en", "fr", "es", "pt", "ar"]

const LOCALE_NAMES := {
	"en": "English",
	"fr": "Français",
	"es": "Español",
	"pt": "Português",
	"ar": "العربية",
}

static var _table : Dictionary = {}
static var _loaded := false

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var file := FileAccess.open("res://assets/json/translations.json", FileAccess.READ)
	if file == null:
		printerr("could not find or load translations.json")
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		printerr("could not parse translations.json")
		return
	file.close()
	_table = json.data as Dictionary

static func get_text(key: String, locale: String) -> String:
	_ensure_loaded()
	var entry : Dictionary = _table.get(key, {})
	if entry.has(locale) and not (entry[locale] as String).is_empty():
		return entry[locale]
	return entry.get("en", key)
