# ==============================================================================
# LAYER 10: ENVIRONMENT & WEATHER MANAGER (scripts/layers/10environment/weather_manager.gd)
# ==============================================================================
# Layer 10 Environment processing:
# 1. GTA San Andreas / GTA 3 Open-World Depth Fog System (35m - 180m).
# 2. Camera Far Clip Plane Culling (200m max render bubble).
# 3. 4 Seasons (SPRING, SUMMER, AUTUMN, WINTER) with snow & autumn particles.
# 4. Smooth 4-Phase Day/Night Cycle.
# ==============================================================================
extends Node

const LAYER_ID: int = 10

signal season_changed(season_name: String)
signal time_changed(phase_name: String)

enum Season { SPRING, SUMMER, AUTUMN, WINTER }

var current_season: Season = Season.SPRING

@export var day_cycle_duration: float = 240.0
var day_time: float = 0.25
var last_time_phase: String = ""

@onready var world_env: WorldEnvironment = get_node_or_null("../WorldEnvironment")
@onready var sun_light: DirectionalLight3D = get_node_or_null("../DirectionalLight3D")
@onready var terrain: Node3D = get_node_or_null("../Terrain")

var weather_particles: GPUParticles3D = null


func _ready() -> void:
	Server.register_layer_manager(LAYER_ID, self)
	if not world_env:
		world_env = get_node_or_null("../WorldEnvironment")
	call_deferred("_setup_mountain_sky")
	call_deferred("_setup_particles")
	call_deferred("_apply_season", current_season)
	print("[Layer 10] GTA-Style Open World Fog & Environment layer initialized.")


func _setup_particles() -> void:
	weather_particles = GPUParticles3D.new()
	weather_particles.name = "SeasonWeatherParticles"
	weather_particles.emitting = false
	weather_particles.amount = 2200
	weather_particles.lifetime = 8.0
	weather_particles.visibility_aabb = AABB(Vector3(-150, -30, -150), Vector3(300, 60, 300))

	var proc_mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	proc_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	proc_mat.emission_box_extents = Vector3(140.0, 1.0, 140.0)
	proc_mat.direction = Vector3(0.2, -1.0, 0.1)
	proc_mat.spread = 15.0
	proc_mat.initial_velocity_min = 3.0
	proc_mat.initial_velocity_max = 6.5
	proc_mat.gravity = Vector3(0.0, -2.5, 0.0)
	proc_mat.scale_min = 0.8
	proc_mat.scale_max = 1.6
	proc_mat.angle_min = -180.0
	proc_mat.angle_max = 180.0
	proc_mat.angular_velocity_min = -60.0
	proc_mat.angular_velocity_max = 60.0
	weather_particles.process_material = proc_mat

	var quad_mesh: QuadMesh = QuadMesh.new()
	quad_mesh.size = Vector2(0.22, 0.22)
	weather_particles.draw_pass_1 = quad_mesh

	add_child(weather_particles)


func _setup_mountain_sky() -> void:
	if not world_env or not world_env.environment:
		return
	var abs_path: String = ProjectSettings.globalize_path("res://assets/mountain_bg.png")
	if not FileAccess.file_exists(abs_path):
		return
	var img: Image = Image.new()
	var err: Error = img.load(abs_path)
	if err != OK:
		return
	var tex: ImageTexture = ImageTexture.create_from_image(img)

	var sky_shader: Shader = Shader.new()
	sky_shader.code = """
	shader_type sky;
	uniform sampler2D panorama_tex : filter_linear, repeat_enable;
	uniform vec4 sky_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
	uniform float energy : hint_range(0.0, 10.0) = 1.0;
	void sky() {
		vec3 base_color = texture(panorama_tex, SKY_COORDS).rgb;
		COLOR = base_color * sky_tint.rgb * energy;
	}
	"""

	var shader_mat: ShaderMaterial = ShaderMaterial.new()
	shader_mat.shader = sky_shader
	shader_mat.set_shader_parameter("panorama_tex", tex)
	shader_mat.set_shader_parameter("sky_tint", Color(1.0, 1.0, 1.0, 1.0))
	shader_mat.set_shader_parameter("energy", 1.0)

	var sky: Sky = Sky.new()
	sky.sky_material = shader_mat
	world_env.environment.background_mode = Environment.BG_SKY
	world_env.environment.sky = sky


