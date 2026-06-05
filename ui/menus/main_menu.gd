extends CanvasLayer

# --- NEW: SPLASH SETTINGS ---
@export_group("Splash Settings")
## Drag and drop your splash screen images here!
@export var splash_images: Array[Texture2D]
@export var splash_duration: float = 2.0 # Time each image stays visible
@export var fade_duration: float = 0.5   # Time to fade in/out
@export var skip_allowed: bool = true    # Can player press space/interact to skip?

# --- Audio Settings ---
@export_group("Atmosphere")
@export var menu_music: AudioStream
@export var music_volume: float = -10.0

# --- Node References ---
@onready var background_video = $BackgroundVideo
@onready var logo_anchor = $LogoAnchor
@onready var title_elements = $TitleElements
@onready var menu_elements = $MenuElements
@onready var music_player = AudioStreamPlayer.new()

# --- NEW UI REFERENCES ---
@onready var main_buttons = $MenuElements/MainButtons
@onready var continue_btn = $MenuElements/MainButtons/ContinueButton
@onready var new_game_btn = $MenuElements/MainButtons/NewGameButton
@onready var load_game_btn = $MenuElements/MainButtons/LoadGameButton
@onready var quit_btn = $MenuElements/MainButtons/QuitButton

@onready var load_menu_panel = $MenuElements/LoadMenuPanel
@onready var save_list_container = $MenuElements/LoadMenuPanel/ScrollContainer/SaveListContainer
@onready var back_btn = $MenuElements/LoadMenuPanel/BackButton

# --- NEW: SPLASH REFERENCES ---
@onready var splash_container = $SplashContainer
@onready var splash_image_rect = $SplashContainer/SplashImageRect
# -------------------------

enum MenuState { SPLASH, TITLE, TRANSITIONING, MENU }
var current_state = MenuState.SPLASH 

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# Initial UI Setup: Hide everything except Splash
	title_elements.modulate.a = 0.0
	logo_anchor.modulate.a = 0.0 # <--- ADD THIS LINE HERE
	menu_elements.modulate.a = 0.0
	menu_elements.hide()
	load_menu_panel.hide()
	
	splash_container.show()
	splash_container.modulate.a = 1.0
	
	if splash_image_rect:
		splash_image_rect.modulate.a = 0.0
	
	# Background Video Setup
	background_video.expand = true
	background_video.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_KEEP_WIDTH)
	background_video.custom_minimum_size.y = 600
	
	# --- CONNECT BUTTONS ---
	continue_btn.pressed.connect(_on_continue_pressed)

	load_game_btn.pressed.connect(_on_load_game_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)
	back_btn.pressed.connect(_on_back_pressed)
	
	main_buttons.show()
	
	# Disable "Continue" if there are no saves
	var all_saves = SaveManager.get_all_saves()
	if all_saves.size() == 0:
		continue_btn.disabled = true
		load_game_btn.disabled = true
	
	await get_tree().process_frame
	_center_logo_initially()
	_set_pivots()
	
	# Start the splash sequence
	_play_splash_sequence()


# ---------------------------------------------------------
# SPLASH SCREEN LOGIC
# ---------------------------------------------------------

func _play_splash_sequence():
	# If no images were added in the inspector, skip straight to title
	if splash_images.size() == 0:
		_enter_title_screen()
		return
		
	for tex in splash_images:
		if current_state != MenuState.SPLASH: break # Abort if player skipped
		
		# Set the current image
		splash_image_rect.texture = tex
		
		# Fade In
		var tween = create_tween()
		tween.tween_property(splash_image_rect, "modulate:a", 1.0, fade_duration)
		await tween.finished
		
		if current_state != MenuState.SPLASH: break 
		
		# Wait (Hold Image)
		await get_tree().create_timer(splash_duration).timeout
		
		if current_state != MenuState.SPLASH: break 
		
		# Fade Out
		var tween_out = create_tween()
		tween_out.tween_property(splash_image_rect, "modulate:a", 0.0, fade_duration)
		await tween_out.finished
	
	# Only enter title screen if we haven't already skipped to it
	if current_state == MenuState.SPLASH:
		_enter_title_screen()

func _enter_title_screen():
	current_state = MenuState.TITLE
	
	# Hide splash container entirely
	splash_container.hide()
	
	# Start music and video when title appears
	_setup_menu_music() 
	if not background_video.is_playing():
		background_video.play()
		
	# Fade in the title logo/text
	var tween = create_tween().set_parallel(true)
	tween.tween_property(title_elements, "modulate:a", 1.0, 1.0)
	tween.tween_property(logo_anchor, "modulate:a", 1.0, 1.0) # <--- ADD THIS LINE


