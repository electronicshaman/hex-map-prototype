class_name CivilizationGeneratorSimple
extends RefCounted

var civilization_settings: CivilizationSettings

func _init():
	if not civilization_settings:
		civilization_settings = CivilizationSettings.new()

# Main entry point for civilization generation
func generate_civilization_for_grid(hex_grid: HexGrid, rng: RandomNumberGenerator) -> Dictionary:
	print("=== Starting civilization generation ===")
	
	var result = {
		"settlements": [],
		"resources": [],
		"roads": []
	}
	
	# Phase 1: Place settlements
	var settlements = _place_settlements(hex_grid, rng)
	result.settlements = settlements
	
	# Phase 2: Place resources
	var resources = _place_resources(hex_grid, rng, settlements)
	result.resources = resources
	
	# Phase 3: Build roads
	var roads = _build_roads(hex_grid, settlements, resources)
	result.roads = roads
	
	print("=== Civilization generation completed ===")
	print("  Settlements: ", settlements.size())
	print("  Resources: ", resources.size())
	print("  Roads: ", roads.size())
	
	return result

func _place_settlements(hex_grid: HexGrid, rng: RandomNumberGenerator) -> Array:
	var settlements = []
	var forbidden = {}
	
	# Place capital at center
	var capital = _place_capital(hex_grid, forbidden)
	settlements.append(capital)
	
	# Place distributed settlements
	var settlement_count = rng.randi_range(
		civilization_settings.settlement_min_count,
		civilization_settings.settlement_max_count
	)
	
	var attempts = 0
	while settlements.size() < settlement_count + 1 and attempts < civilization_settings.max_settlement_attempts:
		attempts += 1
		var coord = _random_coord(hex_grid, rng)
		if _can_place_settlement(hex_grid, coord, forbidden):
			var settlement = _create_settlement(hex_grid, coord, forbidden)
			settlements.append(settlement)
	
	return settlements

func _place_capital(hex_grid: HexGrid, forbidden: Dictionary) -> Dictionary:
	var center = HexCoordinates.new(0, 0)
	var capital = {
		"coordinates": center,
		"type": "capital",
		"size": 7
	}
	
	# Place 7-hex capital
	var capital_hexes = [center]
	for neighbor in center.get_all_neighbors():
		capital_hexes.append(neighbor)
	
	var terrain_db = hex_grid.terrain_database
	for coords in capital_hexes:
		var tile = hex_grid.get_tile(coords)
		if tile:
			tile.set_terrain_resource(terrain_db.get_terrain_by_name("Town"))
			forbidden[_coord_key(coords)] = true
	
	return capital

func _create_settlement(hex_grid: HexGrid, coord: HexCoordinates, forbidden: Dictionary) -> Dictionary:
	var settlement = {
		"coordinates": coord,
		"type": "village",
		"size": 1
	}
	
	var terrain_db = hex_grid.terrain_database
	var tile = hex_grid.get_tile(coord)
	if tile:
		tile.set_terrain_resource(terrain_db.get_terrain_by_name("Town"))
		forbidden[_coord_key(coord)] = true
	
	return settlement

func _place_resources(hex_grid: HexGrid, rng: RandomNumberGenerator, settlements: Array) -> Array:
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

func _create_resource(hex_grid: HexGrid, coord: HexCoordinates, resource_type: String) -> Dictionary:
	var resource = {
		"coordinates": coord,
		"type": resource_type
	}
	
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

func _build_roads(hex_grid: HexGrid, settlements: Array, resources: Array) -> Array:
	var roads = []
	var capital_pos = HexCoordinates.new(0, 0)
	
	# Connect settlements to capital
	for settlement in settlements:
		if settlement.type == "capital":
			continue
		
		var path = _find_path(hex_grid, capital_pos, settlement.coordinates)
		for coord in path:
			var tile = hex_grid.get_tile(coord)
			if tile and _can_place_road(tile):
				tile.set_terrain_resource(hex_grid.terrain_database.get_terrain_by_name("Road"))
				roads.append(coord)
	
	return roads

func _find_path(hex_grid: HexGrid, start: HexCoordinates, end: HexCoordinates) -> Array:
	# Simple A* implementation
	var frontier = [start]
	var came_from = {_coord_key(start): null}
	var cost_so_far = {_coord_key(start): 0}
	
	while frontier.size() > 0:
		var current = frontier.pop_front()
		
		if current.equals(end):
			break
		
		for neighbor in current.get_all_neighbors():
			var tile = hex_grid.get_tile(neighbor)
			if not tile:
				continue
			
			var new_cost = cost_so_far[_coord_key(current)] + _get_movement_cost(tile)
			var neighbor_key = _coord_key(neighbor)
			
			if neighbor_key not in cost_so_far or new_cost < cost_so_far[neighbor_key]:
				cost_so_far[neighbor_key] = new_cost
				frontier.append(neighbor)
				came_from[neighbor_key] = current
	
	# Reconstruct path
	var path = []
	var current = end
	while current != null and _coord_key(current) in came_from:
		path.push_front(current)
		current = came_from[_coord_key(current)]
	
	return path

func _can_place_settlement(hex_grid: HexGrid, coord: HexCoordinates, forbidden: Dictionary) -> bool:
	var key = _coord_key(coord)
	if key in forbidden:
		return false
	
	var tile = hex_grid.get_tile(coord)
	if not tile:
		return false
	
	var terrain_name = tile.get_terrain_name()
	return civilization_settings.is_terrain_suitable_for_settlement(terrain_name)

func _can_place_resource(hex_grid: HexGrid, coord: HexCoordinates) -> bool:
	var tile = hex_grid.get_tile(coord)
	if not tile:
		return false
	
	var terrain_name = tile.get_terrain_name()
	return terrain_name not in ["Mountain", "Creek", "Town", "Road"]

func _can_place_road(tile: HexTile) -> bool:
	var terrain_name = tile.get_terrain_name()
	return civilization_settings.can_place_road_on_terrain(terrain_name)

func _get_movement_cost(tile: HexTile) -> int:
	var terrain_name = tile.get_terrain_name()
	return civilization_settings.get_terrain_movement_cost(terrain_name)

func _random_coord(hex_grid: HexGrid, rng: RandomNumberGenerator) -> HexCoordinates:
	var hw = hex_grid.grid_width >> 1
	var hh = hex_grid.grid_height >> 1
	var q = rng.randi_range(-hw, hw - 1)
	var r = rng.randi_range(-hh, hh - 1)
	return HexCoordinates.new(q, r)

func _coord_key(c: HexCoordinates) -> String:
	return "%d,%d" % [c.q, c.r]
