extends CanvasLayer

@onready var label = $MarginContainer/VBoxContainer/RichTextLabel
@onready var sublabel = $MarginContainer/VBoxContainer/RichTextLabel2
@onready var display_timer = $DisplayTimer

func _ready():
	# Hide the subtitles when the game starts
	label.text = ""
	visible = false
	
	# Connect the timer so it clears the screen when time runs out
	display_timer.timeout.connect(_on_timer_timeout)

# The magic function any script in your game can call
func show_brief(text: String, s_text: String, duration: float = 3.0):
	visible = true
	
	# Using BBCode to make the speaker's name bold and blue!
	label.text = text
	sublabel.text = s_text
	
	# Start the countdown to hide the text
	display_timer.start(duration)

func _on_timer_timeout():
	visible = false
	label.text = ""
