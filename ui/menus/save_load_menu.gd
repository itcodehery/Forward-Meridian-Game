extends Control

var font_title = preload("res://assets/fonts/airlock/Airlock.otf")
var font_text = preload("res://assets/fonts/DM_Sans/static/DMSans-Light.ttf")

var mode: String = "SAVE" # "SAVE" or "LOAD"
var list_vbox: VBoxContainer

func _ready():
	var panel = Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.8)
	style.corner_radius_top_left = 40
	style.corner_radius_top_right = 40
	style.corner_radius_bottom_right = 40
	style.corner_radius_bottom_left = 40
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 80)
	margin.add_theme_constant_override("margin_right", 80)
	margin.add_theme_constant_override("margin_top", 80)
	margin.add_theme_constant_override("margin_bottom", 80)
	panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	margin.add_child(vbox)
	
	var title = Label.new()
	title.text = "SAVE GAME" if mode == "SAVE" else "LOAD GAME"
	if font_title: title.add_theme_font_override("font", font_title)
	title.add_theme_font_size_override("font_size", 32)
	vbox.add_child(title)
	
	var instr = Label.new()
	instr.text = "Select a slot to " + ("overwrite." if mode == "SAVE" else "load.")
	if font_text: instr.add_theme_font_override("font", font_text)
	instr.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(instr)
	
	if mode == "SAVE":
		var new_btn = Button.new()
		new_btn.custom_minimum_size = Vector2(0, 50)
		if font_title: new_btn.add_theme_font_override("font", font_title)
		new_btn.text = "+ CREATE NEW SAVE"
		new_btn.pressed.connect(func(): 
			SaveManager.save_game(true)
			_refresh_list()
		)
		vbox.add_child(new_btn)
	
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	
	list_vbox = VBoxContainer.new()
	list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(list_vbox)
	
	_refresh_list()
	
	var back_btn = Button.new()
	back_btn.text = "BACK TO MENU"
	if font_title: back_btn.add_theme_font_override("font", font_title)
	back_btn.custom_minimum_size = Vector2(300, 60)
	back_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	back_btn.pressed.connect(func(): 
		hide()
		get_parent().get_parent()._reset_menu_state()
	)
	vbox.add_child(back_btn)

func set_mode(new_mode: String):
	mode = new_mode
	if get_child_count() > 0:
		for c in get_children():
			c.queue_free()
		_ready() # Rebuild UI based on mode

func _refresh_list():
	for c in list_vbox.get_children():
		c.queue_free()
		
	var saves = SaveManager.get_all_saves()
	for s in saves:
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(0, 60)
		if font_text: btn.add_theme_font_override("font", font_text)
		
		# e.g., "2026-05-20 14:30  |  Mission: level_1"
		btn.text = s.date + "   |   Mission: " + s.level.capitalize()
		
		btn.pressed.connect(func(): _on_slot_pressed(s.path))
		list_vbox.add_child(btn)

func _on_slot_pressed(path: String):
	if mode == "SAVE":
		SaveManager.current_save_path = path
		SaveManager.save_game(false)
		_refresh_list()
	else:
		if SaveManager.load_game(path):
			get_tree().paused = false
			get_tree().change_scene_to_file("res://levels/" + SaveManager.game_data.current_level + ".tscn")
