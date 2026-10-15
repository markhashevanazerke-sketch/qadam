class_name Traffic
extends Node3D
# Toy-town traffic: cars drive closed polylines from roads.json, stop at
# working traffic lights, keep a gap behind the car in front.
#
# Public API:
#   simulate(seconds, dt)  -- deterministic synchronous stepping (smoke tests)
#   car_count / light_count / travel_total / stop_events / state_changes

const ROUTES_PATH := "res://roads.json"

var car_count := 0
var light_count := 0
var travel_total := 0.0
var stop_events := 0
var state_changes := 0
var special_count := 0
var travel_by_route := {}

var _space
var _car_spec := {}
var _routes := {}
var _cars := []
var _lights := []
var _lights_by_route := {}
var _cycle := {"green": 5.0, "yellow": 1.5}
var _raw_routes := {}
var _colors: Array = []
var _time := 0.0
var _running := false
var _built := false
var _was_fast := {}
var _sirens := []
var _build_tries := 0
# Колонки, где точно есть дорога — гейт «физика готова».
const PROBE_XZ := [Vector2(10.5, 99.0), Vector2(10.5, -13.5), Vector2(-48.0, 4.5)]


func _ready() -> void:
	_space = get_world_3d().direct_space_state
	_load_data()
	_running = true


func _process(delta: float) -> void:
	if not _built:
		# Физика может ещё не зарегистрировать коллизии острова (гонка _ready).
		# Ждём, пока контрольные колонки дороги станут видимыми для лучей.
		_build_tries += 1
		if _ground_ready():
			_build_routes()
			_spawn_lights()
			_spawn_cars()
			_built = true
		elif _build_tries >= 600:
			push_error("Traffic: ground never became queryable; traffic disabled")
			_running = false
	if _running:
		step(delta)


func _ground_ready() -> bool:
	if _space == null:
		return false
	for p in PROBE_XZ:
		var ray := PhysicsRayQueryParameters3D.create(Vector3(p.x, 45.0, p.y), Vector3(p.x, -25.0, p.y))
		if _space.intersect_ray(ray).is_empty():
			return false
	return true


func _build_routes() -> void:
	for rid in _raw_routes:
		_spawn_route_meta(rid, _raw_routes[rid])


func simulate(seconds: float, step_dt: float = 0.1) -> void:
	var n := int(round(seconds / step_dt))
	for i in n:
		step(step_dt)


func step(dt: float) -> void:
	_time += dt
	_update_lights()
	_update_sirens()
	_update_cars(dt)


func _load_data() -> void:
	var f := FileAccess.open(ROUTES_PATH, FileAccess.READ)
	if f == null:
		push_error("Traffic: cannot open " + ROUTES_PATH)
		return
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Traffic: roads.json is not a dict")
		return
	_car_spec = data.get("car", {})
	_cycle = data.get("cycle", _cycle)
	_colors = data.get("colors", [])
	_raw_routes = data.get("routes", {})
	for light in data.get("lights", []):
		_lights.append(light)
		var key: String = str(light["route"])
		if not _lights_by_route.has(key):
			_lights_by_route[key] = []
		_lights_by_route[key].append(light)


