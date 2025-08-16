class_name SettlementPlacer
extends RefCounted

var civilization_settings: CivilizationSettings

func place_settlements(hex_grid: HexGrid, rng: RandomNumberGenerator) -> Array[SettlementData]:
	var settlements: Array[SettlementData] = []
	var forbidden: Dictionary = {}
	
	# Step 1: Place center capital at (0,0)
	var capital = _place_center_capital(hex_grid, forbidden)
	settlements.append(capital)
	
	# Step 2: Place distributed settlements
	var distributed_settlements = _place_distributed_settlements(hex_grid, rng, forbidden)
	settlements.append_array(distributed_settlements)
	
	print("SettlementPlacer: Placed ", settlements.size(), " settlements")
	return settlements

func _place_center_capital(hex_grid: HexGrid, forbidden: Dictionary) -> SettlementData:
	var center = HexCoordinates.new(0, 0)
	var capital = SettlementData.new(center, "capital", civilization_settings.capital_size)
	capital.specialization = "administration"
	
	# Get all hexes for the capital (center + neighbors for 7-hex cluster)
	var capital_hexes: Array[HexCoordinates] = [center]
	for neighbor in center.get_all_neighbors():
		capital_hexes.append(neighbor)
	
	# Place the capital tiles and mark as forbidden
	var terrain_db = hex_grid.terrain_database
	for coords in capital_hexes:
		var tile = hex_grid.get_tile(coords)
		if tile:
			tile.set_terrain_resource(terrain_db.get_terrain_by_name("Town"))
			capital.occupied_hexes.append(coords)
			forbidden[CivilizationGenerator.coord_key(coords)] = true
	
	return capital

func _place_distributed_settlements(hex_grid: HexGrid, rng: RandomNumberGenerator, forbidden: Dictionary) -> Array[SettlementData]:
	var settlements: Array[SettlementData] = []
	
	var settlements_count = rng.randi_range(
		civilization_settings.settlement_min_count,
		civilization_settings.settlement_max_count
	)
	
	var attempts = 0
	while settlements.size() < settlements_count and attempts < civilization_settings.max_settlement_attempts:
		attempts += 1
		
		var coord = _random_coord_within_grid(hex_grid, rng)
		if _is_suitable_for_settlement(hex_grid, coord, forbidden):
			var settlement = _create_settlement(hex_grid, coord, rng, forbidden)
			if settlement:
				settlements.append(settlement)
	
	return settlements

func _create_settlement(hex_grid: HexGrid, coord: HexCoordinates, rng: RandomNumberGenerator, forbidden: Dictionary) -> SettlementData:
	# Determine settlement type and specialization
	var settlement_type = _determine_settlement_type(hex_grid, coord, rng)
	var specialization = _determine_specialization(hex_grid, coord, rng)
	
	var size = civilization_settings.village_size
	match settlement_type:
		"town":
			size = civilization_settings.town_size
		"city":
			size = civilization_settings.city_size
	
	var settlement = SettlementData.new(coord, settlement_type, size)
	settlement.specialization = specialization
	
	# Place the settlement on the map
	var terrain_db = hex_grid.terrain_database
	var tile = hex_grid.get_tile(coord)
	if tile:
		tile.set_terrain_resource(terrain_db.get_terrain_by_name("Town"))
		settlement.occupied_hexes.append(coord)
		forbidden[CivilizationGenerator.coord_key(coord)] = true
	
	return settlement

func _determine_settlement_type(hex_grid: HexGrid, coord: HexCoordinates, rng: RandomNumberGenerator) -> String:
	# For now, all distributed settlements are villages
	# In the future, this could consider economic factors, distance from capital, etc.
	return "village"

func _determine_specialization(hex_grid: HexGrid, coord: HexCoordinates, rng: RandomNumberGenerator) -> String:
	# Check nearby terrain to determine natural specialization
	var nearby_terrain = _analyze_nearby_terrain(hex_grid, coord)
	
	# Mining specialization if near mountains or goldfields
	if nearby_terrain.has("Mountain") or nearby_terrain.has("Goldfield"):
		if rng.randf() < civilization_settings.mining_town_probability:
			return "mining"
	
	# Trading posts tend to be on flat, accessible terrain
	if nearby_terrain.get("Plains", 0) > 3:
		if rng.randf() < civilization_settings.trading_post_probability:
			return "trading"
	
	# Default to farming
	return "farming"

func _analyze_nearby_terrain(hex_grid: HexGrid, center: HexCoordinates) -> Dictionary:
	var terrain_counts = {}
	
	# Check the center tile and its neighbors
	var tiles_to_check = [center]
	tiles_to_check.append_array(center.get_all_neighbors())
	
	for coords in tiles_to_check:
		var tile = hex_grid.get_tile(coords)
		if tile:
			var terrain_name = tile.get_terrain_name()
			terrain_counts[terrain_name] = terrain_counts.get(terrain_name, 0) + 1
	
	return terrain_counts

func _is_suitable_for_settlement(hex_grid: HexGrid, coord: HexCoordinates, forbidden: Dictionary) -> bool:
	var key = CivilizationGenerator.coord_key(coord)
	if key in forbidden:
		return false
	
	var tile = hex_grid.get_tile(coord)
	if not tile:
		return false
	
	var terrain_name = tile.get_terrain_name()
	if not civilization_settings.is_terrain_suitable_for_settlement(terrain_name):
		return false
	
	# Check minimum distance from existing settlements
	for fkey in forbidden.keys():
		var parts = fkey.split(",")
		var fq = int(parts[0])
		var fr = int(parts[1])
		var fcoord = HexCoordinates.new(fq, fr)
		if coord.distance_to(fcoord) < civilization_settings.settlement_min_distance:
			return false
	
	return true

func _random_coord_within_grid(hex_grid: HexGrid, rng: RandomNumberGenerator) -> HexCoordinates:
	var hw = hex_grid.grid_width >> 1
	var hh = hex_grid.grid_height >> 1
	var q = rng.randi_range(-hw, hw - 1)
	var r = rng.randi_range(-hh, hh - 1)
	return HexCoordinates.new(q, r)