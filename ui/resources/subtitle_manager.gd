extends CanvasLayer

@onready var label = $MarginContainer/RichTextLabel
@onready var display_timer = $DisplayTimer

func _ready():
	# Hide the subtitles when the game starts
	label.text = ""
	visible = false
	
	# Connect the timer so it clears the screen when time runs out
	display_timer.timeout.connect(_on_timer_timeout)

# The magic function any script in your game can call
func show_subtitle(speaker: String, text: String, duration: float = 3.0):
	visible = true
	
	# Using BBCode to make the speaker's name bold and blue!
	if speaker != "":
		label.text = "[center][b]" + speaker + ": [/b] " + text + "[/center]"
	else:
		label.text = "[center]" + text + "[/center]"
	
	# Start the countdown to hide the text
	display_timer.start(duration)

func _on_timer_timeout():
	visible = false
	label.text = ""
