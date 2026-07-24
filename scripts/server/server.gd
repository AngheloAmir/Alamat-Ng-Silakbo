# ==============================================================================
# CENTRAL SERVER HUB (scripts/server/server.gd)
# ==============================================================================
# Central Server Autoload Singleton.
# Acts as the central hub for:
# 1. Spawning projectiles across layers (`spawn_projectile_from_player`).
# 2. Triggering particle effects (`spawn_effect`).
# 3. Global state tracking (player registration, mob cap, active blocks, furniture, interactables).
# 4. Global World Reset Endpoint (`clear_all_entities`).
# 5. Routing tasks to numerical layer sub-managers (Layer 0 to Layer 12).
# ==============================================================================
extends Node

# --- SIGNALS ---
signal mob_count_changed(current_count: int, max_cap: int)
signal block_count_changed(count: int)
signal furniture_count_changed(count: int)
signal interactable_count_changed(count: int)

signal mob_killed(mob_name: String)
signal player_spawned(player: Node3D)
signal respawn_timer_tick(seconds_left: float)
signal projectile_spawn_requested(data: Dictionary)
signal effect_spawn_requested(data: Dictionary)

# --- CONSTANTS ---
const MAX_MOBS: int = 16
const RESPAWN_INTERVAL: float = 20.0

# --- STATE ---
var active_mobs: Array[Node3D] = []
var active_blocks: Array[Node3D] = []
var active_furniture: Array[Node3D] = []
var active_interactables: Array[Node3D] = []

var player_ref: Node3D = null
var time_until_next_spawn: float = RESPAWN_INTERVAL

# Layer managers registry dictionary mapping layer ID -> manager Node
var layer_managers: Dictionary = {}


func _ready() -> void:
	print("[Server Hub] Central Server architecture initialized. Max Mob Cap:", MAX_MOBS)


func _process(delta: float) -> void:
	# Server tick for mob respawn timer
	if active_mobs.size() < MAX_MOBS:
		time_until_next_spawn -= delta
		if time_until_next_spawn <= 0.0:
			time_until_next_spawn = RESPAWN_INTERVAL
		respawn_timer_tick.emit(maxf(0.0, time_until_next_spawn))
	else:
		time_until_next_spawn = RESPAWN_INTERVAL
		respawn_timer_tick.emit(RESPAWN_INTERVAL)


# --- PLAYER MANAGEMENT ---
func register_player(player: Node3D) -> void:
	player_ref = player
	player_spawned.emit(player)
	print("[Server Hub] Player registered at:", player.global_position)


func get_player() -> Node3D:
	return player_ref


# --- MOB MANAGEMENT ---
func can_spawn_mob() -> bool:
	return active_mobs.size() < MAX_MOBS


func register_mob(mob: Node3D) -> void:
	if not active_mobs.has(mob):
		active_mobs.append(mob)
		print("[Server Hub] Mob registered:", mob.name, " (", active_mobs.size(), "/", MAX_MOBS, ")")
		mob_count_changed.emit(active_mobs.size(), MAX_MOBS)


func unregister_mob(mob: Node3D) -> void:
	if active_mobs.has(mob):
		active_mobs.erase(mob)
		print("[Server Hub] Mob unregistered:", mob.name, " (", active_mobs.size(), "/", MAX_MOBS, ")")
		mob_killed.emit(mob.name)
		mob_count_changed.emit(active_mobs.size(), MAX_MOBS)


# --- BLOCK, FURNITURE & INTERACTABLE ENTITY TRACKING ---
func register_block(block: Node3D) -> void:
	if not active_blocks.has(block):
		active_blocks.append(block)
		block_count_changed.emit(active_blocks.size())


func unregister_block(block: Node3D) -> void:
	if active_blocks.has(block):
		active_blocks.erase(block)
		block_count_changed.emit(active_blocks.size())


func register_furniture(furniture: Node3D) -> void:
	if not active_furniture.has(furniture):
		active_furniture.append(furniture)
		furniture_count_changed.emit(active_furniture.size())


func unregister_furniture(furniture: Node3D) -> void:
	if active_furniture.has(furniture):
		active_furniture.erase(furniture)
		furniture_count_changed.emit(active_furniture.size())


func register_interactable(cube: Node3D) -> void:
	if not active_interactables.has(cube):
		active_interactables.append(cube)
		interactable_count_changed.emit(active_interactables.size())


func unregister_interactable(cube: Node3D) -> void:
	if active_interactables.has(cube):
		active_interactables.erase(cube)
		interactable_count_changed.emit(active_interactables.size())


## Global Key M Action: Instantly removes all spawned mobs, building blocks, ground furniture, and interactables
func clear_all_entities() -> void:
	print("[Server Hub] Clearing all world entities, mobs, blocks, furniture, and interactables via Key 'M'...")

	# Clear Mobs
	for mob in active_mobs.duplicate():
		if mob and is_instance_valid(mob):
			mob.queue_free()
	active_mobs.clear()
	mob_count_changed.emit(0, MAX_MOBS)

	# Clear Building Blocks
	for block in active_blocks.duplicate():
		if block and is_instance_valid(block):
			block.queue_free()
	active_blocks.clear()
	block_count_changed.emit(0)

	# Clear Ground Furniture
	for furniture in active_furniture.duplicate():
		if furniture and is_instance_valid(furniture):
			furniture.queue_free()
	active_furniture.clear()
	furniture_count_changed.emit(0)

	# Clear Interactables
	for cube in active_interactables.duplicate():
		if cube and is_instance_valid(cube):
			cube.queue_free()
	active_interactables.clear()
	interactable_count_changed.emit(0)

	print("[Server Hub] World reset complete. All entity counters reset to 0.")


# --- LAYER REGISTRATION ---
func register_layer_manager(layer_id: int, manager: Node) -> void:
	layer_managers[layer_id] = manager
	print("[Server Hub] Registered Layer Manager for Layer", layer_id, ":", manager.name)


func get_layer_manager(layer_id: int) -> Node:
	return layer_managers.get(layer_id, null)


# --- PROJECTILE & EFFECT HUB ENDPOINTS ---
func spawn_projectile_from_player(
	projectile_type: String,
	damage: float,
	velocity_speed: float,
	weight: float,
	origin: Vector3,
	direction: Vector3
) -> void:
	var payload := {
		"type": projectile_type,
		"damage": damage,
		"velocity_speed": velocity_speed,
		"weight": weight,
		"origin": origin,
		"direction": direction.normalized(),
		"timestamp": Time.get_ticks_msec()
	}

	projectile_spawn_requested.emit(payload)

	var layer7: Node = get_layer_manager(7)
	if layer7 and layer7.has_method("spawn_projectile"):
		layer7.call("spawn_projectile", payload)


func spawn_effect(effect_type: String, position: Vector3, normal: Vector3 = Vector3.UP) -> void:
	var payload := {
		"type": effect_type,
		"position": position,
		"normal": normal,
		"timestamp": Time.get_ticks_msec()
	}

	effect_spawn_requested.emit(payload)

	var layer9: Node = get_layer_manager(9)
	if layer9 and layer9.has_method("spawn_effect"):
		layer9.call("spawn_effect", payload)
