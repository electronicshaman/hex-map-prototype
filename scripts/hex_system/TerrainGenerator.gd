class_name TerrainGenerator
extends Resource

# Configurable generation parameters
@export var elevation_seed: int = 12345
@export var moisture_seed: int = 67890
@export var elevation_frequency: float = 0.15
@export var moisture_frequency: float = 0.25

# Biome thresholds (adjusted for more varied terrain)
@export var mountain_threshold: float = 0.65
@export var hill_threshold: float = 0.45
@export var valley_threshold: float = 0.35
@export var high_moisture_threshold: float = 0.6
@export var medium_moisture_threshold: float = 0.45
@export var low_moisture_threshold: float = 0.4

# Civilization parameters
@export var town_count: int = 5
@export var town_spacing: float = 8.0

# Noise generators
var elevation_noise: FastNoiseLite
var moisture_noise: FastNoiseLite

func _init():
	_setup_noise_generators()

func _setup_noise_generators():
	# Elevation noise - creates mountain ranges and valleys
	elevation_noise = FastNoiseLite.new()
	elevation_noise.seed = elevation_seed
	elevation_noise.frequency = elevation_frequency
	elevation_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	
	# Moisture noise - creates precipitation patterns
	moisture_noise = FastNoiseLite.new()
	moisture_noise.seed = moisture_seed
	moisture_noise.frequency = moisture_frequency
	moisture_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX

func generate_terrain_for_grid(hex_grid: HexGrid):
	print("=== Starting natural terrain generation ===")
	
	# Phase 1: Generate base terrain using biome rules
	_generate_base_terrain(hex_grid)
	
	# Phase 2: Place civilization features
	_place_civilization_features(hex_grid)
	
	# Phase 3: Post-process for natural appearance
	_post_process_terrain(hex_grid)
	
	print("=== Natural terrain generation completed ===")

func _generate_base_terrain(hex_grid: HexGrid):
	print("Generating base terrain with elevation and moisture layers...")
	var biome_counts = {}
	
	for key in hex_grid.tiles:
		var tile: HexTile = hex_grid.tiles[key]
		var coords = tile.coordinates
		
		# Sample noise values at this coordinate
		var elevation = _get_elevation_at(coords)
		var moisture = _get_moisture_at(coords)
		
		# Determine terrain type based on biome rules
		var terrain_type = _determine_terrain_type(elevation, moisture)
		tile.set_terrain(terrain_type)
		
		# Track biome distribution for debugging
		var terrain_name = tile.get_terrain_name()
		biome_counts[terrain_name] = biome_counts.get(terrain_name, 0) + 1
	
	# Print biome distribution
	print("Biome distribution:")
	for biome in biome_counts:
		print("  ", biome, ": ", biome_counts[biome])

func _get_elevation_at(coords: HexCoordinates) -> float:
	# Convert hex coordinates to world position for noise sampling
	var world_pos = coords.to_pixel(32.0, false)  # Use same hex_size as grid
	var noise_value = elevation_noise.get_noise_2d(world_pos.x, world_pos.y)
	# Normalize from [-1,1] to [0,1]
	return (noise_value + 1.0) * 0.5

func _get_moisture_at(coords: HexCoordinates) -> float:
	var world_pos = coords.to_pixel(32.0, false)
	var noise_value = moisture_noise.get_noise_2d(world_pos.x, world_pos.y)
	return (noise_value + 1.0) * 0.5

func _determine_terrain_type(elevation: float, moisture: float) -> HexTile.TerrainType:
	# High elevation = mountains
	if elevation > mountain_threshold:
		return HexTile.TerrainType.MOUNTAIN
	
	# Hills with high moisture = forests/bush
	if elevation > hill_threshold and moisture > medium_moisture_threshold:
		return HexTile.TerrainType.BUSH
	
	# Low elevation with high moisture = water features
	if elevation < valley_threshold and moisture > high_moisture_threshold:
		return HexTile.TerrainType.CREEK
	
	# Goldfields near mountains (geological features)
	if elevation > 0.5 and elevation < mountain_threshold and moisture > 0.3 and moisture < 0.7:
		var geo_noise = elevation_noise.get_noise_2d(elevation * 200, moisture * 200)
		if geo_noise > 0.4:  # More generous for goldfields
			return HexTile.TerrainType.GOLDFIELD
	
	# Very dry areas = plains  
	if moisture < low_moisture_threshold:
		return HexTile.TerrainType.PLAINS
	
	# Medium moisture areas = more bush/forest
	if moisture > medium_moisture_threshold:
		return HexTile.TerrainType.BUSH
	
	# Default to plains for remaining areas
	return HexTile.TerrainType.PLAINS

