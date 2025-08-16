class_name ResourceData
extends RefCounted

var coordinates: HexCoordinates
var resource_type: String # "gold_mine", "gold_deposit", etc.
var quality: String # "poor", "good", "rich"
var encounter_data: Dictionary

func _init(coords: HexCoordinates, type: String):
	coordinates = coords
	resource_type = type
	quality = "good" # Default quality
