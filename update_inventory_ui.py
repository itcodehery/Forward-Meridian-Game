import sys

file_path = "ui/hud/user_interface.tscn"
with open(file_path, "r") as f:
    lines = f.readlines()

new_lines = []
in_inventory_node = False
in_grid_node = False
in_slot = False

for line in lines:
    if line.startswith('[node name="Inventory" type="PanelContainer"'):
        in_inventory_node = True
        new_lines.append(line)
        continue
    
    if in_inventory_node and line.startswith('['):
        in_inventory_node = False
        
    if in_inventory_node:
        # Remove old layout properties to inject new ones
        if line.strip().startswith('layout_mode') or line.strip().startswith('anchors_preset') or line.strip().startswith('anchor_') or line.strip().startswith('offset_') or line.strip().startswith('grow_'):
            continue
        
        # Once we reach an empty line or something else, we insert our properties
        if line.strip() == "":
            new_lines.append('layout_mode = 1\n')
            new_lines.append('anchors_preset = 1\n')
            new_lines.append('anchor_left = 1.0\n')
            new_lines.append('anchor_right = 1.0\n')
            new_lines.append('offset_left = -250.0\n')
            new_lines.append('offset_top = 20.0\n')
            new_lines.append('offset_right = -20.0\n')
            new_lines.append('offset_bottom = 100.0\n')
            new_lines.append('grow_horizontal = 0\n')
            new_lines.append('grow_vertical = 1\n')
            new_lines.append(line)
            continue

    if line.startswith('[node name="GridContainer"'):
        in_grid_node = True
        new_lines.append(line)
        continue
        
    if in_grid_node and line.startswith('['):
        in_grid_node = False
        
    if in_grid_node:
        if line.strip().startswith('columns'):
            continue
        if line.strip() == "":
            new_lines.append('columns = 8\n') # Make it horizontal and compressed! Or 1 for vertical. Let's do 8 horizontal.
            new_lines.append(line)
            continue
            
    # Shrink the slots from 60,60 to 40,40
    if "custom_minimum_size = Vector2(60, 60)" in line:
        new_lines.append(line.replace("60, 60", "40, 40"))
        continue

    new_lines.append(line)

with open(file_path, "w") as f:
    f.writelines(new_lines)

print("Inventory UI repositioned and compressed!")
