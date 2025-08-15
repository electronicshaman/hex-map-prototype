class_name Player
extends Node2D

signal moved(new_position: HexCoordinates)
signal movement_blocked()

@export var movement_range: int = 10  # Reasonable range for testing
@export var sight_range: int = 3
@export var move_speed: float = 200.0

var current_hex: HexCoordinates
var hex_grid: HexGrid
var is_moving: bool = false
var move_path: Array[HexCoordinates] = []

func _ready():
	current_hex = HexCoordinates.new(0, 0)
	if get_parent() is HexGrid:
		hex_grid = get_parent()
		position = hex_grid.hex_to_pixel(current_hex)
		hex_grid.update_visibility(current_hex, sight_range)

func initialize(grid: HexGrid, start_position: HexCoordinates):
	hex_grid = grid
	current_hex = start_position
	position = hex_grid.hex_to_pixel(current_hex)
	hex_grid.update_visibility(current_hex, sight_range)

func can_move_to(target: HexCoordinates) -> bool:
	print("Player movement validation:")
	print("  Current position: ", current_hex._to_string())
	print("  Target position: ", target._to_string())
	print("  Is moving: ", is_moving)
	
	if is_moving:
		print("  BLOCKED: Player is currently moving")
		return false
	
	var distance = current_hex.distance_to(target)
	print("  Distance: ", distance, " (max: ", movement_range, ")")
	if distance > movement_range:
		print("  BLOCKED: Target too far away")
		return false
	
	var tile = hex_grid.get_tile(target)
	if not tile:
		print("  BLOCKED: No tile found at target")
		return false
	
	var can_move = tile.can_move_to()
	print("  Tile movement cost: ", tile.movement_cost, " (can move: ", can_move, ")")
	
	if can_move:
		print("  MOVEMENT ALLOWED")
	else:
		print("  BLOCKED: Tile blocks movement")
	
	return can_move

func request_move(target: HexCoordinates) -> bool:
	print("=== PLAYER request_move called with target: ", target._to_string(), " ===")
	
	if not can_move_to(target):
		print("Player movement request BLOCKED by can_move_to validation")
		movement_blocked.emit()
		return false
	
	print("Player movement request APPROVED - calling move_to")
	move_to(target)
	return true

func move_to(target: HexCoordinates):
	print("=== PLAYER move_to called with target: ", target._to_string(), " ===")
	
	if is_moving:
		print("Already moving, ignoring move request")
		return
	
	var tile = hex_grid.get_tile(target)
	if not tile or not tile.can_move_to():
		print("Cannot move to target: no tile or blocked")
		movement_blocked.emit()
		return
	
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
