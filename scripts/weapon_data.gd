extends Resource
class_name WeaponData

enum FireMode { SEMI, BURST, AUTO, BEAM, PROJECTILE }
enum AmmoType { RIFLE, PISTOL, SHOTGUN, ENERGY, SNIPER, ROCKET, MELEE }

static func get_default_reserve(type: AmmoType) -> int:
	match type:
		AmmoType.RIFLE:   return 270
		AmmoType.PISTOL:  return 108
		AmmoType.SHOTGUN: return 48
		AmmoType.ENERGY:  return 0 
		AmmoType.SNIPER:  return 20
		AmmoType.ROCKET:  return 4
	return 0

@export_category("Core Setup")
@export var name: String = "Rifle"
@export var damage: float = 20.0
@export var fire_rate: float = 0.1
@export var fire_mode: FireMode = FireMode.SEMI
@export var burst_count: int = 3
@export var burst_delay: float = 0.08
@export var ammo_type: AmmoType = AmmoType.RIFLE
@export var weapon_icon: Texture2D
@export var crosshair: CrosshairData
@export var weapon_mesh: PackedScene
@export var pickup_scale: Vector3 = Vector3(1.0, 1.0, 1.0)

@export_category("Visuals & Audio Layers")
@export var muzzle_flash_scene: PackedScene  # <--- NEW: Unique flash per weapon
@export var fire_sound: AudioStream
@export var fire_tail_sound: AudioStream     # <--- NEW: Reverb/echo tail
@export var empty_click_sound: AudioStream   # <--- NEW: "Click" on empty mag
@export var reload_sound: AudioStream

@export_category("Ammo & Reload")
@export var mag_size: int = 30
@export var reserve_max: int = 90
@export var reload_time: float = 1.5
@export var is_melee: bool = false
@export var uses_battery: bool = false 

@export_category("Projectile Properties")
@export var projectile_scene: PackedScene 
@export var projectile_speed: float = 50.0
@export var max_penetrations: int = 1        # <--- NEW: How many walls/enemies a bullet goes through

@export_category("Recoil Spring (AAA Feel)")
@export var kick_impulse: Vector3 = Vector3(0.08, 0.02, 0.01) # Up, Side, Twist
@export var positional_kick: Vector3 = Vector3(0.0, 0.0, 0.1) # Pushes weapon backward
@export var spring_stiffness: float = 120.0                   # Higher = snaps back faster
@export var spring_damping: float = 12.0                      # Higher = less bouncing

@export_category("Accuracy & Bloom")
@export var base_spread: float = 0.01      
@export var max_bloom: float = 0.08        
@export var bloom_per_shot: float = 0.015  
@export var bloom_recovery_speed: float = 5.0 
@export var ads_spread: float = 0.002      
@export var crouch_multiplier: float = 0.5 
@export var sprint_multiplier: float = 2.5 

@export_category("Overheat Mechanics")
@export var can_overheat: bool = false
@export var heat_per_shot: float = 0.15 
@export var cooling_rate: float = 0.3   
@export var overheat_penalty_time: float = 2.0 

@export_category("Range & Falloff")
@export var effective_range: float = 20.0  
@export var max_range: float = 100.0        
@export var falloff_multiplier: float = 5.0 
@export var pellet_count: int = 1 

@export_category("ADS Settings")
@export var ads_position: Vector3 = Vector3(0.0, -0.2, -0.5) 
@export var ads_rotation: Vector3 = Vector3.ZERO
@export var ads_speed: float = 15.0
