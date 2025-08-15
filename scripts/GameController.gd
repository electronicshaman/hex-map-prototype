class_name GameController
extends Node2D

@export var hex_grid_scene: PackedScene
@export var player_scene: PackedScene

var hex_grid: HexGrid
var hex_renderer: HexRenderer
var player: Player
var touch_controller: TouchController
var camera: Camera2D
var ui_layer: CanvasLayer
var regen_panel: PanelContainer
var gen_controls: Dictionary = {}
var camp_dialog: AcceptDialog

func _ready():
	print("=== GAMECONTROLLER _ready() START ===")
	
	# Try to enable input processing explicitly
	set_process_input(true)
	set_process_unhandled_input(true)
	print("Input processing explicitly enabled")
	
	_setup_camera()
	_setup_hex_grid()
	_setup_player()
	_setup_input()
	_connect_signals()
	_setup_generation_ui()
	
	# Force an initial render
	await get_tree().process_frame
	if hex_renderer:
		hex_renderer.queue_redraw()
	
	# Add a timer to test if node is receiving regular updates
	var timer = Timer.new()
	timer.timeout.connect(_debug_timer_tick)
	timer.wait_time = 2.0
	timer.autostart = true
	add_child(timer)
	print("=== GAMECONTROLLER _ready() COMPLETE - Debug timer started ===")

func _debug_timer_tick():
	print("DEBUG TICK: GameController is alive at: ", Time.get_ticks_msec())
	
	# Manual mouse position check since input events aren't working
	var _mouse_pos = get_global_mouse_position()
	var viewport_mouse = get_viewport().get_mouse_position()
	
	# Check for mouse button state manually
	var is_mouse_pressed = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	
	# Detect click (mouse was released after being pressed)
	if was_mouse_pressed and not is_mouse_pressed:
		print("MANUAL CLICK DETECTED at: ", viewport_mouse)
		_handle_mouse_click(viewport_mouse)
	
	was_mouse_pressed = is_mouse_pressed
	
	# Only trigger hover if mouse position changed (to reduce spam)
	if viewport_mouse != last_mouse_position:
		print("Mouse moved to: ", viewport_mouse)
		_handle_mouse_hover(viewport_mouse)
		last_mouse_position = viewport_mouse
	
	# Check for keyboard input manually
	if Input.is_key_pressed(KEY_R):
		if not show_reachable_area:  # Only toggle on first press
			var fake_event = InputEventKey.new()
			fake_event.keycode = KEY_R
			_handle_keyboard_input(fake_event)

func _input(event: InputEvent):
	# Emergency input handling - bypass broken TouchController
	print("EMERGENCY INPUT: GameController received ", event.get_class())
	
	if event is InputEventMouseMotion:
		print("MOUSE MOTION at: ", event.position)
		_handle_mouse_hover(event.position)
	elif event is InputEventMouseButton:
		print("MOUSE BUTTON: ", event.button_index, " pressed: ", event.pressed, " at: ", event.position)
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_handle_mouse_click(event.position)
	elif event is InputEventKey and event.pressed:
		print("KEY PRESSED: ", event.keycode)
		_handle_keyboard_input(event)

func _unhandled_input(event: InputEvent):
	# Backup emergency input handling
	print("EMERGENCY UNHANDLED INPUT: GameController received ", event.get_class())
	
	if event is InputEventMouseMotion:
		print("UNHANDLED MOUSE MOTION at: ", event.position)
		_handle_mouse_hover(event.position)
	elif event is InputEventMouseButton:
		print("UNHANDLED MOUSE BUTTON: ", event.button_index, " pressed: ", event.pressed, " at: ", event.position)
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_handle_mouse_click(event.position)
	elif event is InputEventKey and event.pressed:
		print("UNHANDLED KEY PRESSED: ", event.keycode)
		_handle_keyboard_input(event)

func _handle_mouse_hover(screen_pos: Vector2):
	print("=== HOVER: Processing mouse position ", screen_pos, " ===")
	
	if not hex_grid or not player:
		print("Missing hex_grid or player for hover")
		return
	
	# Convert screen to world coordinates
	var world_pos = _screen_to_world(screen_pos)
	print("World position: ", world_pos)
	
	# Convert to hex coordinates  
	var hex_coords = hex_grid.pixel_to_hex(world_pos)
	print("Hex coordinates: ", hex_coords._to_string())
	
	# Get tile
	var tile = hex_grid.get_tile(hex_coords)
	if tile and tile.is_explored:
		print("Valid tile found - calculating path preview")
		_show_path_preview(hex_coords)
	else:
		print("No valid tile or not explored")
		hex_grid.clear_highlights()

