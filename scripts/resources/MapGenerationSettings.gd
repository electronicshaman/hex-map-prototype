class_name MapGenerationSettings
extends Resource

@export_group("Grid Settings")
@export var grid_width: int = 80
@export var grid_height: int = 60
@export var hex_size: float = 32.0
@export var flat_top: bool = false

@export_group("Noise Seeds")
@export var elevation_seed: int = 12345
@export var moisture_seed: int = 67890

@export_group("Elevation Settings")
@export var elevation_frequency: float = 0.08
@export var elevation_octaves: int = 4
@export var elevation_lacunarity: float = 2.0
@export var elevation_gain: float = 0.5

@export_group("Moisture Settings")
@export var moisture_frequency: float = 0.18
@export var moisture_octaves: int = 3
@export var moisture_lacunarity: float = 2.0
@export var moisture_gain: float = 0.55

@export_group("Domain Warp")
@export var warp_enabled: bool = true
@export var warp_amplitude: float = 40.0
@export var warp_frequency: float = 0.03

@export_group("Terrain Thresholds")
@export var mountain_threshold: float = 0.6
@export var hill_threshold: float = 0.45
@export var valley_threshold: float = 0.32
@export var high_moisture_threshold: float = 0.58
@export var medium_moisture_threshold: float = 0.48
@export var low_moisture_threshold: float = 0.38

@export_group("Goldfield Settings")
@export var goldfield_elevation_min: float = 0.5
@export var goldfield_moisture_min: float = 0.3
@export var goldfield_moisture_max: float = 0.7
@export var goldfield_noise_threshold: float = 0.4
@export var goldfield_mine_count_min: int = 5
@export var goldfield_mine_count_max: int = 10
@export var goldfield_deposit_count_min: int = 5
@export var goldfield_deposit_count_max: int = 10

@export_group("Civilization Settings")
@export var town_count: int = 5
@export var town_spacing: float = 8.0
@export var river_count: int = 8
@export var max_river_length: int = 120
@export var settlement_min_count: int = 2
@export var settlement_max_count: int = 5
@export var settlement_min_distance: int = 6

@export_group("Post-Processing")
@export var smooth_isolated_tiles: bool = true
@export var majority_smoothing_passes: int = 2
