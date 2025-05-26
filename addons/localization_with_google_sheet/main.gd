# res://addons/localization_with_google_sheet/localization_with_google_sheet.gd

# Refactored: This script now only orchestrates the plugin and delegates logic to components.
# Components:
#   - WorkspaceManager: CRUD and persistence of workspaces
#   - CSVFetcher: Download CSV from Google Sheets
#   - TranslationRegistrar: Parse CSV and register translations
#   - EnumGenerator: Generate enums from CSV keys
#   - LocalizationUtils: Utility functions
#   - LayoutManager: Manages UI layout and creation
#
# Each component is documented in its own file.

@tool
extends EditorPlugin

const CSV_BASE_DIR := "res://data/localization"
const WS_SETTING := "localization_with_google_sheet/workspaces"

# Component instances
var workspace_manager
var csv_fetcher
var translation_registrar
var enum_generator
var layout_manager

var plugin_dir: String
var dialog: AcceptDialog
var entries_container: VBoxContainer
var add_btn: Button
var status_label: Label
var loading_popup: AcceptDialog

var request_headers: Array = [
	"User-Agent: godot-editor-plugin",
	"Accept: text/csv,*/*"
]

var refresh_buttons: Array = []
var pending_delete_idx: int = -1
var scan_timer: Timer = null
var scan_in_progress := false
var scan_queued := false
var running_queued_scan := false
var is_refreshing_ui := false

func _enter_tree() -> void:
	plugin_dir = get_script().get_path().get_base_dir()
	# Instantiate components
	workspace_manager = load("res://addons/localization_with_google_sheet/component/workspace_manager.gd").new()
	csv_fetcher = load("res://addons/localization_with_google_sheet/component/csv_fetcher.gd").new()
	translation_registrar = load("res://addons/localization_with_google_sheet/component/translation_registrar.gd").new()
	enum_generator = load("res://addons/localization_with_google_sheet/component/enum_generator.gd").new()
	layout_manager = load("res://addons/localization_with_google_sheet/component/layout_manager.gd").new()
	add_child(workspace_manager)
	add_child(csv_fetcher)
	add_child(translation_registrar)
	add_child(enum_generator)
	add_child(layout_manager)
	if not ProjectSettings.has_setting(WS_SETTING):
		ProjectSettings.set_setting(WS_SETTING, [])
	add_tool_menu_item("Localization", Callable(self, "_on_localization_menu_item_pressed"))

func _exit_tree() -> void:
	remove_tool_menu_item("Localization")

func _on_localization_menu_item_pressed() -> void:
	if not dialog:
		_create_dialog()
	dialog.popup_centered()

func _create_dialog() -> void:
	var layout = layout_manager.create_layout(self)
	dialog = layout.dialog
	entries_container = layout.entries_container
	status_label = layout.status_label
	add_btn = layout.add_btn
	loading_popup = layout.loading_popup
	add_btn.connect("pressed", Callable(self, "_on_add_workspace"))

	_refresh_workspace_list_ui()

func _clear_entries_container() -> void:
	for child in entries_container.get_children():
		child.queue_free()

