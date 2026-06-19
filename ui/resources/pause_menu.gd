extends CanvasLayer

# --- CUSTOMIZATION ---
@export_category("Styling")
@export var log_button_scene: PackedScene

@export_category("Audio")
@export var menu_open_sound: AudioStream
@export var menu_close_sound: AudioStream

# --- STATE CONTAINERS ---
@onready var main_menu_state = %MainMenuState
@onready var logs_menu_state = %LogsMenuState

# --- MAIN MENU BUTTONS ---
@onready var resume_btn = %ResumeButton
@onready var logs_btn = %LogsButton
@onready var quit_btn = %QuitButton

# --- LOG NODES ---
@onready var log_list = %ButtonList
@onready var log_title = $BackgroundImage/LogsMenuState/LogsContainer/RightSide/VBoxContainer/TitleLabel
@onready var log_meta = $BackgroundImage/LogsMenuState/LogsContainer/RightSide/VBoxContainer/MetaLabel
@onready var log_content = $BackgroundImage/LogsMenuState/LogsContainer/RightSide/VBoxContainer/ContentLabel

# --- PERSISTENT BOTTOM LABELS ---
@onready var mission_name_label = $BackgroundImage/PersistentForeground/Panel/MarginContainer/HBoxContainer/BottomLeftMission/MissionNameLabel
@onready var ui_audio = $AudioStreamPlayer2D

var in_logs_menu: bool = false
var in_controls_menu: bool = false
var in_save_load_menu: bool = false
@onready var controls_menu_state = Control.new()
@onready var save_load_menu_state = Control.new()

func _ready():
	visible = false
	
	# Connect the Main Menu buttons
	resume_btn.pressed.connect(toggle_pause)
	logs_btn.pressed.connect(open_logs_menu)
	quit_btn.pressed.connect(func(): get_tree().quit())
	
	# Initialize UI
	_setup_logs()
	
	# Setup Controls Menu
	controls_menu_state.set_script(preload("res://ui/menus/controls_menu.gd"))
	controls_menu_state.name = "ControlsMenuState"
	controls_menu_state.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	$BackgroundImage.add_child(controls_menu_state)
	controls_menu_state.hide()
	
	# Setup Save/Load Menu
	save_load_menu_state.set_script(preload("res://ui/menus/save_load_menu.gd"))
	save_load_menu_state.name = "SaveLoadMenuState"
	save_load_menu_state.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	$BackgroundImage.add_child(save_load_menu_state)
	save_load_menu_state.hide()
	
	var menu_vbox = $BackgroundImage/MainMenuState/MenuVBox
	
	# Add Save Button dynamically
	var save_btn = log_button_scene.instantiate()
	save_btn.text_label = "SAVE GAME"
	menu_vbox.add_child(save_btn)
	menu_vbox.move_child(save_btn, 2) 
	save_btn.pressed.connect(open_save_menu)
	
	# Add Load Button dynamically
	var load_btn = log_button_scene.instantiate()
	load_btn.text_label = "LOAD GAME"
	menu_vbox.add_child(load_btn)
	menu_vbox.move_child(load_btn, 3) 
	load_btn.pressed.connect(open_load_menu)
	
	# Add Controls Button dynamically
	var controls_btn = log_button_scene.instantiate()
	controls_btn.text_label = "CONTROLS"
	menu_vbox.add_child(controls_btn)
	menu_vbox.move_child(controls_btn, 4) 
	controls_btn.pressed.connect(open_controls_menu)
	
	# Ensure we start on the main menu
	_reset_menu_state()

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		# If we are in the logs or controls, Escape should take us back to the main menu first
		if in_logs_menu or in_controls_menu or in_save_load_menu:
			_reset_menu_state()
		else:
			toggle_pause()

func toggle_pause():
	var new_pause_state = not get_tree().paused
	get_tree().paused = new_pause_state
	visible = new_pause_state
	
	if new_pause_state:
		# Playing the OPEN sound
		if menu_open_sound:
			ui_audio.stream = menu_open_sound
			ui_audio.play()
			
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_toggle_hud(false)
		_update_bottom_labels()
		_reset_menu_state() 
	else:
		# Playing the REVERSED CLOSE sound
		if menu_close_sound:
			ui_audio.stream = menu_close_sound
			ui_audio.play()
			
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_toggle_hud(true)

func _toggle_hud(show_hud: bool):
	var ui_nodes = get_tree().get_nodes_in_group("ui")
	for node in ui_nodes:
		if node is CanvasItem:
			node.visible = show_hud

# --- MENU NAVIGATION ---

func _reset_menu_state():
	in_logs_menu = false
	in_controls_menu = false
	in_save_load_menu = false
	logs_menu_state.hide()
	if is_instance_valid(controls_menu_state):
		controls_menu_state.hide()
	if is_instance_valid(save_load_menu_state):
		save_load_menu_state.hide()
	main_menu_state.show()

func open_logs_menu():
	in_logs_menu = true
	main_menu_state.hide()
	if is_instance_valid(controls_menu_state): controls_menu_state.hide()
	if is_instance_valid(save_load_menu_state): save_load_menu_state.hide()
	logs_menu_state.show()

func open_controls_menu():
	in_controls_menu = true
	main_menu_state.hide()
	logs_menu_state.hide()
	if is_instance_valid(save_load_menu_state): save_load_menu_state.hide()
	controls_menu_state.show()
	
func open_save_menu():
	in_save_load_menu = true
	main_menu_state.hide()
	logs_menu_state.hide()
	if is_instance_valid(controls_menu_state): controls_menu_state.hide()
	save_load_menu_state.set_mode("SAVE")
	save_load_menu_state.show()

func open_load_menu():
	in_save_load_menu = true
	main_menu_state.hide()
	logs_menu_state.hide()
	if is_instance_valid(controls_menu_state): controls_menu_state.hide()
	save_load_menu_state.set_mode("LOAD")
	save_load_menu_state.show()

func _update_bottom_labels():
	var active_level = get_tree().current_scene
	if active_level:
		var m_name = active_level.get("mission_name")
		mission_name_label.text = m_name if m_name else "UNKNOWN DIRECTIVE"

# ------------------------------------------------------------------------------
# LOG SYSTEM INTEGRATION
# ------------------------------------------------------------------------------

func _setup_logs():
	log_title.text = ""
	log_meta.text = ""
	log_content.text = ""
	
	for child in log_list.get_children():
		child.queue_free()
		
	for ulog in LogManager.unlocked_logs:
		create_log_button(ulog)
		
	# Disconnect if previously connected to avoid duplicates on restart
	if not LogManager.log_unlocked.is_connected(create_log_button):
		LogManager.log_unlocked.connect(create_log_button)

func create_log_button(ulog: GameLog):
	var btn = log_button_scene.instantiate()
	
	# 1. Add it to the tree FIRST so all its internal nodes load
	log_list.add_child(btn)
	
	# 2. Reference our custom variable, NOT the default .text property
	btn.text_label = ulog.title
	
	# 3. Connect the signal
	btn.pressed.connect(func(): display_log_details(ulog))

func display_log_details(ulog: GameLog):
	log_title.text = ulog.title
	log_meta.text = ulog.date + " | " + ulog.author
	log_content.text = ulog.content
