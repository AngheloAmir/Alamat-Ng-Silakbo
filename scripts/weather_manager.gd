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


var weather_particles: GPUParticles3D = null


func _ready() -> void:
	if not world_env:
		world_env = get_node_or_null("../WorldEnvironment")
	call_deferred("_setup_mountain_sky")
	call_deferred("_setup_particles")
	call_deferred("_apply_season", current_season)


func _setup_particles() -> void:
	weather_particles = GPUParticles3D.new()
	weather_particles.name = "SeasonWeatherParticles"
	weather_particles.emitting = false
	weather_particles.amount = 2200
	weather_particles.lifetime = 8.0
	weather_particles.visibility_aabb = AABB(Vector3(-150, -30, -150), Vector3(300, 60, 300))

	var proc_mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	proc_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	proc_mat.emission_box_extents = Vector3(140.0, 1.0, 140.0) # Matches 140m simulation distance!
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
		print("[WeatherManager] mountain_bg.png not found at: ", abs_path)
		return
	var img: Image = Image.new()
	var err: Error = img.load(abs_path)
	if err != OK:
		print("[WeatherManager] Failed to load mountain_bg.png, error: ", err)
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
	print("[WeatherManager] Custom tintable mountain skybox applied successfully!")


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

	var player: Node3D = GameManager.get_player()
	if player and is_instance_valid(player) and weather_particles:
		weather_particles.global_position = player.global_position + Vector3(0.0, 15.0, 0.0)

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
		target_sky_top = Color(0.04, 0.08, 0.22)
		target_horizon = Color(0.10, 0.16, 0.32)
		target_sun_color = Color(0.40, 0.55, 0.85)
		target_sun_energy = 0.20 # Bright clear moonlight!
		target_ambient_color = Color(0.18, 0.25, 0.42) # Atmospheric night ambient
		target_ambient_energy = 0.45 # Clear ground illumination
		target_render_far = 2000.0

	# 2. Apply Season Tint Modifier
	var season_tint: Color = _get_season_tint()
	target_horizon = target_horizon * season_tint

	# 3. Position Sun / Moon Directional Light (Always pointing downward from above horizon!)
	if sun_light:
		if day_time < 0.50:
			# Daytime: Sun moves East -> Noon -> West
			var day_progress: float = day_time / 0.50
			var sun_elevation: float = sin(day_progress * PI) * deg_to_rad(60.0) + deg_to_rad(15.0)
			sun_light.rotation.x = -sun_elevation
			sun_light.rotation.y = day_progress * PI
		else:
			# Nighttime: Moon moves West -> Midnight -> East
			var night_progress: float = (day_time - 0.50) / 0.50
			var moon_elevation: float = sin(night_progress * PI) * deg_to_rad(45.0) + deg_to_rad(20.0)
			sun_light.rotation.x = -moon_elevation
			sun_light.rotation.y = PI + (night_progress * PI)

		sun_light.light_color = sun_light.light_color.lerp(target_sun_color, delta * 2.0)
		sun_light.light_energy = lerpf(sun_light.light_energy, target_sun_energy, delta * 2.0)

	# 4. Apply Ambient Light in Environment
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = env.ambient_light_color.lerp(target_ambient_color, delta * 2.0)
	env.ambient_light_energy = lerpf(env.ambient_light_energy, target_ambient_energy, delta * 2.0)

	# 5. Apply Sky Material Colors / Tint / Energy (ShaderMaterial vs PanoramaSkyMaterial vs ProceduralSkyMaterial)
	if env.sky and env.sky.sky_material:
		var target_sky_tint: Color = Color(1.0, 1.0, 1.0)
		var target_sky_energy: float = 1.0

		if day_time < 0.25:
			# --- SUNRISE (0.0 - 0.25) ---
			var t: float = day_time / 0.25
			target_sky_tint = Color(0.18, 0.28, 0.55).lerp(Color(1.0, 0.70, 0.50), t)
			target_sky_energy = lerpf(0.45, 1.0, t)

		elif day_time < 0.50:
			# --- NOON (0.25 - 0.50) ---
			target_sky_tint = Color(1.0, 1.0, 1.0)
			target_sky_energy = 1.0

		elif day_time < 0.75:
			# --- DUSK (0.50 - 0.75) ---
			var t: float = (day_time - 0.50) / 0.25
			target_sky_tint = Color(1.0, 1.0, 1.0).lerp(Color(0.85, 0.45, 0.30), t)
			target_sky_energy = lerpf(1.0, 0.45, t)

		else:
			# --- NIGHT (0.75 - 1.00) ---
			# Rich moonlit blue night sky!
			target_sky_tint = Color(0.18, 0.28, 0.55)
			target_sky_energy = 0.45

		if env.sky.sky_material is ShaderMaterial:
			var mat: ShaderMaterial = env.sky.sky_material as ShaderMaterial
			var curr_tint_param = mat.get_shader_parameter("sky_tint")
			var curr_energy_param = mat.get_shader_parameter("energy")
			var curr_tint: Color = curr_tint_param if curr_tint_param is Color else Color(1.0, 1.0, 1.0)
			var curr_energy: float = curr_energy_param if curr_energy_param is float else 1.0

			mat.set_shader_parameter("sky_tint", curr_tint.lerp(target_sky_tint, delta * 2.0))
			mat.set_shader_parameter("energy", lerpf(curr_energy, target_sky_energy, delta * 2.0))

		elif env.sky.sky_material is PanoramaSkyMaterial:
			var pano_mat: PanoramaSkyMaterial = env.sky.sky_material as PanoramaSkyMaterial
			pano_mat.energy_multiplier = lerpf(pano_mat.energy_multiplier, target_sky_energy, delta * 2.0)

		elif env.sky.sky_material is ProceduralSkyMaterial:
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

	# 8. Update Particle Lighting & Tint for Day/Night Cycle
	if weather_particles and weather_particles.emitting and weather_particles.material_override is StandardMaterial3D:
		var part_mat: StandardMaterial3D = weather_particles.material_override as StandardMaterial3D
		var base_season_color: Color = Color(0.94, 0.97, 1.0)
		if current_season == Season.AUTUMN:
			base_season_color = Color(0.92, 0.48, 0.18)

		var target_tint: Color = Color(1.0, 1.0, 1.0)
		if day_time < 0.25:
			# Sunrise
			target_tint = Color(0.35, 0.50, 0.75).lerp(Color(1.0, 0.80, 0.60), day_time / 0.25)
		elif day_time < 0.50:
			# Noon
			target_tint = Color(1.0, 1.0, 1.0)
		elif day_time < 0.75:
			# Dusk
			target_tint = Color(1.0, 1.0, 1.0).lerp(Color(0.85, 0.55, 0.38), (day_time - 0.50) / 0.25)
		else:
			# Night: Dark cool blue tint matching night lighting
			target_tint = Color(0.22, 0.35, 0.60)

		part_mat.albedo_color = part_mat.albedo_color.lerp(base_season_color * target_tint, delta * 2.0)