func _spawn_route_meta(rid: String, meta: Dictionary) -> void:
	var pts: Array = []
	for p in meta["points"]:
		pts.append(Vector3(float(p[0]), 0.0, float(p[1])))
	# one Chaikin round to soften 90-degree corner cuts
	var smoothed := []
	for i in pts.size():
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[(i + 1) % pts.size()]
		smoothed.append(a.lerp(b, 0.25))
		smoothed.append(a.lerp(b, 0.75))
	# Road height: the chain starts from the median of the top hits and each
	# point takes the surface closest to the PREVIOUS point's level. This both
	# rejects overhangs (roof slabs far above the street) and gaps (holes in
	# the block) and follows the real ramps where the island road steps up
	# through the junction (24.4 -> 26.0 m).
	var first_ys := []
	for i in smoothed.size():
		var hs: Array = _column_hits(smoothed[i], 45.0, -25.0, 6)
		first_ys.append(float(hs[0]) if hs.size() > 0 else -999.0)
	var level := _road_level(first_ys)
	var prev_y := level
	for i in smoothed.size():
		prev_y = _chain_surface(smoothed[i], prev_y)
		smoothed[i].y = prev_y
	# cumulative distances (closed loop)
	var cum := [0.0]
	var total := 0.0
	for i in smoothed.size():
		var a: Vector3 = smoothed[i]
		var b: Vector3 = smoothed[(i + 1) % smoothed.size()]
		total += a.distance_to(b)
		cum.append(total)
	_routes[rid] = {
		"pts": smoothed,
		"cum": cum,
		"length": total,
		"closed": meta.get("closed", true),
		"n_cars": int(meta.get("cars", 2)),
		"cruise": meta.get("cruise", [3.5, 4.0]),
		"special": meta.get("special", {}),
		"corner_zones": meta.get("corner_zones", []),
	}


func _column_hits(pos: Vector3, top: float, bottom: float, max_hits: int) -> Array:
	var out := []
	var from := Vector3(pos.x, top, pos.z)
	for i in max_hits:
		var ray := PhysicsRayQueryParameters3D.create(from, Vector3(pos.x, bottom, pos.z))
		var hit: Dictionary = _space.intersect_ray(ray)
		if hit.is_empty():
			break
		out.append(hit.position.y)
		from = Vector3(pos.x, hit.position.y - 0.06, pos.z)
		if from.y < bottom:
			break
	return out


func _road_level(ys: Array) -> float:
	var good := []
	for y in ys:
		if float(y) > -900.0:
			good.append(float(y))
	good.sort()
	return float(good[good.size() / 2]) if good.size() > 0 else 26.0


func _nearest_surface(pos: Vector3, level: float) -> float:
	var best := level
	var best_diff := 1.8
	var hs: Array = _column_hits(pos, 45.0, -25.0, 6)
	for y in hs:
		var d := absf(float(y) - level)
		if d < best_diff:
			best = float(y)
			best_diff = d
	return best


# Чейн-высота: поверхность, ближайшая к высоте предыдущей точки. Если в
# колонке пусто (дыра в геометрии) — ищет по окрестности 3×3.
func _chain_surface(pos: Vector3, prev_y: float) -> float:
	var best := prev_y
	var best_diff := 1.8
	var hs: Array = _column_hits(pos, 45.0, -25.0, 6)
	if hs.is_empty():
		hs = []
		for dx in [-1.0, 0.0, 1.0]:
			for dz in [-1.0, 0.0, 1.0]:
				hs.append_array(_column_hits(Vector3(pos.x + dx, 0.0, pos.z + dz), 45.0, -25.0, 3))
	for y in hs:
		var d := absf(float(y) - prev_y)
		if d < best_diff:
			best = float(y)
			best_diff = d
	return best


func _ground_y(pos: Vector3) -> float:
	if _space == null:
		return 26.0
	var hs: Array = _column_hits(pos, 45.0, -25.0, 3)
	if hs.is_empty():
		return 26.0
	return float(hs[0])


func _spawn_cars() -> void:
	var uid := 0
	for rid in _routes:
		var route: Dictionary = _routes[rid]
		var n: int = route["n_cars"]
		var cruise: Array = route["cruise"]
		var special: Dictionary = route.get("special", {})
		for i in n:
			var s: float = float(i) * float(route["length"]) / float(n)
			var kind: String = "car"
			if int(special.get("index", -1)) == i:
				kind = str(special.get("kind", "car"))
			var spec: Dictionary = _make_vehicle(kind, cruise[i % cruise.size()])
			var car := {
				"node": spec["node"],
				"route": rid,
				"s": s,
				"speed": 0.0,
				"cruise": spec["cruise"],
				"uid": uid,
				"wheels": spec["wheels"],
				"length": spec["length"],
				"width": spec["width"],
			}
			add_child(spec["node"])
			_cars.append(car)
			_was_fast[uid] = false
			uid += 1
			_place_car(car)
			if kind != "car":
				special_count += 1
				if spec.has("siren"):
					_sirens.append(spec["siren"])
	car_count = _cars.size()


