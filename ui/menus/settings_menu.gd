extends Control

var listening_action: String = ""
var listening_button: Button = null

var font_title = preload("res://assets/fonts/airlock/Airlock.otf")
var font_text = preload("res://assets/fonts/DM_Sans/static/DMSans-Light.ttf")

@onready var fullscreen_check: CheckBox = %FullscreenCheck
@onready var master_slider: HSlider = %MasterSlider
@onready var sfx_slider: HSlider = %SFXSlider
@onready var subtitles_check: CheckBox = %SubtitlesCheck
@onready var controls_vbox: VBoxContainer = %ControlsVBox
@onready var back_btn: Button = %BackBtn

func _ready():
	_init_ui_state()
	_connect_signals()
	_build_controls_list(controls_vbox)

func _init_ui_state():
	fullscreen_check.button_pressed = SettingsManager.fullscreen
	master_slider.value = SettingsManager.master_volume
	sfx_slider.value = SettingsManager.sfx_volume
	subtitles_check.button_pressed = SettingsManager.subtitles_enabled
	if %TutorialsCheck:
		%TutorialsCheck.button_pressed = SettingsManager.tutorials_enabled

func _connect_signals():
	fullscreen_check.toggled.connect(func(toggled_on):
		SettingsManager.fullscreen = toggled_on
		SettingsManager.apply_video_settings()
	)
	
	master_slider.value_changed.connect(func(value):
		SettingsManager.master_volume = value
		SettingsManager.apply_audio_settings()
	)
	
	sfx_slider.value_changed.connect(func(value):
		SettingsManager.sfx_volume = value
		SettingsManager.apply_audio_settings()
	)
	
	subtitles_check.toggled.connect(func(toggled_on):
		SettingsManager.subtitles_enabled = toggled_on
	)
	
	%TutorialsCheck.toggled.connect(func(toggled_on):
		SettingsManager.tutorials_enabled = toggled_on
	)
	
	back_btn.pressed.connect(func():
		SettingsManager.save_settings()
		hide()
		# Assuming parent structure allows resetting (e.g. Pause Menu)
		if get_parent() and get_parent().has_method("_reset_menu_state"):
			get_parent()._reset_menu_state()
		elif get_parent() and get_parent().get_parent() and get_parent().get_parent().has_method("_reset_menu_state"):
			get_parent().get_parent()._reset_menu_state()
	)

# --- CONTROLS LOGIC ---
func _build_controls_list(container: Control):
	var all_actions = SettingsManager.configurable_actions
	for action in all_actions:
		var row = HBoxContainer.new()
		
		var lbl = Label.new()
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
			if event is InputEventMouseButton and event.double_click: return
			
			get_viewport().set_input_as_handled()
			
			if event is InputEventKey and event.physical_keycode == KEY_ESCAPE:
				listening_button.text = _get_event_name(listening_action)
				listening_action = ""
				listening_button = null
				return
			
			InputMap.action_erase_events(listening_action)
			InputMap.action_add_event(listening_action, event)
			
			listening_button.text = _get_event_name(listening_action)
			listening_action = ""
			listening_button = null
