# ==============================================================================
# LAYER 12: BOT DECISION CALCULATIONS LAYER (scripts/layers/12botdecision/bot_decision_manager.gd)
# ==============================================================================
# Layer 12 handles mob AI decision calculations (target tracking, pathing, attack choices)
# off-thread using WorkerThreadPool.
# Performance Optimization: Filters active mob snapshots within 60m radius of player
# before off-thread execution, preventing overhead when mob count reaches 750+.
# ==============================================================================
extends Node

const LAYER_ID: int = 10 # Registers with Server

# Decision tick rate (e.g. every 0.2s for responsive AI without per-frame overhead)
@export var decision_interval: float = 0.2
var time_since_last_decision: float = 0.0


func _ready() -> void:
	Server.register_layer_manager(12, self)
	print("[Layer 12] High-Performance Bot Decision Calculation Layer initialized.")


func _process(delta: float) -> void:
	time_since_last_decision += delta
	if time_since_last_decision >= decision_interval:
		time_since_last_decision = 0.0
		_trigger_decision_cycle()


func _trigger_decision_cycle() -> void:
	var active_mobs: Array[Node3D] = Server.active_mobs
	var player: Node3D = Server.get_player()

	if active_mobs.is_empty() or player == null or not is_instance_valid(player):
		return

	var player_pos: Vector3 = player.global_position
	var mob_snapshots: Array[Dictionary] = []

	# Filter active mobs within 60m active AI simulation radius
	for mob in active_mobs:
		if mob and is_instance_valid(mob):
			var mob_pos: Vector3 = mob.global_position
			if (mob_pos - player_pos).length_squared() <= 3600.0: # 60m ^ 2
				mob_snapshots.append({
					"node": mob,
					"position": mob_pos
				})

	if mob_snapshots.is_empty():
		return

	# Dispatch background math calculations with thread-safe Vector3 snapshots
	WorkerThreadPool.add_task(_calculate_mobs_decisions_task.bind(mob_snapshots, player_pos))


func _calculate_mobs_decisions_task(mob_snapshots: Array[Dictionary], player_pos: Vector3) -> void:
	for snapshot in mob_snapshots:
		var mob: Node3D = snapshot.get("node")
		var mob_pos: Vector3 = snapshot.get("position", Vector3.ZERO)

		if mob == null or not is_instance_valid(mob):
			continue

		var dist_to_player: float = PathfindingUtils.get_flat_distance(mob_pos, player_pos)
		var decision: Dictionary = {}

		if dist_to_player <= 2.5:
			decision = {
				"action": "attack",
				"target_position": player_pos,
				"speed": 0.0
			}
		elif dist_to_player <= 35.0:
			var chase_dir: Vector3 = PathfindingUtils.get_flat_direction(mob_pos, player_pos)
			decision = {
				"action": "chase",
				"target_position": player_pos,
				"direction": chase_dir,
				"speed": 6.5
			}
		else:
			decision = {
				"action": "idle_or_wander",
				"target_position": mob_pos,
				"speed": 2.5
			}

		_push_decision_to_layer_6(mob, decision)


func _push_decision_to_layer_6(mob: Node3D, decision: Dictionary) -> void:
	var layer6: Node = Server.get_layer_manager(6)
	if layer6 and layer6.has_method("receive_mob_action_queue"):
		layer6.call_deferred("receive_mob_action_queue", mob, decision)
