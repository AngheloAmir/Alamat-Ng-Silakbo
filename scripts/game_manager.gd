# ==============================================================================
# GAME MANAGER (Server / State Manager Singleton)
# ==============================================================================
# This script acts as an Autoload (Singleton) in Godot 4.
# It serves as our central "Server" layer:
# 1. Tracks total active mobs in the world.
# 2. Enforces the Mob Cap limit (Max 16 mobs).
# 3. Provides global Signals so UI (HUD) and Spawners remain decoupled.
# 4. Thread-safe execution using deferred calls where necessary.
# ==============================================================================
extends Node

# --- SIGNALS ---
# UI and Spawners connect to these signals to react to game state changes
signal mob_count_changed(current_count: int, max_cap: int)
signal mob_killed(mob_name: String)
signal player_spawned(player: Node3D)
signal respawn_timer_tick(seconds_left: float)

# --- CONFIGURATION & CONSTANTS ---
const MAX_MOBS: int = 16             # Maximum mobs allowed in the open world (Cap = 16)
const RESPAWN_INTERVAL: float = 20.0 # Timer interval for spawning replacement mobs

# --- STATE VARIABLES ---
var active_mobs: Array[Node3D] = []  # List of currently alive enemy nodes
var player_ref: Node3D = null        # Reference to the player node for AI targeting
var time_until_next_spawn: float = RESPAWN_INTERVAL


func _ready() -> void:
	# Called when the node enters the scene tree
	print("[GameManager] Server state initialized. Max Mob Cap:", MAX_MOBS)


func _process(delta: float) -> void:
	# Server tick timer update
	if active_mobs.size() < MAX_MOBS:
		time_until_next_spawn -= delta
		if time_until_next_spawn <= 0.0:
			time_until_next_spawn = RESPAWN_INTERVAL
		# Broadcast timer tick to UI using typed float maxf
		emit_signal("respawn_timer_tick", maxf(0.0, time_until_next_spawn))
	else:
		# Reset timer when cap is reached
		time_until_next_spawn = RESPAWN_INTERVAL
		emit_signal("respawn_timer_tick", RESPAWN_INTERVAL)


# --- PLAYER MANAGEMENT ---
func register_player(player: Node3D) -> void:
	# Registers the active player reference so enemies can chase/target it
	player_ref = player
	emit_signal("player_spawned", player)
	print("[GameManager] Player registered successfully at:", player.global_position)


func get_player() -> Node3D:
	return player_ref


# --- MOB MANAGEMENT ---
func can_spawn_mob() -> bool:
	# Returns true if current mob count is below maximum cap (16)
	return active_mobs.size() < MAX_MOBS


func register_mob(mob: Node3D) -> void:
	# Thread-safe registration of a newly spawned mob
	if not active_mobs.has(mob):
		active_mobs.append(mob)
		print("[GameManager] Registered mob:", mob.name, " | Total Mobs:", active_mobs.size(), "/", MAX_MOBS)
		# Defer signal emission to ensure UI updates safely across threads/frames
		call_deferred("emit_signal", "mob_count_changed", active_mobs.size(), MAX_MOBS)


func unregister_mob(mob: Node3D) -> void:
	# Removes a killed mob from active list
	if active_mobs.has(mob):
		active_mobs.erase(mob)
		print("[GameManager] Unregistered mob:", mob.name, " | Remaining Mobs:", active_mobs.size(), "/", MAX_MOBS)
		emit_signal("mob_killed", mob.name)
		call_deferred("emit_signal", "mob_count_changed", active_mobs.size(), MAX_MOBS)