func _place_civilization_features(hex_grid: HexGrid):
	print("Placing civilization features (towns and roads)...")
	
	# Find suitable locations for towns
	var town_locations = _find_town_locations(hex_grid)
	
	# Place towns
	for location in town_locations:
		var tile = hex_grid.get_tile(location)
		if tile:
			tile.set_terrain(HexTile.TerrainType.TOWN)
	
	# Generate roads between towns
	_generate_roads_between_towns(hex_grid, town_locations)
	
	print("Placed ", town_locations.size(), " towns with connecting roads")

func _find_town_locations(hex_grid: HexGrid) -> Array[HexCoordinates]:
	var suitable_locations: Array[HexCoordinates] = []
	var town_locations: Array[HexCoordinates] = []
	
	# Find all suitable locations (not mountains, not creeks)
	for key in hex_grid.tiles:
		var tile: HexTile = hex_grid.tiles[key]
		if tile.terrain_type in [HexTile.TerrainType.PLAINS, HexTile.TerrainType.GOLDFIELD]:
			suitable_locations.append(tile.coordinates)
	
	# Select well-spaced town locations
	var attempts = 0
	while town_locations.size() < town_count and attempts < suitable_locations.size():
		var candidate = suitable_locations[randi() % suitable_locations.size()]
		
		# Check if far enough from existing towns
		var too_close = false
		for existing_town in town_locations:
			if candidate.distance_to(existing_town) < town_spacing:
				too_close = true
				break
		
		if not too_close:
			town_locations.append(candidate)
		
		attempts += 1
	
	return town_locations

func _generate_roads_between_towns(hex_grid: HexGrid, town_locations: Array[HexCoordinates]):
	# Simple approach: connect each town to nearest town
	for i in range(town_locations.size()):
		for j in range(i + 1, town_locations.size()):
			var start = town_locations[i]
			var end = town_locations[j]
			
			# Only connect if reasonably close
			if start.distance_to(end) <= town_spacing * 1.5:
				_create_road_path(hex_grid, start, end)

func _create_road_path(hex_grid: HexGrid, start: HexCoordinates, end: HexCoordinates):
	# Simple line-drawing algorithm for roads
	var current = start
	var steps = int(start.distance_to(end))
	
	for i in range(steps):
		var progress = float(i) / float(steps)
		var lerped_q = lerpf(start.q, end.q, progress)
		var lerped_r = lerpf(start.r, end.r, progress)
		
		var road_coord = HexCoordinates.new(round(lerped_q), round(lerped_r))
		var tile = hex_grid.get_tile(road_coord)
		
		# Only place road if it's not a town, mountain, or creek
		if tile and tile.terrain_type not in [HexTile.TerrainType.TOWN, HexTile.TerrainType.MOUNTAIN, HexTile.TerrainType.CREEK]:
			tile.set_terrain(HexTile.TerrainType.ROAD)

func _post_process_terrain(hex_grid: HexGrid):
	print("Post-processing terrain for natural appearance...")
	
	# Smooth isolated tiles
	_smooth_isolated_tiles(hex_grid)
	
	# Add variety to large uniform areas
	_add_terrain_variety(hex_grid)

func _smooth_isolated_tiles(hex_grid: HexGrid):
	var tiles_to_change = []
	
	for key in hex_grid.tiles:
		var tile: HexTile = hex_grid.tiles[key]
		var neighbors = hex_grid.get_neighbors(tile.coordinates)
		
		# Count neighbors of same type
		var same_type_count = 0
		for neighbor in neighbors:
			if neighbor.terrain_type == tile.terrain_type:
				same_type_count += 1
		
		# If tile is isolated (no neighbors of same type), change it
		if same_type_count == 0 and neighbors.size() > 0:
			# Change to most common neighbor type
			var neighbor_types = {}
			for neighbor in neighbors:
				var type_name = neighbor.get_terrain_name()
				neighbor_types[type_name] = neighbor_types.get(type_name, 0) + 1
			
			var most_common_type = HexTile.TerrainType.PLAINS
			var max_count = 0
			for type_name in neighbor_types:
				if neighbor_types[type_name] > max_count:
					max_count = neighbor_types[type_name]
					# Convert type name back to enum (simple approach)
					if type_name == "Bush":
						most_common_type = HexTile.TerrainType.BUSH
					elif type_name == "Creek":
						most_common_type = HexTile.TerrainType.CREEK
					elif type_name == "Mountain":
						most_common_type = HexTile.TerrainType.MOUNTAIN
			
			tiles_to_change.append([tile, most_common_type])
	
	# Apply changes
	for change in tiles_to_change:
		change[0].set_terrain(change[1])
	
	print("Smoothed ", tiles_to_change.size(), " isolated tiles")

func _add_terrain_variety(hex_grid: HexGrid):
	# Add small variations to break up large uniform areas
	# This could be expanded with more sophisticated algorithms
	pass

# Utility function to regenerate with new parameters
func regenerate_with_new_settings(hex_grid: HexGrid):
	_setup_noise_generators()
	generate_terrain_for_grid(hex_grid)