# ---------------------------------------------------------
# AUDIO & CORE MENU LOGIC
# ---------------------------------------------------------

func _setup_menu_music():
	if menu_music:
		add_child(music_player)
		music_player.stream = menu_music
		music_player.volume_db = music_volume
		music_player.autoplay = true
		music_player.bus = "Music" 
		music_player.play()

func _center_logo_initially():
	var screen_size = get_viewport().get_visible_rect().size
	logo_anchor.global_position = (screen_size / 2.0) - (logo_anchor.size / 2.0)

func _set_pivots():
	logo_anchor.pivot_offset = logo_anchor.size / 2
	background_video.pivot_offset = background_video.size / 2

func _input(event):
	# 1. Handle Skipping Splash
	if current_state == MenuState.SPLASH and skip_allowed:
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
			_enter_title_screen()
			return

	# 2. Existing Title Logic (Transition to Menu)
	if current_state == MenuState.TITLE and (event.is_action_pressed("ui_accept") or event.is_action_pressed("interact")):
		trigger_transition()


func trigger_transition():
	current_state = MenuState.TRANSITIONING
	
	var screen_size = get_viewport().get_visible_rect().size
	var tween = create_tween().set_parallel(true)
	
	tween.tween_property(background_video, "custom_minimum_size:y", screen_size.y, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(background_video, "modulate", Color(0.4, 0.4, 0.4, 1.0), 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	
	var target_scale = Vector2(0.3, 0.3) 
	var final_width_on_screen = logo_anchor.size.x * target_scale.x
	var target_x = screen_size.x - final_width_on_screen - 50
	var target_y = 50 
	
	tween.tween_property(logo_anchor, "global_position", Vector2(target_x, target_y), 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(logo_anchor, "scale", target_scale, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(title_elements, "modulate:a", 0.0, 0.4)
	
	menu_elements.show()
	menu_elements.modulate.a = 0.0
	var original_menu_x = menu_elements.global_position.x
	menu_elements.global_position.x -= 100
	
	tween.tween_property(menu_elements, "modulate:a", 1.0, 0.6).set_delay(0.4)
	tween.tween_property(menu_elements, "global_position:x", original_menu_x, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).set_delay(0.4)
	
	await tween.finished
	current_state = MenuState.MENU


# ---------------------------------------------------------
# BUTTON HANDLERS & SAVE SYSTEM LOGIC
# ---------------------------------------------------------

func _on_continue_pressed():
	print("Main Menu: Attempting to continue...")
	if SaveManager.continue_game():
		_load_level_scene(SaveManager.game_data.current_level)

func _on_new_game_pressed():
	print("Main Menu: Starting New Game...")
	SaveManager.new_game() 
	_load_level_scene(SaveManager.game_data.current_level)

func _on_load_game_pressed():
	main_buttons.hide()
	load_menu_panel.show()
	_populate_save_list()

func _on_back_pressed():
	load_menu_panel.hide()
	main_buttons.show()

func _on_quit_pressed():
	get_tree().quit()


# ---------------------------------------------------------
# DYNAMIC UI GENERATION
# ---------------------------------------------------------

func _populate_save_list():
	for child in save_list_container.get_children():
		child.queue_free()
		
	var all_saves = SaveManager.get_all_saves()
	
	if all_saves.size() == 0:
		var empty_label = Label.new()
		empty_label.text = "No saves found."
		save_list_container.add_child(empty_label)
		return

	for i in range(all_saves.size()):
		var save_info = all_saves[i]
		var btn = Button.new()
		
		var prefix = "[LATEST] " if i == 0 else ""
		btn.text = prefix + save_info.level.capitalize() + "  -  " + save_info.date
		btn.custom_minimum_size = Vector2(300, 50) 
		btn.pressed.connect(_on_specific_save_selected.bind(save_info.path))
		
		save_list_container.add_child(btn)

func _on_specific_save_selected(file_path: String):
	print("Main Menu: Loading specific save -> ", file_path)
	if SaveManager.load_game(file_path):
		_load_level_scene(SaveManager.game_data.current_level)

func _load_level_scene(level_string: String):
	var full_path = "res://levels/" + level_string + "/" + level_string + ".scn"
	
	var err = get_tree().change_scene_to_file(full_path)
	if err != OK:
		get_tree().change_scene_to_file("res://levels/" + level_string + ".tscn")
