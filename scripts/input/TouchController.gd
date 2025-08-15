class_name TouchController
extends Node

signal hex_clicked(coords: HexCoordinates)
signal hex_hovered(coords: HexCoordinates)
signal drag_started(position: Vector2)
signal drag_updated(position: Vector2)
signal drag_ended(position: Vector2)
signal zoom_changed(zoom_delta: float)

@export var hex_grid: HexGrid
@export var player: Player
@export var camera: Camera2D

var is_dragging: bool = false
var drag_start_pos: Vector2
var last_touch_positions: Dictionary = {}
var initial_pinch_distance: float = 0.0

func _ready():
	set_process_input(true)

func _input(event: InputEvent):
	# Debug all input events
	if event is InputEventMouseButton:
		print("=== INPUT EVENT: Mouse button - ", event.button_index, " pressed: ", event.pressed, " at: ", event.position, " ===")
	elif event is InputEventMouseMotion:
		print("=== INPUT EVENT: Mouse motion at: ", event.position, " ===")
	elif event is InputEventScreenTouch:
		print("=== INPUT EVENT: Touch - index: ", event.index, " pressed: ", event.pressed, " ===")
	
	# Verify node references
	print("Node references - hex_grid: ", hex_grid != null, " player: ", player != null, " camera: ", camera != null)
	
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)
	elif event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)

func _handle_touch(event: InputEventScreenTouch):
	if event.pressed:
		last_touch_positions[event.index] = event.position
		
		if last_touch_positions.size() == 2:
			_start_pinch()
		elif last_touch_positions.size() == 1:
			_check_hex_click(event.position)
	else:
		last_touch_positions.erase(event.index)
		
		if last_touch_positions.size() < 2:
			initial_pinch_distance = 0.0

func _handle_drag(event: InputEventScreenDrag):
	last_touch_positions[event.index] = event.position
	
	if last_touch_positions.size() == 2:
		_update_pinch()
	elif last_touch_positions.size() == 1 and camera:
		var delta = event.relative
		camera.position -= delta

func _handle_mouse_button(event: InputEventMouseButton):
	print("=== MOUSE BUTTON HANDLER: button ", event.button_index, " pressed: ", event.pressed, " at: ", event.position, " ===")
	
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			print("LEFT CLICK DETECTED - about to call _check_hex_click with position: ", event.position)
			_check_hex_click(event.position)
			drag_start_pos = event.position
			is_dragging = true
		else:
			print("Left mouse released - stopping drag")
			is_dragging = false
	elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
		if camera:
			camera.zoom *= Vector2(1.1, 1.1)
			camera.zoom = camera.zoom.clamp(Vector2(0.5, 0.5), Vector2(3.0, 3.0))
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		if camera:
			camera.zoom *= Vector2(0.9, 0.9)
			camera.zoom = camera.zoom.clamp(Vector2(0.5, 0.5), Vector2(3.0, 3.0))

func _handle_mouse_motion(event: InputEventMouseMotion):
	print("=== MOUSE MOTION HANDLER: position ", event.position, " dragging: ", is_dragging, " ===")
	
	if is_dragging and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) and camera:
		var delta = event.relative
		camera.position -= delta / camera.zoom
		print("Camera drag - new position: ", camera.position)
	else:
		# Always check for hover when not dragging
		print("Checking hover at position: ", event.position)
		_check_hex_hover(event.position)

