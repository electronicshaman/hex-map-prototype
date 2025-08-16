class_name HexTile
extends Resource

@export var coordinates: HexCoordinates
@export var terrain_resource: TerrainTypeResource
@export var is_explored: bool = false
@export var is_visible: bool = false
@export var has_encounter: bool = false
@export var encounter_data: Dictionary = {}
@export var custom_data: Dictionary = {}

# Cached movement cost for performance
var _cached_movement_cost: int = 1

func _init(coords: HexCoordinates = null, terrain: TerrainTypeResource = null):
	coordinates = coords if coords else HexCoordinates.new()
	if terrain:
		set_terrain_resource(terrain)

func set_terrain_resource(terrain: TerrainTypeResource):
	terrain_resource = terrain
	if terrain_resource:
		_cached_movement_cost = terrain_resource.movement_cost
	else:
		_cached_movement_cost = 1

func get_movement_cost() -> int:
	if terrain_resource:
		return terrain_resource.movement_cost
	return _cached_movement_cost

func explore():
	is_explored = true
	is_visible = true

func set_visibility(visible: bool):
	is_visible = visible

func can_move_to() -> bool:
	if terrain_resource:
		return terrain_resource.passable
	return _cached_movement_cost < 999

func get_terrain_name() -> String:
	if terrain_resource:
		return terrain_resource.terrain_name
	return "Unknown"

func get_terrain_color() -> Color:
	if terrain_resource:
		return terrain_resource.get_display_color(is_visible, is_explored)
	return Color.WHITE

func to_dict() -> Dictionary:
	return {
		"coordinates": coordinates.to_dict() if coordinates else {},
		"terrain_name": terrain_resource.terrain_name if terrain_resource else "Unknown",
		"is_explored": is_explored,
		"is_visible": is_visible,
		"has_encounter": has_encounter,
		"encounter_data": encounter_data,
		"custom_data": custom_data
	}

static func from_dict(data: Dictionary, terrain_db: TerrainDatabase = null) -> HexTile:
	var tile = HexTile.new()
	tile.coordinates = HexCoordinates.from_dict(data.get("coordinates", {}))
	
	# Try to restore terrain from database if available
	var terrain_name = data.get("terrain_name", "Plains")
	if terrain_db:
		tile.terrain_resource = terrain_db.get_terrain_by_name(terrain_name)
	
	tile.is_explored = data.get("is_explored", false)
	tile.is_visible = data.get("is_visible", false)
	tile.has_encounter = data.get("has_encounter", false)
	tile.encounter_data = data.get("encounter_data", {})
	tile.custom_data = data.get("custom_data", {})
	return tile
