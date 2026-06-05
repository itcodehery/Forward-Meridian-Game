# item.gd
extends Resource
class_name Item

enum ItemType { HEALTH, AMMO, KEY, SPECIAL } # Optional: helps categorize logic

@export var item_id: String
@export var item_name: String
@export var item_description: String
@export var icon: Texture2D
@export var max_stack: int = 1
@export var is_consumable: bool = false
@export var type: ItemType = ItemType.HEALTH # Default to health

# NEW: The "Power" of the item
@export var value: float = 25.0
