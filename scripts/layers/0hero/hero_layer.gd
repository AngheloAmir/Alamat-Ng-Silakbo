# ==============================================================================
# LAYER 0: HERO & MAIN THREAD LAYER (scripts/layers/0hero/hero_layer.gd)
# ==============================================================================
# Layer 0 handles main thread context for local player character and primary UI.
# ==============================================================================
extends Node

const LAYER_ID: int = 0


func _ready() -> void:
	Server.register_layer_manager(LAYER_ID, self)
	print("[Layer 0] Hero & UI layer initialized on main thread.")
