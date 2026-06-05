@tool # Allows the text to update in the editor viewport!
extends Button

@export var text_label: String = "BUTTON" :
	set(value):
		text_label = value
		if is_node_ready():
			%ButtonText.text = value

var neon_green: Color = Color("ACE700") # Replace with your exact hex code

func _ready():
	# Apply the text
	%ButtonText.text = text_label
	
	# Set to normal state on load
	_on_mouse_exited()
	
	# We only connect signals if running the game, not in the editor
	if not Engine.is_editor_hint():
		mouse_entered.connect(_on_mouse_entered)
		mouse_exited.connect(_on_mouse_exited)
		
		# Connect focus so it works with Keyboard/Controller navigation!
		focus_entered.connect(_on_mouse_entered)
		focus_exited.connect(_on_mouse_exited)

func _on_mouse_entered():
	# Hover State: Green background, Black text
	%HoverBlock.color = neon_green
	%ButtonText.add_theme_color_override("font_color", Color.BLACK)

func _on_mouse_exited():
	# Normal State: Transparent background, White text
	%HoverBlock.color = Color.TRANSPARENT
	%ButtonText.add_theme_color_override("font_color", Color.WHITE)