func _refresh_workspace_list_ui() -> void:
	if is_refreshing_ui:
		print("UI refresh already in progress, skipping")
		return
	is_refreshing_ui = true
	_clear_entries_container()

	# --- First row: Template and Tutorial links right-aligned ---
	var links_row = HBoxContainer.new()
	links_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var links_spacer = Control.new()
	links_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	links_row.add_child(links_spacer)

	var template_link = LinkButton.new()
	template_link.text = "Template"
	template_link.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	template_link.connect("pressed", Callable(self, "_on_template_link_pressed"))
	links_row.add_child(template_link)

	var gap = Control.new()
	gap.custom_minimum_size = Vector2(8, 0)
	links_row.add_child(gap)

	var tutorial_link = LinkButton.new()
	tutorial_link.text = "Tutorial"
	tutorial_link.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tutorial_link.connect("pressed", Callable(self, "_on_tutorial_link_pressed"))
	links_row.add_child(tutorial_link)

	entries_container.add_child(links_row)

	# --- Second row: Title left-aligned and large ---
	var title_row = HBoxContainer.new()
	title_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var title_label = Label.new()
	title_label.text = "Your Localization"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title_label.add_theme_font_size_override("font_size", 22)
	title_row.add_child(title_label)

	entries_container.add_child(title_row)

	# --- Column header row ---
	var header_row_columns = HBoxContainer.new()
	header_row_columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_label = Label.new()
	name_label.text = "Name"
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row_columns.add_child(name_label)

	var url_label = Label.new()
	url_label.text = "Google Sheet URL"
	url_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row_columns.add_child(url_label)

	var del_label = Label.new()
	del_label.text = "Delete"
	del_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row_columns.add_child(del_label)

	var ref_label = Label.new()
	ref_label.text = "Refresh"
	ref_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row_columns.add_child(ref_label)

	entries_container.add_child(header_row_columns)

	# --- Workspace rows ---
	var workspaces = workspace_manager.get_workspaces()
	refresh_buttons.clear()
	for i in range(workspaces.size()):
		var entry = workspaces[i] as Dictionary
		var row = HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		entries_container.add_child(row)

		# Name Field
		var name_edit = LineEdit.new()
		name_edit.placeholder_text = "Name"
		name_edit.text = entry.get("name", "")
		name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_edit.connect(
			"text_changed",
			Callable(self, "_on_entry_name_changed").bind(i)
		)
		row.add_child(name_edit)

		# URL Field
		var url_edit = LineEdit.new()
		url_edit.placeholder_text = "Google Sheet URL"
		url_edit.text = entry.get("url", "")
		url_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		url_edit.connect(
			"text_changed",
			Callable(self, "_on_entry_url_changed").bind(i)
		)
		row.add_child(url_edit)

		# Delete Button
		var del_btn = Button.new()
		del_btn.text = "Delete"
		del_btn.connect(
			"pressed",
			Callable(self, "_on_delete_workspace").bind(i)
		)
		row.add_child(del_btn)

		# Refresh Button
		var ref_btn = Button.new()
		ref_btn.text = "Refresh"
		ref_btn.connect(
			"pressed",
			Callable(self, "_on_refresh_workspace").bind(i)
		)
		row.add_child(ref_btn)

		refresh_buttons.append(ref_btn)

	is_refreshing_ui = false

func _on_add_workspace() -> void:
	workspace_manager.add_workspace("", "")
	_refresh_workspace_list_ui()

func _on_entry_name_changed(new_text: String, idx: int) -> void:
	var workspaces = workspace_manager.get_workspaces()
	if idx >= 0 and idx < workspaces.size():
		workspace_manager.update_workspace(idx, new_text.strip_edges(), workspaces[idx]["url"])

func _on_entry_url_changed(new_text: String, idx: int) -> void:
	var workspaces = workspace_manager.get_workspaces()
	if idx >= 0 and idx < workspaces.size():
		workspace_manager.update_workspace(idx, workspaces[idx]["name"], new_text.strip_edges())

func _on_delete_workspace(idx: int) -> void:
	var workspaces = workspace_manager.get_workspaces()
	var entry = workspaces[idx] as Dictionary
	var ws_name = entry["name"].strip_edges()
	if ws_name == "":
		workspace_manager.delete_workspace(idx)
		workspace_manager.reload()
		_refresh_workspace_list_ui()
		return
	pending_delete_idx = idx
	var dlg = ConfirmationDialog.new()
	dlg.name = "DeleteWorkspaceDialog"
	dlg.exclusive = true
	dlg.set_title("Delete Workspace?")
	dlg.set_text("Delete this would also delete related translation in gamesetting and the types file.")
	dlg.get_ok_button().text = "Confirm"
	dlg.get_cancel_button().text = "Cancel"
	dlg.connect("confirmed", Callable(self, "_on_confirm_delete_workspace"))
	dialog.add_child(dlg)
	dlg.popup_centered()

