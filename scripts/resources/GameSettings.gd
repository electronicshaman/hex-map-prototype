class_name GameSettings
extends Resource

@export_group("Player Settings")
@export var max_movement_points: int = 20
@export var sight_range: int = 7
@export var move_speed: float = 200.0
@export var start_hour: int = 6

@export_group("Time of Day Rules")
@export var dawn_start_hour: int = 5
@export var dawn_end_hour: int = 7
@export var day_start_hour: int = 7
@export var day_end_hour: int = 18
@export var dusk_start_hour: int = 18
@export var dusk_end_hour: int = 20
@export var night_start_hour: int = 20
@export var night_end_hour: int = 5
@export var prohibit_night_movement: bool = false
@export var dawn_movement_modifier: int = 1
@export var day_movement_modifier: int = 0
@export var dusk_movement_modifier: int = 1
@export var night_movement_modifier: int = 2

@export_group("Guide Mechanics")
@export var guide_active: bool = false
@export var guide_cost_reduction: int = 1

@export_group("Stimulant Mechanics")
@export var stimulant_min_bonus: int = 2
@export var stimulant_max_bonus: int = 3
@export var stimulant_crash_hours: int = 6

@export_group("Rest Mechanics")
@export var short_rest_hours: int = 2
@export var short_rest_min_recovery: int = 2
@export var short_rest_max_recovery: int = 3
@export var safe_camp_full_recovery: bool = true
@export var wilderness_camp_success_chance: float = 0.6
@export var wilderness_camp_min_recovery: int = 2
@export var wilderness_camp_max_recovery: int = 5

func get_time_phase(hour: int) -> String:
	if (hour >= night_start_hour and hour <= 23) or (hour >= 0 and hour < night_end_hour):
		return "Night"
	elif hour >= dawn_start_hour and hour < dawn_end_hour:
		return "Dawn"
	elif hour >= day_start_hour and hour < day_end_hour:
		return "Day"
	elif hour >= dusk_start_hour and hour < dusk_end_hour:
		return "Dusk"
	else:
		return "Day"

func get_movement_modifier(hour: int) -> int:
	var phase = get_time_phase(hour)
	match phase:
		"Dawn":
			return dawn_movement_modifier
		"Day":
			return day_movement_modifier
		"Dusk":
			return dusk_movement_modifier
		"Night":
			return night_movement_modifier
		_:
			return 0

func can_move_at_time(hour: int) -> bool:
	if prohibit_night_movement and get_time_phase(hour) == "Night":
		return false
	return true