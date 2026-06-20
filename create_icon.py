from PIL import Image, ImageDraw

img = Image.new('RGBA', (64, 64), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)
points = [(32, 4), (60, 32), (32, 60), (4, 32)]
draw.polygon(points, fill=(255, 200, 0, 150), outline=(255, 255, 255, 255), width=3)
img.save("ui/hud/waypoint_icon.png")
print("waypoint_icon.png created!")
