# ==============================================================================
# CLIENT CONTEXT (scripts/client/context/client_context.gd)
# ==============================================================================
# Local player state container & HUD context data.
# ==============================================================================
class_name ClientContext
extends RefCounted

var local_player_id: int = 1
var is_fps_aim: bool = false
var active_weapon_slot: int = 0
