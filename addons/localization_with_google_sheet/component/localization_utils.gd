# localization_utils.gd
# Purpose: Utility functions for localization plugin (URL parsing, sanitization)
# Inputs/Outputs: As described per function
#
# Interface:
#   - get_csv_export_url(url: String) -> String
#   - sanitize(raw: String) -> String
#
# Usage Example:
#   var url = localization_utils.get_csv_export_url("https://docs.google.com/spreadsheets/d/...")
#   var id = localization_utils.sanitize("Some Key!")
#
# Test Template:
#   assert(localization_utils.get_csv_export_url("...").begins_with("https://docs.google.com/spreadsheets/d/"))
#   assert(localization_utils.sanitize("1abc") == "_1abc")

extends Node

static func get_csv_export_url(url: String) -> String:
	if url.find("/pub?") != -1 or url.find("/export?") != -1:
		return url
	var re = RegEx.new()
	re.compile("https://docs\\.google\\.com/spreadsheets/d/(?:e/)?([A-Za-z0-9_-]+)")
	var m = re.search(url)
	if m:
		var id = m.get_string(1)
		var gid = "0"
		var re2 = RegEx.new()
		re2.compile("gid=([0-9]+)")
		var gm = re2.search(url)
		if gm:
			gid = gm.get_string(1)
		return "https://docs.google.com/spreadsheets/d/%s/export?format=csv&gid=%s" % [id, gid]
	return url

static func sanitize(raw: String) -> String:
	var re = RegEx.new()
	re.compile("[^A-Za-z0-9_]")
	var clean = re.sub(raw, "", true)
	if clean.length() > 0 and clean.substr(0, 1) >= "0" and clean.substr(0, 1) <= "9":
		clean = "_" + clean
	if not clean.is_valid_identifier():
		clean = "_" + clean
	return clean