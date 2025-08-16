class_name TerrainGenerator
extends Resource

@export var map_generation_settings: MapGenerationSettings

# Noise generators
var elevation_noise: FastNoiseLite
var moisture_noise: FastNoiseLite
var warp_noise_x: FastNoiseLite
var warp_noise_y: FastNoiseLite

func _init():
	_setup_noise_generators()

func _ensure_settings():
	if not map_generation_settings:
		map_generation_settings = load("res://resources/default_map_generation_settings.tres")
		print("TerrainGenerator: Loaded default map generation settings")

func _setup_noise_generators():
	_ensure_settings()
	
	# Elevation noise - creates mountain ranges and valleys
	elevation_noise = FastNoiseLite.new()
	elevation_noise.seed = map_generation_settings.elevation_seed
	elevation_noise.frequency = map_generation_settings.elevation_frequency
	elevation_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	elevation_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	elevation_noise.fractal_octaves = map_generation_settings.elevation_octaves
	elevation_noise.fractal_lacunarity = map_generation_settings.elevation_lacunarity
	elevation_noise.fractal_gain = map_generation_settings.elevation_gain
	
	# Moisture noise - creates precipitation patterns
	moisture_noise = FastNoiseLite.new()
	moisture_noise.seed = map_generation_settings.moisture_seed
	moisture_noise.frequency = map_generation_settings.moisture_frequency
	moisture_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	moisture_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	moisture_noise.fractal_octaves = map_generation_settings.moisture_octaves
	moisture_noise.fractal_lacunarity = map_generation_settings.moisture_lacunarity
	moisture_noise.fractal_gain = map_generation_settings.moisture_gain

	# Domain warp noises for organic perturbation
	warp_noise_x = FastNoiseLite.new()
	warp_noise_x.seed = map_generation_settings.elevation_seed + map_generation_settings.warp_noise_x_offset
	warp_noise_x.frequency = map_generation_settings.warp_frequency
	warp_noise_x.noise_type = FastNoiseLite.TYPE_SIMPLEX

	warp_noise_y = FastNoiseLite.new()
	warp_noise_y.seed = map_generation_settings.moisture_seed + map_generation_settings.warp_noise_y_offset
	warp_noise_y.frequency = map_generation_settings.warp_frequency
	warp_noise_y.noise_type = FastNoiseLite.TYPE_SIMPLEX

func generate_terrain_for_grid(hex_grid: HexGrid):
	print("=== Starting natural terrain generation ===")
	
	# Phase 1: Generate base terrain using biome rules
	_generate_base_terrain(hex_grid)
	
	# Phase 2: Carve rivers along downhill paths from high elevation sources
	_carve_rivers(hex_grid)

	# Phase 3: Place civilization features after rivers, so roads route around them
	_place_civilization_features(hex_grid)
	
	# Phase 4: Post-process for natural appearance
	_post_process_terrain(hex_grid)
	
	_log_feature_counts(hex_grid)
	print("=== Natural terrain generation completed ===")

func _generate_base_terrain(hex_grid: HexGrid):
	print("Generating base terrain with elevation and moisture layers...")
	
	# Ensure terrain database is available
	if not hex_grid.terrain_database:
		push_error("TerrainGenerator: HexGrid missing terrain_database")
		return
	
	var biome_counts = {}
	
	for key in hex_grid.tiles:
		var tile: HexTile = hex_grid.tiles[key]
		var coords = tile.coordinates
		
		# Sample noise values at this coordinate using grid settings
		var elevation = _get_elevation_at(hex_grid, coords)
		var moisture = _get_moisture_at(hex_grid, coords)
		
		# Determine terrain type based on biome rules
		var terrain_resource = _determine_terrain_resource(hex_grid.terrain_database, elevation, moisture)
		tile.set_terrain_resource(terrain_resource)
		
		# Track biome distribution for debugging
		var terrain_name = tile.get_terrain_name()
		biome_counts[terrain_name] = biome_counts.get(terrain_name, 0) + 1
	
	# Print biome distribution
	print("Biome distribution:")
	for biome in biome_counts:
		print("  ", biome, ": ", biome_counts[biome])