func _on_confirm_delete_workspace() -> void:
	if pending_delete_idx >= 0:
		var workspaces = workspace_manager.get_workspaces()
		var entry = workspaces[pending_delete_idx] as Dictionary
		var ws = entry["name"].strip_edges().replace(" ", "_")
		# Delete GDScript enum file
		var gd_enum_path = "addons/localization_with_google_sheet/enum_gd/%s_localization_key.gd" % ws
		if FileAccess.file_exists(gd_enum_path):
			DirAccess.remove_absolute(gd_enum_path)
		# Delete C# enum file
		var cs_enum_path = "addons/localization_with_google_sheet/enum_csharp/%s_LocalizationKey.cs" % ws
		if FileAccess.file_exists(cs_enum_path):
			DirAccess.remove_absolute(cs_enum_path)
		# Delete translation directory and all files
		var trans_dir = "data/localization/%s" % ws
		if DirAccess.dir_exists_absolute(trans_dir):
			var dir = DirAccess.open(trans_dir)
			dir.list_dir_begin()
			var file_name = dir.get_next()
			while file_name != "":
				if not dir.current_is_dir():
					dir.remove(file_name)
				file_name = dir.get_next()
			dir.list_dir_end()
			DirAccess.remove_absolute(trans_dir)
		# Remove translations from ProjectSettings
		translation_registrar.remove_translations_for(ws)
		workspace_manager.delete_workspace(pending_delete_idx)
		workspace_manager.reload()
		pending_delete_idx = -1
		var fs = get_editor_interface().get_resource_filesystem()
		fs.scan()
		fs.update_file(gd_enum_path)
		fs.update_file(cs_enum_path)
		await _scan_filesystem_and_then(func():
			call_deferred("_refresh_workspace_list_ui")
			call_deferred("_show_delete_success_popup")
			_touch_parent_dir("data/localization")
		)

func _show_delete_success_popup() -> void:
	var popup = AcceptDialog.new()
	popup.title = "Success"
	popup.dialog_text = "Workspace and related files deleted successfully."
	popup.get_ok_button().text = "OK"
	popup.exclusive = true
	dialog.add_child(popup)
	popup.popup_centered()

func _on_refresh_workspace(idx: int) -> void:
	_set_refresh_buttons_disabled(true)
	var workspaces = workspace_manager.get_workspaces()
	var entry = workspaces[idx] as Dictionary
	var url = entry["url"]
	if url.strip_edges() == "":
		loading_popup.dialog_text = "URL is empty."
		loading_popup.popup_centered()
		await get_tree().create_timer(1.5).timeout
		loading_popup.hide()
		_set_refresh_buttons_disabled(false)
		status_label.text = "URL is empty."
		return
	loading_popup.dialog_text = "Fetching…"
	loading_popup.popup_centered()
	status_label.text = "Fetching “%s”…" % entry["name"]
	var ws = entry["name"].strip_edges().replace(" ", "_")
	var proj = ProjectSettings.get_setting("application/config/name", "Project").strip_edges().replace(" ", "_")
	var ws_dir = "%s/%s" % [CSV_BASE_DIR, ws]
	var csv_path = "%s/%s_%s_translation.csv" % [ws_dir, proj, ws]
	if not DirAccess.dir_exists_absolute(ws_dir):
		DirAccess.make_dir_recursive_absolute(ws_dir)
	var csv_url = load("res://addons/localization_with_google_sheet/component/localization_utils.gd").get_csv_export_url(entry["url"])
	if csv_fetcher.is_connected("csv_fetched", Callable(self, "_on_csv_fetched")):
		csv_fetcher.disconnect("csv_fetched", Callable(self, "_on_csv_fetched"))
	csv_fetcher.connect("csv_fetched", Callable(self, "_on_csv_fetched"), CONNECT_ONE_SHOT)
	csv_fetcher.fetch_csv(entry["name"], csv_url, request_headers, csv_path)

