class_name TerrainDatabase
extends Resource

@export var terrain_types: Array[TerrainTypeResource] = []

var _terrain_by_name: Dictionary = {}
var _terrain_by_index: Dictionary = {}

func _init():
	_rebuild_cache()

func _rebuild_cache():
	_terrain_by_name.clear()
	_terrain_by_index.clear()
	
	for i in range(terrain_types.size()):
		var terrain = terrain_types[i]
		if terrain:
			_terrain_by_name[terrain.terrain_name] = terrain
			_terrain_by_index[i] = terrain

func get_terrain_by_name(name: String) -> TerrainTypeResource:
	if _terrain_by_name.is_empty():
		_rebuild_cache()
	return _terrain_by_name.get(name, null)

func get_terrain_by_index(index: int) -> TerrainTypeResource:
	if _terrain_by_index.is_empty():
		_rebuild_cache()
	return _terrain_by_index.get(index, null)

func get_terrain_index(terrain: TerrainTypeResource) -> int:
	return terrain_types.find(terrain)

func add_terrain_type(terrain: TerrainTypeResource):
	if terrain and terrain not in terrain_types:
		terrain_types.append(terrain)
		_rebuild_cache()

func remove_terrain_type(terrain: TerrainTypeResource):
	if terrain and terrain in terrain_types:
		terrain_types.erase(terrain)
		_rebuild_cache()

func get_all_terrain_names() -> Array[String]:
	var names: Array[String] = []
	for terrain in terrain_types:
		if terrain:
			names.append(terrain.terrain_name)
	return names

func get_passable_terrains() -> Array[TerrainTypeResource]:
	var passable: Array[TerrainTypeResource] = []
	for terrain in terrain_types:
		if terrain and terrain.passable:
			passable.append(terrain)
	return passable

func get_buildable_terrains() -> Array[TerrainTypeResource]:
	var buildable: Array[TerrainTypeResource] = []
	for terrain in terrain_types:
		if terrain and terrain.buildable:
			buildable.append(terrain)
	return buildable