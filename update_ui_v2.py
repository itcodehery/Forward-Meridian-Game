import sys

file_path = "ui/hud/user_interface.tscn"
with open(file_path, "r") as f:
    lines = f.readlines()

new_lines = []
inserted_ext = False
inserted_sub = False
inserted_nodes = False

for i, line in enumerate(lines):
    # Insert ExtResource after the last ExtResource
    if line.startswith('[sub_resource') and not inserted_ext:
        new_lines.append('[ext_resource type="Shader" path="res://ui/hud/vignette.gdshader" id="98_vig"]\n')
        new_lines.append('[ext_resource type="Texture2D" path="res://ui/hud/waypoint_icon.png" id="99_waypoint"]\n\n')
        inserted_ext = True
        
    # Insert SubResource after the last ExtResource but before Nodes
    if line.startswith('[node name="UserInterface"') and not inserted_sub:
        if not inserted_ext:
            new_lines.insert(0, '[ext_resource type="Shader" path="res://ui/hud/vignette.gdshader" id="98_vig"]\n')
            new_lines.insert(1, '[ext_resource type="Texture2D" path="res://ui/hud/waypoint_icon.png" id="99_waypoint"]\n\n')
            inserted_ext = True
        new_lines.append('[sub_resource type="ShaderMaterial" id="ShaderMaterial_vig"]\n')
        new_lines.append('shader = ExtResource("98_vig")\n')
        new_lines.append('shader_parameter/vignette_color = Color(0.8, 0.0, 0.0, 1.0)\n')
        new_lines.append('shader_parameter/intensity = 1.0\n\n')
        inserted_sub = True

    new_lines.append(line)
    
    # Insert Nodes right inside [node name="HUD" type="Control" parent="."]
    if line.startswith('[node name="HUD" type="Control"'):
        # We need to skip lines that belong to this node definition until the next blank or node
        pass
        
# To insert nodes safely, we will find the HUD node definition end
for i in range(len(new_lines)):
    if new_lines[i].startswith('[node name="HUD" type="Control"'):
        # insert after its properties
        j = i + 1
        while j < len(new_lines) and not new_lines[j].startswith('['):
            j += 1
        
        nodes = """[node name="HealthVignette" type="ColorRect" parent="HUD"]
unique_name_in_owner = true
material = SubResource("ShaderMaterial_vig")
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2

[node name="WaypointIcon" type="TextureRect" parent="HUD"]
unique_name_in_owner = true
visible = false
layout_mode = 0
offset_right = 64.0
offset_bottom = 64.0
pivot_offset = Vector2(32, 32)
texture = ExtResource("99_waypoint")
expand_mode = 1

"""
        new_lines.insert(j, nodes)
        break

with open(file_path, "w") as f:
    f.writelines(new_lines)

print("Updated user_interface.tscn successfully")