func _sample_world(hex_grid: HexGrid, coords: HexCoordinates) -> Vector2:
	# Convert hex coordinates to world position using grid settings
	return coords.to_pixel(hex_grid.hex_size, hex_grid.flat_top)

func _warp_pos(pos: Vector2) -> Vector2:
	if not map_generation_settings.warp_enabled:
		return pos
	var wx = warp_noise_x.get_noise_2d(pos.x, pos.y) * map_generation_settings.warp_amplitude
	var wy = warp_noise_y.get_noise_2d(pos.x + 1000.0, pos.y + 1000.0) * map_generation_settings.warp_amplitude
	return Vector2(pos.x + wx, pos.y + wy)

func _get_elevation_at(hex_grid: HexGrid, coords: HexCoordinates) -> float:
	var world_pos = _sample_world(hex_grid, coords)
	world_pos = _warp_pos(world_pos)
	var noise_value = elevation_noise.get_noise_2d(world_pos.x, world_pos.y)
	return (noise_value + 1.0) * 0.5

func _get_moisture_at(hex_grid: HexGrid, coords: HexCoordinates) -> float:
	var world_pos = _sample_world(hex_grid, coords)
	world_pos = _warp_pos(world_pos)
	var noise_value = moisture_noise.get_noise_2d(world_pos.x, world_pos.y)
	return (noise_value + 1.0) * 0.5

func _determine_terrain_resource(terrain_db: TerrainDatabase, elevation: float, moisture: float) -> TerrainTypeResource:
	# High elevation = mountains
	if elevation > map_generation_settings.mountain_threshold:
		return terrain_db.get_terrain_by_name("Mountain")
	
	# Hills with high moisture = forests/bush
	if elevation > map_generation_settings.hill_threshold and moisture > map_generation_settings.medium_moisture_threshold:
		return terrain_db.get_terrain_by_name("Bush")
	
	# Low elevation with high moisture = water features
	if elevation < map_generation_settings.valley_threshold and moisture > map_generation_settings.high_moisture_threshold:
		return terrain_db.get_terrain_by_name("Creek")
	
	# Goldfields near mountains (geological features)
	if elevation > map_generation_settings.goldfield_elevation_min and elevation < map_generation_settings.mountain_threshold and moisture > map_generation_settings.goldfield_moisture_min and moisture < map_generation_settings.goldfield_moisture_max:
		var geo_noise = elevation_noise.get_noise_2d(elevation * map_generation_settings.noise_scale_factor, moisture * map_generation_settings.noise_scale_factor)
		if geo_noise > map_generation_settings.goldfield_noise_threshold:
			return terrain_db.get_terrain_by_name("Goldfield")
	
	# Very dry areas = plains  
	if moisture < map_generation_settings.low_moisture_threshold:
		return terrain_db.get_terrain_by_name("Plains")
	
	# Medium moisture areas = more bush/forest
	if moisture > map_generation_settings.medium_moisture_threshold:
		return terrain_db.get_terrain_by_name("Bush")
	
	# Default to plains for remaining areas
	return terrain_db.get_terrain_by_name("Plains")

func _carve_rivers(hex_grid: HexGrid):
	print("Carving rivers from high elevations...")
	var terrain_db = hex_grid.terrain_database
	
	# Collect potential sources across the map with their elevation (prefer highest)
	var candidates: Array = []
	for key in hex_grid.tiles:
		var tile: HexTile = hex_grid.tiles[key]
		var elev = _get_elevation_at(hex_grid, tile.coordinates)
		var terrain_name = tile.get_terrain_name()
		if elev > map_generation_settings.hill_threshold and terrain_name not in ["Mountain", "Town"]:
			candidates.append({"coord": tile.coordinates, "elev": elev})

	if candidates.is_empty():
		return

	# Sort by elevation descending and pick top sources
	candidates.sort_custom(func(a, b): return a["elev"] > b["elev"])
	var count = min(map_generation_settings.river_count, candidates.size())
	for i in range(count):
		_flow_river_from(hex_grid, candidates[i]["coord"])

