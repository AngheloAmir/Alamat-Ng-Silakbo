# ==============================================================================
# DAGGER ATTACK (Slot 5 Attack)
# ==============================================================================
# Fast forward thrust / stab attack using Area3D hitbox detection.
# ==============================================================================
extends Area3D

@export var stab_duration: float = 0.2
var hit_mobs: Array[Node] = []

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	var tween: Tween = create_tween()
	position = Vector3(0.0, 0.0, -0.3)
	tween.tween_property(self, "position:z", -1.8, stab_duration * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:z", -0.3, stab_duration * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)


func _on_body_entered(body: Node) -> void:
	if body == GameManager.get_player() or hit_mobs.has(body):
		return
	if body.has_method("take_damage"):
		hit_mobs.append(body)
		print("[DaggerAttack] Stabbed enemy:", body.name)
		body.take_damage(1)