func _make_vehicle(kind: String, cruise: float) -> Dictionary:
	var root := Node3D.new()
	root.name = "ToyCar"
	var length: float = float(_car_spec.get("length", 2.5))
	var col := Color(0.8, 0.8, 0.85)
	if kind == "car":
		var ci := _cars.size()
		if _colors.size() > 0:
			col = Color(_colors[ci % _colors.size()][0], _colors[ci % _colors.size()][1], _colors[ci % _colors.size()][2])
	elif kind == "police":
		root.name = "PoliceCar"
		col = Color(0.92, 0.93, 0.96)
		length = float(_car_spec.get("police_length", 2.7))
	elif kind == "fire":
		root.name = "FireTruck"
		col = Color(0.82, 0.13, 0.10)
		length = float(_car_spec.get("truck_length", 3.4))
	var wl := float(_car_spec.get("width", 1.0)) * 0.5
	var ll := length * 0.5
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = col
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(float(_car_spec.get("width", 1.0)), 0.5, length)
	body.mesh = bm
	body.material_override = body_mat
	body.position = Vector3(0, 0.5, 0)
	root.add_child(body)
	var cabin_mat := StandardMaterial3D.new()
	cabin_mat.albedo_color = Color(0.15, 0.2, 0.28)
	cabin_mat.roughness = 0.2
	var cabin_len: float = length * 0.5
	var cabin_z: float = 0.12
	if kind == "fire":
		cabin_len = 0.9
		cabin_z = -ll + 0.45
	var cabin := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(float(_car_spec.get("width", 1.0)) * 0.92, 0.42, cabin_len)
	cabin.mesh = cm
	cabin.material_override = cabin_mat
	cabin.position = Vector3(0, 0.92, cabin_z)
	root.add_child(cabin)
	var wheel_mat := StandardMaterial3D.new()
	wheel_mat.albedo_color = Color(0.08, 0.08, 0.09)
	var wheels := []
	for wx in [-1, 1]:
		for wz in [-1, 1]:
			var wheel := MeshInstance3D.new()
			var wm := CylinderMesh.new()
			wm.top_radius = 0.26
			wm.bottom_radius = 0.26
			wm.height = 0.16
			wheel.mesh = wm
			wheel.material_override = wheel_mat
			wheel.rotation.z = PI / 2.0
			wheel.position = Vector3(wx * (wl + 0.02), 0.26, wz * (ll - 0.5))
			root.add_child(wheel)
			wheels.append(wheel)
	var head_mat := StandardMaterial3D.new()
	head_mat.albedo_color = Color(1, 0.98, 0.85)
	head_mat.emission = Color(1, 0.95, 0.7)
	head_mat.emission_energy_multiplier = 1.6
	var tail_mat := StandardMaterial3D.new()
	tail_mat.albedo_color = Color(0.5, 0.05, 0.05)
	tail_mat.emission = Color(1, 0.1, 0.08)
	tail_mat.emission_energy_multiplier = 1.4
	for hx in [-1, 1]:
		var head := MeshInstance3D.new()
		var hm := BoxMesh.new()
		hm.size = Vector3(0.18, 0.12, 0.06)
		head.mesh = hm
		head.material_override = head_mat
		head.position = Vector3(hx * 0.38, 0.52, -(ll + 0.01))
		root.add_child(head)
		var tail := MeshInstance3D.new()
		var tm := BoxMesh.new()
		tm.size = Vector3(0.2, 0.12, 0.06)
		tail.mesh = tm
		tail.material_override = tail_mat
		tail.position = Vector3(hx * 0.38, 0.52, ll + 0.01)
		root.add_child(tail)
	var result := {"node": root, "cruise": cruise, "wheels": wheels, "length": length, "width": float(_car_spec.get("width", 1.0))}
	if kind == "police":
		_decorate_police(root, length, result)
	elif kind == "fire":
		_decorate_fire(root, length, result)
	# Keep the motion root at unit scale: heading interpolation replaces its basis.
	var visual := Node3D.new()
	visual.name = "VehicleVisual"
	var parts := root.get_children()
	root.add_child(visual)
	for part in parts:
		root.remove_child(part)
		visual.add_child(part)
	visual.scale = Vector3.ONE * 1.35
	result["length"] = float(result["length"]) * 1.35
	result["width"] = float(result["width"]) * 1.35
	return result


