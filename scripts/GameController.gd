class_name GameController
extends Node2D

@export var hex_grid_scene: PackedScene
@export var player_scene: PackedScene

var hex_grid: HexGrid
var hex_renderer: HexRenderer
var player: Player
var touch_controller: TouchController
var camera: Camera2D

func _ready():
	_setup_camera()
	_setup_hex_grid()
	_setup_player()
	_setup_input()
	_connect_signals()
	
	# Force an initial render
	await get_tree().process_frame
	if hex_renderer:
		hex_renderer.queue_redraw()

func _input(event: InputEvent):
	# Test if GameController receives input events
	print("GameController _input called with: ", event.get_class())
	
	# Forward to TouchController if it exists
	if touch_controller and touch_controller.has_method("_input"):
		touch_controller._input(event)

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

func _setup_input():
	touch_controller = TouchController.new()
	touch_controller.name = "TouchController"
	touch_controller.hex_grid = hex_grid
	touch_controller.player = player
	touch_controller.camera = camera
	add_child(touch_controller)

func _connect_signals():
	if player:
		player.moved.connect(_on_player_moved)
		player.movement_blocked.connect(_on_movement_blocked)
	
	if touch_controller:
		touch_controller.hex_clicked.connect(_on_hex_clicked)
		touch_controller.hex_hovered.connect(_on_hex_hovered)



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
