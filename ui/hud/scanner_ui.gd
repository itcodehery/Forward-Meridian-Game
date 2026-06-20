extends Panel

@onready var icon: TextureRect = %Icon
@onready var title: Label = %Title
@onready var description: Label = %Description
@onready var details: Label = %Details
@onready var separator: HSeparator = %HSeparator

@onready var primary_icon: TextureRect = %PrimaryIcon
@onready var primary_label: Label = %PrimaryLabel
@onready var primary_desc: Label = %PrimaryDesc

@onready var secondary_icon: TextureRect = %SecondaryIcon
@onready var secondary_label: Label = %SecondaryLabel
@onready var secondary_desc: Label = %SecondaryDesc

@onready var melee_icon: TextureRect = %MeleeIcon
@onready var melee_label: Label = %MeleeLabel

func _process(delta):
	if not visible:
		return
	
	var player = get_tree().get_first_node_in_group("players")
	if player:
		var w_handler = player.get_node_or_null("Camera3D/CanvasLayer/SubViewportContainer/SubViewport/ViewModelCamera/WeaponHandler")
		if w_handler:
			_update_slot(w_handler.slot_1_data, primary_icon, primary_label, "None", primary_desc)
			_update_slot(w_handler.slot_2_data, secondary_icon, secondary_label, "None", secondary_desc)
			_update_slot(w_handler.melee_data, melee_icon, melee_label, "Combat Knife")

func _update_slot(w_data, icon_rect, label, default_name, desc_label = null):
	if w_data:
		icon_rect.texture = w_data.weapon_icon
		label.text = w_data.name
		icon_rect.show()
		if desc_label:
			desc_label.text = w_data.lore_description
			desc_label.show()
	else:
		icon_rect.texture = null
		label.text = default_name
		icon_rect.hide()
		if desc_label:
			desc_label.hide()

func set_lore(data: Dictionary):
	if data.is_empty():
		title.text = "SCANNING..."
		description.text = "NO DATA DETECTED"
		details.text = ""
		details.hide()
		icon.texture = null
		icon.hide()
		separator.hide()
		var style = get_theme_stylebox("panel") as StyleBoxFlat
		if style: style.border_color = Color(0.5, 0.5, 0.5, 0.5)
		return
		
	var style = get_theme_stylebox("panel") as StyleBoxFlat
	if style: style.border_color = Color(0.438, 0.844, 0.0, 0.9)

	# Set Title
	title.text = data.get("title", "UNKNOWN TARGET")
	
	# Set Icon
	var tex = data.get("icon")
	if tex:
		icon.texture = tex
		icon.show()
	else:
		icon.hide()
		
	# Set Description
	description.text = data.get("description", "")
	
	# Set Details
	var det = data.get("details", "")
	if det != "":
		details.text = det
		details.show()
		separator.show()
	else:
		details.hide()
		separator.hide()
