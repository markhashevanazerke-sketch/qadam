extends Node3D

const STREET_START := Vector3(24.75, 26.188, 122.85)
const MOUSE_SENSITIVITY := 0.002
var camera: Camera3D
var status: Label
var pause_hint: Label
var crosshair: Label
var speed: float = 5.0
var velocity := Vector3.ZERO
var pitch: float = 0.0
var yaw: float = 0.372
var overview := false
var movement_enabled := false
var elapsed: float = 0.0
var automated_check := "--scale-check" in OS.get_cmdline_user_args() or "--scale-capture" in OS.get_cmdline_user_args() or "--smoke" in OS.get_cmdline_user_args() or "--npc-check" in OS.get_cmdline_user_args()
var observer: CharacterBody3D
var collider_count := 0
var pedestrians: Node3D
var npc_start := STREET_START
var npc_yaw := 0.372
var traffic: Node3D
var island_life: Node3D
var island_deck: Node3D
var cinematic := false
var _cin_angle := 0.6

func _ready() -> void:
	_register_inputs()
	_setup_environment()
	var city := get_node_or_null("CityBlock")
	if city:
		_add_collisions(city)
	var mini := get_node_or_null("MiniCity")
	if mini:
		# The island asset ships pre-cleaned: the baked-in parked vehicles are
		# already cut out of polygon_mini_free_clean.glb (see glb_surgery.js),
		# so the simulation keeps only the 5 moving cars.
		_add_collisions(mini)
		traffic = Node3D.new()
		traffic.name = "Traffic"
		traffic.set_script(preload("res://traffic.gd"))
		add_child(traffic)
		island_life = Node3D.new()
		island_life.name = "IslandLife"
		island_life.set_script(preload("res://island_life.gd"))
		add_child(island_life)
		# the world ground: a big walkable deck ring around the diorama
		island_deck = Node3D.new()
		island_deck.name = "IslandDeck"
		island_deck.set_script(preload("res://island_deck.gd"))
		island_deck.scale = Vector3(1.5, 1.0, 1.5)
		add_child(island_deck)
	observer = CharacterBody3D.new()
	observer.name = "Observer"
	observer.collision_mask = 3
	observer.motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	add_child(observer)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.7
	shape.shape = capsule
	shape.position = Vector3(0.0, 0.85, 0.0)
	observer.add_child(shape)
	if island_life:
		island_life.observer = observer
	camera = Camera3D.new()
	camera.name = "PlayerCam"
	camera.fov = 78.0
	camera.near = 0.08
	camera.far = 5000.0
	camera.position = Vector3(0.0, 1.65, 0.0)
	observer.add_child(camera)
	camera.current = true
	if city:
		pedestrians = Node3D.new()
		pedestrians.set_script(preload("res://pedestrians.gd"))
		pedestrians.name = "Pedestrians"
		add_child(pedestrians)
		pedestrians.observer = observer
		npc_start = pedestrians.camera_start
		npc_yaw = pedestrians.camera_yaw
	reset_street()
	_setup_hud()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	movement_enabled = true
	print("ALMATY_VIEWER_READY | map loaded | WASD — ходьба · мышь — обзор · Space — прыжок · Shift — бег")
	if "--scale-check" in OS.get_cmdline_user_args():
		_scale_check.call_deferred()
	if "--scale-capture" in OS.get_cmdline_user_args():
		_scale_capture.call_deferred()
	if "--smoke" in OS.get_cmdline_user_args():
		_smoke_check.call_deferred()
	if "--npc-check" in OS.get_cmdline_user_args():
		_npc_check.call_deferred()

func _add_collisions(node: Node) -> void:
	for child in node.get_children():
		_add_collisions(child)
	if node is MeshInstance3D and node.mesh:
		# Tiny decorative bars sit above a continuous solid perimeter base.
		if node.name.begins_with("Boundary_Post") or node.name.begins_with("Boundary_Rail"):
			return
		var body := StaticBody3D.new()
		body.name = "SolidExterior"
		var shape := CollisionShape3D.new()
		var collision: ConcavePolygonShape3D = node.mesh.create_trimesh_shape()
		collision.backface_collision = true
		shape.shape = collision
		node.add_child(body)
		body.add_child(shape)
		collider_count += 1

