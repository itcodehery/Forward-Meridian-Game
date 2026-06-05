extends StaticBody3D
class_name ArmorPickup

@export var armor_amount: float = 100.0
@export var prompt_text: String = "Pick up Armor"

func get_prompt() -> String:
	return prompt_text

func collect(player: CharacterBody3D) -> void:
	player.add_armor(armor_amount)
	queue_free()
