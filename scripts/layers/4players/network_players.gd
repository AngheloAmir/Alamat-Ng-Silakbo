# ==============================================================================
# LAYER 4 (PLAYERS): OTHER NETWORK PLAYERS LAYER (scripts/layers/4players/network_players.gd)
# ==============================================================================
# Manages remote player entities in a multiplayer/MMORPG scenario.
# ==============================================================================
extends Node3D

var remote_players: Dictionary = {}


func _ready() -> void:
	print("[Layer 4 - Players] Network Players layer initialized.")