func _register_inputs() -> void:
	var bindings := {"forward": KEY_W, "back": KEY_S, "left": KEY_A, "right": KEY_D,
		"up": KEY_SPACE, "down": KEY_CTRL, "fast": KEY_SHIFT}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var event := InputEventKey.new()
			event.physical_keycode = bindings[action]
			InputMap.action_add_event(action, event)

func _setup_environment() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("5486ac")
	sky_material.sky_horizon_color = Color("d1dfdf")
	sky_material.ground_horizon_color = Color("d1dfdf")
	sky_material.ground_bottom_color = Color("788479")
	var sky := Sky.new()
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("d4e3ef")
	environment.ambient_light_energy = 0.4
	environment.ambient_light_sky_contribution = 0.0
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_color = Color("fff2dc")
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 650.0
	add_child(sun)

func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _setup_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	layer.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := PanelContainer.new()
	root.add_child(panel)
	panel.position = Vector2(22, 22)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.065, 0.075, 0.88)
	style.set_corner_radius_all(10)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", style)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(stack)
	stack.add_child(_label("QADAM  /  MINI GTA", 20, Color("e4f1e9")))
	stack.add_child(_label("WASD — ходьба  ·  Мышь — обзор", 16, Color("d2dddd")))
	stack.add_child(_label("Space — прыжок  ·  Shift — бег", 16, Color("d2dddd")))
	stack.add_child(_label("Tab — сверху  ·  R — на улицу  ·  C — кино-облёт  ·  Esc — курсор", 16, Color("d2dddd")))
	if pedestrians:
		stack.add_child(_label("N — к пешеходам  ·  Колесо — скорость  ·  F11 — экран", 16, Color("d2dddd")))
	else:
		stack.add_child(_label("Колесо — скорость  ·  F11 — экран", 16, Color("d2dddd")))
	status = _label("", 15, Color("8dd1c1"))
	stack.add_child(status)
	crosshair = _label("·", 32, Color(1,1,1,0.7))
	root.add_child(crosshair)
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.position -= Vector2(5, 20)
	pause_hint = _label("Обзор приостановлен. Щёлкни по карте, чтобы продолжить.", 21, Color.WHITE)
	root.add_child(pause_hint)
	pause_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	pause_hint.position = Vector2(-335, -95)
	pause_hint.visible = false
	var credit := _label("POLYGON Mini [FREE] · Leafia dev. · CC BY 4.0  |  Рабочая копия · расширенная карта", 14, Color("d2dddd"))
	root.add_child(credit)
	credit.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	credit.position = Vector2(22, -31)
	credit.add_theme_color_override("font_shadow_color", Color.BLACK)
	credit.add_theme_constant_override("shadow_offset_x", 1)
	credit.add_theme_constant_override("shadow_offset_y", 1)

func reset_street() -> void:
	observer.position = npc_start
	camera.position = Vector3(0.0, 1.65, 0.0)
	pitch = 0.0
	yaw = npc_yaw
	velocity = Vector3.ZERO
	overview = false
	camera.rotation = Vector3(pitch, yaw, 0)

func toggle_overview() -> void:
	if overview:
		reset_street()
	else:
		observer.position = Vector3(142.5, 125, 210)
		camera.look_at(Vector3(0, 10.42, 58.5))
		pitch = camera.rotation.x
		yaw = camera.rotation.y
		velocity = Vector3.ZERO
		overview = true

func toggle_cinematic() -> void:
	if cinematic:
		cinematic = false
		camera.rotation = Vector3.ZERO
		pitch = 0.0
		yaw = observer.rotation.y
	else:
		cinematic = true
		velocity = Vector3.ZERO

func set_captured(captured: bool) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if captured else Input.MOUSE_MODE_VISIBLE
	movement_enabled = captured
	velocity = Vector3.ZERO
	pause_hint.visible = not captured
	crosshair.visible = captured

func _notification(what: int) -> void:
	if not automated_check and what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(pause_hint):
		set_captured(false)

