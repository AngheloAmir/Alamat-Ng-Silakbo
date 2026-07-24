# ==============================================================================
# LAYER 8: NPC LAYER (scripts/layers/8npc/npc_layer.gd)
# ==============================================================================
# Manages non-hostile NPCs, quest givers, and shopkeepers. Collision Layer 8.
# ==============================================================================
extends Node3D

const LAYER_ID: int = 8


func _ready() -> void:
	Server.register_layer_manager(LAYER_ID, self)
	print("[Layer 8] NPC layer initialized.")
