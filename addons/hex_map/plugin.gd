@tool
extends EditorPlugin

var icon: Texture2D
var controller_script := preload("res://addons/hex_map/scripts/HexMapController.gd")

func _enter_tree() -> void:
	if icon == null:
		# Use a built-in editor icon to avoid missing file issues
		icon = get_editor_interface().get_base_control().get_theme_icon("Node2D", "EditorIcons")
	add_custom_type("HexMapController", "Node2D", controller_script, icon)

func _exit_tree() -> void:
	remove_custom_type("HexMapController")
