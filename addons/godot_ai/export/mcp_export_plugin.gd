@tool
class_name McpExportPlugin
extends EditorExportPlugin

const ADDON_PREFIX := "res://addons/godot_ai/"


func _get_name() -> String:
	return "GodotAIExportPlugin"


func _export_file(path: String, _type: String, features: PackedStringArray) -> void:
	if not features.has("debug") and path.begins_with(ADDON_PREFIX):
		skip()
