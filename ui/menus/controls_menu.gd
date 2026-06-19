extends Control

var listening_action: String = ""
var listening_button: Button = null

var font_title = preload("res://assets/fonts/airlock/Airlock.otf")
var font_text = preload("res://assets/fonts/DM_Sans/static/DMSans-Light.ttf")

func _ready():
	var panel = Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Match the pause menu's custom style
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
	title.text = "CUSTOMIZE CONTROLS"
	if font_title: title.add_theme_font_override("font", font_title)
	title.add_theme_font_size_override("font_size", 32)
	vbox.add_child(title)
	
	var instr = Label.new()
	instr.text = "Click a button to rebind. Press ESC to cancel."
	if font_text: instr.add_theme_font_override("font", font_text)
	instr.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(instr)
	
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	
	var list_vbox = VBoxContainer.new()
	list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(list_vbox)
	
	_build_list(list_vbox)
	
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

func _build_list(container: Control):
	var all_actions = SettingsManager.configurable_actions
	for action in all_actions:
		var row = HBoxContainer.new()
		
		var lbl = Label.new()
		# Make names human readable: "weapon_1" -> "Weapon 1"
		var display_name = action.capitalize().replace("Ui ", "")
		lbl.text = display_name
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if font_text: lbl.add_theme_font_override("font", font_text)
		lbl.add_theme_font_size_override("font_size", 20)
		row.add_child(lbl)
		
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(250, 40)
		if font_text: btn.add_theme_font_override("font", font_text)
		btn.text = _get_event_name(action)
		btn.pressed.connect(func(): _on_rebind_pressed(action, btn))
		row.add_child(btn)
		
		container.add_child(row)

func _get_event_name(action: String) -> String:
	if not InputMap.has_action(action): return "Unbound"
	var events = InputMap.action_get_events(action)
	if events.size() == 0: return "Unbound"
	var ev = events[0]
	if ev is InputEventKey:
		var keycode = ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode
		return OS.get_keycode_string(keycode)
	elif ev is InputEventMouseButton:
		var btn_names = ["None", "Left Click", "Right Click", "Middle Click", "Wheel Up", "Wheel Down"]
		return btn_names[ev.button_index] if ev.button_index < btn_names.size() else "Mouse " + str(ev.button_index)
	return "Unknown"

func _on_rebind_pressed(action: String, btn: Button):
	listening_action = action
	listening_button = btn
	btn.text = "Press key or mouse button..."
	set_process_unhandled_input(true)

func _unhandled_input(event):
	if listening_action == "": return
	
	if event is InputEventKey or event is InputEventMouseButton:
		if event.is_pressed():
			# Ignore double clicks so it just registers as a normal click
			if event is InputEventMouseButton and event.double_click: return
			
			get_viewport().set_input_as_handled()
			
			# ESC cancels the rebind
			if event is InputEventKey and event.physical_keycode == KEY_ESCAPE:
				listening_button.text = _get_event_name(listening_action)
				listening_action = ""
				listening_button = null
				return
			
			InputMap.action_erase_events(listening_action)
			InputMap.action_add_event(listening_action, event)
			SettingsManager.save_controls()
			
			listening_button.text = _get_event_name(listening_action)
			listening_action = ""
			listening_button = null
