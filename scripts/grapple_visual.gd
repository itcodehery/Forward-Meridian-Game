extends Node3D

@onready var rope = $Rope
@onready var hook = $Hook

func update_length(distance: float):
	# 1. Snap the hook to the exact end of the distance
	hook.position.z = -distance
	
	# 2. Stretch and Position the Rope
	# A default Godot CylinderMesh is exactly 2.0 meters long.
	# We scale its local Y-axis (which is now pointing forward) by half the distance.
	rope.scale.y = distance / 2.0
	
	# Move the rope forward by half the distance so it perfectly bridges the gap
	# between the gun (0,0,0) and the hook (-distance).
	rope.position.z = -distance / 2.0
