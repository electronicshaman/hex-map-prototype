class_name Player
extends Node2D

signal moved(new_position: HexCoordinates)
signal movement_blocked()
signal movement_points_depleted()
signal time_changed(current_hour: int)
signal movement_points_changed(current: int, max_val: int)

@export var max_movement_points: int = 20  # Movement points per turn
@export var sight_range: int = 7
@export var move_speed: float = 200.0
@export var start_hour: int = 6  # 0-23
@export var prohibit_night_movement: bool = false  # If true, cannot move during Night
@export var guide_active: bool = false  # If true, reduce effective terrain costs
@export var guide_reduction: int = 1  # Movement cost reduction when guide is active

var current_hour: int = 6  # 0-23 time of day
var stimulant_crash_in_hours: int = -1
var stimulant_crash_amount: int = 0

var current_movement_points: int

var current_hex: HexCoordinates
var hex_grid: HexGrid
var is_moving: bool = false
var move_path: Array[HexCoordinates] = []

func _ready():
	current_hex = HexCoordinates.new(0, 0)
	current_movement_points = max_movement_points
	current_hour = start_hour % 24
	if get_parent() is HexGrid:
		hex_grid = get_parent()
		position = hex_grid.hex_to_pixel(current_hex)
		hex_grid.update_visibility(current_hex, sight_range)

func initialize(grid: HexGrid, start_position: HexCoordinates):
	hex_grid = grid
	current_hex = start_position
	current_movement_points = max_movement_points
	current_hour = start_hour % 24
	position = hex_grid.hex_to_pixel(current_hex)
	hex_grid.update_visibility(current_hex, sight_range)
	time_changed.emit(current_hour)
	movement_points_changed.emit(current_movement_points, max_movement_points)

func can_move_to(target: HexCoordinates) -> bool:
	if is_moving:
		return false
	# Don't allow requesting a move to the current position
	if current_hex and target and current_hex.equals(target):
		return false
	# Prohibit movement at night if configured
	if prohibit_night_movement and _is_night():
		return false
	
	# Calculate path and cost to target
	var movement_path = calculate_movement_path_to(target)
	if not movement_path.is_valid:
		return false
	
	if not movement_path.can_afford(current_movement_points):
		return false
	
	var target_tile = hex_grid.get_tile(target)
	if not target_tile or not target_tile.can_move_to():
		return false

	return true

func calculate_movement_path_to(target: HexCoordinates) -> Resource:
	var movement_path_class = load("res://scripts/hex_system/MovementPath.gd")
	if not hex_grid:
		return movement_path_class.new()

	# Use pathfinding to get route with costs
	var prefer_roads = false
	var current_tile = hex_grid.get_tile(current_hex)
	if current_tile and current_tile.terrain_type == HexTile.TerrainType.ROAD:
		prefer_roads = true
	var path_coords = hex_grid.find_path_to(current_hex, target, prefer_roads)
	var mp: Resource = movement_path_class.from_pathfinding_result(path_coords, hex_grid)
	# Approximate preview: apply current time-of-day modifier and guide reduction uniformly per step
	if mp and mp.is_valid and mp.get_length() > 1:
		var mod := _time_of_day_modifier()
		var adj_individual: Array[int] = []
		var adj_cumulative: Array[int] = []
		var running := 0
		for i in range(1, mp.get_length()):
			var coord: HexCoordinates = mp.coordinates[i]
			var tile := hex_grid.get_tile(coord)
			var base_cost: int = tile.movement_cost if tile else 1
			var reduction_val: int = guide_reduction if guide_active else 0
			var eff: int = max(1, base_cost + mod - reduction_val)
			adj_individual.append(eff)
			running += eff
			adj_cumulative.append(running)
		mp.individual_costs = adj_individual
		mp.cumulative_costs = adj_cumulative
		mp.total_cost = running
	return mp

func get_reachable_tiles() -> Array[HexCoordinates]:
	# Use HexGrid's efficient reachable tiles calculation
	if not hex_grid:
		return []
	
	return hex_grid.find_reachable_tiles(current_hex, current_movement_points)

func consume_movement_points(cost: int):
	current_movement_points -= cost
	print("Consumed ", cost, " MP. Remaining: ", current_movement_points, "/", max_movement_points)
	# Advance time by 1 hour per movement point consumed
	_advance_time(cost)
	movement_points_changed.emit(current_movement_points, max_movement_points)

func reset_movement_points():
	current_movement_points = max_movement_points
	print("Movement points reset to: ", current_movement_points)
	movement_points_changed.emit(current_movement_points, max_movement_points)

func get_movement_points_remaining() -> int:
	return current_movement_points

func request_move(target: HexCoordinates) -> bool:
	# Calculate movement cost before validation
	var movement_path = calculate_movement_path_to(target)
	
	if not can_move_to(target):
		movement_blocked.emit()
		return false

	_move_along_path(movement_path)
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

	# If movement points are fully spent, notify
	if current_movement_points <= 0:
		movement_points_depleted.emit()
	
	print("=== PLAYER movement fully completed ===")

# New: Move step-by-step along a MovementPath
func _move_along_path(movement_path: Resource):
	if is_moving:
		print("Already moving, ignoring _move_along_path request")
		return
	if not movement_path or not movement_path.is_valid or movement_path.get_length() <= 1:
		print("No steps to move or invalid path")
		movement_blocked.emit()
		return

	is_moving = true
	move_path = movement_path.coordinates.duplicate()
	# Start from the first step after current position
	_move_step(1)

