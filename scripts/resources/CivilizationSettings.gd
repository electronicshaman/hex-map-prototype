class_name CivilizationSettings
extends Resource

@export_group("Settlement Hierarchy")
@export var village_size: int = 1
@export var town_size: int = 3
@export var city_size: int = 7
@export var capital_size: int = 19

@export_group("Settlement Distribution")
@export var settlement_min_count: int = 2
@export var settlement_max_count: int = 5
@export var settlement_min_distance: int = 6
@export var max_settlement_attempts: int = 1000

@export_group("Economic Specialization")
@export var mining_town_probability: float = 0.3
@export var trading_post_probability: float = 0.2
@export var farming_village_probability: float = 0.5

@export_group("Resource Economics")
@export var goldfield_mine_count_min: int = 5
@export var goldfield_mine_count_max: int = 10
@export var goldfield_deposit_count_min: int = 5
@export var goldfield_deposit_count_max: int = 10
@export var max_placement_attempts: int = 2000

@export_group("Infrastructure Development")
@export var road_development_rate: float = 1.0
@export var bridge_construction_cost: int = 5
@export var tunnel_construction_cost: int = 10
@export var road_connections_per_settlement: int = 2

@export_group("Town Generation (Legacy)")
@export var town_count: int = 5
@export var town_spacing: float = 8.0

# Terrain cost mapping for pathfinding
func get_terrain_movement_cost(terrain_name: String) -> int:
	match terrain_name:
		"Mountain", "Creek":
			return 9999 # Impassable for roads
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

# Check if terrain is suitable for settlement placement
func is_terrain_suitable_for_settlement(terrain_name: String) -> bool:
	return terrain_name not in ["Mountain", "Creek", "Town"]

# Check if terrain can be overridden by roads
func can_place_road_on_terrain(terrain_name: String) -> bool:
	return terrain_name not in ["Town", "Mountain", "Creek"]