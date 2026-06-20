import sys

file_path = "ui/hud/user_interface.tscn"
with open(file_path, "r") as f:
    lines = f.readlines()

new_lines = []

for i, line in enumerate(lines):
    new_lines.append(line)
    if line.startswith('[node name="WaypointIcon" type="TextureRect" parent="HUD"]'):
        # Find where this node's properties end and insert the child node
        pass

for i in range(len(new_lines)):
    if new_lines[i].startswith('[node name="WaypointIcon" type="TextureRect" parent="HUD"]'):
        j = i + 1
        while j < len(new_lines) and not new_lines[j].startswith('['):
            j += 1
            
        label_node = """[node name="WaypointDistanceLabel" type="Label" parent="HUD/WaypointIcon"]
unique_name_in_owner = true
layout_mode = 1
anchors_preset = 7
anchor_left = 0.5
anchor_top = 1.0
anchor_right = 0.5
anchor_bottom = 1.0
offset_left = -32.0
offset_top = 0.0
offset_right = 32.0
offset_bottom = 23.0
grow_horizontal = 2
grow_vertical = 0
theme_override_colors/font_color = Color(1, 1, 1, 1)
theme_override_colors/font_outline_color = Color(0, 0, 0, 1)
theme_override_constants/outline_size = 4
theme_override_font_sizes/font_size = 14
text = "100m"
horizontal_alignment = 1

"""
        new_lines.insert(j, label_node)
        break

with open(file_path, "w") as f:
    f.writelines(new_lines)

print("Updated user_interface.tscn successfully")