func _handle_mouse_click(screen_pos: Vector2):
	print("=== CLICK: Processing click at ", screen_pos, " ===")
	
	if not hex_grid or not player:
		print("Missing hex_grid or player for click")
		return
	
	# Convert screen to world coordinates
	var world_pos = _screen_to_world(screen_pos)
	print("World position: ", world_pos)
	
	# Convert to hex coordinates  
	var hex_coords = hex_grid.pixel_to_hex(world_pos)
	print("Hex coordinates: ", hex_coords._to_string())
	
	# Check bounds
	if hex_coords.q < -20 or hex_coords.q >= 20 or hex_coords.r < -15 or hex_coords.r >= 15:
		print("Click outside valid grid bounds")
		return
	
	# Get tile
	var tile = hex_grid.get_tile(hex_coords)
	if tile and tile.is_explored:
		print("Valid tile found - attempting to move player")
		if player.can_move_to(hex_coords):
			var success = player.request_move(hex_coords)
			print("Move request result: ", success)
		else:
			print("Player cannot move to selected tile")
	else:
		print("No valid tile or not explored")

func _handle_keyboard_input(event: InputEventKey):
	print("=== KEYBOARD: Processing key ", event.keycode, " ===")
	
	if event.keycode == KEY_R:  # R key to toggle reachable area
		_toggle_reachable_area_display()
	elif event.keycode == KEY_SPACE:  # Space to reset movement points
		if player:
			player.reset_movement_points()
			print("Movement points reset")

var show_reachable_area: bool = false
var reachable_tiles_cache: Array[HexCoordinates] = []
var last_mouse_position: Vector2 = Vector2.ZERO
var was_mouse_pressed: bool = false

func _toggle_reachable_area_display():
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
		print("Updated reachable area cache: ", reachable_tiles_cache.size(), " tiles")

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
	# Simple coordinate conversion using camera
	if camera:
		# Convert screen position to world coordinates
		var _viewport = get_viewport()
		return camera.get_global_mouse_position()
	return screen_pos

func _show_path_preview(target: HexCoordinates):
	print("=== PATH PREVIEW: Calculating path to ", target._to_string(), " ===")
	
	# Calculate movement path
	var movement_path = player.calculate_movement_path_to(target)
	if not movement_path or not movement_path.is_valid:
		print("Invalid movement path")
		return
	
	print("Path calculated - cost: ", movement_path.total_cost, " points: ", player.get_movement_points_remaining())
	
	# Determine color based on affordability
	var path_color: Color
	if movement_path.can_afford(player.get_movement_points_remaining()):
		path_color = Color.YELLOW  # Bright yellow for affordable
		print("Path is AFFORDABLE - showing in yellow")
	else:
		path_color = Color.ORANGE_RED  # Bright orange-red for too expensive
		print("Path is TOO EXPENSIVE - showing in red")
	
	# Highlight the path
	var tiles_to_highlight: Array[HexTile] = []
	for coord in movement_path.coordinates:
		var tile = hex_grid.get_tile(coord)
		if tile:
			tiles_to_highlight.append(tile)
	
	print("Highlighting ", tiles_to_highlight.size(), " tiles in path")
	hex_grid.highlight_tiles(tiles_to_highlight, path_color)

func _setup_camera():
	camera = Camera2D.new()
	camera.name = "MainCamera"
	camera.zoom = Vector2(0.5, 0.5)  # Zoom out to see more tiles
	camera.position = Vector2(0, 0)  # Start at origin
	camera.enabled = true
	add_child(camera)
	# Make camera current
	camera.make_current()

func _setup_hex_grid():
	hex_grid = HexGrid.new()
	hex_grid.name = "HexGrid"
	add_child(hex_grid)
	
	hex_renderer = HexRenderer.new(hex_grid)
	hex_renderer.name = "HexRenderer"
	hex_grid.add_child(hex_renderer)
	
	print("HexGrid created with ", hex_grid.tiles.size(), " tiles")
	print("HexRenderer created with size: ", hex_renderer.hex_size)