func _check_hex_click(screen_position: Vector2):
	print("=== _check_hex_click called with position: ", screen_position, " ===")
	
	if not hex_grid:
		print("ERROR: No hex_grid available")
		return
	if not player:
		print("ERROR: No player available")
		return
	
	var world_pos = _screen_to_world(screen_position)
	print("Screen to world conversion: ", screen_position, " -> ", world_pos)
	
	var hex_coords = hex_grid.pixel_to_hex(world_pos)
	print("World to hex conversion: ", world_pos, " -> ", hex_coords._to_string())
	
	# Validate coordinates are within actual grid bounds (40x30 grid = -20 to +19, -15 to +14)
	if hex_coords.q < -20 or hex_coords.q >= 20 or hex_coords.r < -15 or hex_coords.r >= 15:
		print("Click outside valid grid bounds: ", hex_coords._to_string())
		return
	
	var tile = hex_grid.get_tile(hex_coords)
	print("Retrieved tile: ", tile != null)
	
	if tile:
		print("Tile found - Visible: ", tile.is_visible, " Explored: ", tile.is_explored, " Type: ", tile.get_terrain_name())
		var can_move = player.can_move_to(hex_coords)
		print("Player can move to tile: ", can_move)
		
		if tile.is_explored:
			if can_move:
				print("Attempting to move player...")
				var success = player.request_move(hex_coords)
				print("Move to ", hex_coords._to_string(), ": ", success)
			else:
				print("Movement blocked by player validation")
		else:
			print("Tile not explored - cannot move")
		hex_clicked.emit(hex_coords)
	else:
		print("No tile found at coordinates")
	
	print("=== _check_hex_click completed ===")	

func _check_hex_hover(screen_position: Vector2):
	print("=== _check_hex_hover called with position: ", screen_position, " ===")
	
	if not hex_grid:
		print("ERROR: No hex_grid available for hover")
		return
	
	var world_pos = _screen_to_world(screen_position)
	print("Hover - Screen to world conversion: ", screen_position, " -> ", world_pos)
	
	var hex_coords = hex_grid.pixel_to_hex(world_pos)
	print("Hover - World to hex conversion: ", world_pos, " -> ", hex_coords._to_string())
	
	var tile = hex_grid.get_tile(hex_coords)
	print("Hover - Retrieved tile: ", tile != null)
	
	if tile:
		print("Hover - Tile found at ", hex_coords._to_string(), " - Explored: ", tile.is_explored)
		hex_hovered.emit(hex_coords)
		
		# Provide visual feedback based on tile state
		var tiles_to_highlight: Array[HexTile] = [tile]
		
		if tile.is_explored:
			if player and player.can_move_to(hex_coords):
				# Green: Can move here
				print("Hover - Highlighting GREEN (can move)")
				hex_grid.highlight_tiles(tiles_to_highlight, Color.GREEN)
			else:
				# Yellow: Explored but can't move (too far or blocked)
				print("Hover - Highlighting YELLOW (can't move)")
				hex_grid.highlight_tiles(tiles_to_highlight, Color.YELLOW)
		else:
			# Red: Not explored yet
			print("Hover - Highlighting RED (not explored)")
			hex_grid.highlight_tiles(tiles_to_highlight, Color.RED)
	else:
		# Clear highlights if no tile
		print("Hover - No tile found, clearing highlights")
		hex_grid.clear_highlights()
	
	print("=== _check_hex_hover completed ===")

func _screen_to_world(screen_pos: Vector2) -> Vector2:
	# Convert screen position to world position using proper Godot 4.4 method
	if camera:
		# Use viewport to get proper mouse position in world coordinates
		var viewport = get_viewport()
		var world_pos = viewport.get_camera_2d().get_global_mouse_position()
		print("Coordinate conversion: screen ", screen_pos, " -> world ", world_pos)
		return world_pos
	elif hex_grid:
		return hex_grid.get_global_transform().affine_inverse() * screen_pos
	return screen_pos

func _start_pinch():
	var keys = last_touch_positions.keys()
	if keys.size() >= 2:
		var pos1 = last_touch_positions[keys[0]]
		var pos2 = last_touch_positions[keys[1]]
		initial_pinch_distance = pos1.distance_to(pos2)

func _update_pinch():
	if initial_pinch_distance == 0.0:
		_start_pinch()
		return
	
	var keys = last_touch_positions.keys()
	if keys.size() >= 2 and camera:
		var pos1 = last_touch_positions[keys[0]]
		var pos2 = last_touch_positions[keys[1]]
		var current_distance = pos1.distance_to(pos2)
		
		var zoom_factor = current_distance / initial_pinch_distance
		camera.zoom *= Vector2(zoom_factor, zoom_factor)
		camera.zoom = camera.zoom.clamp(Vector2(0.5, 0.5), Vector2(3.0, 3.0))
		
		initial_pinch_distance = current_distance
