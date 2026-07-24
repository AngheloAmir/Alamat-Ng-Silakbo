# ==============================================================================
# SEASONS & DAY/NIGHT CYCLE MANAGER (FOG & LIGHTING FIX)
# ==============================================================================
# 1. 4 Seasons (Key T toggle): SPRING, SUMMER, AUTUMN, WINTER.
# 2. Key Y Manual Time Advance: Instantly jumps between Sunrise -> Noon -> Dusk -> Night.
# 3. Smooth 4-Phase Day/Night Cycle (240s full cycle with rotating sun).
# 4. Eliminates white frustum light cone washouts by configuring fog_sky_affect = 0.2.
# 5. Night Render Distance Reduction: Camera far distance smoothly lerps down to 320m.
# ==============================================================================
extends Node

signal season_changed(season_name: String)
signal time_changed(phase_name: String)

enum Season { SPRING, SUMMER, AUTUMN, WINTER }

var current_season: Season = Season.SPRING

# Day/Night Cycle Variables
@export var day_cycle_duration: float = 240.0 # 4 minutes total
var day_time: float = 0.25                     # Range 0.0 (Sunrise) to 1.0

@onready var world_env: WorldEnvironment = get_node_or_null("../WorldEnvironment")
@onready var sun_light: DirectionalLight3D = get_node_or_null("../DirectionalLight3D")
@onready var terrain: Node3D = get_node_or_null("../Terrain")


func _ready() -> void:
	if not world_env:
		world_env = get_node_or_null("../WorldEnvironment")
	call_deferred("_setup_mountain_sky")
	call_deferred("_apply_season", current_season)


func _setup_mountain_sky() -> void:
	if not world_env or not world_env.environment:
		return
	var abs_path: String = ProjectSettings.globalize_path("res://assets/mountain_bg.png")
	if not FileAccess.file_exists(abs_path):
		print("[WeatherManager] mountain_bg.png not found at: ", abs_path)
		return
	var img: Image = Image.new()
	var err: Error = img.load(abs_path)
	if err != OK:
		print("[WeatherManager] Failed to load mountain_bg.png, error: ", err)
		return
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	var pano_mat: PanoramaSkyMaterial = PanoramaSkyMaterial.new()
	pano_mat.panorama = tex
	var sky: Sky = Sky.new()
	sky.sky_material = pano_mat
	world_env.environment.background_mode = Environment.BG_SKY
	world_env.environment.sky = sky
	print("[WeatherManager] Mountain skybox applied successfully!")


func _get_season_tint() -> Color:
	match current_season:
		Season.SPRING: return Color(1.0, 1.0, 1.0)
		Season.SUMMER: return Color(1.0, 0.98, 0.85)
		Season.AUTUMN: return Color(1.0, 0.75, 0.5)
		Season.WINTER: return Color(0.85, 0.92, 1.0)
	return Color(1.0, 1.0, 1.0)


func _unhandled_input(event: InputEvent) -> void:
	# Key 'T' -> Cycle Seasons (SPRING -> SUMMER -> AUTUMN -> WINTER)
	if event.is_action_pressed("cycle_weather"):
		var next_idx: int = (int(current_season) + 1) % Season.size()
		current_season = next_idx as Season
		_apply_season(current_season)

	# Key 'Y' -> Manually Advance Time of Day (Sunrise -> Noon -> Dusk -> Night)
	elif event.is_action_pressed("advance_time"):
		day_time = fmod(day_time + 0.25, 1.0)
		print("[WeatherManager] Time of Day manually advanced to:", get_time_phase_name())


func get_current_season_name() -> String:
	match current_season:
		Season.SPRING: return "SPRING"
		Season.SUMMER: return "SUMMER"
		Season.AUTUMN: return "AUTUMN"
		Season.WINTER: return "WINTER"
	return "SPRING"


func get_time_phase_name() -> String:
	if day_time < 0.25:
		return "SUNRISE"
	elif day_time < 0.50:
		return "NOON"
	elif day_time < 0.75:
		return "DUSK"
	else:
		return "NIGHT"


func _process(delta: float) -> void:
	# Advance Day/Night Cycle smooth time
	day_time += (delta / day_cycle_duration)
	if day_time >= 1.0:
		day_time -= 1.0

	_update_environment_and_sun(delta)


