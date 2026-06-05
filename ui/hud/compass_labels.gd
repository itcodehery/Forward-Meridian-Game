# compass.gd
extends Control

@export var player_path: NodePath
@onready var player = get_node(player_path)

# This should match the distance between your first 'N' and your second 'N'
@export var compass_width: float = 2000.0 

func _process(_delta):
	if not player: return

	# 1. Get the player's Y rotation in degrees (0 to 360)
	var player_rot = player.global_transform.basis.get_euler().y
	var degrees = rad_to_deg(player_rot)
	
	# 2. Normalize degrees to 0-360 (Godot uses -180 to 180)
	# We use fposmod to ensure it's always positive
	var normalized_degrees = fposmod(degrees, 360.0)
	
	# 3. Calculate the shift
	# (normalized_degrees / 360) gives us 0.0 to 1.0
	# Multiplying by width tells us how many pixels to slide
	var lerp_val = normalized_degrees / 360.0
	var target_x = -lerp_val * compass_width
	
	# 4. Apply the position
	# We center it by adding half the screen width
	var screen_center = get_viewport_rect().size.x / 2
	position.x = target_x + screen_center
