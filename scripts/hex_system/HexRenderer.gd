class_name HexRenderer
extends Node2D

var hex_grid: HexGrid
var hex_size: float = 32.0
var flat_top: bool = false

func _init(grid: HexGrid = null):
	if grid:
		hex_grid = grid
		hex_size = grid.hex_size
		flat_top = grid.flat_top

func _ready():
	queue_redraw()

func _draw():
	if not hex_grid or hex_grid.tiles.is_empty():
		return
	
	# Draw all visible tiles
	for key in hex_grid.tiles:
		var tile: HexTile = hex_grid.tiles[key]
		if tile.is_explored or tile.is_visible:
			_draw_hex_tile(tile)

func _draw_hex_tile(tile: HexTile):
	var center = tile.coordinates.to_pixel(hex_size, flat_top)
	var points = _get_hex_points(center)
	
	var color = Color.WHITE
	if tile.terrain_resource:
		color = tile.terrain_resource.get_display_color(tile.is_visible, tile.is_explored)
	else:
		# Fallback colors if no terrain resource
		if not tile.is_explored:
			color = Color.BLACK
		elif not tile.is_visible:
			color = Color.DARK_GRAY
	
	draw_colored_polygon(points, color)

	# Draw outlines for all terrains (including roads and creeks)
	var outline_color = Color.BLACK if tile.is_explored else Color.DARK_GRAY
	if tile.terrain_resource and tile.is_explored:
		outline_color = tile.terrain_resource.outline_color
	
	for i in range(points.size()):
		var next_i = (i + 1) % points.size()
		draw_line(points[i], points[next_i], outline_color, 1.0)

	# No additional overlays for roads and rivers; base fill color is used

func _get_hex_points(center: Vector2) -> PackedVector2Array:
	var points = PackedVector2Array()
	var angle_offset = 0.0 if flat_top else PI / 6.0
	
	for i in range(6):
		var angle = angle_offset + i * PI / 3.0
		var point = center + Vector2(
			hex_size * cos(angle),
			hex_size * sin(angle)
		)
		points.append(point)
	
	return points

func _get_hex_points_scaled(center: Vector2, radius_scale: float) -> PackedVector2Array:
	var points = PackedVector2Array()
	var angle_offset = 0.0 if flat_top else PI / 6.0
	var radius = hex_size * radius_scale
	for i in range(6):
		var angle = angle_offset + i * PI / 3.0
		var point = center + Vector2(
			radius * cos(angle),
			radius * sin(angle)
		)
		points.append(point)
	return points

func update_display():
	queue_redraw()
