class_name RoadBuilder
extends RefCounted

var civilization_settings: CivilizationSettings

func build_road_network(hex_grid: HexGrid, settlements: Array[SettlementData], resources: Array[ResourceData]) -> Array[HexCoordinates]:
	var roads: Array[HexCoordinates] = []
	
	# Build roads connecting settlements to capital
	var capital_roads = _connect_settlements_to_capital(hex_grid, settlements)
	roads.append_array(capital_roads)
	
	# Build roads connecting major resource sites
	var resource_roads = _connect_major_resources(hex_grid, settlements, resources)
	roads.append_array(resource_roads)
	
	print("RoadBuilder: Built ", roads.size(), " road segments")
	return roads

func _connect_settlements_to_capital(hex_grid: HexGrid, settlements: Array[SettlementData]) -> Array[HexCoordinates]:
	var roads: Array[HexCoordinates] = []
	var capital_pos = HexCoordinates.new(0, 0)
	
	for settlement in settlements:
		# Skip the capital itself
		if settlement.settlement_type == "capital":
			continue
		
		var path = _find_low_cost_path(hex_grid, capital_pos, settlement.coordinates)
		var road_tiles = _build_road_on_path(hex_grid, path)
		roads.append_array(road_tiles)
	
	return roads

func _connect_major_resources(hex_grid: HexGrid, settlements: Array[SettlementData], resources: Array[ResourceData]) -> Array[HexCoordinates]:
	var roads: Array[HexCoordinates] = []
	
	# Connect high-value resources to nearest settlements
	for resource in resources:
		if resource.quality == "rich" or resource.resource_type == "gold_mine":
			var nearest_settlement = _find_nearest_settlement(resource.coordinates, settlements)
			if nearest_settlement:
				var path = _find_low_cost_path(hex_grid, resource.coordinates, nearest_settlement.coordinates)
				var road_tiles = _build_road_on_path(hex_grid, path)
				roads.append_array(road_tiles)
	
	return roads

func _find_nearest_settlement(coord: HexCoordinates, settlements: Array[SettlementData]) -> SettlementData:
	var nearest: SettlementData = null
	var min_distance = 999999
	
	for settlement in settlements:
		var distance = coord.distance_to(settlement.coordinates)
		if distance < min_distance:
			min_distance = distance
			nearest = settlement
	
	return nearest

func _build_road_on_path(hex_grid: HexGrid, path: Array[HexCoordinates]) -> Array[HexCoordinates]:
	var road_tiles: Array[HexCoordinates] = []
	var terrain_db = hex_grid.terrain_database
	
	for coord in path:
		var tile = hex_grid.get_tile(coord)
		if tile:
			var terrain_name = tile.get_terrain_name()
			if civilization_settings.can_place_road_on_terrain(terrain_name):
				tile.set_terrain_resource(terrain_db.get_terrain_by_name("Road"))
				road_tiles.append(coord)
	
	return road_tiles

func _find_low_cost_path(hex_grid: HexGrid, start: HexCoordinates, end: HexCoordinates) -> Array[HexCoordinates]:
	# A* pathfinding with terrain cost weighting
	var frontier: Array[HexCoordinates] = []
	var priority_map: Dictionary = {}
	var came_from: Dictionary = {}
	var g_cost: Dictionary = {}

	frontier.push_back(start)
	priority_map[_coord_key(start)] = 0.0
	came_from[_coord_key(start)] = null
	g_cost[_coord_key(start)] = 0

	while frontier.size() > 0:
		var current = frontier.pop_front()
		
		if current.equals(end):
			break
		
		for neighbor in current.get_all_neighbors():
			var step_cost = _get_terrain_cost(hex_grid, neighbor)
			if step_cost >= 9999:
				continue
			
			var new_cost = g_cost[_coord_key(current)] + step_cost
			var neighbor_key = _coord_key(neighbor)
			
			if neighbor_key not in g_cost or new_cost < g_cost[neighbor_key]:
				g_cost[neighbor_key] = new_cost
				var priority = float(new_cost + neighbor.distance_to(end))
				_insert_sorted(frontier, neighbor, priority, priority_map)
				came_from[neighbor_key] = current

	# Reconstruct path
	var path: Array[HexCoordinates] = []
	var cursor: HexCoordinates = end
	
	while cursor != null and _coord_key(cursor) in came_from:
		path.push_front(cursor)
		cursor = came_from[_coord_key(cursor)]
	
	return path

func _get_terrain_cost(hex_grid: HexGrid, coord: HexCoordinates) -> int:
	var tile = hex_grid.get_tile(coord)
	if not tile:
		return 9999
	
	var terrain_name = tile.get_terrain_name()
	return civilization_settings.get_terrain_movement_cost(terrain_name)

func _insert_sorted(array: Array, item: HexCoordinates, priority: float, priority_map: Dictionary):
	var key = _coord_key(item)
	priority_map[key] = priority
	
	for i in range(array.size()):
		var other: HexCoordinates = array[i]
		var other_priority = priority_map.get(_coord_key(other), 1e20)
		if priority < other_priority:
			array.insert(i, item)
			return
	
	array.push_back(item)

func _coord_key(c: HexCoordinates) -> String:
	return "%d,%d" % [c.q, c.r]