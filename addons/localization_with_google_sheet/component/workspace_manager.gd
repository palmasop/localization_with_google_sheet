# workspace_manager.gd
# Purpose: Manage CRUD and persistence of localization workspaces (name + URL)
# ... (docstring) ...

extends Node

const WS_SETTING := "localization_with_google_sheet/workspaces"
var workspaces: Array = []

func _init():
    if not ProjectSettings.has_setting(WS_SETTING):
        ProjectSettings.set_setting(WS_SETTING, [])
    workspaces = ProjectSettings.get_setting(WS_SETTING, []) as Array

func get_workspaces() -> Array:
    return workspaces.duplicate()

func add_workspace(name: String, url: String) -> void:
    workspaces.append({"name": name, "url": url})
    save()

func update_workspace(idx: int, name: String, url: String) -> void:
    if idx >= 0 and idx < workspaces.size():
        workspaces[idx]["name"] = name
        workspaces[idx]["url"] = url
        save()

func delete_workspace(idx: int) -> void:
    if idx >= 0 and idx < workspaces.size():
        workspaces.remove_at(idx)
        save()

func save() -> void:
    ProjectSettings.set_setting(WS_SETTING, workspaces)
    ProjectSettings.save()

func reload():
    workspaces = ProjectSettings.get_setting(WS_SETTING, []) as Array