class_name HudPanel
extends PanelContainer

signal camp_pressed
signal short_rest_pressed
signal stimulant_pressed

var time_label: Label
var mp_label: Label

func build():
	custom_minimum_size = Vector2(220, 0)
	# Anchor to top-right corner with 10px margins
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 0.0
	anchor_bottom = 0.0
	# Right edge margin
	offset_right = -10
	# Compute left offset so panel width stays ~custom_minimum_size.x from right edge
	offset_left = -10 - custom_minimum_size.x
	# Top margin
	offset_top = 10

	var vb = VBoxContainer.new()
	add_child(vb)

	var title = Label.new()
	title.text = "Status"
	title.add_theme_font_size_override("font_size", 14)
	vb.add_child(title)

	time_label = Label.new()
	time_label.text = "Time: 06:00 (Day)"
	vb.add_child(time_label)

	mp_label = Label.new()
	mp_label.text = "MP: 0/0"
	vb.add_child(mp_label)

	var actions_hb = HBoxContainer.new()
	vb.add_child(actions_hb)

	var camp_btn = Button.new()
	camp_btn.text = "Camp"
	actions_hb.add_child(camp_btn)
	camp_btn.pressed.connect(func(): emit_signal("camp_pressed"))

	var short_btn = Button.new()
	short_btn.text = "Short Rest"
	actions_hb.add_child(short_btn)
	short_btn.pressed.connect(func(): emit_signal("short_rest_pressed"))

	var stim_btn = Button.new()
	stim_btn.text = "Stimulant"
	actions_hb.add_child(stim_btn)
	stim_btn.pressed.connect(func(): emit_signal("stimulant_pressed"))

func set_time_and_mp(time_text: String, mp_text: String):
	time_label.text = time_text
	mp_label.text = mp_text