func _flow_river_from(hex_grid: HexGrid, start: HexCoordinates):
	var terrain_db = hex_grid.terrain_database
	var visited := {}
	var current := start
	var length := 0
	while length < map_generation_settings.max_river_length:
		length += 1
		visited[_coord_key(current)] = true
		var current_elev = _get_elevation_at(hex_grid, current)
		# Mark current as creek if allowed
		var tile = hex_grid.get_tile(current)
		if tile:
			var terrain_name = tile.get_terrain_name()
			if terrain_name not in ["Town", "Road", "Mountain"]:
				tile.set_terrain_resource(terrain_db.get_terrain_by_name("Creek"))

		# Choose lowest neighbor not visited; if no downhill, allow gentle flat continuation
		var lowest_neighbor: HexCoordinates = null
		var lowest_elev = current_elev
		for neighbor in current.get_all_neighbors():
			if _coord_key(neighbor) in visited:
				continue
			var n_tile = hex_grid.get_tile(neighbor)
			if not n_tile:
				continue
			var e = _get_elevation_at(hex_grid, neighbor)
			if e < lowest_elev or (abs(e - lowest_elev) < 0.05):
				lowest_elev = e
				lowest_neighbor = neighbor
		# Stop if no candidate
		if lowest_neighbor == null:
			break
		current = lowest_neighbor

func _place_civilization_features(hex_grid: HexGrid):
	print("Placing civilization features (center town, settlements, roads, gold)...")
	var terrain_db = hex_grid.terrain_database

	# Center 7-hex town at (0,0)
	var center_cluster: Array[HexCoordinates] = _place_center_town(hex_grid)

	# Random single-tile settlements
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var settlements_count = rng.randi_range(map_generation_settings.settlement_min_count, map_generation_settings.settlement_max_count)
	var min_distance = map_generation_settings.settlement_min_distance
		
	var settlement_locations: Array[HexCoordinates] = []

	var forbidden: Dictionary = {}
	for c in center_cluster:
		forbidden[_coord_key(c)] = true

	var attempts = 0
	while settlement_locations.size() < settlements_count and attempts < map_generation_settings.max_settlement_attempts:
		attempts += 1
		var coord = _random_coord_within_grid(hex_grid, rng)
		if _is_suitable_for_settlement(hex_grid, coord, forbidden, min_distance):
			settlement_locations.append(coord)
			forbidden[_coord_key(coord)] = true

	# Place settlements
	for loc in settlement_locations:
		var t = hex_grid.get_tile(loc)
		if t:
			t.set_terrain_resource(terrain_db.get_terrain_by_name("Town"))

	# Place gold mines and deposits based on settings
	var mines = rng.randi_range(map_generation_settings.goldfield_mine_count_min, map_generation_settings.goldfield_mine_count_max)
	var deposits = rng.randi_range(map_generation_settings.goldfield_deposit_count_min, map_generation_settings.goldfield_deposit_count_max)
	
	_place_gold_features(hex_grid, rng, mines, true, forbidden)
	_place_gold_features(hex_grid, rng, deposits, false, forbidden)

	# Roads: connect each settlement to the center via low-cost path
	for s in settlement_locations:
		var path = _find_low_cost_path(hex_grid, HexCoordinates.new(0, 0), s)
		for c in path:
			var tile = hex_grid.get_tile(c)
			if tile:
				var terrain_name = tile.get_terrain_name()
				if terrain_name not in ["Town", "Mountain", "Creek"]:
					tile.set_terrain_resource(terrain_db.get_terrain_by_name("Road"))

	print("Placed ", settlement_locations.size(), " settlements and center town")

