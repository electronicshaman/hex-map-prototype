extends PanelContainer

signal regenerate_pressed
signal randomize_pressed
signal sight_range_changed(value)
signal camera_zoom_changed(value)

var gen_controls: Dictionary = {}

func _ready():
	pass

func build():
	position = Vector2(10, 10)
	custom_minimum_size = Vector2(320, 0)
	var vb = VBoxContainer.new()
	add_child(vb)
	var title = Label.new()
	title.text = "World Generation"
	title.add_theme_font_size_override("font_size", 16)
	vb.add_child(title)
	gen_controls["elevation_frequency"] = _add_slider(vb, "Elevation Freq", 0.02, 0.3, 0.005)
	gen_controls["moisture_frequency"] = _add_slider(vb, "Moisture Freq", 0.02, 0.3, 0.005)
	gen_controls["mountain_threshold"] = _add_slider(vb, "Mountain Threshold", 0.4, 0.8, 0.01)
	gen_controls["hill_threshold"] = _add_slider(vb, "Hill Threshold", 0.3, 0.7, 0.01)
	gen_controls["valley_threshold"] = _add_slider(vb, "Valley Threshold", 0.1, 0.6, 0.01)
	gen_controls["high_moisture_threshold"] = _add_slider(vb, "High Moisture", 0.4, 0.9, 0.01)
	gen_controls["medium_moisture_threshold"] = _add_slider(vb, "Medium Moisture", 0.3, 0.8, 0.01)
	gen_controls["low_moisture_threshold"] = _add_slider(vb, "Low Moisture", 0.1, 0.7, 0.01)
	gen_controls["warp_enabled"] = _add_checkbox(vb, "Warp Enabled")
	gen_controls["warp_amplitude"] = _add_slider(vb, "Warp Amplitude", 0.0, 100.0, 1.0)
	gen_controls["river_count"] = _add_spinbox(vb, "Rivers", 0, 20, 1)
	gen_controls["sight_range"] = _add_slider(vb, "Sight Range", 2.0, 15.0, 1.0)
	gen_controls["camera_zoom"] = _add_slider(vb, "Camera Zoom", 0.25, 3.0, 0.05)
	gen_controls["goldfield_elevation_min"] = _add_slider(vb, "Gold Elev Min", 0.0, 1.0, 0.01)
	gen_controls["goldfield_moisture_min"] = _add_slider(vb, "Gold Moist Min", 0.0, 1.0, 0.01)
	gen_controls["goldfield_moisture_max"] = _add_slider(vb, "Gold Moist Max", 0.0, 1.0, 0.01)
	gen_controls["goldfield_noise_threshold"] = _add_slider(vb, "Gold Noise Thresh", 0.0, 1.0, 0.01)
	var hb = HBoxContainer.new()
	vb.add_child(hb)
	var regen_btn = Button.new()
	regen_btn.text = "Regenerate"
	hb.add_child(regen_btn)
	var randomize_btn = Button.new()
	randomize_btn.text = "Randomize Seeds"
	hb.add_child(randomize_btn)
	regen_btn.pressed.connect(func(): emit_signal("regenerate_pressed"))
	randomize_btn.pressed.connect(func(): emit_signal("randomize_pressed"))
	_get_slider(gen_controls["sight_range"]).value_changed.connect(func(v): emit_signal("sight_range_changed", v))
	_get_slider(gen_controls["camera_zoom"]).value_changed.connect(func(v): emit_signal("camera_zoom_changed", v))

func set_from_settings(s: MapGenerationSettings, sight_range: int, camera_zoom: float):
	_get_slider(gen_controls["elevation_frequency"]).value = s.elevation_frequency
	_get_slider(gen_controls["moisture_frequency"]).value = s.moisture_frequency
	_get_slider(gen_controls["mountain_threshold"]).value = s.mountain_threshold
	_get_slider(gen_controls["hill_threshold"]).value = s.hill_threshold
	_get_slider(gen_controls["valley_threshold"]).value = s.valley_threshold
	_get_slider(gen_controls["high_moisture_threshold"]).value = s.high_moisture_threshold
	_get_slider(gen_controls["medium_moisture_threshold"]).value = s.medium_moisture_threshold
	_get_slider(gen_controls["low_moisture_threshold"]).value = s.low_moisture_threshold
	_get_checkbox(gen_controls["warp_enabled"]).button_pressed = s.warp_enabled
	_get_slider(gen_controls["warp_amplitude"]).value = s.warp_amplitude
	_get_spinbox(gen_controls["river_count"]).value = s.river_count
	_get_slider(gen_controls["goldfield_elevation_min"]).value = s.goldfield_elevation_min
	_get_slider(gen_controls["goldfield_moisture_min"]).value = s.goldfield_moisture_min
	_get_slider(gen_controls["goldfield_moisture_max"]).value = s.goldfield_moisture_max
	_get_slider(gen_controls["goldfield_noise_threshold"]).value = s.goldfield_noise_threshold
	_get_slider(gen_controls["sight_range"]).value = float(sight_range)
	_get_slider(gen_controls["camera_zoom"]).value = float(camera_zoom)

func apply_to_settings(s: MapGenerationSettings) -> Dictionary:
	s.elevation_frequency = _get_slider(gen_controls["elevation_frequency"]).value
	s.moisture_frequency = _get_slider(gen_controls["moisture_frequency"]).value
	s.mountain_threshold = _get_slider(gen_controls["mountain_threshold"]).value
	s.hill_threshold = _get_slider(gen_controls["hill_threshold"]).value
	s.valley_threshold = _get_slider(gen_controls["valley_threshold"]).value
	var low_m = _get_slider(gen_controls["low_moisture_threshold"]).value
	var med_m = _get_slider(gen_controls["medium_moisture_threshold"]).value
	var high_m = _get_slider(gen_controls["high_moisture_threshold"]).value
	var m_vals: Array = [low_m, med_m, high_m]
	m_vals.sort()
	s.low_moisture_threshold = m_vals[0]
	s.medium_moisture_threshold = m_vals[1]
	s.high_moisture_threshold = m_vals[2]
	_get_slider(gen_controls["low_moisture_threshold"]).value = s.low_moisture_threshold
	_get_slider(gen_controls["medium_moisture_threshold"]).value = s.medium_moisture_threshold
	_get_slider(gen_controls["high_moisture_threshold"]).value = s.high_moisture_threshold
	s.warp_enabled = _get_checkbox(gen_controls["warp_enabled"]).button_pressed
	s.warp_amplitude = _get_slider(gen_controls["warp_amplitude"]).value
	s.river_count = int(_get_spinbox(gen_controls["river_count"]).value)
	s.goldfield_elevation_min = _get_slider(gen_controls["goldfield_elevation_min"]).value
	var gf_min = _get_slider(gen_controls["goldfield_moisture_min"]).value
	var gf_max = _get_slider(gen_controls["goldfield_moisture_max"]).value
	if gf_min > gf_max:
		var tmp = gf_min
		gf_min = gf_max
		gf_max = tmp
	s.goldfield_moisture_min = gf_min
	s.goldfield_moisture_max = gf_max
	_get_slider(gen_controls["goldfield_moisture_min"]).value = s.goldfield_moisture_min
	_get_slider(gen_controls["goldfield_moisture_max"]).value = s.goldfield_moisture_max
	s.goldfield_noise_threshold = _get_slider(gen_controls["goldfield_noise_threshold"]).value
	return {
		"sight_range": int(_get_slider(gen_controls["sight_range"]).value),
		"camera_zoom": float(_get_slider(gen_controls["camera_zoom"]).value)
	}

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
