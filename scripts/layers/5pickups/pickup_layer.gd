# ==============================================================================
# LAYER 5: PICKUPS LAYER (scripts/layers/5pickups/pickup_layer.gd)
# ==============================================================================
# Manages ground item drops, pickups, and loot items. Collision Layer 5.
# ==============================================================================
extends Node3D

const LAYER_ID: int = 5


func _ready() -> void:
	Server.register_layer_manager(LAYER_ID, self)
	print("[Layer 5] Pickups layer initialized.")