func _update_environment_and_sun(delta: float) -> void:
	if not world_env or not world_env.environment:
		return

	var env: Environment = world_env.environment

	# 1. Calculate Time-of-Day Sky, Sun & Ambient Targets
	var target_sky_top: Color = Color(0.35, 0.65, 0.95)
	var target_horizon: Color = Color(0.68, 0.8, 0.92)
	var target_sun_color: Color = Color(1.0, 0.96, 0.88)
	var target_sun_energy: float = 1.1
	var target_ambient_color: Color = Color(0.65, 0.75, 0.88)
	var target_ambient_energy: float = 1.0
	var target_render_far: float = 2500.0

	if day_time < 0.25:
		# --- SUNRISE (0.0 - 0.25) ---
		var t: float = day_time / 0.25
		target_sky_top = Color(0.3, 0.45, 0.75).lerp(Color(0.35, 0.65, 0.95), t)
		target_horizon = Color(0.95, 0.62, 0.45).lerp(Color(0.68, 0.8, 0.92), t)
		target_sun_color = Color(1.0, 0.65, 0.45).lerp(Color(1.0, 0.96, 0.88), t)
		target_sun_energy = lerpf(0.3, 1.1, t)
		target_ambient_color = Color(0.45, 0.35, 0.35).lerp(Color(0.65, 0.75, 0.88), t)
		target_ambient_energy = lerpf(0.5, 1.0, t)
		target_render_far = 2500.0

	elif day_time < 0.50:
		# --- NOON (0.25 - 0.50) ---
		target_sky_top = Color(0.35, 0.65, 0.95)
		target_horizon = Color(0.68, 0.8, 0.92)
		target_sun_color = Color(1.0, 0.96, 0.88)
		target_sun_energy = 1.1
		target_ambient_color = Color(0.65, 0.75, 0.88)
		target_ambient_energy = 1.0
		target_render_far = 2500.0

	elif day_time < 0.75:
		# --- DUSK (0.50 - 0.75) ---
		var t: float = (day_time - 0.50) / 0.25
		target_sky_top = Color(0.35, 0.65, 0.95).lerp(Color(0.18, 0.12, 0.35), t)
		target_horizon = Color(0.68, 0.8, 0.92).lerp(Color(0.85, 0.42, 0.25), t)
		target_sun_color = Color(1.0, 0.96, 0.88).lerp(Color(1.0, 0.5, 0.3), t)
		target_sun_energy = lerpf(1.1, 0.15, t)
		target_ambient_color = Color(0.65, 0.75, 0.88).lerp(Color(0.35, 0.25, 0.3), t)
		target_ambient_energy = lerpf(1.0, 0.3, t)
		target_render_far = lerpf(2500.0, 2000.0, t)

	else:
		# --- NIGHT (0.75 - 1.00) ---
		target_sky_top = Color(0.02, 0.04, 0.12)
		target_horizon = Color(0.05, 0.08, 0.18)
		target_sun_color = Color(0.12, 0.18, 0.35)
		target_sun_energy = 0.03
		target_ambient_color = Color(0.04, 0.06, 0.14)
		target_ambient_energy = 0.18
		target_render_far = 2000.0

	# 2. Apply Season Tint Modifier
	var season_tint: Color = _get_season_tint()
	target_horizon = target_horizon * season_tint

	# 3. Rotate Sun Directional Light around sky and update sun color & energy
	if sun_light:
		var sun_angle_rad: float = (day_time * TAU) - (PI * 0.5)
		sun_light.rotation.x = sun_angle_rad
		sun_light.light_color = sun_light.light_color.lerp(target_sun_color, delta * 2.0)
		sun_light.light_energy = lerpf(sun_light.light_energy, target_sun_energy, delta * 2.0)

	# 4. Apply Ambient Light in Environment
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = env.ambient_light_color.lerp(target_ambient_color, delta * 2.0)
	env.ambient_light_energy = lerpf(env.ambient_light_energy, target_ambient_energy, delta * 2.0)

	# 5. Apply Sky Colors
	if env.sky and env.sky.sky_material:
		if env.sky.sky_material is ProceduralSkyMaterial:
			var sky_mat: ProceduralSkyMaterial = env.sky.sky_material as ProceduralSkyMaterial
			sky_mat.sky_top_color = sky_mat.sky_top_color.lerp(target_sky_top, delta * 2.0)
			sky_mat.sky_horizon_color = sky_mat.sky_horizon_color.lerp(target_horizon, delta * 2.0)
			sky_mat.ground_horizon_color = sky_mat.ground_horizon_color.lerp(target_horizon, delta * 2.0)
			sky_mat.ground_bottom_color = sky_mat.ground_bottom_color.lerp(target_horizon * 0.3, delta * 2.0)

	# Fog disabled per request
	env.fog_enabled = false
	# env.fog_mode = Environment.FOG_MODE_DEPTH
	# env.fog_sky_affect = 0.2
	# env.fog_light_color = env.fog_light_color.lerp(target_horizon, delta * 2.0)
	# env.fog_depth_begin = 90.0
	# env.fog_depth_end = target_render_far * 0.9



	# 7. Update Camera Render Far Distance for Night Reduction
	var player: Node3D = GameManager.get_player()
	if player and is_instance_valid(player):
		var cam: Camera3D = player.get_node_or_null("CameraRig/Camera3D") as Camera3D
		if cam:
			cam.far = lerpf(cam.far, target_render_far, delta * 1.5)


func _apply_season(season: Season) -> void:
	var season_name: String = get_current_season_name()
	print("[WeatherManager] Season switched to:", season_name)
	_set_terrain_tint(_get_season_tint())
	emit_signal("season_changed", season_name)




func _set_terrain_tint(tint_color: Color) -> void:
	if not terrain:
		return
	var mesh_inst: MeshInstance3D = terrain.get_node_or_null("TerrainMesh") as MeshInstance3D
	if mesh_inst and mesh_inst.material_override is StandardMaterial3D:
		var mat: StandardMaterial3D = mesh_inst.material_override as StandardMaterial3D
		mat.albedo_color = Color(0.22, 0.52, 0.25) * tint_color