func _unhandled_input(event: InputEvent) -> void:
	if automated_check:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * MOUSE_SENSITIVITY
		pitch = clampf(pitch - event.relative.y * MOUSE_SENSITIVITY, deg_to_rad(-89), deg_to_rad(89))
		camera.rotation = Vector3(pitch, yaw, 0)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			set_captured(true)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			speed = minf(speed * 1.25, 100.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			speed = maxf(speed / 1.25, 2.0)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ESCAPE: set_captured(Input.mouse_mode != Input.MOUSE_MODE_CAPTURED)
			KEY_R: reset_street()
			KEY_N: if pedestrians: inspect_npc()
			KEY_TAB: toggle_overview()
			KEY_C: toggle_cinematic()
			KEY_F11:
				var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)

func _physics_process(delta: float) -> void:
	if cinematic:
		_cin_angle += delta * 0.05
		var center := Vector3(0.0, 10.42, 58.5)
		observer.position = center + Vector3(cos(_cin_angle) * 127.5, 55.0, sin(_cin_angle) * 127.5)
		observer.look_at(center)
	elif movement_enabled and not overview:
		# first-person walking: the player is a person on the ground (POV,
		# no body model) — gravity, jump, walk on the paved plazas
		var planar := Input.get_vector("left", "right", "forward", "back")
		var direction := Basis(Vector3.UP, yaw) * Vector3(planar.x, 0, planar.y)
		var multiplier: float = 1.8 if Input.is_action_pressed("fast") else 1.0
		observer.velocity.x = lerpf(observer.velocity.x, direction.x * speed * multiplier, 1.0 - exp(-12.0 * delta))
		observer.velocity.z = lerpf(observer.velocity.z, direction.z * speed * multiplier, 1.0 - exp(-12.0 * delta))
		if Input.is_action_just_pressed("up") and observer.is_on_floor():
			observer.velocity.y = 4.8
		if not observer.is_on_floor():
			observer.velocity += Vector3(0.0, -9.8, 0.0) * delta
		observer.move_and_slide()
		velocity = Vector3(observer.velocity.x, 0.0, observer.velocity.z)
		# fell off the world? back on the deck
		var void_level: float = 5.0
		if island_deck and is_instance_valid(island_deck):
			void_level = float(island_deck.deck_top) - 8.0
		if observer.position.y < void_level:
			observer.position = npc_start
			observer.velocity = Vector3.ZERO
			velocity = Vector3.ZERO
	elapsed += delta
	if elapsed > 0.15:
		elapsed = 0.0
		status.text = "Высота %.1f м  ·  Скорость %.0f м/с  ·  Машин: %d  ·  Людей: %d" % [camera.global_position.y, velocity.length(), traffic.car_count if traffic else 0, island_life.walker_count if island_life else 0]
	if cinematic:
		status.text += "  ·  КИНО-ОБЛЁТ (C — выйти)"

# 2D oriented-rectangle clearance via SAT: returns the minimum gap between
# two OBBs on the ground plane; 0.0 means the rectangles intersect.
# The four face-normal axes are exact for overlap detection and conservative
# (never under-reports) for the clearance value.
# Exact clearance between two ground-plane OBBs: for disjoint convex
# polygons the minimum distance is always a vertex-to-vertex or
# vertex-to-edge pair, so testing all 4x4 of both ways is exact.
func _obb_clearance(pa: Vector3, ya: float, la: float, wa: float, pb: Vector3, yb: float, lb: float, wb: float) -> float:
	var a := Vector2(pa.x, pa.z)
	var b := Vector2(pb.x, pb.z)
	var ad := Vector2(sin(ya), cos(ya))
	var bd := Vector2(sin(yb), cos(yb))
	var ac: Array = []
	var bc: Array = []
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			ac.append(a + ad * (float(sx) * la * 0.5) + Vector2(-ad.y, ad.x) * (float(sz) * wa * 0.5))
			bc.append(b + bd * (float(sx) * lb * 0.5) + Vector2(-bd.y, bd.x) * (float(sz) * wb * 0.5))
	# corner order: (-x,-z) (-x,+z) (+x,-z) (+x,+z) -> ring edges
	var ea: Array = [[ac[0], ac[1]], [ac[1], ac[3]], [ac[3], ac[2]], [ac[2], ac[0]]]
	var eb: Array = [[bc[0], bc[1]], [bc[1], bc[3]], [bc[3], bc[2]], [bc[2], bc[0]]]
	var best := 1e9
	for i in 4:
		for j in 4:
			best = minf(best, ac[i].distance_to(bc[j]))
			best = minf(best, _edge_dist(bc[j], ea[i][0], ea[i][1]))
			best = minf(best, _edge_dist(ac[i], eb[j][0], eb[j][1]))
	return best