func _setup_player():
	player = Player.new()
	player.name = "Player"
	hex_grid.add_child(player)
	
	var start_pos = HexCoordinates.new(0, 0)
	player.initialize(hex_grid, start_pos)
	
	camera.position = player.position
	print("Player created at: ", player.position)
	print("Camera positioned at: ", camera.position)

	# Setup camp dialog UI
	camp_dialog = AcceptDialog.new()
	camp_dialog.dialog_text = "You've used all movement points. Camp to restore them?"
	camp_dialog.title = "Camp"
	# Add a button for Camp action
	var _camp_button = camp_dialog.add_button("Camp", true, "camp")
	# Add a cancel button
	camp_dialog.get_ok_button().text = "Cancel"
	add_child(camp_dialog)
	# Handle custom Camp action via dialog signal
	camp_dialog.custom_action.connect(func(action: StringName):
		if action == "camp":
			player.reset_movement_points()
			print("Player camped and restored movement points")
			# Refresh reachable highlight if enabled
			if show_reachable_area:
				_update_reachable_area_cache()
				_show_reachable_area()
			camp_dialog.hide()
	)

func _setup_input():
	# DISABLED: TouchController is broken and consuming all input
	# touch_controller = TouchController.new()
	# touch_controller.name = "TouchController"
	# touch_controller.hex_grid = hex_grid
	# touch_controller.player = player
	# touch_controller.camera = camera
	# add_child(touch_controller)
	print("TouchController disabled - using emergency input handling only")

func _setup_generation_ui():
	# Create a lightweight panel to tweak terrain gen and regenerate
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 50
	add_child(ui_layer)

	regen_panel = PanelContainer.new()
	regen_panel.name = "RegenPanel"
	regen_panel.position = Vector2(10, 10)
	regen_panel.custom_minimum_size = Vector2(320, 0)
	ui_layer.add_child(regen_panel)

	var vb = VBoxContainer.new()
	regen_panel.add_child(vb)

	var title = Label.new()
	title.text = "World Generation"
	title.add_theme_font_size_override("font_size", 16)
	vb.add_child(title)

	# Elevation frequency slider
	gen_controls["elevation_frequency"] = _add_slider(vb, "Elevation Freq", 0.02, 0.3, 0.005)
	# Moisture frequency slider
	gen_controls["moisture_frequency"] = _add_slider(vb, "Moisture Freq", 0.02, 0.3, 0.005)
	# Mountain threshold
	gen_controls["mountain_threshold"] = _add_slider(vb, "Mountain Threshold", 0.4, 0.8, 0.01)
	# Warp enabled
	gen_controls["warp_enabled"] = _add_checkbox(vb, "Warp Enabled")
	# Warp amplitude
	gen_controls["warp_amplitude"] = _add_slider(vb, "Warp Amplitude", 0.0, 100.0, 1.0)
	# River count
	gen_controls["river_count"] = _add_spinbox(vb, "Rivers", 0, 20, 1)

	# Buttons
	var hb = HBoxContainer.new()
	vb.add_child(hb)
	var regen_btn = Button.new()
	regen_btn.text = "Regenerate"
	hb.add_child(regen_btn)
	var randomize_btn = Button.new()
	randomize_btn.text = "Randomize Seeds"
	hb.add_child(randomize_btn)

	# Initialize control values from current generator if available
	var tg: TerrainGenerator = hex_grid.terrain_generator if hex_grid else null
	if tg:
		(_get_slider(gen_controls["elevation_frequency"]).value) = tg.elevation_frequency
		(_get_slider(gen_controls["moisture_frequency"]).value) = tg.moisture_frequency
		(_get_slider(gen_controls["mountain_threshold"]).value) = tg.mountain_threshold
		(_get_checkbox(gen_controls["warp_enabled"]).button_pressed) = tg.warp_enabled
		(_get_slider(gen_controls["warp_amplitude"]).value) = tg.warp_amplitude
		(_get_spinbox(gen_controls["river_count"]).value) = tg.river_count

	regen_btn.pressed.connect(func():
		_apply_generation_settings()
		if hex_grid and hex_grid.terrain_generator:
			hex_grid.terrain_generator.regenerate_with_new_settings(hex_grid)
			if hex_renderer:
				hex_renderer.update_display()
			if player:
				hex_grid.update_visibility(player.current_hex, player.sight_range)
	)

	randomize_btn.pressed.connect(func():
		if not hex_grid or not hex_grid.terrain_generator:
			return
		var rng = RandomNumberGenerator.new()
		rng.randomize()
		hex_grid.terrain_generator.elevation_seed = rng.randi()
		hex_grid.terrain_generator.moisture_seed = rng.randi()
		_apply_generation_settings()
		hex_grid.terrain_generator.regenerate_with_new_settings(hex_grid)
		if hex_renderer:
			hex_renderer.update_display()
		if player:
			hex_grid.update_visibility(player.current_hex, player.sight_range)
	)

