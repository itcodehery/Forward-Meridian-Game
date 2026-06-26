extends Control

var listening_action: String = ""
var listening_button: Button = null
var has_unsaved_changes: bool = false

# --- UI References ---
var tab_container: TabContainer
var controls_vbox: VBoxContainer
var ui_components = {} # Store references to dynamic UI elements

func _ready():
	set_process_input(false)
	_bind_nodes()
	_init_ui_state()
	_build_controls_list()

func _bind_nodes():
	# Find Tab Container
	tab_container = _find_node_by_class(self, "TabContainer")
	
	# Find Sidebar Buttons
	var tabs = ["VIDEO", "AUDIO", "ACCESSIBILITY", "CONTROLS"]
	var tab_buttons = []
	for i in range(tabs.size()):
		var btn = _find_button_by_text(self, tabs[i])
		if btn:
			tab_buttons.append(btn)
			btn.pressed.connect(func():
				tab_container.current_tab = i
				for b in tab_buttons:
					b.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
				btn.add_theme_color_override("font_color", Color("ace700"))
			)
			
	if tab_buttons.size() > 0:
		tab_buttons[0].add_theme_color_override("font_color", Color("ace700"))
	
	# Find Action Buttons
	ui_components["save_btn"] = _find_button_by_text(self, "SAVE CHANGES")
	if ui_components["save_btn"]:
		ui_components["save_btn"].pressed.connect(func():
			SettingsManager.apply_and_save()
			_mark_saved()
		)
		
	var back_btn = _find_button_by_text(self, "BACK TO MENU")
	if back_btn:
		back_btn.pressed.connect(func():
			if has_unsaved_changes:
				SettingsManager.revert_changes()
			hide()
			if get_parent() and get_parent().has_method("_reset_menu_state"):
				get_parent()._reset_menu_state()
		)

	# Presets
	var presets = ["Ultra", "High", "Balanced", "Performance"]
	for i in range(presets.size()):
		var btn = _find_button_by_text(self, presets[i])
		if btn:
			btn.pressed.connect(func():
				SettingsManager.apply_preset(i)
				_init_ui_state() # Refresh UI
				_mark_unsaved()
			)

	# Video Settings
	ui_components["resolution"] = _find_option_control("Resolution")
	ui_components["display_mode"] = _find_option_control("Display Mode")
	ui_components["vsync"] = _find_option_control("VSync")
	ui_components["fps_cap"] = _find_option_control("Framerate Cap")
	ui_components["fsr"] = _find_option_control("AMD FSR 2.0")
	ui_components["anti_aliasing"] = _find_option_control("Anti-Aliasing")
	ui_components["shadows"] = _find_option_control("Shadow Quality")
	ui_components["sdfgi"] = _find_option_control("Global Illumination (SDFGI)")
	ui_components["bloom"] = _find_option_control("Bloom")
	
	# Add Macbook Resolutions
	var res_dropdown = ui_components["resolution"] as OptionButton
	if res_dropdown:
		res_dropdown.clear()
		for r in ["1024x666", "1280x720", "1280x832", "1479x956", "1600x900", "1710x1112", "1920x1080", "2560x1440", "3840x2160"]:
			res_dropdown.add_item(r)
	
	if ui_components["resolution"]: ui_components["resolution"].item_selected.connect(func(idx):
		var res_str = ui_components["resolution"].get_item_text(idx).split("x")
		SettingsManager.resolution = Vector2i(int(res_str[0]), int(res_str[1]))
		_mark_unsaved()
	)
	if ui_components["display_mode"]: ui_components["display_mode"].item_selected.connect(func(idx): SettingsManager.display_mode = idx; _mark_unsaved())
	if ui_components["vsync"]: ui_components["vsync"].item_selected.connect(func(idx): SettingsManager.vsync_mode = idx; _mark_unsaved())
	if ui_components["fps_cap"]: ui_components["fps_cap"].item_selected.connect(func(idx):
		var caps = [0, 30, 60, 120, 144]
		SettingsManager.fps_cap = caps[idx]
		_mark_unsaved()
	)
	if ui_components["fsr"]: ui_components["fsr"].item_selected.connect(func(idx): SettingsManager.fsr_mode = idx; _mark_unsaved())
	if ui_components["anti_aliasing"]: ui_components["anti_aliasing"].item_selected.connect(func(idx): SettingsManager.anti_aliasing = idx; _mark_unsaved())
	if ui_components["shadows"]: ui_components["shadows"].item_selected.connect(func(idx): SettingsManager.shadow_quality = idx; _mark_unsaved())
	if ui_components["sdfgi"]: ui_components["sdfgi"].toggled.connect(func(on): SettingsManager.sdfgi_enabled = on; _mark_unsaved())
	if ui_components["bloom"]:
		ui_components["bloom"].toggled.connect(func(on): SettingsManager.bloom_enabled = on; _mark_unsaved())
		ui_components["bloom"].get_parent().hide()

	# Audio Settings
	ui_components["master_vol"] = _find_option_control("Master Volume")
	ui_components["sfx_vol"] = _find_option_control("SFX Volume")
	ui_components["music_vol"] = _find_option_control("Music Volume")
	ui_components["dialog_vol"] = _find_option_control("Dialogue Volume")
	ui_components["subtitles"] = _find_option_control("Subtitles")

	if ui_components["master_vol"]: ui_components["master_vol"].value_changed.connect(func(v): SettingsManager.master_volume = v; _mark_unsaved())
	if ui_components["sfx_vol"]: ui_components["sfx_vol"].value_changed.connect(func(v): SettingsManager.sfx_volume = v; _mark_unsaved())
	if ui_components["music_vol"]: ui_components["music_vol"].value_changed.connect(func(v): SettingsManager.music_volume = v; _mark_unsaved())
	if ui_components["dialog_vol"]: ui_components["dialog_vol"].value_changed.connect(func(v): SettingsManager.dialog_volume = v; _mark_unsaved())
	if ui_components["subtitles"]: ui_components["subtitles"].toggled.connect(func(on): SettingsManager.subtitles_enabled = on; _mark_unsaved())

	# Accessibility
	ui_components["tutorials"] = _find_option_control("Enable Tutorials")
	if ui_components["tutorials"]: ui_components["tutorials"].toggled.connect(func(on): SettingsManager.tutorials_enabled = on; _mark_unsaved())
	
	# Controls
	var instr_label = _find_label_by_text(self, "Click a button to rebind. Press ESC to cancel.")
	if instr_label:
		controls_vbox = instr_label.get_parent()

