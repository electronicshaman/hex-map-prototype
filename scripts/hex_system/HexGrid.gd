class_name HexGrid
extends Node2D

signal tile_clicked(tile: HexTile)
signal tile_hovered(tile: HexTile)

@export var grid_width: int = 80
@export var grid_height: int = 60
@export var hex_size: float = 32.0
@export var flat_top: bool = false
@export var terrain_generator: Resource
@export var terrain_database: TerrainDatabase

var tiles: Dictionary = {}
var tile_map: TileMap
var highlight_layer: Node2D
var player_position: HexCoordinates

func _ready():
	_initialize_grid()
	_setup_tilemap()
	_generate_world()

func _initialize_grid():
	# Load default terrain database if not set
	if not terrain_database:
		terrain_database = load("res://resources/default_terrain_database.tres")
		print("Loaded default terrain database")
	
	var default_terrain = terrain_database.get_terrain_by_name("Plains")
	var count = 0
	for q in range(-_half_w(), _half_w()):
		for r in range(-_half_h(), _half_h()):
			var coords = HexCoordinates.new(q, r)
			var tile = HexTile.new(coords, default_terrain)
			# Start unseen and unexplored; visibility will be updated around player
			tile.set_visibility(false)
			tiles[_coord_key(coords)] = tile
			count += 1
			
			# Debug: Print some sample coordinates
			if count <= 5 or (q == 10 and r == 12):
				print("Created tile at: ", coords._to_string(), " key: ", _coord_key(coords))

func _setup_tilemap():
	tile_map = TileMap.new()
	tile_map.name = "HexTileMap"
	add_child(tile_map)
	
	highlight_layer = Node2D.new()
	highlight_layer.name = "HighlightLayer"
	# Ensure highlights are drawn above tiles and renderer
	highlight_layer.z_index = 100
	highlight_layer.z_as_relative = false
	add_child(highlight_layer)

func _generate_world():
	# Create terrain generator if not set
	if not terrain_generator:
		terrain_generator = load("res://scripts/hex_system/TerrainGenerator.gd").new()
		print("Created default TerrainGenerator")
	
	# Use natural terrain generation instead of random
	if terrain_generator.has_method("generate_terrain_for_grid"):
		terrain_generator.generate_terrain_for_grid(self)
	else:
		print("ERROR: terrain_generator doesn't have generate_terrain_for_grid method")

func get_tile(coords: HexCoordinates) -> HexTile:
	# Check bounds first to avoid unnecessary dictionary lookups
	if coords.q < -_half_w() or coords.q >= _half_w() or coords.r < -_half_h() or coords.r >= _half_h():
		return null
	
	var key = _coord_key(coords)
	return tiles.get(key, null)

func set_tile(coords: HexCoordinates, tile: HexTile):
	var key = _coord_key(coords)
	tiles[key] = tile

func get_neighbors(coords: HexCoordinates) -> Array[HexTile]:
	var neighbors: Array[HexTile] = []
	for neighbor_coord in coords.get_all_neighbors():
		var tile = get_tile(neighbor_coord)
		if tile:
			neighbors.append(tile)
	return neighbors

func get_tiles_in_range(center: HexCoordinates, range_val: int) -> Array[HexTile]:
	var result: Array[HexTile] = []
	for q in range(-range_val, range_val + 1):
		for r in range(max(-range_val, -q - range_val), min(range_val, -q + range_val) + 1):
			var offset = HexCoordinates.new(q, r)
			var target_coords = center.add(offset)
			
			# Only check tiles that are within grid bounds
			if target_coords.q >= -_half_w() and target_coords.q < _half_w() and target_coords.r >= -_half_h() and target_coords.r < _half_h():
				var tile = get_tile(target_coords)
				if tile:
					result.append(tile)
	return result

func pixel_to_hex(pixel_pos: Vector2) -> HexCoordinates:
	return HexCoordinates.from_pixel(pixel_pos, hex_size, flat_top)

func hex_to_pixel(coords: HexCoordinates) -> Vector2:
	return coords.to_pixel(hex_size, flat_top)

func find_path_to(start: HexCoordinates, end: HexCoordinates, prefer_roads: bool = false) -> Array[HexCoordinates]:
	# A* with a simple priority queue (array + separate priority map)
	var frontier: Array[HexCoordinates] = []
	var priority_map: Dictionary = {}
	var came_from: Dictionary = {}
	var cost_so_far: Dictionary = {}

	frontier.push_back(start)
	priority_map[_coord_key(start)] = 0.0
	came_from[_coord_key(start)] = null
	cost_so_far[_coord_key(start)] = 0

	while frontier.size() > 0:
		var current_node: HexCoordinates = frontier.pop_front()

		if current_node.equals(end):
			break

		for neighbor in current_node.get_all_neighbors():
			var tile = get_tile(neighbor)
			if not tile or not tile.can_move_to():
				continue

			var step_cost: float = float(tile.get_movement_cost())
			if prefer_roads:
				var current_tile = get_tile(current_node)
				if current_tile and current_tile.terrain_resource and current_tile.terrain_resource.is_road:
					# Prefer staying on roads; small penalty for leaving road
					if tile.terrain_resource and tile.terrain_resource.is_road:
						step_cost *= 0.5
					else:
						step_cost += 0.5
				elif current_tile and current_tile.terrain_resource and not current_tile.terrain_resource.is_road and tile.terrain_resource and tile.terrain_resource.is_road:
					# Slight incentive to move onto a road
					step_cost -= 0.25
			var new_cost = float(cost_so_far[_coord_key(current_node)]) + step_cost
			var neighbor_key = _coord_key(neighbor)

			if neighbor_key not in cost_so_far or new_cost < cost_so_far[neighbor_key]:
				cost_so_far[neighbor_key] = new_cost
				var priority: float = float(new_cost + neighbor.distance_to(end))
				_insert_sorted(frontier, neighbor, priority, priority_map)
				came_from[neighbor_key] = current_node

	var path: Array[HexCoordinates] = []
	var cursor: HexCoordinates = end

	# Build path from end to start (includes start because it exists in came_from)
	while cursor != null and _coord_key(cursor) in came_from:
		path.push_front(cursor)
		cursor = came_from[_coord_key(cursor)]

	return path

