@tool
extends EditorPlugin

var _icon := preload("res://icon.svg")
var _controller_script := preload("res://addons/hex_map/scripts/HexMapController.gd")

func _enter_tree() -> void:
	add_custom_type("HexMapController", "Node2D", _controller_script, _icon)

func _exit_tree() -> void:
	remove_custom_type("HexMapController")
