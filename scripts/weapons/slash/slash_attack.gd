# ==============================================================================
# MELEE SLASH ATTACK (Left-Click Attack)
# ==============================================================================
# Rectangular weapon mesh that swings in an arc in front of the player.
# Detects enemies via Area3D and triggers 1-hit kill.
# ==============================================================================
extends Node3D

@export var swing_duration: float = 0.25  # Duration of slash animation (seconds)
@export var damage_radius: float = 2.5     # Reach of slash

var hit_mobs: Array[Node] = []             # Prevent multi-hitting the same mob in 1 slash

func _ready() -> void:
	# 1. Connect Area3D signal for body detection
	var area: Area3D = $Area3D as Area3D
	if area:
		area.body_entered.connect(_on_body_entered)
	
	# 2. Perform smooth arc swing animation using Godot 4 Tween
	var tween: Tween = create_tween()
	# Rotate Y from -60 degrees to +60 degrees
	rotation_degrees.y = -60.0
	tween.tween_property(self, "rotation_degrees:y", 60.0, swing_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Automatically clean up node after swing finishes
	tween.tween_callback(queue_free)


func _on_body_entered(body: Node) -> void:
	# Ignore player or non-enemy objects
	if body == GameManager.get_player() or hit_mobs.has(body):
		return
		
	# Check if the hit body is an enemy with a take_damage method
	if body.has_method("take_damage"):
		hit_mobs.append(body)
		print("[SlashAttack] Hit enemy:", body.name)
		body.take_damage(1)
