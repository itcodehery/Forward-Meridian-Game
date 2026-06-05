extends CanvasLayer

@onready var background = $Background
@onready var margin_container = $MarginContainer

func _ready():
	# Start completely invisible
	background.modulate.a = 0.0
	margin_container.modulate.a = 0.0
	margin_container.hide() # Hides buttons so they aren't accidentally clickable

func trigger_death():
	# 1. Free the mouse so the player can click
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# 2. Pause the game
	get_tree().paused = true
	
	# 3. Fade in animation
	margin_container.show()
	var tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	
	# Fade background to full opacity over 1 second
	tween.tween_property(background, "modulate:a", 1.0, 1.0)
	
	# Add a slight delay, then slide and fade the menu in
	# We use TRANS_CUBIC with EASE_OUT for that smooth "Halo" slide feel
	margin_container.position.x -= 50 # Start slightly to the left
	tween.parallel().tween_property(margin_container, "modulate:a", 1.0, 0.6).set_delay(0.5)
	tween.parallel().tween_property(margin_container, "position:x", margin_container.position.x + 50, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).set_delay(0.5)


# --- BUTTON SIGNALS ---

func _on_restart_button_pressed():
	print("Restarting Level...")
	# 1. Unpause the engine
	get_tree().paused = false 
	# 2. Kill this UI so it doesn't persist into the next life
	queue_free() 
	# 3. Now reload the scene
	get_tree().reload_current_scene()

func _on_menu_button_pressed():
	get_tree().paused = false
	queue_free()
	get_tree().change_scene_to_file("res://ui/menus/main_menu.tscn")

func _on_quit_button_pressed():
	# Shut it down
	get_tree().quit()
