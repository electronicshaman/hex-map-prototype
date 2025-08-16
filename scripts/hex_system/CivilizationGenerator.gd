class_name CivilizationGenerator
extends Resource

@export var civilization_settings: CivilizationSettings

# Components for modular generation
var settlement_placer: SettlementPlacer
var road_builder: RoadBuilder
var resource_placer: ResourcePlacer

func _init():
	_ensure_settings()
	_initialize_components()

func _ensure_settings():
	if not civilization_settings:
		civilization_settings = CivilizationSettings.new()
		print("CivilizationGenerator: Created default civilization settings")

func _initialize_components():
	settlement_placer = SettlementPlacer.new()
	settlement_placer.civilization_settings = civilization_settings
	
	road_builder = RoadBuilder.new()
	road_builder.civilization_settings = civilization_settings
	
	resource_placer = ResourcePlacer.new()
	resource_placer.civilization_settings = civilization_settings

# Main entry point for civilization generation
func generate_civilization_for_grid(hex_grid: HexGrid, rng: RandomNumberGenerator) -> CivilizationData:
	print("=== Starting civilization generation ===")
	
	var civilization_data = CivilizationData.new()
	
	# Phase 1: Place settlements (center town + distributed settlements)
	var settlements = settlement_placer.place_settlements(hex_grid, rng)
	civilization_data.settlements = settlements
	
	# Phase 2: Place resource extraction sites
	var resources = resource_placer.place_resources(hex_grid, rng, settlements)
	civilization_data.resources = resources
	
	# Phase 3: Build road network connecting everything
	var roads = road_builder.build_road_network(hex_grid, settlements, resources)
	civilization_data.roads = roads
	
	_log_civilization_stats(civilization_data)
	print("=== Civilization generation completed ===")
	
	return civilization_data

func _log_civilization_stats(data: CivilizationData):
	print("Civilization Statistics:")
	print("  Settlements: ", data.settlements.size())
	print("  Resource sites: ", data.resources.size())
	print("  Road segments: ", data.roads.size())

# Utility function for coordinate keys (shared by all components)
static func coord_key(c: HexCoordinates) -> String:
	return "%d,%d" % [c.q, c.r]
