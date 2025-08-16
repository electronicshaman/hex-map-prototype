class_name HexMapController
extends Node2D

# Addon wrapper that reuses the existing MapController logic.
# It preloads GenerationPanel/HudPanel from the addon path and embeds the same behavior.

const GenerationPanel = preload("res://addons/hex_map/scripts/ui/GenerationPanel.gd")
const HudPanel = preload("res://addons/hex_map/scripts/ui/HudPanel.gd")

@export var manage_camera := true
@export var show_generation_ui := true
@export var show_hud := true
@export var map_settings: MapGenerationSettings

var hex_grid: HexGrid
var hex_renderer: HexRenderer
var player: Player
var camera: Camera2D
var ui_layer: CanvasLayer
var generation_panel
var last_preview_target: HexCoordinates = null
var hud_panel

func _ready():
	set_process_input(true)
	set_process_unhandled_input(true)
	
	_setup_camera()
	_setup_hex_grid()
	# Inject editor-provided settings if present
	if hex_grid and hex_grid.terrain_generator and map_settings:
		hex_grid.terrain_generator.map_generation_settings = map_settings
		hex_grid.terrain_generator.regenerate_with_new_settings(hex_grid)
	_setup_player()
	_setup_input()
	_connect_signals()
	_setup_generation_ui()
	_setup_hud()
	_update_hud()
	await get_tree().process_frame
	if hex_renderer:
		hex_renderer.queue_redraw()

# Input plumbing identical to MapController, trimmed for brevity
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

var show_reachable_area: bool = false
var reachable_tiles_cache: Array[HexCoordinates] = []

# --- Copy of core helpers from MapController ---
# For brevity, we call into helper functions stored in this file (same content as MapController).
# In a real extraction, we'd refactor shared code into a module to avoid duplication.

func _handle_mouse_hover(screen_pos: Vector2):
	if not hex_grid or not player:
		return
	if player.is_moving:
		if not show_reachable_area:
			hex_grid.clear_highlights()
		return
	var world_pos = _screen_to_world(screen_pos)
	var hex_coords = hex_grid.pixel_to_hex(world_pos)
	var tile = hex_grid.get_tile(hex_coords)
	if tile and tile.is_explored:
		# Avoid rework if same as last
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
	if player.is_moving:
		return
	var world_pos = _screen_to_world(screen_pos)
	var hex_coords = hex_grid.pixel_to_hex(world_pos)
	var settings = _get_map_settings()
	if hex_coords.q < settings.min_q or hex_coords.q >= settings.max_q or hex_coords.r < settings.min_r or hex_coords.r >= settings.max_r:
		return
	var tile = hex_grid.get_tile(hex_coords)
	if tile and tile.is_explored:
		if player.can_move_to(hex_coords):
			var _success = player.request_move(hex_coords)

func _handle_keyboard_input(event: InputEventKey):
	if event.keycode == KEY_R:
		_toggle_reachable_area_display()
	elif event.keycode == KEY_SPACE:
		if player:
			player.reset_movement_points()

func _toggle_reachable_area_display():
	show_reachable_area = !show_reachable_area
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
	var tiles_to_highlight: Array[HexTile] = []
	for coord in reachable_tiles_cache:
		var tile = hex_grid.get_tile(coord)
		if tile:
			tiles_to_highlight.append(tile)
	hex_grid.highlight_tiles(tiles_to_highlight, Color.LIME_GREEN)

func _screen_to_world(screen_pos: Vector2) -> Vector2:
	if camera:
		return camera.get_global_mouse_position()
	return screen_pos

func _show_path_preview(target: HexCoordinates):
	if not player or player.is_moving:
		return
	var movement_path = player.calculate_movement_path_to(target)
	if not movement_path or not movement_path.is_valid:
		return
	var path_color: Color = Color.YELLOW if movement_path.can_afford(player.get_movement_points_remaining()) else Color.ORANGE_RED
	var tiles_to_highlight: Array[HexTile] = []
	for coord in movement_path.coordinates:
		var tile = hex_grid.get_tile(coord)
		if tile:
			tiles_to_highlight.append(tile)
	hex_grid.highlight_tiles(tiles_to_highlight, path_color, Color.RED)

