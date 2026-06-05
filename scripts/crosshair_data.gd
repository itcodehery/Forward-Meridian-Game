# crosshair_data.gd
extends Resource
class_name CrosshairData

@export_group("Textures")
@export var tex_normal: Texture2D
@export var tex_active: Texture2D
@export var tex_ads: Texture2D
@export var tex_ads_active: Texture2D

@export_group("Scaling")
@export var base_scale: float = 1.0 
@export var sprint_scale_mult: float = 1.6
@export var crouch_scale_mult: float = 0.7
@export var shoot_scale_bump: float = 0.4 # Momentary expansion when firing

@export_group("Animation")
@export var lerp_speed: float = 15.0
@export var recovery_speed: float = 10.0