# --- HELPER FUNCTIONS ---

func _find_option_control(label_text: String) -> Control:
	var label = _find_label_by_text(self, label_text)
	if label:
		for sibling in label.get_parent().get_children():
			if sibling != label and (sibling is OptionButton or sibling is HSlider or sibling is CheckBox):
				return sibling
	return null

func _find_label_by_text(node: Node, text: String) -> Label:
	for child in node.get_children():
		if child is Label and child.text == text:
			return child
		var found = _find_label_by_text(child, text)
		if found: return found
	return null

func _find_button_by_text(node: Node, text: String) -> Button:
	for child in node.get_children():
		if child is Button and child.text.begins_with(text):
			return child
		var found = _find_button_by_text(child, text)
		if found: return found
	return null

func _find_node_by_class(node: Node, class_name_str: String) -> Node:
	if node.is_class(class_name_str):
		return node
	for child in node.get_children():
		var found = _find_node_by_class(child, class_name_str)
		if found: return found
	return null


func _mark_unsaved():
	has_unsaved_changes = true
	if ui_components.has("save_btn") and ui_components["save_btn"]:
		ui_components["save_btn"].text = "SAVE CHANGES *"

func _mark_saved():
	has_unsaved_changes = false
	if ui_components.has("save_btn") and ui_components["save_btn"]:
		ui_components["save_btn"].text = "SAVE CHANGES"