func _get_season_tint() -> Color:
	match current_season:
		Season.SPRING: return Color(1.0, 1.0, 1.0)
		Season.SUMMER: return Color(1.0, 0.98, 0.85)
		Season.AUTUMN: return Color(1.0, 0.75, 0.5)
		Season.WINTER: return Color(0.85, 0.92, 1.0)
	return Color(1.0, 1.0, 1.0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("cycle_weather"):
		var next_idx: int = (int(current_season) + 1) % Season.size()
		current_season = next_idx as Season
		_apply_season(current_season)
	elif event.is_action_pressed("advance_time"):
		day_time = fmod(day_time + 0.25, 1.0)


func get_current_season_name() -> String:
	match current_season:
		Season.SPRING: return "SPRING"
		Season.SUMMER: return "SUMMER"
		Season.AUTUMN: return "AUTUMN"
		Season.WINTER: return "WINTER"
	return "SPRING"


func get_time_phase_name() -> String:
	if day_time < 0.25: return "SUNRISE"
	elif day_time < 0.50: return "NOON"
	elif day_time < 0.75: return "DUSK"
	else: return "NIGHT"


func _process(delta: float) -> void:
	day_time += (delta / day_cycle_duration)
	if day_time >= 1.0:
		day_time -= 1.0

	var curr_phase: String = get_time_phase_name()
	if curr_phase != last_time_phase:
		last_time_phase = curr_phase
		time_changed.emit(curr_phase)

	var player: Node3D = Server.get_player()
	if player and is_instance_valid(player) and weather_particles:
		weather_particles.global_position = player.global_position + Vector3(0.0, 15.0, 0.0)

	_update_environment_and_sun(delta)


func _update_environment_and_sun(delta: float) -> void:
	if not world_env or not world_env.environment:
		return

	var env: Environment = world_env.environment
	var target_horizon: Color = Color(0.68, 0.8, 0.92)
	var target_sun_color: Color = Color(1.0, 0.96, 0.88)
	var target_sun_energy: float = 1.1
	var target_ambient_color: Color = Color(0.65, 0.75, 0.88)
	var target_ambient_energy: float = 1.0

	if day_time < 0.25:
		var t: float = day_time / 0.25
		target_horizon = Color(0.95, 0.62, 0.45).lerp(Color(0.68, 0.8, 0.92), t)
		target_sun_color = Color(1.0, 0.65, 0.45).lerp(Color(1.0, 0.96, 0.88), t)
		target_sun_energy = lerpf(0.3, 1.1, t)
		target_ambient_color = Color(0.45, 0.35, 0.35).lerp(Color(0.65, 0.75, 0.88), t)
		target_ambient_energy = lerpf(0.5, 1.0, t)
	elif day_time < 0.50:
		target_horizon = Color(0.68, 0.8, 0.92)
		target_sun_color = Color(1.0, 0.96, 0.88)
		target_sun_energy = 1.1
		target_ambient_color = Color(0.65, 0.75, 0.88)
		target_ambient_energy = 1.0
	elif day_time < 0.75:
		var t: float = (day_time - 0.50) / 0.25
		target_horizon = Color(0.68, 0.8, 0.92).lerp(Color(0.85, 0.42, 0.25), t)
		target_sun_color = Color(1.0, 0.96, 0.88).lerp(Color(1.0, 0.5, 0.3), t)
		target_sun_energy = lerpf(1.1, 0.15, t)
		target_ambient_color = Color(0.65, 0.75, 0.88).lerp(Color(0.35, 0.25, 0.3), t)
		target_ambient_energy = lerpf(1.0, 0.3, t)
	else:
		target_horizon = Color(0.10, 0.16, 0.32)
		target_sun_color = Color(0.40, 0.55, 0.85)
		target_sun_energy = 0.20
		target_ambient_color = Color(0.18, 0.25, 0.42)
		target_ambient_energy = 0.45

	var season_tint: Color = _get_season_tint()
	target_horizon = target_horizon * season_tint

	if sun_light:
		if day_time < 0.50:
			var day_progress: float = day_time / 0.50
			var sun_elevation: float = sin(day_progress * PI) * deg_to_rad(60.0) + deg_to_rad(15.0)
			sun_light.rotation.x = -sun_elevation
			sun_light.rotation.y = day_progress * PI
		else:
			var night_progress: float = (day_time - 0.50) / 0.50
			var moon_elevation: float = sin(night_progress * PI) * deg_to_rad(45.0) + deg_to_rad(20.0)
			sun_light.rotation.x = -moon_elevation
			sun_light.rotation.y = PI + (night_progress * PI)

		sun_light.light_color = sun_light.light_color.lerp(target_sun_color, delta * 2.0)
		sun_light.light_energy = lerpf(sun_light.light_energy, target_sun_energy, delta * 2.0)

	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = env.ambient_light_color.lerp(target_ambient_color, delta * 2.0)
	env.ambient_light_energy = lerpf(env.ambient_light_energy, target_ambient_energy, delta * 2.0)

	# --- GTA SAN ANDREAS / GTA 3 OPEN WORLD ATMOSPHERIC FOG ---
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = env.fog_light_color.lerp(target_horizon, delta * 2.0)
	env.fog_density = 0.0065
	env.fog_depth_begin = 35.0
	env.fog_depth_end = 180.0
	env.fog_sky_affect = 1.0

	if env.sky and env.sky.sky_material:
		if env.sky.sky_material is ShaderMaterial:
			var mat: ShaderMaterial = env.sky.sky_material as ShaderMaterial
			var target_sky_tint: Color = Color(1.0, 1.0, 1.0)
			var target_sky_energy: float = 1.0
			var curr_tint_param = mat.get_shader_parameter("sky_tint")
			var curr_energy_param = mat.get_shader_parameter("energy")

			var curr_tint: Color = Color(1.0, 1.0, 1.0)
			if curr_tint_param is Color:
				curr_tint = curr_tint_param as Color

			var curr_energy: float = 1.0
			if curr_energy_param is float:
				curr_energy = curr_energy_param as float

			mat.set_shader_parameter("sky_tint", curr_tint.lerp(target_sky_tint, delta * 2.0))
			mat.set_shader_parameter("energy", lerpf(curr_energy, target_sky_energy, delta * 2.0))

	# Restrict Camera Render Bubble to 200m (matches GTA San Andreas atmospheric culling)
	var player: Node3D = Server.get_player()
	if player and is_instance_valid(player):
		var cam: Camera3D = player.get_node_or_null("CameraRig/Camera3D") as Camera3D
		if cam:
			cam.far = 200.0


func _apply_season(season: Season) -> void:
	var season_name: String = get_current_season_name()

	if weather_particles:
		match season:
			Season.SPRING, Season.SUMMER:
				weather_particles.emitting = false
			Season.AUTUMN:
				AutumnEffect.configure_autumn(weather_particles)
			Season.WINTER:
				SnowEffect.configure_snow(weather_particles)

	season_changed.emit(season_name)
