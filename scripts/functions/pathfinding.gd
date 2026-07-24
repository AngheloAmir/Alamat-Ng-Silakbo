# ==============================================================================
# PATHFINDING HELPER (scripts/functions/pathfinding.gd)
# ==============================================================================
# Reusable pathfinding calculations, distance utilities, and waypoint math
# for mob AI decision layer (Layer 12) and mob movement (Layer 6).
# ==============================================================================
class_name PathfindingUtils
extends RefCounted

## Calculates direction vector towards target position ignoring vertical height (XZ plane)
static func get_flat_direction(from_pos: Vector3, to_pos: Vector3) -> Vector3:
	var diff: Vector3 = to_pos - from_pos
	diff.y = 0.0
	return diff.normalized()


## Calculates 2D distance on XZ plane between two 3D points
static func get_flat_distance(from_pos: Vector3, to_pos: Vector3) -> float:
	var diff: Vector3 = to_pos - from_pos
	diff.y = 0.0
	return diff.length()


## Generates a random wander target point within max_radius of origin
static func get_random_wander_point(origin: Vector3, min_radius: float, max_radius: float) -> Vector3:
	var angle: float = randf() * TAU
	var dist: float = randf_range(min_radius, max_radius)
	var offset := Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
	return origin + offset
