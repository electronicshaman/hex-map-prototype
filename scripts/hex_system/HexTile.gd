class_name HexTile
extends Resource

enum TerrainType {
	GOLDFIELD,
	BUSH,
	CREEK,
	TOWN,
	MOUNTAIN,
	ROAD,
	PLAINS
}

@export var coordinates: HexCoordinates
@export var terrain_type: TerrainType = TerrainType.PLAINS
@export var is_explored: bool = false
@export var is_visible: bool = false
@export var movement_cost: int = 1
@export var has_encounter: bool = false
@export var encounter_data: Dictionary = {}
@export var custom_data: Dictionary = {}

func _init(coords: HexCoordinates = null, terrain: TerrainType = TerrainType.PLAINS):
	coordinates = coords if coords else HexCoordinates.new()
	terrain_type = terrain
	_set_terrain_properties()

func _set_terrain_properties():
	match terrain_type:
		TerrainType.GOLDFIELD:
			movement_cost = 2
		TerrainType.BUSH:
			movement_cost = 3
		TerrainType.CREEK:
			movement_cost = 2
		TerrainType.TOWN:
			movement_cost = 1
		TerrainType.MOUNTAIN:
			movement_cost = 4
		TerrainType.ROAD:
			movement_cost = 1
		TerrainType.PLAINS:
			movement_cost = 2

func set_terrain(terrain: TerrainType):
	terrain_type = terrain
	_set_terrain_properties()

func explore():
	is_explored = true
	is_visible = true

func set_visibility(visible: bool):
	is_visible = visible

func can_move_to() -> bool:
	return movement_cost < 999

func get_terrain_name() -> String:
	match terrain_type:
		TerrainType.GOLDFIELD:
			return "Goldfield"
		TerrainType.BUSH:
			return "Bush"
		TerrainType.CREEK:
			return "Creek"
		TerrainType.TOWN:
			return "Town"
		TerrainType.MOUNTAIN:
			return "Mountain"
		TerrainType.ROAD:
			return "Road"
		TerrainType.PLAINS:
			return "Plains"
		_:
			return "Unknown"

func get_terrain_color() -> Color:
	match terrain_type:
		TerrainType.GOLDFIELD:
			return Color.GOLD
		TerrainType.BUSH:
			return Color.DARK_OLIVE_GREEN
		TerrainType.CREEK:
			return Color.CYAN
		TerrainType.TOWN:
			return Color.BROWN
		TerrainType.MOUNTAIN:
			return Color.DIM_GRAY
		TerrainType.ROAD:
			return Color.SANDY_BROWN
		TerrainType.PLAINS:
			return Color.YELLOW_GREEN
		_:
			return Color.WHITE

func to_dict() -> Dictionary:
	return {
		"coordinates": coordinates.to_dict() if coordinates else {},
		"terrain_type": terrain_type,
		"is_explored": is_explored,
		"is_visible": is_visible,
		"movement_cost": movement_cost,
		"has_encounter": has_encounter,
		"encounter_data": encounter_data,
		"custom_data": custom_data
	}

static func from_dict(data: Dictionary) -> HexTile:
	var tile = HexTile.new()
	tile.coordinates = HexCoordinates.from_dict(data.get("coordinates", {}))
	tile.terrain_type = data.get("terrain_type", TerrainType.PLAINS)
	tile.is_explored = data.get("is_explored", false)
	tile.is_visible = data.get("is_visible", false)
	tile.movement_cost = data.get("movement_cost", 1)
	tile.has_encounter = data.get("has_encounter", false)
	tile.encounter_data = data.get("encounter_data", {})
	tile.custom_data = data.get("custom_data", {})
	return tile