func _decorate_police(root: Node3D, length: float, result: Dictionary) -> void:
	var stripe_mat := StandardMaterial3D.new()
	stripe_mat.albedo_color = Color(0.13, 0.3, 0.75)
	var stripe := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(float(_car_spec.get("width", 1.0)) + 0.04, 0.24, length)
	stripe.mesh = sm
	stripe.material_override = stripe_mat
	stripe.position = Vector3(0, 0.42, 0)
	root.add_child(stripe)
	var bar_mat := StandardMaterial3D.new()
	bar_mat.albedo_color = Color(0.1, 0.11, 0.14)
	var bar := MeshInstance3D.new()
	var bmx := BoxMesh.new()
	bmx.size = Vector3(0.62, 0.1, 0.34)
	bar.mesh = bmx
	bar.material_override = bar_mat
	bar.position = Vector3(0, 1.17, 0.1)
	root.add_child(bar)
	var blue_mat := StandardMaterial3D.new()
	blue_mat.albedo_color = Color(0.2, 0.4, 1)
	blue_mat.emission = Color(0.15, 0.35, 1)
	blue_mat.emission_energy_multiplier = 5.0
	var red_mat := StandardMaterial3D.new()
	red_mat.albedo_color = Color(1, 0.2, 0.15)
	red_mat.emission = Color(1, 0.12, 0.08)
	red_mat.emission_energy_multiplier = 0.25
	var blue_lamp := MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(0.22, 0.12, 0.28)
	blue_lamp.mesh = lm
	blue_lamp.material_override = blue_mat
	blue_lamp.position = Vector3(-0.16, 1.24, 0.1)
	root.add_child(blue_lamp)
	var red_lamp := MeshInstance3D.new()
	var lm2 := BoxMesh.new()
	lm2.size = Vector3(0.22, 0.12, 0.28)
	red_lamp.mesh = lm2
	red_lamp.material_override = red_mat
	red_lamp.position = Vector3(0.16, 1.24, 0.1)
	root.add_child(red_lamp)
	var light := SpotLight3D.new()
	light.light_color = Color(0.4, 0.55, 1.0)
	light.light_energy = 0.0
	light.spot_range = 5.0
	if "spot_attenuation" in light:
		light.spot_attenuation = 1.2
	if "spot_fov" in light:
		light.spot_fov = 85.0
	light.position = Vector3(0, 1.45, 0.1)
	light.rotation.x = -PI / 2.0
	root.add_child(light)
	result["siren"] = {"mats": [blue_mat, red_mat], "light": light, "phase": 0.0}


