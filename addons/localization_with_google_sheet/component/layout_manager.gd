# layout_manager.gd
# Purpose: Manage creation of the main plugin UI layout and loading popup
# Inputs: owner (Node) - the parent node to attach dialogs to
# Outputs: Dictionary with keys: dialog, entries_container, status_label, add_btn, loading_popup
#
# Interface:
#   - create_layout(owner: Node) -> Dictionary
#
# Usage Example:
#   var layout = layout_manager.create_layout(self)
#   var dialog = layout.dialog
#   var loading_popup = layout.loading_popup
#
extends Node

func create_layout(owner: Node) -> Dictionary:
	var dialog = AcceptDialog.new()
	dialog.title = "Localization Manager"
	dialog.exclusive = true
	owner.get_editor_interface().get_base_control().add_child(dialog)
	dialog.get_ok_button().hide()
	dialog.min_size = Vector2(600, 400)

	var vb = VBoxContainer.new()
	vb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dialog.add_child(vb)

	var entries_container = VBoxContainer.new()
	entries_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	entries_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(entries_container)

	var status_label = Label.new()
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(status_label)

	var add_btn = Button.new()
	add_btn.text = "+ Add"
	add_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(add_btn)

	var loading_popup = AcceptDialog.new()
	loading_popup.name = "LoadingPopup"
	loading_popup.title = "Please Wait"
	loading_popup.dialog_text = "Fetching..."
	loading_popup.get_ok_button().hide()
	loading_popup.exclusive = true
	dialog.add_child(loading_popup)

	return {
		"dialog": dialog,
		"entries_container": entries_container,
		"status_label": status_label,
		"add_btn": add_btn,
		"loading_popup": loading_popup
	}