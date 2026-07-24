# ==============================================================================
# MOB SPAWNER (scripts/layers/6mobs/mob_spawner.gd)
# ==============================================================================
# Spawns initial dummy enemies and handles 20s replacement timer checks via Server.
# ==============================================================================
extends Node3D

@export var spawn_radius: float = 16.0
@export var initial_mob_count: int = 8

var static_scene: PackedScene = preload("res://scenes/enemy_static.tscn")
var wander_scene: PackedScene = preload("res://scenes/enemy_wander.tscn")
var chase_scene: PackedScene = preload("res://scenes/enemy_chase.tscn")

@onready var spawn_timer: Timer = $SpawnTimer


func _ready() -> void:
	call_deferred("_spawn_initial_dummies")

	if spawn_timer:
		spawn_timer.wait_time = Server.RESPAWN_INTERVAL
		spawn_timer.timeout.connect(_on_spawn_timer_timeout)
		spawn_timer.start()


func _spawn_initial_dummies() -> void:
	print("[Spawner] Spawning initial ", initial_mob_count, " dummy enemies with random traits...")
	var enemy_types: Array[PackedScene] = [static_scene, wander_scene, chase_scene]

	for i in range(initial_mob_count):
		var chosen_scene: PackedScene = enemy_types[randi() % enemy_types.size()]
		var rand_offset: Vector3 = Vector3(
			randf_range(-spawn_radius, spawn_radius),
			0.0,
			randf_range(-spawn_radius, spawn_radius)
		)
		if rand_offset.length() < 3.0:
			rand_offset = rand_offset.normalized() * 5.0

		var spawn_pos: Vector3 = global_position + rand_offset
		_instantiate_mob(chosen_scene, spawn_pos)


func _on_spawn_timer_timeout() -> void:
	if Server.can_spawn_mob():
		print("[Spawner] 20s Timer Triggered -> Spawning replacement mob...")
		var enemy_types: Array[PackedScene] = [static_scene, wander_scene, chase_scene]
		var chosen_scene: PackedScene = enemy_types[randi() % enemy_types.size()]
		var rand_offset: Vector3 = Vector3(
			randf_range(-spawn_radius, spawn_radius),
			0.0,
			randf_range(-spawn_radius, spawn_radius)
		)
		var spawn_pos: Vector3 = global_position + rand_offset
		_instantiate_mob(chosen_scene, spawn_pos)


func _instantiate_mob(scene: PackedScene, pos: Vector3) -> void:
	var mob_inst: Node3D = scene.instantiate() as Node3D
	get_parent().add_child(mob_inst)
	mob_inst.global_position = pos
