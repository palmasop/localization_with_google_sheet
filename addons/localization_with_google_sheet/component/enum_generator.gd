# enum_generator.gd
# Purpose: Generate GDScript and C# enums from CSV keys
# Inputs: csv_path (String), workspace (String), plugin_dir (String)
# Outputs: Returns true on success, false on failure
#
# Interface:
#   - generate_enum_for(csv_path: String, workspace: String, plugin_dir: String) -> bool
#
# Usage Example:
#   var gen = enum_generator.new()
#   var ok = gen.generate_enum_for("res://.../file.csv", "WorkspaceName", "res://addons/localization_with_google_sheet")
#
# Test Template:
#   assert(gen.generate_enum_for("res://.../file.csv", "WorkspaceName", "res://addons/localization_with_google_sheet"))

extends Node

func generate_enum_for(csv_path: String, workspace: String, plugin_dir: String, resource_fs) -> bool:
	# Ensure output directories exist
	var gd_dir = plugin_dir + "/enum_gd"
	var cs_dir = plugin_dir + "/enum_csharp"
	if not DirAccess.dir_exists_absolute(gd_dir):
		DirAccess.make_dir_recursive_absolute(gd_dir)
	if not DirAccess.dir_exists_absolute(cs_dir):
		DirAccess.make_dir_recursive_absolute(cs_dir)

	var f = FileAccess.open(csv_path, FileAccess.READ)
	if not f:
		push_error("Cannot open %s"%csv_path)
		return false
	var lines = f.get_as_text().split("\n", false)
	f.close()
	if lines.size() < 2:
		push_error("Insufficient CSV data")
		return false

	var enum_name = "%s_localization_key"%workspace
	var enum_name_cs = "%s_LocalizationKey"%workspace
	var keys: Array = []
	for i in range(1, lines.size()):
		var row = lines[i].strip_edges()
		if row == "": continue
		var k = row.split(",", false)[0].strip_edges()
		if k != "" and not keys.has(k):
			keys.append(k)
	if keys.is_empty():
		push_error("No keys")
		return false

	var gd_out = ["# Auto-generated %s\n"%enum_name, "extends Node\n\n", "enum %s {\n"%enum_name]
	for k in keys:
		var id = _sanitize(k)
		if id != "": gd_out.append("\t%s,\n"%id)
	gd_out.append("}\n")

	var cs_out = ["namespace Localization {\n", "\tpublic enum %s {\n"%enum_name_cs]
	for k in keys:
		var id = _sanitize(k)
		if id != "": cs_out.append("\t\t%s,\n"%id)
	cs_out.append("\t}\n}\n")

	var gd_p = gd_dir + "/%s.gd" % enum_name
	var cs_p = cs_dir + "/%s.cs" % enum_name_cs

	var g = FileAccess.open(gd_p, FileAccess.WRITE)
	if not g:
		push_error("Enum write fail %s"%gd_p)
		return false
	g.store_string("".join(gd_out)); g.close()

	var c = FileAccess.open(cs_p, FileAccess.WRITE)
	if not c:
		push_error("Enum write fail %s"%cs_p)
		return false
	c.store_string("".join(cs_out)); c.close()

	resource_fs.update_file(gd_p)
	resource_fs.update_file(cs_p)
	resource_fs.scan()
	return true

func _sanitize(raw: String) -> String:
	var re = RegEx.new()
	re.compile("[^A-Za-z0-9_]")
	var clean = re.sub(raw, "", true)
	if clean.length() > 0 and clean.substr(0, 1) >= "0" and clean.substr(0, 1) <= "9":
		clean = "_" + clean
	if not clean.is_valid_identifier():
		clean = "_" + clean
	return clean