extends SceneTree
func _init():
    var light = OmniLight3D.new()
    for prop in light.get_property_list():
        if "cull" in prop.name or "mask" in prop.name or "layer" in prop.name:
            print(prop.name)
    quit()
