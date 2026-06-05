extends PanelContainer

@onready var objective_text = %ObjectiveText
@onready var checkmark = %Checkmark

func setup_objective(text: String, is_done: bool):
	if is_done:
		# Dim the text and add strikethrough (using Catppuccin Mocha-style hex codes)
		objective_text.text = "[color=#7f849c][s]" + text + "[/s][/color]"
		checkmark.show()
		
		# Optional: You can also dim the background panel here if you want
		# self.modulate.a = 0.5 
	else:
		# Bright text, hide the checkmark
		objective_text.text = "[color=#cdd6f4]" + text + "[/color]"
		checkmark.hide()