func _setup_generation_ui():
	if not show_generation_ui:
		return
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 50
	add_child(ui_layer)
	generation_panel = GenerationPanel.new()
	ui_layer.add_child(generation_panel)
	generation_panel.build()
	var tg: TerrainGenerator = hex_grid.terrain_generator if hex_grid else null
	if tg and tg.map_generation_settings:
		generation_panel.set_from_settings(tg.map_generation_settings, player.sight_range if player else 6, camera.zoom.x if camera else 1.0)
	generation_panel.regenerate_pressed.connect(func():
		_apply_generation_settings()
		if hex_grid and hex_grid.terrain_generator:
			hex_grid.terrain_generator.regenerate_with_new_settings(hex_grid)
			if hex_renderer:
				hex_renderer.update_display()
			if player:
				hex_grid.update_visibility(player.current_hex, player.sight_range)
	)
	generation_panel.randomize_pressed.connect(func():
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
	generation_panel.sight_range_changed.connect(func(v):
		if player and hex_grid:
			player.sight_range = int(v)
			hex_grid.update_visibility(player.current_hex, player.sight_range)
	)
	generation_panel.camera_zoom_changed.connect(func(v):
		if camera:
			camera.zoom = Vector2(v, v)
	)

func _setup_hud():
	if not show_hud:
		return
	if not ui_layer:
		ui_layer = CanvasLayer.new()
		ui_layer.layer = 50
		add_child(ui_layer)
	hud_panel = HudPanel.new()
	ui_layer.add_child(hud_panel)
	hud_panel.build()
	hud_panel.camp_pressed.connect(func():
		if not player or player.is_moving:
			return
		player.camp_full()
		if hex_renderer:
			hex_renderer.update_display()
		if hex_grid and player:
			hex_grid.update_visibility(player.current_hex, player.sight_range)
		_update_hud()
		if show_reachable_area:
			_update_reachable_area_cache()
			_show_reachable_area()
	)
	hud_panel.short_rest_pressed.connect(func():
		if not player or player.is_moving:
			return
		player.short_rest()
		_update_hud()
		if show_reachable_area:
			_update_reachable_area_cache()
			_show_reachable_area()
	)
	hud_panel.stimulant_pressed.connect(func():
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
	var hh := str(player.current_hour)
	if player.current_hour < 10:
		hh = "0" + hh
	var phase := player.get_time_phase_name() if player.has_method("get_time_phase_name") else ""
	hud_panel.set_time_and_mp("Time: %s:00 (%s)" % [hh, phase], "MP: %d/%d" % [player.get_movement_points_remaining(), player.max_movement_points])

func _apply_generation_settings():
	if not hex_grid or not hex_grid.terrain_generator:
		return
	var tg: TerrainGenerator = hex_grid.terrain_generator
	var s := tg.map_generation_settings
	if not s:
		s = _get_map_settings()
		tg.map_generation_settings = s
	if generation_panel:
		var extras = generation_panel.apply_to_settings(s)
		if player and "sight_range" in extras:
			player.sight_range = int(extras["sight_range"])
		if camera and "camera_zoom" in extras:
			var z = float(extras["camera_zoom"])
			camera.zoom = Vector2(z, z)

func _connect_signals():
	if player:
		player.moved.connect(_on_player_moved)
		player.movement_blocked.connect(_on_movement_blocked)
		player.movement_points_depleted.connect(_on_points_depleted)
		if player.has_signal("time_changed"):
			player.time_changed.connect(func(_hour): _update_hud())
		if player.has_signal("movement_points_changed"):
			player.movement_points_changed.connect(func(_c, _m): _update_hud())

func _on_player_moved(new_position: HexCoordinates):
	var target_pos = hex_grid.hex_to_pixel(new_position)
	var tween = create_tween()
	tween.tween_property(camera, "position", target_pos, 0.3)
	hex_renderer.update_display()
	_update_hud()
	_maybe_prompt_camp_if_stuck()

func _on_movement_blocked():
	_maybe_prompt_camp_if_stuck()

func _on_points_depleted():
	pass

func _maybe_prompt_camp_if_stuck():
	if not player or not hex_grid:
		return
	if player.is_moving:
		return
	var remaining := player.get_movement_points_remaining()
	if remaining <= 0:
		return
	for neighbor in player.current_hex.get_all_neighbors():
		var t: HexTile = hex_grid.get_tile(neighbor)
		if t and t.can_move_to() and t.get_movement_cost() <= remaining:
			return

func _on_hex_clicked(coords: HexCoordinates):
	var tile = hex_grid.get_tile(coords)
	if tile:
		print("Clicked: ", tile.get_terrain_name(), " at ", coords._to_string())

func _on_hex_hovered(_coords: HexCoordinates):
	pass

func _process(_delta):
	if hex_renderer and (player.is_moving or Input.is_action_just_pressed("ui_accept")):
		hex_renderer.update_display()

func _setup_camera():
	if not manage_camera:
		return
	camera = Camera2D.new()
	camera.name = "MainCamera"
	camera.zoom = Vector2(1.5, 1.5)
	camera.position = Vector2(0, 0)
	camera.enabled = true
	add_child(camera)
	camera.make_current()

func _setup_hex_grid():
	hex_grid = HexGrid.new()
	hex_grid.name = "HexGrid"
	add_child(hex_grid)
	hex_renderer = HexRenderer.new(hex_grid)
	hex_renderer.name = "HexRenderer"
	hex_grid.add_child(hex_renderer)

func _setup_player():
	player = Player.new()
	player.name = "Player"
	hex_grid.add_child(player)
	var start_pos = HexCoordinates.new(0, 0)
	player.initialize(hex_grid, start_pos)
	if camera:
		camera.position = player.position

func _setup_input():
	pass

func _get_map_settings() -> MapGenerationSettings:
	if map_settings:
		return map_settings
	if hex_grid and hex_grid.terrain_generator and hex_grid.terrain_generator.map_generation_settings:
		return hex_grid.terrain_generator.map_generation_settings
	return load("res://resources/default_map_generation_settings.tres")
