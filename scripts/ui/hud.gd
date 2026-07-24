# ==============================================================================
# HUD & UI CONTROLLER (SEASONS, MINECRAFT HOTBAR & TIME SYSTEM)
# ==============================================================================
# Displays player controls guide, crosshair, mob counter, respawn countdown, FPS,
# Season status (Key T), Time of Day status (Key Y), and Minecraft Hotbar Slots!
# ==============================================================================
extends CanvasLayer

@onready var mob_count_label: Label = $MarginContainer/VBoxContainer/MobCountLabel
@onready var respawn_timer_label: Label = $MarginContainer/VBoxContainer/RespawnTimerLabel
@onready var fps_label: Label = $MarginContainer/VBoxContainer/FPSLabel
@onready var weather_label: Label = $MarginContainer/VBoxContainer/WeatherLabel
@onready var time_label: Label = $MarginContainer/VBoxContainer/TimeLabel

# Hotbar Slot Panels at Bottom Right
@onready var slot_1: PanelContainer = $HotbarPanel/HBoxContainer/Slot1
@onready var slot_2: PanelContainer = $HotbarPanel/HBoxContainer/Slot2
@onready var slot_3: PanelContainer = $HotbarPanel/HBoxContainer/Slot3
@onready var slot_4: PanelContainer = $HotbarPanel/HBoxContainer/Slot4

var fps_update_timer: float = 0.0


func _ready() -> void:
	# Connect to GameManager signals
	GameManager.mob_count_changed.connect(_on_mob_count_changed)
	GameManager.respawn_timer_tick.connect(_on_respawn_timer_tick)
	
	# Connect to WeatherManager signals
	var weather_mgr: Node = get_node_or_null("../WeatherManager")
	if weather_mgr:
		if weather_mgr.has_signal("season_changed"):
			weather_mgr.connect("season_changed", _on_season_changed)
		if weather_mgr.has_method("get_current_season_name"):
			_on_season_changed(weather_mgr.call("get_current_season_name"))

	# Connect to Player weapon_slot_changed signal
	call_deferred("_connect_player_signals")
	
	# Initial UI state update
	_on_mob_count_changed(GameManager.active_mobs.size(), GameManager.MAX_MOBS)
	_highlight_hotbar_slot(0)


func _connect_player_signals() -> void:
	var player: Node3D = GameManager.get_player()
	if player and player.has_signal("weapon_slot_changed"):
		player.connect("weapon_slot_changed", _on_weapon_slot_changed)


func _process(delta: float) -> void:
	fps_update_timer += delta
	if fps_update_timer >= 0.05:
		fps_update_timer = 0.0
		if fps_label:
			var frame_time: float = maxf(delta, 0.00001)
			var current_fps: float = Performance.get_monitor(Performance.TIME_FPS)
			var process_ms: float = frame_time * 1000.0
			
			fps_label.text = "FPS: %.0f (%.1f ms)" % [current_fps, process_ms]
			
			if current_fps >= 55.0:
				fps_label.modulate = Color(0.4, 1.0, 0.4)
			elif current_fps >= 30.0:
				fps_label.modulate = Color(1.0, 0.9, 0.3)
			else:
				fps_label.modulate = Color(1.0, 0.3, 0.3)

	# Update Time-of-Day status label
	var weather_mgr: Node = get_node_or_null("../WeatherManager")
	if weather_mgr and weather_mgr.has_method("get_time_phase_name") and time_label:
		var time_phase: String = weather_mgr.call("get_time_phase_name")
		time_label.text = "Time of Day: %s (Press 'Y' to Advance)" % time_phase


func _on_weapon_slot_changed(slot_idx: int) -> void:
	_highlight_hotbar_slot(slot_idx)


func _highlight_hotbar_slot(active_idx: int) -> void:
	var slots: Array[PanelContainer] = [slot_1, slot_2, slot_3, slot_4]
	for i in range(slots.size()):
		var slot_panel: PanelContainer = slots[i]
		if not slot_panel:
			continue
		if i == active_idx:
			slot_panel.modulate = Color(1.4, 1.2, 0.4) # Bright Gold Active Highlight
			slot_panel.scale = Vector2(1.1, 1.1)
		else:
			slot_panel.modulate = Color(0.7, 0.7, 0.7) # Dim Inactive
			slot_panel.scale = Vector2(1.0, 1.0)


func _on_season_changed(season_name: String) -> void:
	if weather_label:
		weather_label.text = "Season: %s (Press 'T' to Cycle)" % season_name


func _on_mob_count_changed(current_count: int, max_cap: int) -> void:
	if mob_count_label:
		mob_count_label.text = "Active Mobs: %d / %d" % [current_count, max_cap]
		if current_count >= max_cap:
			mob_count_label.modulate = Color(1.0, 0.4, 0.4)
		else:
			mob_count_label.modulate = Color(0.4, 1.0, 0.5)


func _on_respawn_timer_tick(seconds_left: float) -> void:
	if respawn_timer_label:
		if GameManager.active_mobs.size() >= GameManager.MAX_MOBS:
			respawn_timer_label.text = "Respawn Timer: PAUSED (Max Cap Reached)"
			respawn_timer_label.modulate = Color(0.8, 0.8, 0.8)
		else:
			respawn_timer_label.text = "Next Respawn In: %.1fs" % seconds_left
			respawn_timer_label.modulate = Color(1.0, 0.9, 0.3)