func _decorate_fire(root: Node3D, length: float, result: Dictionary) -> void:
	var ll := length * 0.5
	var tank_mat := StandardMaterial3D.new()
	tank_mat.albedo_color = Color(0.9, 0.9, 0.92)
	tank_mat.roughness = 0.35
	var tank := MeshInstance3D.new()
	var tkm := CylinderMesh.new()
	tkm.top_radius = 0.34
	tkm.bottom_radius = 0.34
	tkm.height = 2.0
	tank.mesh = tkm
	tank.material_override = tank_mat
	tank.rotation.x = PI / 2.0
	tank.position = Vector3(0, 1.12, 0.35)
	root.add_child(tank)
	var lad_mat := StandardMaterial3D.new()
	lad_mat.albedo_color = Color(0.75, 0.76, 0.8)
	var ladder := MeshInstance3D.new()
	var ldm := BoxMesh.new()
	ldm.size = Vector3(0.3, 0.07, 2.6)
	ladder.mesh = ldm
	ladder.material_override = lad_mat
	ladder.position = Vector3(0, 1.42, 0.25)
	root.add_child(ladder)
	var bar_mat := StandardMaterial3D.new()
	bar_mat.albedo_color = Color(0.1, 0.11, 0.14)
	var bar := MeshInstance3D.new()
	var bmx := BoxMesh.new()
	bmx.size = Vector3(0.5, 0.09, 0.26)
	bar.mesh = bmx
	bar.material_override = bar_mat
	bar.position = Vector3(0, 1.2, -ll + 0.55)
	root.add_child(bar)
	var red_mat := StandardMaterial3D.new()
	red_mat.albedo_color = Color(1, 0.25, 0.18)
	red_mat.emission = Color(1, 0.12, 0.08)
	red_mat.emission_energy_multiplier = 5.0
	var lamp := MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(0.34, 0.11, 0.22)
	lamp.mesh = lm
	lamp.material_override = red_mat
	lamp.position = Vector3(0, 1.27, -ll + 0.55)
	root.add_child(lamp)
	var light := SpotLight3D.new()
	light.light_color = Color(1.0, 0.35, 0.3)
	light.light_energy = 0.0
	light.spot_range = 5.0
	if "spot_attenuation" in light:
		light.spot_attenuation = 1.2
	if "spot_fov" in light:
		light.spot_fov = 85.0
	light.position = Vector3(0, 1.5, -ll + 0.55)
	light.rotation.x = -PI / 2.0
	root.add_child(light)
	result["siren"] = {"mats": [red_mat], "light": light, "phase": 0.35}


func _update_sirens() -> void:
	for siren in _sirens:
		var t: float = fposmod(_time * 2.2 + float(siren.get("phase", 0.0)), 1.0)
		var a_on: bool = t < 0.5
		var mats: Array = siren["mats"]
		for i in mats.size():
			var on: bool = a_on if i % 2 == 0 else not a_on
			var mat: StandardMaterial3D = mats[i]
			mat.emission_energy_multiplier = 5.0 if on else 0.25
		var light: SpotLight3D = siren["light"]
		light.light_energy = 2.5 if a_on else 0.0


func _place_car(car: Dictionary, dt: float = 0.0) -> void:
	var route: Dictionary = _routes[car["route"]]
	var sample := _sample(route, car["s"])
	var node: Node3D = car["node"]
	node.position = sample["pos"]
	var dir: Vector3 = _heading(route, car["s"], float(car["speed"]))
	if dir.length_squared() <= 0.0001:
		return
	if not car.get("oriented", false):
		node.look_at(node.position + dir, Vector3.UP)
		car["oriented"] = true
	else:
		var target := Basis.looking_at(dir, Vector3.UP)
		# fast catch-up slerp: heading stays glued to the path, corners look soft
		node.basis = node.basis.slerp(target, 1.0 - exp(-14.0 * maxf(dt, 0.016)))
	# wheel spin
	var spin: float = float(car["speed"]) / 0.26 * maxf(dt, 0.0)
	if spin > 0.0:
		for wheel in car.get("wheels", []):
			wheel.rotate_object_local(Vector3.UP, spin)


func _heading(route: Dictionary, s: float, speed: float) -> Vector3:
	# Chord over a small arc ahead of the car: the heading changes gradually
	# through corners (geometric lead, no temporal lag -> no extra clipping).
	var a: Vector3 = _sample(route, s - 0.4)["pos"]
	var b: Vector3 = _sample(route, s + 0.55 + 0.12 * speed)["pos"]
	var dir := b - a
	if dir.length_squared() < 0.0001:
		return _sample(route, s)["dir"]
	return dir.normalized()


