# ==============================================================================
# COLLISION UTILITIES (scripts/functions/collision_utils.gd)
# ==============================================================================
# Layer bitmask definitions and collision utility functions based on the project's
# 13-layer architectural design.
# ==============================================================================
class_name CollisionUtils
extends RefCounted

# Layer indices (1-indexed for Godot collision layers)
enum LayerIndex {
	HERO = 1,          # Layer 0 (Hero / Player)
	GROUND = 2,        # Layer 1 (Ground / Terrain)
	WALL = 3,          # Layer 2 (Wall structures)
	BLOCK = 4,         # Layer 3 (Player-placed blocks / furniture)
	INTERACTABLE = 5,  # Layer 4 (Static interactable objects)
	OTHER_PLAYERS = 6, # Layer 4 (Remote players)
	PICKUPS = 7,       # Layer 5 (Ground drops / items)
	MOBS = 8,          # Layer 6 (Enemy mobs)
	PROJECTILES = 9,   # Layer 7 (Projectiles)
	NPC = 10,          # Layer 8 (Non-hostile NPCs)
	EFFECTS = 11,      # Layer 9 (Visual particle effects)
	ENVIRONMENT = 12,  # Layer 10 (Ambient environment)
	WATER = 13,        # Layer 11 (Water / fluid)
	BOTDECISION = 14,  # Layer 12 (Off-thread AI decision queue)
}


## Returns bitmask for a given single layer index
static func get_layer_bitmask(layer_index: LayerIndex) -> int:
	return 1 << (int(layer_index) - 1)


## Combines multiple layer indices into a single bitmask integer
static func combine_masks(layers: Array[LayerIndex]) -> int:
	var mask: int = 0
	for layer in layers:
		mask |= get_layer_bitmask(layer)
	return mask


## Standard projectile collision mask (collides with Ground, Wall, Block, and Mobs)
static func get_default_projectile_mask() -> int:
	return combine_masks([
		LayerIndex.GROUND,
		LayerIndex.WALL,
		LayerIndex.BLOCK,
		LayerIndex.MOBS
	])
