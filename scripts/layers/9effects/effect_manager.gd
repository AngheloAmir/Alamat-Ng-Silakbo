# ==============================================================================
# LAYER 9: VISUAL EFFECTS LAYER (scripts/layers/9effects/effect_manager.gd)
# ==============================================================================
# Layer 9 effect processing loop. Receives effect spawn requests from Server hub
# and generates particles/sparks/explosions off the main gameplay loop.
# ==============================================================================
extends Node3D

const LAYER_ID: int = 9


func _ready() -> void:
	Server.register_layer_manager(LAYER_ID, self)
	print("[Layer 9] Visual Effects processing layer initialized.")


func spawn_effect(data: Dictionary) -> void:
	var effect_type: String = data.get("type", "sparks")
	var pos: Vector3 = data.get("position", Vector3.ZERO)

	match effect_type:
		"block_explosion":
			ExplosionEffect.create_block_debris_explosion(self, pos)
		"explosion":
			ExplosionEffect.create_explosion(self, pos)
		_: # "sparks" default
			SparksEffect.create_spark_burst(self, pos)


## API: Spawn 50 Block Debris Explosions near position (Key B)
func spawn_block_explosion_batch(count: int, origin: Vector3) -> void:
	print("[Layer 9] Spawning batch of ", count, " block debris explosions via Key 'B'...")
	for i in range(count):
		var offset := Vector3(
			randf_range(-22.0, 22.0),
			randf_range(0.2, 3.0),
			randf_range(-22.0, 22.0)
		)
		ExplosionEffect.create_block_debris_explosion(self, origin + offset)
