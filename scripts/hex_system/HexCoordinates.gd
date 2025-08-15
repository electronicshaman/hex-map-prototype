class_name HexCoordinates
extends Resource

@export var q: int = 0
@export var r: int = 0

func _init(q_val: int = 0, r_val: int = 0):
	q = q_val
	r = r_val

func get_s() -> int:
	return -q - r

static func from_cube(x: int, _y: int, z: int) -> HexCoordinates:
	return HexCoordinates.new(x, z)

func to_cube() -> Vector3i:
	return Vector3i(q, -q - r, r)

func add(other: HexCoordinates) -> HexCoordinates:
	return HexCoordinates.new(q + other.q, r + other.r)

func subtract(other: HexCoordinates) -> HexCoordinates:
	return HexCoordinates.new(q - other.q, r - other.r)

func scale(factor: int) -> HexCoordinates:
	return HexCoordinates.new(q * factor, r * factor)

func distance_to(other: HexCoordinates) -> int:
	var vec = subtract(other)
	return (abs(vec.q) + abs(vec.q + vec.r) + abs(vec.r)) / 2

func get_neighbor(direction: int) -> HexCoordinates:
	var directions = [
		HexCoordinates.new(1, 0),   # Right
		HexCoordinates.new(1, -1),  # Top-Right
		HexCoordinates.new(0, -1),  # Top-Left
		HexCoordinates.new(-1, 0),  # Left
		HexCoordinates.new(-1, 1),  # Bottom-Left
		HexCoordinates.new(0, 1),   # Bottom-Right
	]
	return add(directions[direction % 6])

func get_all_neighbors() -> Array[HexCoordinates]:
	var neighbors: Array[HexCoordinates] = []
	for i in range(6):
		neighbors.append(get_neighbor(i))
	return neighbors

func to_pixel(size: float, flat_top: bool = false) -> Vector2:
	if flat_top:
		var x = size * (3.0/2.0 * q)
		var y = size * (sqrt(3.0)/2.0 * q + sqrt(3.0) * r)
		return Vector2(x, y)
	else:
		var x = size * (sqrt(3.0) * q + sqrt(3.0)/2.0 * r)
		var y = size * (3.0/2.0 * r)
		return Vector2(x, y)

static func from_pixel(pixel: Vector2, size: float, flat_top: bool = false) -> HexCoordinates:
	if flat_top:
		var q_val = (2.0/3.0 * pixel.x) / size
		var r_val = (-1.0/3.0 * pixel.x + sqrt(3.0)/3.0 * pixel.y) / size
		return round_hex(q_val, r_val)
	else:
		var q_val = (sqrt(3.0)/3.0 * pixel.x - 1.0/3.0 * pixel.y) / size
		var r_val = (2.0/3.0 * pixel.y) / size
		return round_hex(q_val, r_val)

static func round_hex(q_val: float, r_val: float) -> HexCoordinates:
	var s_val = -q_val - r_val
	var q_round = round(q_val)
	var r_round = round(r_val)
	var s_round = round(s_val)
	
	var q_diff = abs(q_round - q_val)
	var r_diff = abs(r_round - r_val)
	var s_diff = abs(s_round - s_val)
	
	if q_diff > r_diff and q_diff > s_diff:
		q_round = -r_round - s_round
	elif r_diff > s_diff:
		r_round = -q_round - s_round
	
	return HexCoordinates.new(int(q_round), int(r_round))

func _to_string() -> String:
	return "Hex(%d, %d)" % [q, r]

func equals(other: HexCoordinates) -> bool:
	return q == other.q and r == other.r

func to_dict() -> Dictionary:
	return {"q": q, "r": r}

static func from_dict(data: Dictionary) -> HexCoordinates:
	return HexCoordinates.new(data.get("q", 0), data.get("r", 0))
