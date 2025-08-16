class_name ResourcePlacer
extends RefCounted

var civilization_settings: CivilizationSettings

func _init():
	if not civilization_settings:
		civilization_settings = CivilizationSettings.new()

func place_resources(hex_grid: HexGrid, rng: RandomNumberGenerator, settlements: Array) -> Array:
	var resources = []
	var forbidden = {}
	
	# Mark settlements as forbidden
	for settlement in settlements:
		forbidden[_coord_key(settlement.coordinates)] = true
	
	# Place gold mines
	var mine_count = rng.randi_range(
		civilization_settings.goldfield_mine_count_min,
		civilization_settings.goldfield_mine_count_max
	)
	
	for i in range(mine_count):
		var attempts = 0
		while attempts < civilization_settings.max_placement_attempts:
			attempts += 1
			var coord = _random_coord(hex_grid, rng)
			var key = _coord_key(coord)
			
			if key in forbidden:
				continue
			
			if _can_place_resource(hex_grid, coord):
				var resource = _create_resource(hex_grid, coord, "mine")
				resources.append(resource)
				forbidden[key] = true
				break
	
	return resources

func _create_resource(hex_grid: HexGrid, coord: HexCoordinates, resource_type: String) -> ResourceData:
	var resource = ResourceData.new(coord, resource_type)
	
	var terrain_db = hex_grid.terrain_database
	var tile = hex_grid.get_tile(coord)
	if tile:
		tile.set_terrain_resource(terrain_db.get_terrain_by_name("Goldfield"))
		tile.has_encounter = true
		tile.encounter_data = {
			"resource": "gold",
			"kind": resource_type
		}
	
	return resource

func _can_place_resource(hex_grid: HexGrid, coord: HexCoordinates) -> bool:
	var tile = hex_grid.get_tile(coord)
	if not tile:
		return false
	
	var terrain_name = tile.get_terrain_name()
	return terrain_name not in ["Mountain", "Creek", "Town", "Road"]

func _random_coord(hex_grid: HexGrid, rng: RandomNumberGenerator) -> HexCoordinates:
	var hw = hex_grid.grid_width >> 1
	var hh = hex_grid.grid_height >> 1
	var q = rng.randi_range(-hw, hw - 1)
	var r = rng.randi_range(-hh, hh - 1)
	return HexCoordinates.new(q, r)

func _coord_key(c: HexCoordinates) -> String:
	return "%d,%d" % [c.q, c.r]
