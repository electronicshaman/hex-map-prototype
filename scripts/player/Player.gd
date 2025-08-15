class_name Player
extends Node2D

signal moved(new_position: HexCoordinates)
signal movement_blocked()

@export var max_movement_points: int = 20  # Movement points per turn
@export var sight_range: int = 3
@export var move_speed: float = 200.0

var current_movement_points: int

var current_hex: HexCoordinates
var hex_grid: HexGrid
var is_moving: bool = false
var move_path: Array[HexCoordinates] = []

func _ready():
	current_hex = HexCoordinates.new(0, 0)
	current_movement_points = max_movement_points
	if get_parent() is HexGrid:
		hex_grid = get_parent()
		position = hex_grid.hex_to_pixel(current_hex)
		hex_grid.update_visibility(current_hex, sight_range)

func initialize(grid: HexGrid, start_position: HexCoordinates):
	hex_grid = grid
	current_hex = start_position
	current_movement_points = max_movement_points
	position = hex_grid.hex_to_pixel(current_hex)
	hex_grid.update_visibility(current_hex, sight_range)

func can_move_to(target: HexCoordinates) -> bool:
	print("Player movement validation:")
	print("  Current position: ", current_hex._to_string())
	print("  Target position: ", target._to_string())
	print("  Current movement points: ", current_movement_points, "/", max_movement_points)
	print("  Is moving: ", is_moving)
	
	if is_moving:
		print("  BLOCKED: Player is currently moving")
		return false
	
	# Calculate path and cost to target
	var movement_path = calculate_movement_path_to(target)
	if not movement_path.is_valid:
		print("  BLOCKED: No valid path to target")
		return false
	
	print("  Path cost: ", movement_path.total_cost)
	print("  Path summary: ", movement_path.get_path_summary())
	
	if not movement_path.can_afford(current_movement_points):
		print("  BLOCKED: Insufficient movement points (need ", movement_path.total_cost, ", have ", current_movement_points, ")")
		return false
	
	var target_tile = hex_grid.get_tile(target)
	if not target_tile or not target_tile.can_move_to():
		print("  BLOCKED: Target tile blocks movement")
		return false
	
	print("  MOVEMENT ALLOWED - Cost: ", movement_path.total_cost)
	return true

func calculate_movement_path_to(target: HexCoordinates) -> Resource:
	if not hex_grid:
		var movement_path_class = load("res://scripts/hex_system/MovementPath.gd")
		return movement_path_class.new()
	
	# Use pathfinding to get route with costs
	var path_coords = hex_grid.find_path_to(current_hex, target)
	var movement_path_class = load("res://scripts/hex_system/MovementPath.gd")
	return movement_path_class.from_pathfinding_result(path_coords, hex_grid)

func get_reachable_tiles() -> Array[HexCoordinates]:
	# Use HexGrid's efficient reachable tiles calculation
	if not hex_grid:
		return []
	
	return hex_grid.find_reachable_tiles(current_hex, current_movement_points)

func consume_movement_points(cost: int):
	current_movement_points -= cost
	print("Consumed ", cost, " movement points. Remaining: ", current_movement_points, "/", max_movement_points)

func reset_movement_points():
	current_movement_points = max_movement_points
	print("Movement points reset to: ", current_movement_points)

func get_movement_points_remaining() -> int:
	return current_movement_points

func request_move(target: HexCoordinates) -> bool:
	print("=== PLAYER request_move called with target: ", target._to_string(), " ===")
	
	# Calculate movement cost before validation
	var movement_path = calculate_movement_path_to(target)
	
	if not can_move_to(target):
		print("Player movement request BLOCKED by can_move_to validation")
		movement_blocked.emit()
		return false
	
	print("Player movement request APPROVED - calling move_to")
	print("Movement will consume ", movement_path.total_cost, " points")
	move_to(target, movement_path.total_cost)
	return true

func move_to(target: HexCoordinates, movement_cost: int = 0):
	print("=== PLAYER move_to called with target: ", target._to_string(), " cost: ", movement_cost, " ===")
	
	if is_moving:
		print("Already moving, ignoring move request")
		return
	
	var tile = hex_grid.get_tile(target)
	if not tile or not tile.can_move_to():
		print("Cannot move to target: no tile or blocked")
		movement_blocked.emit()
		return
	
	# Consume movement points before starting movement
	if movement_cost > 0:
		consume_movement_points(movement_cost)
	
	print("Starting move from ", current_hex._to_string(), " to ", target._to_string())
	is_moving = true
	
	var target_pos = hex_grid.hex_to_pixel(target)
	print("Moving from pixel position ", position, " to ", target_pos)
	
	print("Creating tween for movement animation")
	var tween = create_tween()
	tween.tween_property(self, "position", target_pos, 0.3)
	tween.tween_callback(func(): _on_move_complete(target))
	print("Tween created and started")
	
	# Failsafe timeout in case tween fails
	get_tree().create_timer(1.0).timeout.connect(func():
		if is_moving:
			print("Movement timeout, forcing completion")
			_on_move_complete(target)
	)

func _on_move_complete(target: HexCoordinates):
	print("=== PLAYER _on_move_complete called with target: ", target._to_string(), " ===")
	is_moving = false
	current_hex = target  # Ensure current_hex is updated
	hex_grid.update_visibility(current_hex, sight_range)
	moved.emit(current_hex)
	print("Move completed to: ", current_hex._to_string(), " at position: ", position)
	
	var tile = hex_grid.get_tile(current_hex)
	if tile and tile.has_encounter:
		_trigger_encounter(tile)
	
	print("=== PLAYER movement fully completed ===")

func _trigger_encounter(tile: HexTile):
	print("Encounter triggered at ", tile.coordinates._to_string())

func get_valid_moves() -> Array[HexCoordinates]:
	var valid_moves: Array[HexCoordinates] = []
	var neighbors = current_hex.get_all_neighbors()
	
	for neighbor in neighbors:
		if can_move_to(neighbor):
			valid_moves.append(neighbor)
	
	return valid_moves

func highlight_valid_moves():
	if not hex_grid:
		return
	
	var valid_moves = get_valid_moves()
	var tiles_to_highlight: Array[HexTile] = []
	
	for coord in valid_moves:
		var tile = hex_grid.get_tile(coord)
		if tile:
			tiles_to_highlight.append(tile)
	
	hex_grid.highlight_tiles(tiles_to_highlight, Color.GREEN)

func clear_move_highlights():
	if hex_grid:
		hex_grid.clear_highlights()

func _draw():
	draw_circle(Vector2.ZERO, 16, Color.RED)
	draw_circle(Vector2.ZERO, 12, Color.WHITE)
	draw_circle(Vector2.ZERO, 8, Color.BLUE)
