extends Node3D

func _ready():
	# Start the smoke puff
	$GPUParticles3D.emitting = true
	
	# Wait 5 seconds, then delete the hole and smoke to save memory
	await get_tree().create_timer(5.0).timeout
	queue_free()