func _place_center_town(hex_grid: HexGrid) -> Array[HexCoordinates]:
	var terrain_db = hex_grid.terrain_database
	var center = HexCoordinates.new(0, 0)
	var coords: Array[HexCoordinates] = [center]
	# Add the six neighbors
	for n in center.get_all_neighbors():
		coords.append(n)
	for c in coords:
		var tile = hex_grid.get_tile(c)
		if tile:
			tile.set_terrain_resource(terrain_db.get_terrain_by_name("Town"))
	return coords

func _random_coord_within_grid(hex_grid: HexGrid, rng: RandomNumberGenerator) -> HexCoordinates:
	var hw = hex_grid.grid_width >> 1
	var hh = hex_grid.grid_height >> 1
	var q = rng.randi_range(-hw, hw - 1)
	var r = rng.randi_range(-hh, hh - 1)
	return HexCoordinates.new(q, r)

func _is_suitable_for_settlement(hex_grid: HexGrid, coord: HexCoordinates, forbidden: Dictionary, min_dist: int) -> bool:
	var key = _coord_key(coord)
	if key in forbidden:
		return false
	var tile = hex_grid.get_tile(coord)
	if not tile:
		return false
	var terrain_name = tile.get_terrain_name()
	if terrain_name in ["Mountain", "Creek", "Town"]:
		return false
	# Keep away from existing forbidden set by min_dist
	for fkey in forbidden.keys():
		var parts = fkey.split(",")
		var fq = int(parts[0])
		var fr = int(parts[1])
		var fcoord = HexCoordinates.new(fq, fr)
		if coord.distance_to(fcoord) < min_dist:
			return false
	return true

func _place_gold_features(hex_grid: HexGrid, rng: RandomNumberGenerator, count: int, is_mine: bool, forbidden: Dictionary):
	var terrain_db = hex_grid.terrain_database
	var placed = 0
	var tries = 0
	while placed < count and tries < map_generation_settings.max_placement_attempts:
		tries += 1
		var coord = _random_coord_within_grid(hex_grid, rng)
		var key = _coord_key(coord)
		if key in forbidden:
			continue
		var tile = hex_grid.get_tile(coord)
		if not tile:
			continue
		var terrain_name = tile.get_terrain_name()
		if terrain_name in ["Mountain", "Creek", "Town", "Road"]:
			continue
		# Place goldfield and annotate
		tile.set_terrain_resource(terrain_db.get_terrain_by_name("Goldfield"))
		tile.has_encounter = true
		tile.encounter_data = {
			"resource": "gold",
			"kind": ("mine" if is_mine else "deposit")
		}
		forbidden[key] = true
		placed += 1

func _find_town_locations(hex_grid: HexGrid) -> Array[HexCoordinates]:
	var suitable_locations: Array[HexCoordinates] = []
	var town_locations: Array[HexCoordinates] = []
	
	# Find all suitable locations (not mountains, not creeks)
	for key in hex_grid.tiles:
		var tile: HexTile = hex_grid.tiles[key]
		var terrain_name = tile.get_terrain_name()
		if terrain_name in ["Plains", "Goldfield"]:
			suitable_locations.append(tile.coordinates)
	
	# Select well-spaced town locations
	var attempts = 0
	while town_locations.size() < map_generation_settings.town_count and attempts < suitable_locations.size():
		var candidate = suitable_locations[randi() % suitable_locations.size()]
		
		# Check if far enough from existing towns
		var too_close = false
		for existing_town in town_locations:
			if candidate.distance_to(existing_town) < map_generation_settings.town_spacing:
				too_close = true
				break
		
		if not too_close:
			town_locations.append(candidate)
		
		attempts += 1
	
	return town_locations