func find_reachable_tiles(start: HexCoordinates, max_movement_points: int) -> Array[HexCoordinates]:
	# Dijkstra to find all tiles reachable within movement budget
	var reachable: Array[HexCoordinates] = []
	var frontier: Array[HexCoordinates] = []
	var priority_map: Dictionary = {}
	var cost_so_far: Dictionary = {}

	frontier.push_back(start)
	priority_map[_coord_key(start)] = 0.0
	cost_so_far[_coord_key(start)] = 0

	while frontier.size() > 0:
		var node: HexCoordinates = frontier.pop_front()
		var current_cost = cost_so_far[_coord_key(node)]

		# Add current tile to reachable if it's not the start position
		if not node.equals(start):
			reachable.append(node)

		# Explore neighbors
		for neighbor in node.get_all_neighbors():
			var tile = get_tile(neighbor)
			if not tile or not tile.can_move_to():
				continue

			var new_cost = current_cost + tile.get_movement_cost()
			var neighbor_key = _coord_key(neighbor)

			# Skip if this path would exceed movement budget
			if new_cost > max_movement_points:
				continue

			# If we found a better path to this neighbor, update it
			if neighbor_key not in cost_so_far or new_cost < cost_so_far[neighbor_key]:
				cost_so_far[neighbor_key] = new_cost
				_insert_sorted(frontier, neighbor, float(new_cost), priority_map)

	print("Found ", reachable.size(), " tiles reachable within ", max_movement_points, " movement points")
	return reachable

func _insert_sorted(array: Array, item: HexCoordinates, priority: float, priority_map: Dictionary):
	# Maintain a parallel map of priorities for items in the queue
	var key = _coord_key(item)
	priority_map[key] = priority
	for i in range(array.size()):
		var other: HexCoordinates = array[i]
		var other_priority = priority_map.get(_coord_key(other), 1e20)
		if priority < other_priority:
			array.insert(i, item)
			return
	array.push_back(item)

func _coord_key(coords: HexCoordinates) -> String:
	return "%d,%d" % [coords.q, coords.r]

func highlight_tiles(tiles_to_highlight: Array[HexTile], color: Color, border_color: Color = Color.TRANSPARENT):
	for child in highlight_layer.get_children():
		child.queue_free()
	
	for tile in tiles_to_highlight:
		var poly := Polygon2D.new()
		poly.color = Color(color, 0.3)
		var center := hex_to_pixel(tile.coordinates)
		poly.polygon = _get_hex_points(center)
		poly.z_index = 100
		poly.z_as_relative = false
		highlight_layer.add_child(poly)
		
		# Add border if border_color is specified
		if border_color != Color.TRANSPARENT:
			var border := Line2D.new()
			border.width = 3.0
			border.default_color = border_color
			border.closed = true
			border.z_index = 101
			border.z_as_relative = false
			var points = _get_hex_points(center)
			for point in points:
				border.add_point(point)
			highlight_layer.add_child(border)

func clear_highlights():
	for child in highlight_layer.get_children():
		child.queue_free()

func _get_hex_points(center: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	var angle_offset := 0.0 if flat_top else PI / 6.0
	for i in range(6):
		var angle = angle_offset + i * PI / 3.0
		var pt = center + Vector2(
			hex_size * cos(angle),
			hex_size * sin(angle)
		)
		points.append(pt)
	return points

func update_visibility(center: HexCoordinates, sight_range: int):
	# Robust visibility update with bounds checking
	var visible_coords = {}
	
	# Only update visibility if center is within bounds
	if center.q < -_half_w() or center.q >= _half_w() or center.r < -_half_h() or center.r >= _half_h():
		print("Warning: update_visibility called with out-of-bounds center: ", center._to_string())
		return
	
	var tiles_in_range = get_tiles_in_range(center, sight_range)
	
	# Mark tiles in range as visible
	for tile in tiles_in_range:
		visible_coords[_coord_key(tile.coordinates)] = true
		if not tile.is_visible:
			tile.set_visibility(true)
			tile.explore()
	
	# Hide tiles that are no longer visible but keep them explored (so they render dimmed)
	for key in tiles:
		var tile = tiles[key]
		if tile.is_visible and key not in visible_coords:
			tile.set_visibility(false)

func save_grid() -> Dictionary:
	var save_data = {}
	for key in tiles:
		save_data[key] = tiles[key].to_dict()
	return save_data

func load_grid(save_data: Dictionary):
	tiles.clear()
	for key in save_data:
		tiles[key] = HexTile.from_dict(save_data[key], terrain_database)

# Helpers to avoid integer-division warnings and keep bounds consistent
func _half_w() -> int:
	return grid_width >> 1

func _half_h() -> int:
	return grid_height >> 1
