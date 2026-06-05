extends RigidBody3D

@export var explosion_vfx: PackedScene
@onready var blast_radius = $BlastRadius

func _on_fuse_timer_timeout():
	# 1. Spawn the visual explosion
	if explosion_vfx:
		var vfx = explosion_vfx.instantiate()
		get_tree().root.add_child(vfx)
		vfx.global_position = global_position
		
	# 2. Damage everything in the blast radius
	var targets = blast_radius.get_overlapping_bodies()
	for target in targets:
		if target.has_method("take_damage"):
			# Optional: Calculate distance here so closer targets take more damage!
			target.take_damage(180.0)
			
	# 3. Destroy the grenade object
	queue_free()