func _add_slider(parent: VBoxContainer, label_text: String, min_val: float, max_val: float, step: float) -> HBoxContainer:
	var hb = HBoxContainer.new()
	parent.add_child(hb)
	var lbl = Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(130, 0)
	hb.add_child(lbl)
	var slider = HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.step = step
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(slider)
	var val_lbl = Label.new()
	val_lbl.custom_minimum_size = Vector2(60, 0)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_lbl.text = str(snappedf(slider.value, step))
	hb.add_child(val_lbl)
	slider.value_changed.connect(func(v): val_lbl.text = str(snappedf(v, step)))
	return hb

func _add_spinbox(parent: VBoxContainer, label_text: String, min_val: int, max_val: int, step: int) -> HBoxContainer:
	var hb = HBoxContainer.new()
	parent.add_child(hb)
	var lbl = Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(130, 0)
	hb.add_child(lbl)
	var spin = SpinBox.new()
	spin.min_value = min_val
	spin.max_value = max_val
	spin.step = step
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(spin)
	return hb

func _add_checkbox(parent: VBoxContainer, label_text: String) -> HBoxContainer:
	var hb = HBoxContainer.new()
	parent.add_child(hb)
	var chk = CheckBox.new()
	chk.text = label_text
	hb.add_child(chk)
	return hb

func _get_slider(hb: HBoxContainer) -> HSlider:
	return hb.get_child(1) as HSlider

func _get_spinbox(hb: HBoxContainer) -> SpinBox:
	return hb.get_child(1) as SpinBox

func _get_checkbox(hb: HBoxContainer) -> CheckBox:
	return hb.get_child(0) as CheckBox

func _apply_generation_settings():
	if not hex_grid or not hex_grid.terrain_generator:
		return
	var tg: TerrainGenerator = hex_grid.terrain_generator
	tg.elevation_frequency = _get_slider(gen_controls["elevation_frequency"]).value
	tg.moisture_frequency = _get_slider(gen_controls["moisture_frequency"]).value
	tg.mountain_threshold = _get_slider(gen_controls["mountain_threshold"]).value
	tg.warp_enabled = _get_checkbox(gen_controls["warp_enabled"]).button_pressed
	tg.warp_amplitude = _get_slider(gen_controls["warp_amplitude"]).value
	tg.river_count = int(_get_spinbox(gen_controls["river_count"]).value)

func _connect_signals():
	if player:
		player.moved.connect(_on_player_moved)
		player.movement_blocked.connect(_on_movement_blocked)
		player.movement_points_depleted.connect(_on_points_depleted)
	
	# DISABLED: TouchController connections
	# if touch_controller:
	#	touch_controller.hex_clicked.connect(_on_hex_clicked)
	#	touch_controller.hex_hovered.connect(_on_hex_hovered)



func _on_player_moved(new_position: HexCoordinates):
	var target_pos = hex_grid.hex_to_pixel(new_position)
	var tween = create_tween()
	tween.tween_property(camera, "position", target_pos, 0.3)
	
	hex_renderer.update_display()
	
	var tile = hex_grid.get_tile(new_position)
	if tile:
		print("Player moved to: ", tile.get_terrain_name(), " at ", new_position._to_string())

func _on_movement_blocked():
	print("Movement blocked!")

func _on_points_depleted():
	print("Movement points depleted - prompting to camp")
	if camp_dialog:
		camp_dialog.popup_centered()

func _on_hex_clicked(coords: HexCoordinates):
	var tile = hex_grid.get_tile(coords)
	if tile:
		print("Clicked: ", tile.get_terrain_name(), " at ", coords._to_string())

func _on_hex_hovered(_coords: HexCoordinates):
	pass

func _process(_delta):
	# Only update display when needed
	if hex_renderer and (player.is_moving or Input.is_action_just_pressed("ui_accept")):
		hex_renderer.update_display()
