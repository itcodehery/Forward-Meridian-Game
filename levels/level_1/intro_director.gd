extends Node3D

@export_group("Slideshow Settings")
## Drag and drop your images here in the inspector
@export var intro_images: Array[Texture2D]
@export var image_hold_time: float = 3.0
@export var crossfade_time: float = 1.0

@onready var anim = $AnimationPlayer
@onready var cine_cam = $CineCam
@onready var audio_player = $AudioStreamPlayer3D

# --- NEW SLIDESHOW NODES ---
@onready var slideshow_layer = $SlideshowLayer
@onready var bg_rect = $SlideshowLayer/ColorRect
@onready var image_rect = $SlideshowLayer/TextureRect

var player
var is_skipping = false

func _ready():
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("players")
	
	# Ensure the slideshow starts visible but the image itself is invisible
	if slideshow_layer:
		slideshow_layer.show()
		image_rect.modulate.a = 0.0
		bg_rect.modulate.a = 1.0
	
	if player:
		start_intro()

func _input(event):
	if event.is_action_pressed("interact") and not is_skipping:
		skip_cutscene()

func skip_cutscene():
	is_skipping = true
	print("Cutscene skipped by player.")
	
	anim.stop()
	audio_player.stop()
	SubtitleManager.show_subtitle("", "", 0.1) 
	
	# Instantly hide the slideshow if we skip during it
	if slideshow_layer:
		slideshow_layer.hide()
		
	finalize_intro()

func start_intro():
	var ui = get_tree().get_first_node_in_group("ui")
	
	player.has_control = false
	player.get_node("Camera3D/CanvasLayer").visible = false 
	if ui and ui.has_method("hide_ui"):
		ui.hide_ui()
	
	cine_cam.make_current() 
	
	# 1. PLAY THE SLIDESHOW FIRST
	if intro_images.size() > 0:
		await _run_slideshow()
		
	# Stop right here if the player pressed skip during the slideshow
	if is_skipping: return
	
	# 2. START THE 3D CAMERA ANIMATION
	anim.play("intro_sequence")
	audio_player.play()
	
	MissionBrief.show_brief("ARAVINDA-1 Geosync Platform", "48 Hours in the Past", 9.0)
	_run_subtitle_sequence()

	await anim.animation_finished
	if not is_skipping:
		finalize_intro()

func _run_slideshow():
	# Loop through however many images you put in the inspector
	for tex in intro_images:
		if is_skipping: return
		
		# Load the image and fade it in
		image_rect.texture = tex
		var fade_in = create_tween()
		fade_in.tween_property(image_rect, "modulate:a", 1.0, crossfade_time)
		await fade_in.finished
		
		if is_skipping: return
		# Hold the image on screen
		await get_tree().create_timer(image_hold_time).timeout
		
		if is_skipping: return
		# Fade it back to black
		var fade_out = create_tween()
		fade_out.tween_property(image_rect, "modulate:a", 0.0, crossfade_time)
		await fade_out.finished

	if is_skipping: return
	
	# Finally, fade out the black background to reveal the 3D scene
	var bg_fade = create_tween()
	bg_fade.tween_property(bg_rect, "modulate:a", 0.0, crossfade_time)
	await bg_fade.finished
	
	slideshow_layer.hide()

func _run_subtitle_sequence():
	var subs = [
		["Mission data states that Aravinda has a biochemical package", 4.0],
		["in one of its locked quadrants.", 2.0],
		["Your mission is to unlock the quadrants,", 2.0],
		["neutralize the enemies, and fetch the package.", 3.0],
		["We will then extract you from here.", 2.0]
	]
	
	for sub in subs:
		if is_skipping: return
		SubtitleManager.show_subtitle("", sub[0], sub[1])
		await get_tree().create_timer(sub[1]).timeout

func finalize_intro():
	if player:
		player.get_node("Camera3D").make_current()
		player.get_node("Camera3D/CanvasLayer").visible = true
		player.has_control = true
	
	var ui = get_tree().get_first_node_in_group("ui")
	if ui and ui.has_method("fade_in_ui"):
		ui.fade_in_ui(1.0 if is_skipping else 1.5) 
	
	# --- TRIGGER AMBIENCE IN THE LEVEL ---
	var level = get_tree().current_scene
	if level and level.has_method("start_ambience"):
		level.start_ambience()
	# -------------------------------------
		
	queue_free()