func _generate_roads_between_towns(hex_grid: HexGrid, town_locations: Array[HexCoordinates]):
	var terrain_db = hex_grid.terrain_database
	# Connect each town to nearest neighbors via low-cost paths avoiding mountains/creeks
	for i in range(town_locations.size()):
		var start = town_locations[i]
		# Find nearest k towns
		var pairs: Array = []
		for j in range(town_locations.size()):
			if i == j:
				continue
			var end = town_locations[j]
			pairs.append({"end": end, "dist": start.distance_to(end)})
		pairs.sort_custom(func(a, b): return a["dist"] < b["dist"])
		var connect_count = min(2, pairs.size())
		for k in range(connect_count):
			var end: HexCoordinates = pairs[k]["end"]
			var path = _find_low_cost_path(hex_grid, start, end)
			if path.size() > 0:
				for coord in path:
					var tile = hex_grid.get_tile(coord)
					if tile:
						var terrain_name = tile.get_terrain_name()
						if terrain_name not in ["Town", "Mountain", "Creek"]:
							tile.set_terrain_resource(terrain_db.get_terrain_by_name("Road"))

func _find_low_cost_path(hex_grid: HexGrid, start: HexCoordinates, end: HexCoordinates) -> Array[HexCoordinates]:
	# A* variant with terrain costs; block mountains/creeks to make roads organic around features
	var frontier: Array[HexCoordinates] = []
	var priority_map: Dictionary = {}
	var came_from: Dictionary = {}
	var g_cost: Dictionary = {}

	var terrain_cost_cb: Callable = func(c: HexCoordinates) -> int:
		var t = hex_grid.get_tile(c)
		if not t:
			return 9999
		var terrain_name = t.get_terrain_name()
		match terrain_name:
			"Mountain", "Creek":
				return 9999 # treat as impassable for roads
			"Bush":
				return 3
			"Goldfield":
				return 2
			"Plains":
				return 1
			"Town", "Road":
				return 1
			_:
				return 2

	frontier.push_back(start)
	priority_map[_coord_key(start)] = 0.0
	came_from[_coord_key(start)] = null
	g_cost[_coord_key(start)] = 0

	while frontier.size() > 0:
		var node: HexCoordinates = frontier.pop_front()
		if node.equals(end):
			break
		for neighbor in node.get_all_neighbors():
			var step = terrain_cost_cb.call(neighbor)
			if step >= 9999:
				continue
			var new_cost = g_cost[_coord_key(node)] + step
			var key = _coord_key(neighbor)
			if key not in g_cost or new_cost < g_cost[key]:
				g_cost[key] = new_cost
				var priority = float(new_cost + neighbor.distance_to(end))
				_insert_sorted(frontier, neighbor, priority, priority_map)
				came_from[key] = node

	var path: Array[HexCoordinates] = []
	var cursor: HexCoordinates = end
	while cursor != null and _coord_key(cursor) in came_from:
		path.push_front(cursor)
		cursor = came_from[_coord_key(cursor)]
	return path

func _post_process_terrain(hex_grid: HexGrid):
	print("Post-processing terrain for natural appearance...")
	
	# Smooth isolated tiles and apply majority smoothing passes
	if map_generation_settings.smooth_isolated_tiles:
		_smooth_isolated_tiles(hex_grid)
	_majority_smooth(hex_grid, map_generation_settings.majority_smoothing_passes)
	
	# Add variety to large uniform areas
	_add_terrain_variety(hex_grid)