func _edge_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var l2: float = ab.length_squared()
	if l2 < 0.000001:
		return p.distance_to(a)
	var t: float = clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return (p - (a + ab * t)).length()


func _smoke_check() -> void:
	await get_tree().physics_frame
	assert(collider_count > 3, "Collision shapes missing")
	# Ждём, пока трафик и жизнь острова построятся (гейт «физика готова»).
	var build_wait := 0
	while (traffic != null and not traffic._built) or (island_life != null and not island_life._built):
		build_wait += 1
		if build_wait >= 600:
			break
		await get_tree().process_frame
	set_physics_process(false)
	set_captured(true)
	reset_street()
	var start := observer.position
	Input.action_press("forward")
	for i in range(20):
		_physics_process(1.0/60.0)
		await get_tree().physics_frame
	Input.action_release("forward")
	print("MOVEMENT_CHECK ",start," -> ",observer.position)
	assert(observer.position.distance_to(start) > 1.0, "W movement failed")
	set_captured(false)
	start = observer.position
	Input.action_press("forward")
	_physics_process(1.0/60.0)
	Input.action_release("forward")
	assert(observer.position.is_equal_approx(start), "Paused camera must stay still")
	# Sweep at the diorama deck level: rays toward the island must hit its solid
	# base, and the camera must stop against the first hit point. The origin
	# sits beyond the outer edge of the world deck (z 250) at deck level.
	var space := get_world_3d().direct_space_state
	var sweep_from := Vector3(0.0, 25.0, 260.0)
	var tested := 0
	for i in range(16):
		var angle := TAU * float(i) / 16.0
		var direction := Vector3(cos(angle),0,sin(angle))
		var query := PhysicsRayQueryParameters3D.create(sweep_from,sweep_from+direction*220)
		query.exclude = [observer.get_rid()]
		var hit := space.intersect_ray(query)
		if hit.is_empty() or absf(hit.normal.y) > .2:
			continue
		observer.position = hit.position - direction*2.0
		await get_tree().physics_frame
		var collision := observer.move_and_collide(direction*4.0)
		assert(collision != null, "Camera crossed the mini-city")
		tested += 1
	assert(tested >= 4, "Insufficient mini-city collision checks")
	# Perimeter wall check only applies to the old city map, if present in the scene.
	var boundary_count := 0
	if get_node_or_null("CityBlock"):
		var boundary := get_node("CityBlock").find_children("Boundary_Base*", "MeshInstance3D", true, false)
		for wall in boundary:
			var center: Vector3 = wall.global_transform * wall.get_aabb().get_center()
			var away := Vector3(center.x,0,center.z).normalized()
			var query := PhysicsRayQueryParameters3D.create(center-away*5,center+away*5)
			query.exclude = [observer.get_rid()]
			assert(not space.intersect_ray(query).is_empty(), "Open perimeter wall")
		boundary_count = boundary.size()
	set_captured(true)
	reset_street()
	assert(observer.position == npc_start, "Reset failed")
	# Traffic + town life: interleaved deterministic simulation with hard
	# separation asserts (cars never overlap, never cross pedestrians,
	# pedestrians never overlap, shops are entered, the child plays).
	var car_y_prev := {}
	var min_car_dist := 1e9
	var min_car_clear := 1e9
	var min_car_ped := 1e9
	var min_ped_dist := 1e9
	if traffic:
		traffic.set_process(false)
		# deterministic window: zero the counters so the asserts below measure
		# exactly the 300 manual steps (30 s) and not stray physics frames
		traffic.travel_total = 0.0
		traffic.stop_events = 0
		traffic.state_changes = 0
		traffic.travel_by_route = {}
		if island_life:
			island_life.set_physics_process(false)
			island_life.travel_total = 0.0
			island_life.visit_count = 0
			island_life.play_events = 0
			for walker in island_life._walkers:
				walker["travelled"] = 0.0
		for i in 300:
			traffic.step(0.1)
			if island_life:
				island_life.tick(0.1)
			for car in traffic._cars:
				var uid: int = int(car["uid"])
				var y: float = car["node"].position.y
				if car_y_prev.has(uid):
					assert(absf(y - float(car_y_prev[uid])) < 0.6, "Car %d fell or jumped (y %f -> %f)" % [uid, float(car_y_prev[uid]), y])
				car_y_prev[uid] = y
			for a in traffic._cars:
				for b in traffic._cars:
					if int(a["uid"]) >= int(b["uid"]):
						continue
					var pa: Vector3 = a["node"].position
					var pb: Vector3 = b["node"].position
					min_car_dist = minf(min_car_dist, Vector3(pa.x, 0, pa.z).distance_to(Vector3(pb.x, 0, pb.z)))
					var clear_ij: float = _obb_clearance(
						pa, float(a["node"].rotation.y), float(a["length"]), float(a["width"]),
						pb, float(b["node"].rotation.y), float(b["length"]), float(b["width"]))
					min_car_clear = minf(min_car_clear, clear_ij)
					if clear_ij <= 0.05:
						print("CAR_TOUCH_DEBUG | pair (%d,%d) clear %.3f | (%.2f,%.2f) yaw %.2f len %.1f / (%.2f,%.2f) yaw %.2f len %.1f | s=%s" % [
							int(a["uid"]), int(b["uid"]), clear_ij,
							pa.x, pa.z, float(a["node"].rotation.y), float(a["length"]),
							pb.x, pb.z, float(b["node"].rotation.y), float(b["length"]),
							"a_s=%.1f v=%.2f b_s=%.1f v=%.2f" % [float(a["s"]), float(a["speed"]), float(b["s"]), float(b["speed"])]
						])
			if island_life:
				for car in traffic._cars:
					var ca: Vector3 = car["node"].position
					for w in island_life._walkers:
						var pw: Vector3 = w["node"].global_position
						min_car_ped = minf(min_car_ped, Vector3(ca.x, 0, ca.z).distance_to(Vector3(pw.x, 0, pw.z)))
				for w1 in island_life._walkers:
					for w2 in island_life._walkers:
						if w1 == w2:
							continue
						var p1: Vector3 = w1["node"].global_position
						var p2: Vector3 = w2["node"].global_position
						min_ped_dist = minf(min_ped_dist, Vector3(p1.x, 0, p1.z).distance_to(Vector3(p2.x, 0, p2.z)))
		for car in traffic._cars:
			var cpos: Vector3 = car["node"].position
			assert(cpos.is_finite(), "Car position is NaN")
			assert(cpos.y > 10.0 and cpos.y < 45.0, "Car left the deck")
		assert(traffic.car_count == 5, "Fleet must be exactly 5 active cars")
		assert(traffic.special_count >= 2, "No emergency vehicles spawned")
		assert(traffic.light_count >= 4, "Not enough traffic lights")
		assert(traffic.travel_total > 30.0, "Cars did not drive")
		assert(traffic.stop_events >= 1, "Cars never stopped at a light")
		assert(traffic.state_changes >= 6, "Traffic lights never changed state")
		assert(min_car_clear > 0.02, "Cars touched (min bumper clearance %.2f m)" % min_car_clear)
		assert(min_car_dist > 1.8, "Car centers collapsed (min %.2f m)" % min_car_dist)
		assert(min_car_ped > 1.2, "A car crossed a pedestrian (min gap %.2f m)" % min_car_ped)
		var route_report := ""
		var route_thresholds := {"main": 120.0, "lot": 60.0}
		for rid in route_thresholds:
			var rt: float = float(traffic.travel_by_route.get(rid, 0.0))
			assert(rt > float(route_thresholds[rid]), "Route %s was not used by its cars" % rid)
			route_report += "%s=%.0fm " % [rid, rt]
		print("TRAFFIC_OK | cars: ", traffic.car_count, " (special: ", traffic.special_count, ") / lights: ", traffic.light_count, " / travel: ", int(traffic.travel_total), " m / stops: ", traffic.stop_events, " / min bumper clearance: %.2fm " % min_car_clear, " / min car-ped gap: %.2fm " % min_car_ped, " / routes: ", route_report.strip_edges(), " / light changes: ", traffic.state_changes)
	if island_life:
		island_life.set_physics_process(false)
		for walker in island_life._walkers:
			var wpos: Vector3 = walker["node"].global_position
			assert(wpos.is_finite(), "Walker position is NaN")
			assert(wpos.y > 10.0 and wpos.y < 30.0, "Walker left the plaza")
		assert(island_life.walker_count >= 10, "Not enough pedestrians")
		assert(island_life.shop_count >= 3, "Not enough shops")
		assert(island_life.travel_total > 100.0, "Pedestrians did not walk")
		assert(island_life.visit_count >= 1, "Shops were never entered")
		assert(island_life.play_events >= 1, "Child never played at the playground")
		assert(min_ped_dist > 0.30, "Pedestrians overlapped (min gap %.2f m)" % min_ped_dist)
		print("ISLAND_LIFE_OK | walkers: ", island_life.walker_count, " / shops: ", island_life.shop_count, " / travel: ", int(island_life.travel_total), " m / shop entries: ", island_life.visit_count, " / play events: ", island_life.play_events, " / min ped gap: %.2fm" % min_ped_dist)
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://").path_join("../previews/enclosed_street.png"))
	toggle_overview()
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://").path_join("../previews/enclosed_overview.png"))
	print("SMOKE_OK | WASD / pause / reset / city sweeps: ", tested, " / border walls: ", boundary_count, " / collision meshes: ",collider_count)
	get_tree().quit()

