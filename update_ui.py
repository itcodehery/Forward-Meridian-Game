import sys

file_path = "ui/hud/user_interface.tscn"
with open(file_path, "r") as f:
    lines = f.readlines()

new_lines = []
in_equipment_row = False
added_double_jump = False

i = 0
while i < len(lines):
    line = lines[i]
    new_lines.append(line)
    
    # We are looking for the end of GrappleBar section (before GrenadeBar starts)
    if line.startswith('[node name="GrenadeBar"'):
        # Inject our DoubleJumpBar right before GrenadeBar
        injection = """[node name="DoubleJumpBar" type="TextureProgressBar" parent="HUD/EquipmentRow/MarginContainer/VBoxContainer/EquipmentRow" unique_id=888888888]
unique_name_in_owner = true
layout_mode = 2
fill_mode = 3
texture_under = ExtResource("12_fcotm")
texture_progress = ExtResource("13_jsps8")

[node name="MarginContainer" type="MarginContainer" parent="HUD/EquipmentRow/MarginContainer/VBoxContainer/EquipmentRow/DoubleJumpBar" unique_id=888888889]
layout_mode = 1
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -20.0
offset_top = -20.0
offset_right = 20.0
offset_bottom = 20.0
grow_horizontal = 2
grow_vertical = 2
theme_override_constants/margin_left = 7
theme_override_constants/margin_top = 7
theme_override_constants/margin_right = 7
theme_override_constants/margin_bottom = 7

[node name="TextureRect" type="TextureRect" parent="HUD/EquipmentRow/MarginContainer/VBoxContainer/EquipmentRow/DoubleJumpBar/MarginContainer" unique_id=888888890]
layout_mode = 2
texture = ExtResource("15_eq3cv")
expand_mode = 1

"""
        # Note: ExtResource("15_eq3cv") is the 'Q' key icon, wait, I want a different icon.
        # "15_wnll5" is eq_2_icon.png, let's use that.
        injection = injection.replace('ExtResource("15_eq3cv")', 'ExtResource("15_wnll5")')
        new_lines.insert(-1, injection)
        
    i += 1

with open(file_path, "w") as f:
    f.writelines(new_lines)
print("Updated user_interface.tscn")