func _sample(route: Dictionary, s: float) -> Dictionary:
	var pts: Array = route["pts"]
	var cum: Array = route["cum"]
	var length: float = route["length"]
	s = fposmod(s, length)
	var lo := 0
	var hi := cum.size() - 1
	while hi - lo > 1:
		var mid := (lo + hi) / 2
		if cum[mid] <= s:
			lo = mid
		else:
			hi = mid
	var a: Vector3 = pts[lo]
	var b: Vector3 = pts[(lo + 1) % pts.size()]
	var seg_len: float = a.distance_to(b)
	var t: float = 0.0 if seg_len < 0.0001 else (s - float(cum[lo])) / seg_len
	var pos := a.lerp(b, t)
	var dir := (b - a)
	if dir.length_squared() < 0.0001:
		dir = Vector3.FORWARD
	dir = dir.normalized()
	return {"pos": pos, "dir": dir}


func _spawn_lights() -> void:
	for light in _lights:
		var rid: String = str(light.get("route", ""))
		if _routes.has(rid):
			var route: Dictionary = _routes[rid]
			var jx: float = float(light["junction"][0])
			var jz: float = float(light["junction"][1])
			# nearest point of the route polyline (segment projection)
			var best_idx := 0
			var best_d := 1e9
			for i in route["pts"].size():
				var a: Vector3 = route["pts"][i]
				var b: Vector3 = route["pts"][(i + 1) % route["pts"].size()]
				var ab := Vector3(b.x - a.x, 0.0, b.z - a.z)
				var l2 := ab.length_squared()
				var t := 0.0 if l2 < 0.0001 else clampf(Vector3(jx - a.x, 0.0, jz - a.z).dot(ab) / l2, 0.0, 1.0)
				var p := Vector3(a.x + ab.x * t, 0.0, a.z + ab.z * t)
				var d: float = (Vector3(jx, 0.0, jz) - p).length()
				if d < best_d:
					best_d = d
					best_idx = i
				var a2: Vector3 = route["pts"][best_idx]
				var b2: Vector3 = route["pts"][(best_idx + 1) % route["pts"].size()]
				var ab2 := Vector3(b2.x - a2.x, 0.0, b2.z - a2.z)
				var l2b := ab2.length_squared()
				var tb := 0.0 if l2b < 0.0001 else clampf(Vector3(jx - a2.x, 0.0, jz - a2.z).dot(ab2) / l2b, 0.0, 1.0)
				var s_at: float = float(route["cum"][best_idx]) + tb * a2.distance_to(b2)
				light["stop_s"] = fposmod(s_at - 0.9, float(route["length"]))
			if best_d > 3.0:
				push_warning("Traffic: light %s junction is far from route %s d=%.2f" % [light.get("id", "?"), rid, best_d])
		else:
			# Decorative light (no cars on its road): just blinks.
			light["stop_s"] = 0.0
		light["state"] = 2
		light["root"] = _make_light(light)
		add_child(light["root"])
	light_count = _lights.size()