# --- STATE SYNC ---

func _init_ui_state():
	# Video
	if ui_components["resolution"]:
		var res_str = str(SettingsManager.resolution.x) + "x" + str(SettingsManager.resolution.y)
		for i in range(ui_components["resolution"].get_item_count()):
			if ui_components["resolution"].get_item_text(i) == res_str:
				ui_components["resolution"].selected = i
				break
	if ui_components["display_mode"]: ui_components["display_mode"].selected = SettingsManager.display_mode
	if ui_components["vsync"]: ui_components["vsync"].selected = SettingsManager.vsync_mode
	
	if ui_components["fps_cap"]:
		var caps = [0, 30, 60, 120, 144]
		ui_components["fps_cap"].selected = caps.find(SettingsManager.fps_cap) if caps.has(SettingsManager.fps_cap) else 0
	
	if ui_components["fsr"]: ui_components["fsr"].selected = SettingsManager.fsr_mode
	if ui_components["anti_aliasing"]: ui_components["anti_aliasing"].selected = SettingsManager.anti_aliasing
	if ui_components["shadows"]: ui_components["shadows"].selected = SettingsManager.shadow_quality
	if ui_components["sdfgi"]: ui_components["sdfgi"].button_pressed = SettingsManager.sdfgi_enabled
	if ui_components["bloom"]: ui_components["bloom"].button_pressed = SettingsManager.bloom_enabled
	
	# Audio
	if ui_components["master_vol"]: ui_components["master_vol"].value = SettingsManager.master_volume
	if ui_components["sfx_vol"]: ui_components["sfx_vol"].value = SettingsManager.sfx_volume
	if ui_components["music_vol"]: ui_components["music_vol"].value = SettingsManager.music_volume
	if ui_components["dialog_vol"]: ui_components["dialog_vol"].value = SettingsManager.dialog_volume
	if ui_components["subtitles"]: ui_components["subtitles"].button_pressed = SettingsManager.subtitles_enabled
	
	# Accessibility
	if ui_components["tutorials"]: ui_components["tutorials"].button_pressed = SettingsManager.tutorials_enabled

# --- CONTROLS LOGIC ---

func _build_controls_list():
	if not controls_vbox: return
	
	# Clear existing children except the instruction label
	for child in controls_vbox.get_children():
		if not (child is Label and child.text == "Click a button to rebind. Press ESC to cancel."):
			child.queue_free()
			
	var font_text = preload("res://assets/fonts/DM_Sans/static/DMSans-Light.ttf")
	var all_actions = SettingsManager.configurable_actions
	for action in all_actions:
		var row = HBoxContainer.new()
		var lbl = Label.new()
		lbl.text = action.capitalize().replace("Ui ", "")
		lbl.size_flags_horizontal = SIZE_EXPAND_FILL
		if font_text: lbl.add_theme_font_override("font", font_text)
		lbl.add_theme_font_size_override("font_size", 20)
		row.add_child(lbl)
		
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(250, 40)
		if font_text: btn.add_theme_font_override("font", font_text)
		btn.text = _get_event_name(action)
		btn.pressed.connect(func(): _on_rebind_pressed(action, btn))
		row.add_child(btn)
		
		controls_vbox.add_child(row)

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
	set_process_input(true)

func _input(event):
	if listening_action == "": return
	
	if event is InputEventKey or event is InputEventMouseButton:
		if event.is_pressed():
			if event is InputEventMouseButton and event.double_click: return
			
			get_viewport().set_input_as_handled()
			
			if event is InputEventKey and event.physical_keycode == KEY_ESCAPE:
				listening_button.text = _get_event_name(listening_action)
				listening_action = ""
				listening_button = null
				set_process_input(false)
				return
			
			InputMap.action_erase_events(listening_action)
			InputMap.action_add_event(listening_action, event)
			_mark_unsaved()
			
			listening_button.text = _get_event_name(listening_action)
			listening_action = ""
			listening_button = null
			set_process_input(false)
