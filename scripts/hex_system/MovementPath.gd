class_name MovementPath
extends Resource

# Path data
@export var coordinates: Array[HexCoordinates] = []
@export var individual_costs: Array[int] = []
@export var cumulative_costs: Array[int] = []
@export var total_cost: int = 0
@export var is_valid: bool = false

func _init(path_coords: Array[HexCoordinates] = [], hex_grid: HexGrid = null):
	coordinates = path_coords
	if hex_grid and coordinates.size() > 0:
		_calculate_costs(hex_grid)

func _calculate_costs(hex_grid: HexGrid):
	individual_costs.clear()
	cumulative_costs.clear()
	total_cost = 0
	
	if coordinates.size() == 0:
		is_valid = false
		return
	
	# For single tile path (no movement), mark as valid with zero cost
	if coordinates.size() == 1:
		is_valid = true
		total_cost = 0
		print("MovementPath created - Single tile (no movement), cost: 0")
		return
	
	var running_total = 0
	
	# Skip the first coordinate (starting position has no cost)
	for i in range(1, coordinates.size()):
		var coord = coordinates[i]
		var tile = hex_grid.get_tile(coord)
		
		if not tile:
			is_valid = false
			print("MovementPath failed - No tile at ", coord._to_string())
			return
		
		var tile_cost = tile.movement_cost
		individual_costs.append(tile_cost)
		running_total += tile_cost
		cumulative_costs.append(running_total)
	
	total_cost = running_total
	is_valid = true
	
	print("MovementPath created - Total cost: ", total_cost, " for ", coordinates.size(), " tiles")

func can_afford(available_points: int) -> bool:
	return is_valid and total_cost <= available_points

func get_cost_at_step(step: int) -> int:
	if step <= 0 or step >= individual_costs.size() + 1:
		return 0
	return individual_costs[step - 1]  # Offset by 1 since we skip starting position

func get_cumulative_cost_at_step(step: int) -> int:
	if step <= 0:
		return 0
	if step > cumulative_costs.size():
		return total_cost
	return cumulative_costs[step - 1]  # Offset by 1 since we skip starting position

func get_path_summary() -> String:
	if not is_valid:
		return "Invalid path"
	
	var summary = "Path: "
	for i in range(coordinates.size()):
		if i > 0:
			summary += " -> "
		summary += coordinates[i]._to_string()
		if i > 0:  # Skip cost for starting position
			var step_cost = get_cost_at_step(i)
			var cumulative = get_cumulative_cost_at_step(i)
			summary += "(+" + str(step_cost) + "=" + str(cumulative) + ")"
	
	summary += " | Total: " + str(total_cost)
	return summary

func is_empty() -> bool:
	return coordinates.size() == 0

func get_length() -> int:
	return coordinates.size()

func get_final_coordinate() -> HexCoordinates:
	if coordinates.size() == 0:
		return null
	return coordinates[-1]

func contains_coordinate(coord: HexCoordinates) -> bool:
	for path_coord in coordinates:
		if path_coord.equals(coord):
			return true
	return false

# Static utility function to create path from A* result
static func from_pathfinding_result(path_coords: Array[HexCoordinates], hex_grid: HexGrid) -> MovementPath:
	return MovementPath.new(path_coords, hex_grid)

# Debug function
func debug_print():
	print("=== MovementPath Debug ===")
	print("Valid: ", is_valid)
	print("Total cost: ", total_cost)
	print("Coordinates: ", coordinates.size())
	for i in range(coordinates.size()):
		var coord_str = coordinates[i]._to_string()
		if i == 0:
			print("  ", i, ": ", coord_str, " (start)")
		else:
			var step_cost = get_cost_at_step(i)
			var cumulative = get_cumulative_cost_at_step(i)
			print("  ", i, ": ", coord_str, " (+", step_cost, " = ", cumulative, ")")
	print("===========================")