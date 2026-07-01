extends Node
class_name SquadManager

# Dictionary mapping squad_id (String) to an Array of Soldier nodes
var squads: Dictionary = {}

func _ready():
	add_to_group("squad_managers")

func register_soldier(soldier: Node3D, squad_id: String):
	if not squads.has(squad_id):
		squads[squad_id] = []
	if not squads[squad_id].has(soldier):
		squads[squad_id].append(soldier)

func unregister_soldier(soldier: Node3D, squad_id: String):
	if squads.has(squad_id):
		squads[squad_id].erase(soldier)

func report_combat(squad_id: String, target: Node3D):
	if not squads.has(squad_id): return
	
	var active_members = []
	for s in squads[squad_id]:
		if is_instance_valid(s) and not s.is_dead:
			active_members.append(s)
			
	if active_members.is_empty(): return
	
	# Determine if we need to assign new roles
	var flanker_exists = false
	for s in active_members:
		if s.current_role == s.Role.FLANKER:
			flanker_exists = true
			break
			
	# Distribute roles
	for s in active_members:
		# Alert any unaware soldiers
		if s.current_state == s.State.IDLE or s.current_state == s.State.PATROL:
			if not flanker_exists and active_members.size() > 1:
				s.assign_role(s.Role.FLANKER, target)
				flanker_exists = true
			else:
				s.assign_role(s.Role.SUPPRESSOR, target)
