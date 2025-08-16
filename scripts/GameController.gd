class_name GameController
extends Node2D

@export var hex_grid_scene: PackedScene
@export var player_scene: PackedScene

var hex_grid: HexGrid
var hex_renderer: HexRenderer
var player: Player
var camera: Camera2D
var ui_layer: CanvasLayer
var regen_panel: PanelContainer
var gen_controls: Dictionary = {}
var last_preview_target: HexCoordinates = null
var hud_panel: PanelContainer
var hud_time_label: Label
var hud_mp_label: Label
var hud_camp_btn: Button
var hud_short_btn: Button
var hud_stim_btn: Button

func _ready():
	set_process_input(true)
	set_process_unhandled_input(true)
	
	_setup_camera()
	_setup_hex_grid()
	_setup_player()
	_setup_input()
	_connect_signals()
	_setup_generation_ui()
	_setup_hud()
	_update_hud()
	
	# Force an initial render
	await get_tree().process_frame
	if hex_renderer:
		hex_renderer.queue_redraw()



func _input(event: InputEvent):
	if event is InputEventMouseMotion:
		_handle_mouse_hover(event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_mouse_click(event.position)
	elif event is InputEventKey and event.pressed:
		_handle_keyboard_input(event)

func _unhandled_input(event: InputEvent):
	if event is InputEventMouseMotion:
		_handle_mouse_hover(event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_mouse_click(event.position)
	elif event is InputEventKey and event.pressed:
		_handle_keyboard_input(event)

func _handle_mouse_hover(screen_pos: Vector2):
	if not hex_grid or not player:
		return
	# Skip expensive hover work while moving
	if player.is_moving:
		if not show_reachable_area:
			hex_grid.clear_highlights()
		return
	
	# Convert screen to world coordinates
	var world_pos = _screen_to_world(screen_pos)
	
	# Convert to hex coordinates  
	var hex_coords = hex_grid.pixel_to_hex(world_pos)
	
	# Get tile
	var tile = hex_grid.get_tile(hex_coords)
	if tile and tile.is_explored:
		# Avoid re-calculating preview for the same target repeatedly
		if last_preview_target and last_preview_target.equals(hex_coords):
			return
		last_preview_target = hex_coords
		_show_path_preview(hex_coords)
	else:
		hex_grid.clear_highlights()
		last_preview_target = null

func _handle_mouse_click(screen_pos: Vector2):
	if not hex_grid or not player:
		return
	# Ignore clicks while moving
	if player.is_moving:
		return
	
	# Convert screen to world coordinates
	var world_pos = _screen_to_world(screen_pos)
	
	# Convert to hex coordinates  
	var hex_coords = hex_grid.pixel_to_hex(world_pos)
	
	# Check bounds using grid settings
	var settings = _get_map_settings()
	if hex_coords.q < settings.min_q or hex_coords.q >= settings.max_q or hex_coords.r < settings.min_r or hex_coords.r >= settings.max_r:
		return
	
	# Get tile
	var tile = hex_grid.get_tile(hex_coords)
	if tile and tile.is_explored:
		if player.can_move_to(hex_coords):
			var _success = player.request_move(hex_coords)

func _handle_keyboard_input(event: InputEventKey):
	if event.keycode == KEY_R:  # R key to toggle reachable area
		_toggle_reachable_area_display()
	elif event.keycode == KEY_SPACE:  # Space to reset movement points
		if player:
			player.reset_movement_points()

var show_reachable_area: bool = false
var reachable_tiles_cache: Array[HexCoordinates] = []

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
	if not player or player.is_moving:
		return
	# Calculate movement path
	var movement_path = player.calculate_movement_path_to(target)
	if not movement_path or not movement_path.is_valid:
		return
	
	# Determine color based on affordability
	var path_color: Color
	if movement_path.can_afford(player.get_movement_points_remaining()):
		path_color = Color.YELLOW  # Bright yellow for affordable
	else:
		path_color = Color.ORANGE_RED  # Bright orange-red for too expensive
	
	# Highlight the path
	var tiles_to_highlight: Array[HexTile] = []
	for coord in movement_path.coordinates:
		var tile = hex_grid.get_tile(coord)
		if tile:
			tiles_to_highlight.append(tile)
	
	hex_grid.highlight_tiles(tiles_to_highlight, path_color, Color.RED)

func _setup_camera():
	camera = Camera2D.new()
	camera.name = "MainCamera"
	# Start zoomed in a bit by default
	camera.zoom = Vector2(1.5, 1.5)
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

func _setup_input():
	# Input is handled directly in _input() and _unhandled_input()
	pass

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
	# Hill threshold
	gen_controls["hill_threshold"] = _add_slider(vb, "Hill Threshold", 0.3, 0.7, 0.01)
	# Valley threshold
	gen_controls["valley_threshold"] = _add_slider(vb, "Valley Threshold", 0.1, 0.6, 0.01)
	# Moisture thresholds
	gen_controls["high_moisture_threshold"] = _add_slider(vb, "High Moisture", 0.4, 0.9, 0.01)
	gen_controls["medium_moisture_threshold"] = _add_slider(vb, "Medium Moisture", 0.3, 0.8, 0.01)
	gen_controls["low_moisture_threshold"] = _add_slider(vb, "Low Moisture", 0.1, 0.7, 0.01)
	# Warp enabled
	gen_controls["warp_enabled"] = _add_checkbox(vb, "Warp Enabled")
	# Warp amplitude
	gen_controls["warp_amplitude"] = _add_slider(vb, "Warp Amplitude", 0.0, 100.0, 1.0)
	# River count
	gen_controls["river_count"] = _add_spinbox(vb, "Rivers", 0, 20, 1)
	# Sight range (player vision)
	gen_controls["sight_range"] = _add_slider(vb, "Sight Range", 2.0, 15.0, 1.0)
	# Camera zoom (lower = zoom out, higher = zoom in)
	gen_controls["camera_zoom"] = _add_slider(vb, "Camera Zoom", 0.25, 3.0, 0.05)
	# Goldfield params
	gen_controls["goldfield_elevation_min"] = _add_slider(vb, "Gold Elev Min", 0.0, 1.0, 0.01)
	gen_controls["goldfield_moisture_min"] = _add_slider(vb, "Gold Moist Min", 0.0, 1.0, 0.01)
	gen_controls["goldfield_moisture_max"] = _add_slider(vb, "Gold Moist Max", 0.0, 1.0, 0.01)
	gen_controls["goldfield_noise_threshold"] = _add_slider(vb, "Gold Noise Thresh", 0.0, 1.0, 0.01)

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
		var s := tg.map_generation_settings
		if s:
			(_get_slider(gen_controls["elevation_frequency"]).value) = s.elevation_frequency
			(_get_slider(gen_controls["moisture_frequency"]).value) = s.moisture_frequency
			(_get_slider(gen_controls["mountain_threshold"]).value) = s.mountain_threshold
			(_get_slider(gen_controls["hill_threshold"]).value) = s.hill_threshold
			(_get_slider(gen_controls["valley_threshold"]).value) = s.valley_threshold
			(_get_slider(gen_controls["high_moisture_threshold"]).value) = s.high_moisture_threshold
			(_get_slider(gen_controls["medium_moisture_threshold"]).value) = s.medium_moisture_threshold
			(_get_slider(gen_controls["low_moisture_threshold"]).value) = s.low_moisture_threshold
			(_get_checkbox(gen_controls["warp_enabled"]).button_pressed) = s.warp_enabled
			(_get_slider(gen_controls["warp_amplitude"]).value) = s.warp_amplitude
			(_get_spinbox(gen_controls["river_count"]).value) = s.river_count
			(_get_slider(gen_controls["goldfield_elevation_min"]).value) = s.goldfield_elevation_min
			(_get_slider(gen_controls["goldfield_moisture_min"]).value) = s.goldfield_moisture_min
			(_get_slider(gen_controls["goldfield_moisture_max"]).value) = s.goldfield_moisture_max
			(_get_slider(gen_controls["goldfield_noise_threshold"]).value) = s.goldfield_noise_threshold

	# Initialize sight range slider from current player value
	if player:
		(_get_slider(gen_controls["sight_range"]).value) = float(player.sight_range)
		# Live update: when sight slider changes, update player and visibility immediately
		_get_slider(gen_controls["sight_range"]).value_changed.connect(func(v):
			if player and hex_grid:
				player.sight_range = int(v)
				hex_grid.update_visibility(player.current_hex, player.sight_range)
		)

	# Initialize camera zoom slider and live-update camera
	if camera and "camera_zoom" in gen_controls:
		(_get_slider(gen_controls["camera_zoom"]).value) = float(camera.zoom.x)
		_get_slider(gen_controls["camera_zoom"]).value_changed.connect(func(v):
			if camera:
				camera.zoom = Vector2(v, v)
		)

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
		if hex_grid.terrain_generator.map_generation_settings:
			hex_grid.terrain_generator.map_generation_settings.elevation_seed = rng.randi()
			hex_grid.terrain_generator.map_generation_settings.moisture_seed = rng.randi()
		_apply_generation_settings()
		hex_grid.terrain_generator.regenerate_with_new_settings(hex_grid)
		if hex_renderer:
			hex_renderer.update_display()
		if player:
			hex_grid.update_visibility(player.current_hex, player.sight_range)
	)

func _setup_hud():
	if not ui_layer:
		return
	# Create a simple HUD panel showing time of day and MP
	hud_panel = PanelContainer.new()
	hud_panel.name = "HudPanel"
	hud_panel.custom_minimum_size = Vector2(220, 0)
	# Anchor to top-right corner with 10px margins
	hud_panel.anchor_left = 1.0
	hud_panel.anchor_right = 1.0
	hud_panel.anchor_top = 0.0
	hud_panel.anchor_bottom = 0.0
	# Right edge margin
	hud_panel.offset_right = -10
	# Compute left offset so panel width stays ~custom_minimum_size.x from right edge
	hud_panel.offset_left = -10 - hud_panel.custom_minimum_size.x
	# Top margin
	hud_panel.offset_top = 10
	ui_layer.add_child(hud_panel)

	var vb = VBoxContainer.new()
	hud_panel.add_child(vb)

	var title = Label.new()
	title.text = "Status"
	title.add_theme_font_size_override("font_size", 14)
	vb.add_child(title)

	hud_time_label = Label.new()
	hud_time_label.text = "Time: 06:00 (Day)"
	vb.add_child(hud_time_label)

	hud_mp_label = Label.new()
	hud_mp_label.text = "MP: 0/0"
	vb.add_child(hud_mp_label)

	# Action buttons
	var actions_hb = HBoxContainer.new()
	vb.add_child(actions_hb)

	hud_camp_btn = Button.new()
	hud_camp_btn.text = "Camp"
	actions_hb.add_child(hud_camp_btn)

	hud_short_btn = Button.new()
	hud_short_btn.text = "Short Rest"
	actions_hb.add_child(hud_short_btn)

	hud_stim_btn = Button.new()
	hud_stim_btn.text = "Stimulant"
	actions_hb.add_child(hud_stim_btn)

	# Wire button actions
	hud_camp_btn.pressed.connect(func():
		if not player or player.is_moving:
			return
		player.camp_full()
		# Refresh map visuals and visibility after time advance
		if hex_renderer:
			hex_renderer.update_display()
		if hex_grid and player:
			hex_grid.update_visibility(player.current_hex, player.sight_range)
		# Update HUD and reachable area display if on
		_update_hud()
		if show_reachable_area:
			_update_reachable_area_cache()
			_show_reachable_area()
	)

	hud_short_btn.pressed.connect(func():
		if not player or player.is_moving:
			return
		player.short_rest()
		_update_hud()
		if show_reachable_area:
			_update_reachable_area_cache()
			_show_reachable_area()
	)

	hud_stim_btn.pressed.connect(func():
		if not player or player.is_moving:
			return
		player.use_stimulant()
		_update_hud()
		if show_reachable_area:
			_update_reachable_area_cache()
			_show_reachable_area()
	)

func _update_hud():
	if not player or not hud_panel:
		return
	# Format hour as HH:00
	var hh := str(player.current_hour)
	if player.current_hour < 10:
		hh = "0" + hh
	var phase := player.get_time_phase_name() if player.has_method("get_time_phase_name") else ""
	hud_time_label.text = "Time: %s:00 (%s)" % [hh, phase]
	hud_mp_label.text = "MP: %d/%d" % [player.get_movement_points_remaining(), player.max_movement_points]

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
	var s := tg.map_generation_settings
	if not s:
		# Fallback to default settings if missing
		s = load("res://resources/default_map_generation_settings.tres")
		tg.map_generation_settings = s
	# Apply sight range from UI to player as part of settings apply
	if "sight_range" in gen_controls and player:
		player.sight_range = int(_get_slider(gen_controls["sight_range"]).value)
	# Apply camera zoom from UI
	if "camera_zoom" in gen_controls and camera:
		camera.zoom = Vector2(_get_slider(gen_controls["camera_zoom"]).value, _get_slider(gen_controls["camera_zoom"]).value)
	s.elevation_frequency = _get_slider(gen_controls["elevation_frequency"]).value
	s.moisture_frequency = _get_slider(gen_controls["moisture_frequency"]).value
	s.mountain_threshold = _get_slider(gen_controls["mountain_threshold"]).value
	s.hill_threshold = _get_slider(gen_controls["hill_threshold"]).value
	s.valley_threshold = _get_slider(gen_controls["valley_threshold"]).value
	# Normalize moisture thresholds to low <= medium <= high
	var low_m = _get_slider(gen_controls["low_moisture_threshold"]).value
	var med_m = _get_slider(gen_controls["medium_moisture_threshold"]).value
	var high_m = _get_slider(gen_controls["high_moisture_threshold"]).value
	var m_vals: Array = [low_m, med_m, high_m]
	m_vals.sort()
	s.low_moisture_threshold = m_vals[0]
	s.medium_moisture_threshold = m_vals[1]
	s.high_moisture_threshold = m_vals[2]
	# Reflect normalized values back to sliders
	_get_slider(gen_controls["low_moisture_threshold"]).value = s.low_moisture_threshold
	_get_slider(gen_controls["medium_moisture_threshold"]).value = s.medium_moisture_threshold
	_get_slider(gen_controls["high_moisture_threshold"]).value = s.high_moisture_threshold
	s.warp_enabled = _get_checkbox(gen_controls["warp_enabled"]).button_pressed
	s.warp_amplitude = _get_slider(gen_controls["warp_amplitude"]).value
	s.river_count = int(_get_spinbox(gen_controls["river_count"]).value)
	s.goldfield_elevation_min = _get_slider(gen_controls["goldfield_elevation_min"]).value
	# Ensure goldfield moisture min <= max
	var gf_min = _get_slider(gen_controls["goldfield_moisture_min"]).value
	var gf_max = _get_slider(gen_controls["goldfield_moisture_max"]).value
	if gf_min > gf_max:
		var tmp = gf_min
		gf_min = gf_max
		gf_max = tmp
	s.goldfield_moisture_min = gf_min
	s.goldfield_moisture_max = gf_max
	# Reflect back to sliders after normalization
	_get_slider(gen_controls["goldfield_moisture_min"]).value = s.goldfield_moisture_min
	_get_slider(gen_controls["goldfield_moisture_max"]).value = s.goldfield_moisture_max
	s.goldfield_noise_threshold = _get_slider(gen_controls["goldfield_noise_threshold"]).value

func _connect_signals():
	if player:
		player.moved.connect(_on_player_moved)
		player.movement_blocked.connect(_on_movement_blocked)
		player.movement_points_depleted.connect(_on_points_depleted)
		# HUD updates
		if player.has_signal("time_changed"):
			player.time_changed.connect(func(_hour): _update_hud())
		if player.has_signal("movement_points_changed"):
			player.movement_points_changed.connect(func(_c, _m): _update_hud())
	



func _on_player_moved(new_position: HexCoordinates):
	var target_pos = hex_grid.hex_to_pixel(new_position)
	var tween = create_tween()
	tween.tween_property(camera, "position", target_pos, 0.3)
	
	hex_renderer.update_display()
	
	# Minimal logging on move to avoid console pauses

	# After each move, update HUD and check if we are stuck (no affordable adjacent moves)
	_update_hud()
	_maybe_prompt_camp_if_stuck()

func _on_movement_blocked():
	print("Movement blocked!")
	# If we can't proceed and there are no affordable adjacent moves, prompt to camp
	_maybe_prompt_camp_if_stuck()

func _on_points_depleted():
	print("Movement points depleted - use HUD Camp button to restore")

func _maybe_prompt_camp_if_stuck():
	if not player or not hex_grid:
		return
	if player.is_moving:
		return
	var remaining := player.get_movement_points_remaining()
	# If out of points, normal depletion flow handles this
	if remaining <= 0:
		return
	# Inspect adjacent tiles for any affordable, passable move
	for neighbor in player.current_hex.get_all_neighbors():
		var t: HexTile = hex_grid.get_tile(neighbor)
		if t and t.can_move_to() and t.get_movement_cost() <= remaining:
			return
	# No affordable moves around; player is stuck but has points
	print("Player is stuck - use HUD Camp button to restore movement points")

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

func _get_map_settings() -> MapGenerationSettings:
	if hex_grid and hex_grid.terrain_generator and hex_grid.terrain_generator.map_generation_settings:
		return hex_grid.terrain_generator.map_generation_settings
	# Fallback to default settings
	return load("res://resources/default_map_generation_settings.tres")