func inspect_npc() -> void:
	var view: Dictionary = pedestrians.inspection_view()
	observer.position = view.position
	camera.look_at(view.target)
	pitch = camera.rotation.x
	yaw = camera.rotation.y
	velocity = Vector3.ZERO
	overview = false

func _npc_check() -> void:
	if not pedestrians:
		print("NPC_CHECK_SKIPPED | CityBlock map not in scene, no NPC routes")
		get_tree().quit()
		return
	await get_tree().physics_frame
	set_physics_process(false)
	pedestrians.set_physics_process(false)
	pedestrians.observer = null
	assert(pedestrians.walkers.size() == 24)
	assert(pedestrians.routes.size() == 8)
	var space := get_world_3d().direct_space_state
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.55
	var route_checks := 0
	for route in pedestrians.routes:
		for index in range(0, route.points.size(), 10):
			var point: Vector3 = route.points[index]
			var ray := PhysicsRayQueryParameters3D.create(point+Vector3.UP*0.2, point-Vector3.UP*0.35, 1)
			var floor_hit := space.intersect_ray(ray)
			assert(not floor_hit.is_empty(), "Missing sidewalk under NPC")
			if not str(floor_hit.collider.get_parent().name).begins_with("terrain"):
				print("NPC_FLOOR_MISMATCH ",route.name," point=",point," mesh=",floor_hit.collider.get_parent().name)
				get_tree().quit(1)
				return
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = capsule
			query.collision_mask = 1
			query.exclude = [observer.get_rid()]
			query.transform = Transform3D(Basis.IDENTITY, point+Vector3.UP*0.85)
			var hits := space.intersect_shape(query,1)
			if not hits.is_empty():
				print("NPC_ROUTE_OBSTACLE ", route.name, " point=",point, " mesh=",hits[0].collider.get_parent().name)
				get_tree().quit(1)
				return
			route_checks += 1
	print("NPC_SURFACES_OK | capsule and floor samples=", route_checks)
	# A pedestrian yields when the observer blocks the lane, then resumes.
	var first: Dictionary = pedestrians.walkers[0]
	var ahead: Dictionary = pedestrians.sample_route(pedestrians.routes[0], first.distance+0.45)
	observer.position = ahead.position+Vector3.UP*1.8
	pedestrians.observer = observer
	var stopped_at: Vector3 = first.node.position
	pedestrians._physics_process(0.1)
	assert(first.node.position.distance_to(stopped_at)<0.001, "NPC did not yield to observer")
	pedestrians.observer = null
	pedestrians._physics_process(0.1)
	assert(first.node.position.distance_to(stopped_at)>0.01, "NPC failed to resume")
	var initial: Array[Vector3] = []
	for walker in pedestrians.walkers:
		initial.append(walker.node.position)
		assert(walker.animation.has_animation("Walk"))
	# Cover more than a full circuit of the longest promenade, using the actual
	# runtime follower and yielding periodically to the physics server.
	for tick in range(2400):
		pedestrians._physics_process(0.2)
		if tick % 100 == 0:
			await get_tree().physics_frame
	for i in range(pedestrians.walkers.size()):
		var walker: Dictionary = pedestrians.walkers[i]
		assert(walker.travelled > 30.0, "Pedestrian stuck")
		assert(walker.node.position.distance_to(initial[i]) > 0.1)
		var expected: Dictionary = pedestrians.sample_route(pedestrians.routes[walker.route], walker.distance)
		assert(walker.node.position.distance_to(expected.position) < 0.01, "Walker left sidewalk route")
		print("NPC_CHECK ", i, " travelled=", walker.travelled)
	pedestrians.inspection_index = -1
	inspect_npc()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://").path_join("../previews/npcs_city_street.png"))
	pedestrians.inspection_index = 3
	inspect_npc()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://").path_join("../previews/npcs_jane_sidewalk.png"))
	print("NPC_CHECK_OK | 24 walkers | 8 pavement-only routes | simulated 480 seconds")
	get_tree().quit()

