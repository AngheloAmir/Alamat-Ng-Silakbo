# ==============================================================================
# PROJECTILE MATH HELPER (scripts/functions/projectile_math.gd)
# ==============================================================================
# Reusable pure math and physics functions for frame-rate independent
# projectile calculations, weight falloff, time-delta trajectory tracking,
# and Continuous Collision Detection (CCD) raycasting.
# ==============================================================================
class_name ProjectileMath
extends RefCounted

# Standard base gravity value in world space (m/s^2)
const BASE_GRAVITY: float = 15.0


## Calculates projectile velocity at time t given initial velocity, weight, and elapsed time delta.
## Weight scales gravity drop: weight = 100.0 -> standard 15.0 m/s^2 gravity drop.
static func calculate_velocity(initial_velocity: Vector3, weight: float, elapsed_time: float) -> Vector3:
	var gravity_accel: float = BASE_GRAVITY * (weight / 100.0)
	var current_vel: Vector3 = initial_velocity
	current_vel.y -= gravity_accel * elapsed_time
	return current_vel


## Calculates exact position step for time delta dt.
static func calculate_next_position(current_pos: Vector3, velocity: Vector3, delta: float) -> Vector3:
	return current_pos + (velocity * delta)


## Performs continuous collision detection (CCD) raycast sweep between from_pos and to_pos.
## Returns a Dictionary with hit data, or empty Dictionary if no collision occurred.
static func perform_ccd_raycast(
	space_state: PhysicsDirectSpaceState3D,
	from_pos: Vector3,
	to_pos: Vector3,
	collision_mask: int,
	exclude_rids: Array[RID] = []
) -> Dictionary:
	if space_state == null:
		return {}

	var query := PhysicsRayQueryParameters3D.create(from_pos, to_pos)
	query.collision_mask = collision_mask
	query.exclude = exclude_rids

	return space_state.intersect_ray(query)
