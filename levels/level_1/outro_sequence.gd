extends CanvasLayer

@onready var background = $Background
@onready var debrief_text = $DebriefText
@onready var title_image = $TitleImage
@onready var disclaimer_image = $DisclaimerImage

# --- NEW AUDIO VARIABLES ---
@export var outro_music: AudioStream
var outro_player: AudioStreamPlayer
# -------------------------

# Configure your transition timings here
var flashbang_speed : float = 1.1
var text_type_speed : float = 6.0
var read_delay : float = 6.0
var fade_speed : float = 4.5

func _ready():
	background.modulate.a = 0.0
	title_image.modulate.a = 0.0
	disclaimer_image.modulate.a = 0.0
	debrief_text.visible_ratio = 0.0 
	
	# --- SETUP AUDIO PLAYER ---
	if outro_music:
		outro_player = AudioStreamPlayer.new()
		outro_player.stream = outro_music
		outro_player.volume_db = -80.0 # Start silent for the fade-in
		add_child(outro_player)
	# --------------------------
	
	await get_tree().create_timer(0.5).timeout
	start_outro()

func start_outro():
	# 1. Lock the player down
	var player = get_tree().get_first_node_in_group("players")
	if player:
		player.has_control = false
		
	var ui = get_tree().get_first_node_in_group("ui")
	if ui and ui.has_method("hide_ui"):
		ui.hide_ui()
		
	# --- MUSIC CROSSFADE ---
	# Try to find the root level node and trigger its fade_out functions
	var level = get_tree().current_scene
	if level.has_method("fade_out_music"):
		level.fade_out_music(1.0)
	if level.has_method("fade_out_ambience"):
		level.fade_out_ambience(1.0)
		
	# Start playing the outro music silently, then tween its volume up
	if outro_player:
		outro_player.play()
		var audio_tween = create_tween()
		# Tween to a comfortable volume (e.g., -10.0 dB) over 1 second
		audio_tween.tween_property(outro_player, "volume_db", -10.0, 1.0)

	# 2. FLASHBANG! (Instantly fade the white background in)
	var flash_tween = create_tween()
	flash_tween.tween_property(background, "modulate:a", 1.0, flashbang_speed)
	await flash_tween.finished
	
	await get_tree().create_timer(1.0).timeout # Let the whiteness linger for a second
	
	# 3. TYPEWRITER TEXT EFFECT
	debrief_text.text = "EXTRACTED SUCCESSFULLY.\nMED PACKAGE OBTAINED."
	var text_tween = create_tween()
	# Tweens visible_ratio from 0 to 1, revealing characters one by one
	text_tween.tween_property(debrief_text, "visible_ratio", 1.0, text_type_speed)
	await text_tween.finished
	
	# Give the player time to read it
	await get_tree().create_timer(read_delay).timeout
	
	# Fade text out
	var text_fade = create_tween()
	text_fade.tween_property(debrief_text, "modulate:a", 0.0, 1.0)
	await text_fade.finished
	
	# 4. FADE BACKGROUND TO BLACK FOR THE IMAGES
	var bg_darken = create_tween()
	bg_darken.tween_property(background, "color", Color.BLACK, 1.0)
	await bg_darken.finished
	
	# 5. TITLE LOGO FADE IN/OUT
	var title_tween = create_tween()
	title_tween.tween_property(title_image, "modulate:a", 1.0, fade_speed)
	title_tween.tween_interval(2.0) # Hold it on screen for 2 seconds
	title_tween.tween_property(title_image, "modulate:a", 0.0, fade_speed)
	await title_tween.finished
	
	# 6. DISCLAIMER IMAGE FADE IN/OUT
	var disc_tween = create_tween()
	disc_tween.tween_property(disclaimer_image, "modulate:a", 1.0, fade_speed)
	disc_tween.tween_interval(5.0) # Hold disclaimer a bit longer
	disc_tween.tween_property(disclaimer_image, "modulate:a", 0.0, fade_speed)
	await disc_tween.finished
	
	# 7. LOAD MAIN MENU
	finalize_and_exit()

func finalize_and_exit():
	# Godot's change_scene_to_file automatically unloads the current active scene (the level)
	# and loads the new one. Ensure this path is perfectly correct!
	var next_scene_path = "res://ui/menus/main_menu.tscn" 
	
	var error = get_tree().change_scene_to_file(next_scene_path)
	if error != OK:
		print("ERROR: Failed to load main menu at path: ", next_scene_path)