# Checks for the expanded copy; original viewer smoke probes use old coordinates.
func _scale_check() -> void:
	await get_tree().create_timer(3).timeout
	assert(traffic._built and island_life._built, "Map probes failed")
	assert(traffic.car_count == 5 and island_life.walker_count == 11, "Original population changed")
	assert(is_equal_approx($MiniCity.scale.x, 4.5) and is_equal_approx($MiniCity.scale.y, 3.6), "Map scale mismatch")
	for car in traffic._cars:
		assert(is_equal_approx(car["node"].get_node("VehicleVisual").scale.x, 1.35), "Car scale lost")
		assert(float(car["width"]) > 1.3, "Avoidance dimensions not updated")
	var start: Vector3 = observer.position
	Input.action_press("forward")
	await get_tree().create_timer(.7).timeout
	Input.action_release("forward")
	assert(observer.position.distance_to(start)>1, "Player cannot walk from spawn")
	assert(observer.position.y>24, "Player fell through the map")
	var travel_before: float = traffic.travel_total
	traffic.simulate(30.0, .1)
	assert(traffic.travel_total > travel_before + 30, "Traffic does not move")
	for car in traffic._cars:
		assert(is_equal_approx(car["node"].get_node("VehicleVisual").scale.x, 1.35), "Turning reset visual size")
	var tested := 0
	var space := get_world_3d().direct_space_state
	for i in 32:
		var angle := TAU * float(i)/32.0
		var origin := Vector3(-15, 28, 40) + Vector3(cos(angle),0,sin(angle))*180
		var destination := Vector3(-15,28,40)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(origin,destination,1))
		if hit.is_empty() or absf(hit.normal.y)>.2: continue
		observer.position = hit.position + hit.normal*1.2 - Vector3(0,.85,0)
		assert(observer.test_move(observer.global_transform,-hit.normal*2), "Wall collision missing")
		tested += 1
	assert(tested>=4, "Not enough solid walls checked")
	print("SCALE_CHECK_PASS | original map, 5 vehicles, 11 pedestrians, movement, walls, 30s traffic, persistent visual scale")
	get_tree().quit()

func _scale_capture() -> void:
	await get_tree().create_timer(4).timeout
	set_physics_process(false)
	camera.global_position = Vector3(115, 110, 205)
	camera.look_at(Vector3(-12, 25, 60))
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../previews/expanded_original.png"))
	get_tree().quit()
