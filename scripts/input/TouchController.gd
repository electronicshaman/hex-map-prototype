class_name TouchController
extends Node

signal hex_clicked(coords: HexCoordinates)
signal hex_hovered(coords: HexCoordinates)
@warning_ignore("unused_signal")
signal drag_started(position: Vector2)
@warning_ignore("unused_signal")
signal drag_updated(position: Vector2)
@warning_ignore("unused_signal")
signal drag_ended(position: Vector2)
@warning_ignore("unused_signal")
signal zoom_changed(zoom_delta: float)

@export var hex_grid: HexGrid
@export var player: Player
@export var camera: Camera2D

var is_dragging: bool = false
var drag_start_pos: Vector2
var last_touch_positions: Dictionary = {}
var initial_pinch_distance: float = 0.0
var show_reachable_area: bool = false
var reachable_tiles_cache: Array[HexCoordinates] = []

func _ready():
	# Ensure this node can receive input events
	set_process_input(true)
	set_process_unhandled_input(true)
	# Debug disabled to avoid log spam

func _input(event: InputEvent):
	# Debug disabled to avoid log spam
	
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)
	elif event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)
	elif event is InputEventKey:
		_handle_keyboard(event)

func _unhandled_input(event: InputEvent):
	# Process mouse motion here if it's not handled elsewhere
	if event is InputEventMouseMotion:
		_handle_mouse_motion(event)

func _handle_keyboard(event: InputEventKey):
	if event.pressed:
		if event.keycode == KEY_R:  # R key to toggle reachable area
			toggle_reachable_area_display()
		elif event.keycode == KEY_SPACE:  # Space to reset movement points
			if player:
				player.reset_movement_points()
				_update_reachable_area_cache()
				if show_reachable_area:
					_show_reachable_area()

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
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_check_hex_click(event.position)
			drag_start_pos = event.position
			is_dragging = true
		else:
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
	# Debug disabled to avoid log spam
	if is_dragging and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) and camera:
		var delta = event.relative
		camera.position -= delta / camera.zoom
	else:
		# Always check for hover when not dragging
		_check_hex_hover(event.position)

func _check_hex_click(screen_position: Vector2):
	if not hex_grid:
		return
	if not player:
		return
	
	var world_pos = _screen_to_world(screen_position)
	
	var hex_coords = hex_grid.pixel_to_hex(world_pos)
	
	# Validate coordinates are within actual grid bounds (40x30 grid = -20 to +19, -15 to +14)
	if hex_coords.q < -20 or hex_coords.q >= 20 or hex_coords.r < -15 or hex_coords.r >= 15:
		return
	
	var tile = hex_grid.get_tile(hex_coords)
	
	if tile:
		var can_move = player.can_move_to(hex_coords)
		
		if tile.is_explored:
			if can_move:
				var _success = player.request_move(hex_coords)
			else:
				pass
		else:
			pass
		hex_clicked.emit(hex_coords)
	else:
		pass

func _check_hex_hover(screen_position: Vector2):
	# Skip hover work while player is moving to avoid heavy path calculations
	if player and player.is_moving:
		if show_reachable_area:
			_show_reachable_area()
		else:
			hex_grid.clear_highlights()
		return
	if not hex_grid:
		return
	var world_pos = _screen_to_world(screen_position)
	var hex_coords = hex_grid.pixel_to_hex(world_pos)
	var tile = hex_grid.get_tile(hex_coords)
	
	if tile and tile.is_explored:
		hex_hovered.emit(hex_coords)
		
		# Calculate movement path for preview
		if player:
			var movement_path = player.calculate_movement_path_to(hex_coords)
			_show_movement_path_preview(movement_path)
		else:
			hex_grid.clear_highlights()
	else:
		# Only clear if not showing reachable area, otherwise restore it
		if show_reachable_area:
			_show_reachable_area()
		else:
			hex_grid.clear_highlights()

func _show_movement_path_preview(movement_path: Resource):
	# Only clear highlights if we're not showing reachable area
	if not show_reachable_area:
		hex_grid.clear_highlights()
	
	if not movement_path or not movement_path.is_valid or movement_path.is_empty():
		if show_reachable_area:
			_show_reachable_area()  # Restore reachable area display
		return
	
	# Determine path color based on affordability
	var path_color: Color
	var can_afford = movement_path.can_afford(player.get_movement_points_remaining())
	
	if can_afford:
		path_color = Color.YELLOW  # Bright yellow for affordable paths (more visible than cyan)
	else:
		path_color = Color.ORANGE_RED   # Bright red-orange for unaffordable paths
	
	# Highlight path tiles
	var tiles_to_highlight: Array[HexTile] = []
	for coord in movement_path.coordinates:
		var tile = hex_grid.get_tile(coord)
		if tile:
			tiles_to_highlight.append(tile)
	hex_grid.highlight_tiles(tiles_to_highlight, path_color)

func toggle_reachable_area_display():
	show_reachable_area = !show_reachable_area
	print("Reachable area display: ", "ON" if show_reachable_area else "OFF")
	
	if show_reachable_area:
		_update_reachable_area_cache()
		_show_reachable_area()
	else:
		hex_grid.clear_highlights()

func _update_reachable_area_cache():
	if player:
		reachable_tiles_cache = player.get_reachable_tiles()

func _show_reachable_area():
	if not hex_grid or reachable_tiles_cache.is_empty():
		return
	
	# Get tiles to highlight
	var tiles_to_highlight: Array[HexTile] = []
	for coord in reachable_tiles_cache:
		var tile = hex_grid.get_tile(coord)
		if tile:
			tiles_to_highlight.append(tile)
	
	# Highlight reachable area in bright green
	hex_grid.highlight_tiles(tiles_to_highlight, Color.LIME_GREEN)
	print("Showing reachable area: ", tiles_to_highlight.size(), " tiles highlighted")

func _screen_to_world(screen_pos: Vector2) -> Vector2:
	# Convert screen position to world position using proper Godot 4.4 method
	if camera:
		# Use viewport to get proper mouse position in world coordinates
		var viewport = get_viewport()
		var world_pos = viewport.get_camera_2d().get_global_mouse_position()
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
