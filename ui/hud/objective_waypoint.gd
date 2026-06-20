extends Marker3D
class_name ObjectiveWaypoint

@export var objective_id: String = ""

func _ready():
	add_to_group("objective_waypoints")