func _make_light(light: Dictionary) -> Node3D:
	var px := float(light["pole"][0])
	var pz := float(light["pole"][1])
	var root := Node3D.new()
	root.name = "TrafficLight_" + str(light.get("id", ""))
	var gy := _ground_y(Vector3(px, 0, pz))
	root.position = Vector3(px, gy, pz)
	# face the approaching car (approach direction from the route at the stop line)
	var rid2: String = str(light.get("route", ""))
	var toward: Vector3
	if _routes.has(rid2):
		var route2: Dictionary = _routes[rid2]
		var sample := _sample(route2, light["stop_s"])
		toward = -Vector3(sample["dir"])
	else:
		var face: Array = light.get("face", [0.0, -1.0])
		toward = Vector3(float(face[0]), 0.0, float(face[1]))
	root.rotation.y = atan2(toward.x, toward.z)
	var pole_mat := StandardMaterial3D.new()
	pole_mat.albedo_color = Color(0.25, 0.27, 0.3)
	pole_mat.roughness = 0.6
	var pole := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.09
	pm.bottom_radius = 0.12
	pm.height = 4.3
	pole.mesh = pm
	pole.material_override = pole_mat
	pole.position = Vector3(0, 2.15, 0)
	root.add_child(pole)
	var head_mat := StandardMaterial3D.new()
	head_mat.albedo_color = Color(0.1, 0.11, 0.13)
	head_mat.roughness = 0.4
	var head := MeshInstance3D.new()
	var hm := BoxMesh.new()
	hm.size = Vector3(0.44, 1.25, 0.4)
	head.mesh = hm
	head.material_override = head_mat
	head.position = Vector3(0, 3.7, 0)
	root.add_child(head)
	light["lamps"] = {}
	for kind in ["red", "yellow", "green"]:
		var c := Color.WHITE
		if kind == "red":
			c = Color(1, 0.12, 0.08)
		elif kind == "yellow":
			c = Color(1, 0.75, 0.1)
		else:
			c = Color(0.2, 1, 0.35)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = c.darkened(0.75)
		mat.emission = c
		mat.emission_energy_multiplier = 0.06
		var lamp := MeshInstance3D.new()
		var lm := BoxMesh.new()
		lm.size = Vector3(0.3, 0.3, 0.08)
		lamp.mesh = lm
		lamp.material_override = mat
		var y := 4.15 if kind == "red" else (3.7 if kind == "yellow" else 3.25)
		lamp.position = Vector3(0, y, 0.22)
		root.add_child(lamp)
		light["lamps"][kind] = lamp
	return root


func _update_lights() -> void:
	var green: float = _cycle["green"]
	var yellow: float = _cycle["yellow"]
	var total := green + 2.0 * yellow + green
	for light in _lights:
		var t: float = fposmod(_time + float(light.get("phase", 0.0)), total)
		var st := 0
		if t >= green and t < green + yellow:
			st = 1
		elif t >= green + yellow:
			st = 2
		if st != light["state"]:
			light["state"] = st
			state_changes += 1
		var red: MeshInstance3D = light["lamps"]["red"]
		var yellow_l: MeshInstance3D = light["lamps"]["yellow"]
		var green_l: MeshInstance3D = light["lamps"]["green"]
		_set_lamp(red, st == 2)
		_set_lamp(yellow_l, st == 1)
		_set_lamp(green_l, st == 0)


func _set_lamp(lamp: MeshInstance3D, on: bool) -> void:
	var mat: StandardMaterial3D = lamp.material_override
	mat.emission_energy_multiplier = 3.2 if on else 0.06
	mat.albedo_color = mat.emission if on else mat.emission.darkened(0.75)


