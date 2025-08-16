class_name RoadBuilder
extends RefCounted

var civilization_settings: CivilizationSettings

func _init(civ_settings: CivilizationSettings = null):
	civilization_settings = civ_settings
	if not civilization_settings:
		civilization_settings = CivilizationSettings.new()

func build_road_network(hex_grid: HexGrid, settlements: Array, resources: Array) -> Array:
	var roads = []
	var capital_pos = HexCoordinates.new(0, 0)
	
	# Connect settlements to capital
	for settlement in settlements:
		if settlement.settlement_type == "capital":
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

func _can_place_road(tile: HexTile) -> bool:
	var terrain_name = tile.get_terrain_name()
	return civilization_settings.can_place_road_on_terrain(terrain_name)

func _get_movement_cost(tile: HexTile) -> int:
	var terrain_name = tile.get_terrain_name()
	return civilization_settings.get_terrain_movement_cost(terrain_name)

func _coord_key(c: HexCoordinates) -> String:
	return "%d,%d" % [c.q, c.r]