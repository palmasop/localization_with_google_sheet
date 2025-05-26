# translation_registrar.gd
# Purpose: Parse CSV and register translations in ProjectSettings
# Inputs: csv_path (String), workspace (String)
# Outputs: Returns true on success, false on failure
#
# Interface:
#   - process_translations_for(csv_path: String, workspace: String) -> bool
#
# Usage Example:
#   var reg = translation_registrar.new()
#   var ok = reg.process_translations_for("res://.../file.csv", "WorkspaceName")
#
# Test Template:
#   assert(reg.process_translations_for("res://.../file.csv", "WorkspaceName"))

@tool
extends Node

const CSV_BASE_DIR := "res://data/localization"

func process_translations_for(csv_path: String, workspace: String) -> bool:
	var f = FileAccess.open(csv_path, FileAccess.READ)
	if not f:
		push_error("Cannot read %s"%csv_path)
		return false
	var lines = f.get_as_text().split("\n", false)
	f.close()
	if lines.size() == 0:
		return false

	var base = csv_path.substr(0, csv_path.rfind(".csv"))
	var cols = lines[0].split(",", false)
	var newt: Array = []
	for i in range(1, cols.size()):
		var lang = cols[i].strip_edges()
		if lang == "": continue
		var tp = "%s.%s.translation" % [base, lang]
		if FileAccess.file_exists(tp):
			newt.append(tp)
		else:
			push_warning("Missing: %s"%tp)
	if newt.is_empty():
		return false

	var existing = ProjectSettings.get_setting("internationalization/locale/translations", []) as Array
	var prefix = "%s/%s" % [CSV_BASE_DIR, workspace]
	for old in existing.duplicate():
		if old.begins_with(prefix):
			existing.erase(old)
	for p in newt:
		if not existing.has(p):
			existing.append(p)

	ProjectSettings.set_setting("internationalization/locale/translations", existing)
	ProjectSettings.save()
	return true

# Remove translation paths from ProjectSettings
func remove_translations_for(workspace: String):
	var prefix = "res://data/localization/%s" % workspace
	var translations = ProjectSettings.get_setting("internationalization/locale/translations", []) as Array
	var changed = false
	for t in translations.duplicate():
		if t.begins_with(prefix):
			translations.erase(t)
			changed = true
	if changed:
		ProjectSettings.set_setting("internationalization/locale/translations", translations)
		ProjectSettings.save()