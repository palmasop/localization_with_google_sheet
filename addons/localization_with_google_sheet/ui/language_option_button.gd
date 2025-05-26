# language_option_button.gd
# Purpose: UI OptionButton for selecting and switching the current language.
# Inputs: None (reads available languages from registered translations)
# Outputs: Changes the locale via TranslationServer.set_locale(language_code)
#
# Interface:
#   - Populates itself with available languages on ready
#   - Switches language on selection
#
# Usage Example:
#   var lang_btn = preload("res://addons/localization_with_google_sheet/ui/language_option_button.gd").new()
#   add_child(lang_btn)
#
# Test Template:
#   lang_btn._ready()
#   lang_btn._on_language_selected(1) # Simulate selecting a language

class_name LanguageOptionButton

extends OptionButton

# Only allow these languages
const ALLOWED_LANGUAGES = [
	"en", "zh", "zh_TW", "ko", "ja", "fr", "es", "de", "it", "pt", "ru", "tr"
]

# Language code to human-readable name mapping (autonyms)
const LANGUAGE_NAMES = {
	"en": "English",
	"zh": "简体中文",
	"zh_TW": "繁體中文",
	"ko": "한국어",
	"ja": "日本語",
	"fr": "Français",
	"es": "Español",
	"de": "Deutsch",
	"it": "Italiano",
	"pt": "Português",
	"ru": "Русский",
	"tr": "Türkçe"
}

# Helper: Extract language code from translation file path
func _extract_lang_code(path: String) -> String:
	# Try .translation.<lang>
	var regex = RegEx.new()
	regex.compile("\\.translation\\.([A-Za-z_]+)")
	var result = regex.search(path)
	if result:
		return result.get_string(1)
	# Try .<lang>.translation
	var parts = path.get_file().split(".")
	if parts.size() >= 3 and parts[-2] in ALLOWED_LANGUAGES:
		return parts[-2]
	return ""

# Get all available language codes from registered translations, filtered by allowed
func _get_available_languages() -> Array:
	var translations = ProjectSettings.get_setting("internationalization/locale/translations", [])
	var langs = []
	for t in translations:
		var lang = _extract_lang_code(str(t))
		print("File: %s, Extracted lang: %s" % [t, lang])
		if lang != "" and not langs.has(lang) and ALLOWED_LANGUAGES.has(lang):
			langs.append(lang)
	return langs

# Get display name for a language code
func _get_language_display(lang: String) -> String:
	if LANGUAGE_NAMES.has(lang):
		return "%s (%s)" % [LANGUAGE_NAMES[lang], lang]
	return lang

# Store language codes for each item
var _lang_codes := []

func _ready():
	clear()
	_lang_codes.clear()
	var langs = _get_available_languages()
	for lang in langs:
		add_item(_get_language_display(lang))
		_lang_codes.append(lang)
	# Set current to match current locale
	var current = TranslationServer.get_locale()
	var idx = langs.find(current)
	if idx != -1:
		select(idx)
	connect("item_selected", Callable(self, "_on_language_selected"))

func _on_language_selected(index: int):
	if index >= 0 and index < _lang_codes.size():
		var lang = _lang_codes[index]
		TranslationServer.set_locale(lang)
		# Optionally persist
		# ProjectSettings.set_setting("application/config/locale", lang)
		# ProjectSettings.save()