func _smooth_isolated_tiles(hex_grid: HexGrid):
	var terrain_db = hex_grid.terrain_database
	var tiles_to_change = []
	
	for key in hex_grid.tiles:
		var tile: HexTile = hex_grid.tiles[key]
		# Preserve special features
		var terrain_name = tile.get_terrain_name()
		if terrain_name in ["Creek", "Road", "Town"]:
			continue
		var neighbors = hex_grid.get_neighbors(tile.coordinates)
		
		# Count neighbors of same type
		var same_type_count = 0
		for neighbor in neighbors:
			if neighbor.get_terrain_name() == terrain_name:
				same_type_count += 1
		
		# If tile is isolated (no neighbors of same type), change it
		if same_type_count == 0 and neighbors.size() > 0:
			# Change to most common neighbor type
			var neighbor_types = {}
			for neighbor in neighbors:
				var type_name = neighbor.get_terrain_name()
				neighbor_types[type_name] = neighbor_types.get(type_name, 0) + 1
			
			var most_common_terrain_name = "Plains"
			var max_count = 0
			for type_name in neighbor_types:
				if neighbor_types[type_name] > max_count:
					max_count = neighbor_types[type_name]
					most_common_terrain_name = type_name
			
			var most_common_resource = terrain_db.get_terrain_by_name(most_common_terrain_name)
			if most_common_resource:
				tiles_to_change.append([tile, most_common_resource])
	
	# Apply changes
	for change in tiles_to_change:
		change[0].set_terrain_resource(change[1])
	
	print("Smoothed ", tiles_to_change.size(), " isolated tiles")

func _log_feature_counts(hex_grid: HexGrid):
	var roads := 0
	var rivers := 0
	var towns := 0
	for key in hex_grid.tiles:
		var t: HexTile = hex_grid.tiles[key]
		var terrain_name = t.get_terrain_name()
		match terrain_name:
			"Road":
				roads += 1
			"Creek":
				rivers += 1
			"Town":
				towns += 1
	print("Feature counts -> Roads:", roads, " Rivers:", rivers, " Towns:", towns)

func _add_terrain_variety(_hex_grid: HexGrid):
	# Add small variations to break up large uniform areas
	# This could be expanded with more sophisticated algorithms
	pass

# Utility function to regenerate with new parameters
func regenerate_with_new_settings(hex_grid: HexGrid):
	_setup_noise_generators()
	generate_terrain_for_grid(hex_grid)

# Utilities
func _coord_key(c: HexCoordinates) -> String:
	return "%d,%d" % [c.q, c.r]

func _insert_sorted(array: Array, item: HexCoordinates, priority: float, priority_map: Dictionary):
	var key = _coord_key(item)
	priority_map[key] = priority
	for i in range(array.size()):
		var other: HexCoordinates = array[i]
		var other_p = priority_map.get(_coord_key(other), 1e20)
		if priority < other_p:
			array.insert(i, item)
			return
	array.push_back(item)

func _majority_smooth(hex_grid: HexGrid, passes: int = 1):
	var terrain_db = hex_grid.terrain_database
	for p in range(passes):
		var changes: Array = []
		for key in hex_grid.tiles:
			var tile: HexTile = hex_grid.tiles[key]
			# Don't alter special features; preserve creeks (rivers)
			var terrain_name = tile.get_terrain_name()
			if terrain_name in ["Town", "Road", "Creek"]:
				continue
			var neighbors = hex_grid.get_neighbors(tile.coordinates)
			var counts := {}
			for n in neighbors:
				var n_terrain_name = n.get_terrain_name()
				if n_terrain_name in ["Town", "Road", "Creek"]:
					continue
				counts[n_terrain_name] = counts.get(n_terrain_name, 0) + 1
			var best_terrain_name = terrain_name
			var best_count = 0
			for t_name in counts.keys():
				if counts[t_name] > best_count:
					best_count = counts[t_name]
					best_terrain_name = t_name
			# Apply if there is a strong local majority
			if best_terrain_name != terrain_name and best_count >= map_generation_settings.majority_smoothing_threshold:
				var best_resource = terrain_db.get_terrain_by_name(best_terrain_name)
				if best_resource:
					changes.append([tile, best_resource])
		for change in changes:
			change[0].set_terrain_resource(change[1])