func _move_step(step_index: int):
	if step_index >= move_path.size():
		print("Completed all steps in path")
		is_moving = false
		if current_movement_points <= 0:
			movement_points_depleted.emit()
		return

	var next_hex: HexCoordinates = move_path[step_index]
	var tile := hex_grid.get_tile(next_hex)
	if not tile or not tile.can_move_to():
		print("Blocked step at ", next_hex._to_string())
		is_moving = false
		movement_blocked.emit()
		return

	# Compute effective step cost with time-of-day modifiers and guide
	if prohibit_night_movement and _is_night():
		print("Night movement prohibited")
		is_moving = false
		movement_blocked.emit()
		return
	var base_cost: int = tile.movement_cost
	var eff_mod: int = _time_of_day_modifier()
	var reduction: int = guide_reduction if guide_active else 0
	var step_cost: int = max(1, base_cost + eff_mod - reduction)
	if current_movement_points < step_cost:
		print("Insufficient points for next step: need ", step_cost, ", have ", current_movement_points)
		is_moving = false
		movement_blocked.emit()
		return

	# Consume cost per step
	consume_movement_points(step_cost)

	var target_pos = hex_grid.hex_to_pixel(next_hex)
	var distance = position.distance_to(target_pos)
	var duration = max(0.05, distance / move_speed)

	var tween = create_tween()
	tween.tween_property(self, "position", target_pos, duration)
	tween.tween_callback(func():
		# Update state at tile arrival
		current_hex = next_hex
		hex_grid.update_visibility(current_hex, sight_range)
		moved.emit(current_hex)
		# Handle encounter per step
		var arrived_tile = hex_grid.get_tile(current_hex)
		if arrived_tile and arrived_tile.has_encounter:
			_trigger_encounter(arrived_tile)
		# If we've spent all movement points, and no further steps, notify; otherwise continue
		if current_movement_points <= 0 and step_index + 1 >= move_path.size():
			movement_points_depleted.emit()
		# Continue to next step
		_move_step(step_index + 1)
	)

	# Failsafe: if tween fails, force next step after a short delay
	get_tree().create_timer(max(0.5, duration * 2.0)).timeout.connect(func():
		if is_moving and current_hex != next_hex:
			print("Tween fallback triggered for step to ", next_hex._to_string())
			position = target_pos
			current_hex = next_hex
			hex_grid.update_visibility(current_hex, sight_range)
			moved.emit(current_hex)
			_move_step(step_index + 1)
	)

func _trigger_encounter(tile: HexTile):
	print("Encounter triggered at ", tile.coordinates._to_string())

# ==== Time-of-day and recovery mechanics ====

func _advance_time(hours: int):
	if hours <= 0:
		return
	current_hour = (current_hour + hours) % 24
	# Handle stimulant crash countdown
	if stimulant_crash_in_hours > 0:
		stimulant_crash_in_hours -= hours
		if stimulant_crash_in_hours <= 0 and stimulant_crash_amount > 0:
			print("Stimulant crash: -", stimulant_crash_amount, " MP")
			current_movement_points = max(0, current_movement_points - stimulant_crash_amount)
			stimulant_crash_amount = 0
			stimulant_crash_in_hours = -1
			movement_points_changed.emit(current_movement_points, max_movement_points)
	# Notify listeners
	time_changed.emit(current_hour)

func _time_of_day_modifier() -> int:
	# Day: 0, Dawn/Dusk: +1, Night: +2
	if _is_night():
		return 2
	elif _is_dawn() or _is_dusk():
		return 1
	return 0

func _is_dawn() -> bool:
	return current_hour >= 5 and current_hour < 7

func _is_day() -> bool:
	return current_hour >= 7 and current_hour < 18

func _is_dusk() -> bool:
	return current_hour >= 18 and current_hour < 20

func _is_night() -> bool:
	return current_hour >= 20 or current_hour < 5

func get_time_phase_name() -> String:
	if _is_night():
		return "Night"
	if _is_dusk():
		return "Dusk"
	if _is_dawn():
		return "Dawn"
	return "Day"

func camp_full():
	# Determine if current tile is a safe camping spot (e.g., Town)
	var safe := false
	if hex_grid:
		var tile := hex_grid.get_tile(current_hex)
		safe = tile and tile.terrain_type == HexTile.TerrainType.TOWN
	if safe:
		# Advance to next 6am and restore full MP
		var to_morning := (24 + 6 - current_hour) % 24
		if to_morning == 0:
			to_morning = 24
		_advance_time(to_morning)
		reset_movement_points()
	else:
		# Wilderness risk: 60% chance full rest to morning, else partial interrupted
		var rng = RandomNumberGenerator.new()
		rng.randomize()
		if rng.randf() < 0.6:
			var to_morning2 := (24 + 6 - current_hour) % 24
			if to_morning2 == 0:
				to_morning2 = 24
			_advance_time(to_morning2)
			reset_movement_points()
		else:
			# Interrupted: still reaches morning, but recovery is partial
			var to_morning3 := (24 + 6 - current_hour) % 24
			if to_morning3 == 0:
				to_morning3 = 24
			_advance_time(to_morning3)
			var rec := rng.randi_range(2, 5)
			current_movement_points = min(max_movement_points, current_movement_points + rec)
			movement_points_changed.emit(current_movement_points, max_movement_points)

func short_rest():
	# 2-hour rest, recover 2-3 MP
	_advance_time(2)
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var rec := rng.randi_range(2, 3)
	current_movement_points = min(max_movement_points, current_movement_points + rec)
	movement_points_changed.emit(current_movement_points, max_movement_points)

func use_stimulant():
	# Grant +2-3 temporary MP; crash after 6 hours subtracts same amount
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var bonus := rng.randi_range(2, 3)
	current_movement_points = min(max_movement_points, current_movement_points + bonus)
	stimulant_crash_amount = bonus
	stimulant_crash_in_hours = 6
	movement_points_changed.emit(current_movement_points, max_movement_points)

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