func _apply_season(season: Season) -> void:
	var season_name: String = get_current_season_name()
	print("[WeatherManager] Season switched to:", season_name)
	_set_terrain_tint(_get_season_tint())

	if weather_particles:
		var proc_mat: ParticleProcessMaterial = weather_particles.process_material as ParticleProcessMaterial
		var quad_mesh: QuadMesh = weather_particles.draw_pass_1 as QuadMesh
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.shading_mode = StandardMaterial3D.SHADING_MODE_PER_PIXEL
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED

		match season:
			Season.SPRING, Season.SUMMER:
				weather_particles.emitting = false

			Season.AUTUMN:
				# Autumn: Falling 2D leaf sprites over 140m simulation distance (650 amount)
				weather_particles.amount = 650
				mat.albedo_color = Color(0.92, 0.48, 0.18, 0.90)
				if quad_mesh:
					quad_mesh.size = Vector2(0.28, 0.20)
				weather_particles.material_override = mat
				if proc_mat:
					proc_mat.initial_velocity_min = 2.0
					proc_mat.initial_velocity_max = 4.0
				weather_particles.emitting = true

			Season.WINTER:
				# Winter: Falling 2D snow sprites over 140m simulation distance (2200 amount)
				weather_particles.amount = 2200
				mat.albedo_color = Color(0.94, 0.97, 1.0, 0.90)
				if quad_mesh:
					quad_mesh.size = Vector2(0.22, 0.22)
				weather_particles.material_override = mat
				if proc_mat:
					proc_mat.initial_velocity_min = 3.5
					proc_mat.initial_velocity_max = 7.0
				weather_particles.emitting = true

	emit_signal("season_changed", season_name)




func _set_terrain_tint(tint_color: Color) -> void:
	if not terrain:
		return
	var mesh_inst: MeshInstance3D = terrain.get_node_or_null("TerrainMesh") as MeshInstance3D
	if mesh_inst and mesh_inst.material_override is StandardMaterial3D:
		var mat: StandardMaterial3D = mesh_inst.material_override as StandardMaterial3D
		mat.albedo_color = Color(0.22, 0.52, 0.25) * tint_color
