class_name ResourcePlacer
extends RefCounted

var civilization_settings: CivilizationSettings

func place_resources(hex_grid: HexGrid, rng: RandomNumberGenerator, settlements: Array[SettlementData]) -> Array[ResourceData]:
	var resources: Array[ResourceData] = []
	var forbidden: Dictionary = {}
	
	# Mark settlement areas as forbidden for resource placement
	for settlement in settlements:
		for coords in settlement.occupied_hexes:
			forbidden[CivilizationGenerator.coord_key(coords)] = true
	
	# Place gold mines and deposits
	var gold_resources = _place_gold_resources(hex_grid, rng, forbidden)
	resources.append_array(gold_resources)
	
	print("ResourcePlacer: Placed ", resources.size(), " resource sites")
	return resources

func _place_gold_resources(hex_grid: HexGrid, rng: RandomNumberGenerator, forbidden: Dictionary) -> Array[ResourceData]:
	var resources: Array[ResourceData] = []
	
	# Place gold mines
	var mines_count = rng.randi_range(
		civilization_settings.goldfield_mine_count_min,
		civilization_settings.goldfield_mine_count_max
	)
	var mines = _place_resource_type(hex_grid, rng, "gold_mine", mines_count, forbidden)
	resources.append_array(mines)
	
	# Place gold deposits
	var deposits_count = rng.randi_range(
		civilization_settings.goldfield_deposit_count_min,
		civilization_settings.goldfield_deposit_count_max
	)
	var deposits = _place_resource_type(hex_grid, rng, "gold_deposit", deposits_count, forbidden)
	resources.append_array(deposits)
	
	return resources

func _place_resource_type(hex_grid: HexGrid, rng: RandomNumberGenerator, resource_type: String, count: int, forbidden: Dictionary) -> Array[ResourceData]:
	var resources: Array[ResourceData] = []
	var placed = 0
	var tries = 0
	
	while placed < count and tries < civilization_settings.max_placement_attempts:
		tries += 1
		
		var coord = _random_coord_within_grid(hex_grid, rng)
		var key = CivilizationGenerator.coord_key(coord)
		
		if key in forbidden:
			continue
		
		if _is_suitable_for_resource(hex_grid, coord, resource_type):
			var resource = _create_resource(hex_grid, coord, resource_type, rng)
			if resource:
				resources.append(resource)
				forbidden[key] = true
				placed += 1
	
	return resources

func _create_resource(hex_grid: HexGrid, coord: HexCoordinates, resource_type: String, rng: RandomNumberGenerator) -> ResourceData:
	var resource = ResourceData.new(coord, resource_type)
	
	# Determine quality based on location and random factors
	resource.quality = _determine_resource_quality(hex_grid, coord, rng)
	
	# Set up encounter data for gameplay integration
	resource.encounter_data = _create_encounter_data(resource_type, resource.quality)
	
	# Place the resource on the map
	var terrain_db = hex_grid.terrain_database
	var tile = hex_grid.get_tile(coord)
	if tile:
		tile.set_terrain_resource(terrain_db.get_terrain_by_name("Goldfield"))
		tile.has_encounter = true
		tile.encounter_data = resource.encounter_data
	
	return resource

func _determine_resource_quality(hex_grid: HexGrid, coord: HexCoordinates, rng: RandomNumberGenerator) -> String:
	# Quality could be determined by:
	# - Distance from existing resources (competition)
	# - Terrain favorability
	# - Random factors
	
	var quality_roll = rng.randf()
	if quality_roll < 0.1:
		return "rich"
	elif quality_roll < 0.4:
		return "good"
	else:
		return "poor"

func _create_encounter_data(resource_type: String, quality: String) -> Dictionary:
	var base_type = "gold" # All current resources are gold-based
	var extraction_method = "mine" if resource_type == "gold_mine" else "deposit"
	
	return {
		"resource": base_type,
		"kind": extraction_method,
		"quality": quality
	}

func _is_suitable_for_resource(hex_grid: HexGrid, coord: HexCoordinates, resource_type: String) -> bool:
	var tile = hex_grid.get_tile(coord)
	if not tile:
		return false
	
	var terrain_name = tile.get_terrain_name()
	
	# Resources cannot be placed on certain terrain types
	if terrain_name in ["Mountain", "Creek", "Town", "Road"]:
		return false
	
	# For gold resources, we could add more specific criteria:
	# - Elevation requirements
	# - Proximity to mountains
	# - Distance from water features
	# For now, accept any suitable terrain
	
	return true

func _random_coord_within_grid(hex_grid: HexGrid, rng: RandomNumberGenerator) -> HexCoordinates:
	var hw = hex_grid.grid_width >> 1
	var hh = hex_grid.grid_height >> 1
	var q = rng.randi_range(-hw, hw - 1)
	var r = rng.randi_range(-hh, hh - 1)
	return HexCoordinates.new(q, r)