func _update_cars(dt: float) -> void:
	var accel: float = float(_car_spec.get("accel", 3.0))
	var decel: float = float(_car_spec.get("decel", 4.5))
	var gap: float = float(_car_spec.get("follow_gap", 6.0))
	var range_m: float = float(_car_spec.get("follow_range", 14.0))
	for car in _cars:
		var route: Dictionary = _routes[car["route"]]
		var target: float = car["cruise"]
		# corner zones: the ring folds back at the hairpins and the lot ring
		# has 90-degree turns — a speed limit there keeps braking distances
		# short and the U-turn passing clearance reliable
		var p_now: Vector3 = _sample(route, car["s"])["pos"]
		for cz in route["corner_zones"]:
			var dz: float = Vector3(p_now.x, 0.0, p_now.z).distance_to(Vector3(float(cz[0]), 0.0, float(cz[1])))
			if dz < float(cz[2]):
				target = minf(target, float(cz[3]))
				break
		# traffic lights on this route
		for light in _lights_by_route.get(car["route"], []):
			var d: float = fposmod(float(light["stop_s"]) - float(car["s"]), float(route["length"]))
			if d < 1.2:
				# committed to (or past) the stop line: no mid-intersection brake
				continue
			# braking window for the light must cover the full queue stop
			# distance (bumper gap 3.0 m + deceleration), otherwise the car
			# behind discovers the stopped leader too late and compresses
			if d < 8.0:
				if light["state"] == 2:
					target = minf(target, 0.0)
				elif light["state"] == 1:
					var need: float = car["speed"] * car["speed"] / (2.0 * decel) + 0.8
					if d > need:
						target = minf(target, 0.0)
		# car following: kinematic (can brake to a stop before the car ahead)
		for other in _cars:
			if other["uid"] == car["uid"] or other["route"] != car["route"]:
				continue
			var d: float = fposmod(float(other["s"]) - float(car["s"]), float(route["length"]))
			if d > 0.01 and d < range_m:
				# bumper gap the two cars actually need + a full-braking margin,
				# otherwise the follower cuts into the stop envelope and rams
				# the leader's rear bumper (the chase dynamics undershoot by
				# up to v^2/2a without the margin)
				var gap_m: float = (float(car["length"]) + float(other["length"])) * 0.5 + 0.3
				var allowed: float = sqrt(2.0 * decel * maxf(d - gap_m - 2.0, 0.0))
				if d < gap:
					# platoon: match the leader (tiny epsilon so a standing
					# queue can release without a deadlock); no +0.4 allowance,
					# that allowed slow compression of the queue
					allowed = minf(allowed, float(other["speed"]) + 0.1)
				target = minf(target, allowed)
		# Global avoidance (safety net across routes): any car physically ahead
		# in the driving direction gets a kinematic brake limit. Catches rare
		# cross-route approaches where the same-route spacing model cannot see.
		var my_pos: Vector3 = _sample(route, car["s"])["pos"]
		var my_dir: Vector3 = _heading(route, car["s"], float(car["speed"]))
		for other in _cars:
			# safety net for ALL pairs (same route included): at the hairpin the
			# ring folds back, so the arc distance can be long while the XZ
			# distance of the two legs is short — the arc-only model cannot see it
			if other["uid"] == car["uid"]:
				continue
			var o_pos: Vector3 = other["node"].position
			var o_delta := Vector3(o_pos.x - my_pos.x, 0.0, o_pos.z - my_pos.z)
			var o_len: float = o_delta.length()
			if o_len < 0.001 or o_len > 7.0:
				continue
			var o_forward: float = o_delta.normalized().dot(my_dir) * o_len
			# lateral offset: a car in the opposing lane (offset >= lane width)
			# is never a risk; only a car nearly on our own lane line is
			var o_lat: float = absf(o_delta.x * my_dir.z - o_delta.z * my_dir.x)
			if o_forward < 0.2 or o_lat > 1.6:
				continue
			var gap_m2: float = (float(car["length"]) + float(other["length"])) * 0.5 + 0.3
			var o_allowed: float = sqrt(2.0 * decel * maxf(o_forward - gap_m2 - 2.0, 0.0))
			if o_forward < gap_m2 + 0.2:
				o_allowed = minf(o_allowed, float(other["speed"]) + 0.1)
			target = minf(target, o_allowed)
		if car["speed"] < target:
			car["speed"] = minf(target, car["speed"] + accel * dt)
		else:
			car["speed"] = maxf(target, car["speed"] - decel * dt)
		car["s"] = fposmod(car["s"] + car["speed"] * dt, route["length"])
		travel_total += car["speed"] * dt
		travel_by_route[car["route"]] = float(travel_by_route.get(car["route"], 0.0)) + car["speed"] * dt
		_place_car(car, dt)
		# stop event bookkeeping
		var was: bool = _was_fast[car["uid"]]
		var now_fast: bool = car["speed"] > 0.5
		if was and not now_fast:
			stop_events += 1
		_was_fast[car["uid"]] = now_fast
