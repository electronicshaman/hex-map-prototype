class_name HexGrid
extends Node2D

signal tile_clicked(tile: HexTile)
signal tile_hovered(tile: HexTile)

@export var grid_width: int = 40
@export var grid_height: int = 30
@export var hex_size: float = 32.0
@export var flat_top: bool = false

var tiles: Dictionary = {}
var tile_map: TileMap
var highlight_layer: Node2D
var player_position: HexCoordinates

func _ready():
	_initialize_grid()
	_setup_tilemap()
	_generate_world()

func _initialize_grid():
	var count = 0
	for q in range(-grid_width/2, grid_width/2):
		for r in range(-grid_height/2, grid_height/2):
			var coords = HexCoordinates.new(q, r)
			var tile = HexTile.new(coords, HexTile.TerrainType.PLAINS)
			tile.set_visibility(true)  # Make tiles visible initially
			tile.explore()  # Mark as explored so they render
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
	add_child(highlight_layer)

func _generate_world():
	for key in tiles:
		var tile: HexTile = tiles[key]
		var noise_val = randf()
		
		if noise_val < 0.05:
			tile.set_terrain(HexTile.TerrainType.TOWN)
		elif noise_val < 0.15:
			tile.set_terrain(HexTile.TerrainType.GOLDFIELD)
		elif noise_val < 0.25:
			tile.set_terrain(HexTile.TerrainType.CREEK)
		elif noise_val < 0.35:
			tile.set_terrain(HexTile.TerrainType.MOUNTAIN)
		elif noise_val < 0.50:
			tile.set_terrain(HexTile.TerrainType.BUSH)
		elif noise_val < 0.60:
			tile.set_terrain(HexTile.TerrainType.ROAD)
		else:
			tile.set_terrain(HexTile.TerrainType.PLAINS)

func get_tile(coords: HexCoordinates) -> HexTile:
	# Check bounds first to avoid unnecessary dictionary lookups
	if coords.q < -grid_width/2 or coords.q >= grid_width/2 or coords.r < -grid_height/2 or coords.r >= grid_height/2:
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
			if target_coords.q >= -grid_width/2 and target_coords.q < grid_width/2 and target_coords.r >= -grid_height/2 and target_coords.r < grid_height/2:
				var tile = get_tile(target_coords)
				if tile:
					result.append(tile)
	return result

func pixel_to_hex(pixel_pos: Vector2) -> HexCoordinates:
	return HexCoordinates.from_pixel(pixel_pos, hex_size, flat_top)

func hex_to_pixel(coords: HexCoordinates) -> Vector2:
	return coords.to_pixel(hex_size, flat_top)

func find_path_to(start: HexCoordinates, end: HexCoordinates) -> Array[HexCoordinates]:
	var frontier = []
	var came_from = {}
	var cost_so_far = {}
	
	frontier.push_back(start)
	came_from[_coord_key(start)] = null
	cost_so_far[_coord_key(start)] = 0
	
	while frontier.size() > 0:
		var current = frontier.pop_front()
		
		if current.equals(end):
			break
		
		for neighbor in current.get_all_neighbors():
			var tile = get_tile(neighbor)
			if not tile or not tile.can_move_to():
				continue
			
			var new_cost = cost_so_far[_coord_key(current)] + tile.movement_cost
			var neighbor_key = _coord_key(neighbor)
			
			if neighbor_key not in cost_so_far or new_cost < cost_so_far[neighbor_key]:
				cost_so_far[neighbor_key] = new_cost
				var priority = new_cost + neighbor.distance_to(end)
				_insert_sorted(frontier, neighbor, priority)
				came_from[neighbor_key] = current
	
	var path: Array[HexCoordinates] = []
	var current = end
	
	while current != null and _coord_key(current) in came_from:
		path.push_front(current)
		current = came_from[_coord_key(current)]
	
	return path

func _insert_sorted(array: Array, item: HexCoordinates, priority: float):
	for i in range(array.size()):
		if priority < array[i].distance_to(item):
			array.insert(i, item)
			return
	array.push_back(item)

func _coord_key(coords: HexCoordinates) -> String:
	return "%d,%d" % [coords.q, coords.r]

func highlight_tiles(tiles_to_highlight: Array[HexTile], color: Color):
	for child in highlight_layer.get_children():
		child.queue_free()
	
	for tile in tiles_to_highlight:
		var highlight = ColorRect.new()
		highlight.size = Vector2(hex_size * 1.5, hex_size * 1.5)
		highlight.position = hex_to_pixel(tile.coordinates) - highlight.size / 2
		highlight.color = color
		highlight.modulate.a = 0.3
		highlight_layer.add_child(highlight)

func clear_highlights():
	for child in highlight_layer.get_children():
		child.queue_free()

func update_visibility(center: HexCoordinates, sight_range: int):
	# Robust visibility update with bounds checking
	var visible_coords = {}
	
	# Only update visibility if center is within bounds
	if center.q < -grid_width/2 or center.q >= grid_width/2 or center.r < -grid_height/2 or center.r >= grid_height/2:
		print("Warning: update_visibility called with out-of-bounds center: ", center._to_string())
		return
	
	var tiles_in_range = get_tiles_in_range(center, sight_range)
	
	# Mark tiles in range as visible
	for tile in tiles_in_range:
		visible_coords[_coord_key(tile.coordinates)] = true
		if not tile.is_visible:
			tile.set_visibility(true)
			tile.explore()
	
	# Hide tiles that are no longer visible (only check previously visible ones)
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
		tiles[key] = HexTile.from_dict(save_data[key])
