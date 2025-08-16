class_name TerrainTypeResource
extends Resource

@export_group("Basic Properties")
@export var terrain_name: String = "Unknown"
@export var movement_cost: int = 1
@export var passable: bool = true
@export var buildable: bool = true

@export_group("Visual Properties")
@export var base_color: Color = Color.WHITE
@export var dimmed_color: Color = Color.DARK_GRAY
@export var outline_color: Color = Color.BLACK
@export var icon_texture: Texture2D

@export_group("Gameplay Modifiers")
@export var visibility_modifier: float = 1.0
@export var defense_bonus: int = 0
@export var resource_yield: float = 1.0

@export_group("Special Properties")
@export var blocks_line_of_sight: bool = false
@export var provides_water: bool = false
@export var is_road: bool = false
@export var is_settlement: bool = false

@export_group("Time of Day Modifiers")
@export var dawn_movement_modifier: int = 0
@export var day_movement_modifier: int = 0
@export var dusk_movement_modifier: int = 0
@export var night_movement_modifier: int = 0
@export var prohibit_night_movement: bool = false

func get_effective_movement_cost(base_cost: int, time_phase: String) -> int:
	if not passable:
		return 999
	
	var modifier = 0
	match time_phase:
		"Dawn":
			modifier = dawn_movement_modifier
		"Day":
			modifier = day_movement_modifier
		"Dusk":
			modifier = dusk_movement_modifier
		"Night":
			if prohibit_night_movement:
				return 999
			modifier = night_movement_modifier
	
	return max(1, base_cost + modifier)

func get_display_color(is_visible: bool, is_explored: bool) -> Color:
	if not is_explored:
		return Color.BLACK
	elif not is_visible:
		return dimmed_color
	else:
		return base_color

func can_build_on() -> bool:
	return passable and buildable

func _to_string() -> String:
	return terrain_name