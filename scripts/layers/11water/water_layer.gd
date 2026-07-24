# ==============================================================================
# LAYER 11: WATER & FLUID PHYSICS LAYER (scripts/layers/11water/water_layer.gd)
# ==============================================================================
# Calculates water physics, buoyancy, and fluid dynamics off-thread.
# Collision Layer 11.
# ==============================================================================
extends Node3D

const LAYER_ID: int = 11


func _ready() -> void:
	Server.register_layer_manager(LAYER_ID, self)
	print("[Layer 11] Water physics layer initialized.")