func _on_csv_fetched(result: int, response_code: int, headers: Array, body: PackedByteArray, csv_path: String) -> void:
	loading_popup.hide()
	_set_refresh_buttons_disabled(false)
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		status_label.text = "Fetch failed (%d)" % response_code
		_show_fetch_error_popup(response_code)
		return
	status_label.text = "Saved → %s" % csv_path
	_show_apply_translations_dialog(csv_path)

func _show_fetch_error_popup(response_code: int) -> void:
	var popup = AcceptDialog.new()
	popup.title = "Fetch Error"
	popup.dialog_text = "Failed to fetch CSV. HTTP code: %d" % response_code
	popup.get_ok_button().text = "OK"
	popup.exclusive = true
	dialog.add_child(popup)
	popup.popup_centered()

func _show_apply_translations_dialog(csv_path: String) -> void:
	if dialog.has_node("ApplyTranslationsDialog"):
		var old = dialog.get_node("ApplyTranslationsDialog")
		dialog.remove_child(old)
		old.queue_free()
	var dlg = ConfirmationDialog.new()
	dlg.name = "ApplyTranslationsDialog"
	dlg.exclusive = false
	dlg.set_title("Apply Translations?")
	dlg.set_text("Apply translations to Game Settings?")
	dlg.get_ok_button().text = "Confirm"
	dlg.get_cancel_button().text = "Cancel"
	dlg.connect("confirmed", Callable(self, "_on_apply_translations_confirmed").bind(csv_path))
	dialog.add_child(dlg)
	dlg.popup_centered()

func _on_apply_translations_confirmed(csv_path: String) -> void:
	var workspace = csv_path.get_file().split("_")[-2]
	status_label.text = "Applying translations for %s…" % workspace

	await _scan_filesystem_and_then(func():
		print("translation_registrar.process_translations_for(csv_path, workspace)")

		if translation_registrar.process_translations_for(csv_path, workspace):
			status_label.text = "Registered translations for %s." % workspace
		else:
			status_label.text = "Failed to register translations for %s." % workspace
			return

		print("enum_generator.generate_enum_for(csv_path, workspace, plugin_dir, fs)")

		var editor_interface = get_editor_interface()
		if not editor_interface:
			print("Editor interface not available!")
			return
		var fs = editor_interface.get_resource_filesystem()
		if not fs:
			print("Resource filesystem not available!")
			return
		if enum_generator.generate_enum_for(csv_path, workspace, plugin_dir, fs):
			status_label.text += " Enum generated."
		else:
			status_label.text += " Enum gen failed."
		_refresh_workspace_list_ui()
	)

func _set_refresh_buttons_disabled(disabled: bool) -> void:
	for btn in refresh_buttons.duplicate():
		if is_instance_valid(btn):
			btn.disabled = disabled

func _scan_filesystem_and_then(callback: Callable) -> void:
	var editor_interface = get_editor_interface()
	if not editor_interface:
		print("Editor interface not available!")
		return
	var fs = editor_interface.get_resource_filesystem()
	if not fs:
		print("Resource filesystem not available!")
		return

	# Connect the callback to the signal, one-shot so it disconnects after firing
	fs.filesystem_changed.connect(callback, CONNECT_ONE_SHOT)
	fs.scan()

func _touch_parent_dir(path: String) -> void:
	var dummy_path = path + "/.dummy"
	var f = FileAccess.open(dummy_path, FileAccess.WRITE)
	if f:
		f.store_line("force update")
		f.close()
		DirAccess.remove_absolute(dummy_path)

# Add handler for template link/button
func _on_template_link_pressed() -> void:
	OS.shell_open("https://docs.google.com/spreadsheets/d/1qpASVrKa8W4SQscppcuo9j0iQWIaM2IlscuIX52MmwY/edit?usp=sharing") # Replace with your actual template link

# Add handler for tutorial link/button
func _on_tutorial_link_pressed() -> void:
	OS.shell_open("https://www.youtube.com/watch?v=mX8JiJAYOEo") # Replace with your actual tutorial link
