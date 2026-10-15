extends Node3D
# Living town v4: pedestrians with independent plans.
#  - each walker: own destination on the plaza loop, lateral offset, yield to
#    the walker ahead (no queues / no following), loiter with a personal stand
#    offset so two people never stand at the exact same spot
#  - shoppers ENTER the kiosk through a real doorway (gap in the front wall),
#    browse the goods shelf inside, then leave the same way
#  - the child plays on the playground: walks to each piece of equipment,
#    circles it with a run-gait (the "play" clip the character set has),
#    then moves to the next activity
# Routes/shops are data-driven from island_life.json; every point is
# probe-verified against the real island collisions (heightmap scan).

const LIFESTYLE_PATH := "res://island_life.json"
# Columns that definitely have floor — "physics is ready" gate.
const PROBE_XZ := [Vector2(-48.0, 4.5), Vector2(-10.5, -15.0), Vector2(7.5, -27.0)]

var walker_count := 0
var shop_count := 0
var visit_count := 0
var travel_total := 0.0
var play_events := 0

# Free-fly camera: pedestrians yield when the observer stands in their path.
var observer: Node3D

var _routes: Array[Dictionary] = []
var _walkers: Array[Dictionary] = []
var _shops: Array[Dictionary] = []
var _models: Array[PackedScene] = []
var _spec: Dictionary = {}
var _route_lead_done := {}
var _built := false
var _frame := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 20261010


func _process(_delta: float) -> void:
	_frame += 1
	if not _built:
		if _frame >= 2 and _ground_ready():
			_build()
		elif _frame >= 600:
			push_error("IslandLife: ground never became queryable; pedestrians disabled")
			set_physics_process(false)


func _ground_ready() -> bool:
	var space := get_world_3d().direct_space_state
	if space == null:
		return false
	for p in PROBE_XZ:
		var ray := PhysicsRayQueryParameters3D.create(Vector3(p.x, 45.0, p.y), Vector3(p.x, -25.0, p.y))
		if space.intersect_ray(ray).is_empty():
			return false
	return true


func _physics_process(delta: float) -> void:
	if _built:
		_step(delta)


# Deterministic synchronous stepping (smoke tests / interleaved simulation).
func tick(delta: float) -> void:
	if _built:
		_step(delta)


func simulate(seconds: float, step_dt: float = 0.1) -> void:
	if not _built:
		_build()
	var n := int(round(seconds / step_dt))
	for i in n:
		_step(step_dt)


func _build() -> void:
	if _built:
		return
	_built = true
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(LIFESTYLE_PATH))
	if parsed is Dictionary:
		_spec = parsed
	if _spec.is_empty():
		push_error("IslandLife: cannot load ", LIFESTYLE_PATH)
		return
	for path in _spec.get("models", []):
		var packed := load(path) as PackedScene
		if packed:
			_models.append(packed)
		else:
			push_warning("IslandLife: model failed to load: ", path)
	for definition in _spec.get("routes", []):
		var rect: Array = definition["rect"]
		var step: float = float(definition.get("step", 0.5))
		var raw := _rounded_rect_loop(float(rect[0]), float(rect[1]), float(rect[2]), float(rect[3]), step)
		var points := _smooth(raw)
		var route := _finalize_route(points)
		route["name"] = str(definition.get("name", "route"))
		route["walkers"] = int(definition.get("walkers", 3))
		route["role"] = str(definition.get("role", ""))
		route["roles"] = definition.get("roles", [])
		route["model"] = int(definition.get("model", -1))
		route["models"] = definition.get("models", [])
		route["scale"] = float(definition.get("scale", 1.0))
		route["speed_min"] = float(definition.get("speed_min", _spec.get("walk_speed_min", 0.7)))
		route["speed_max"] = float(definition.get("speed_max", _spec.get("walk_speed_max", 1.15)))
		route["play_spots"] = definition.get("play_spots", [])
		# child: precompute the route point nearest to each piece of equipment
		route["play_ats"] = []
		route["play_s"] = []
		route["play_y"] = []
		for spot in route["play_spots"]:
			var best_s := 0.0
			var best_d := 1e9
			for i in int(route["length"] / 0.4):
				var s: float = float(i) * 0.4
				var at: Dictionary = _sample(route, s)
				var d: float = Vector2(float(spot[0]) - at["position"].x, float(spot[1]) - at["position"].z).length()
				if d < best_d:
					best_d = d
					best_s = s
			route["play_s"].append(best_s)
			route["play_ats"].append(_sample(route, best_s)["position"])
		# play spot floor: the equipment sits on its own base slab a little
		# below the promenade level — probe the real collision under each spot
		# (the playground is a raised rim over a sunk equipment pit)
		var space2 := get_world_3d().direct_space_state
		for i in (route["play_s"] as Array).size():
			var at2: Vector3 = route["play_ats"][i]
			var loop_y: float = float(at2.y)
			var base_y: float = loop_y
			var best_diff := 1e9
			for hy in _column_hits(Vector3(float((route["play_spots"] as Array)[i][0]), loop_y + 2.0, float((route["play_spots"] as Array)[i][1])), space2, loop_y - 0.2, loop_y - 2.6, 4):
				var dd: float = absf(float(hy) - (loop_y - 1.15))
				if dd < best_diff:
					best_diff = dd
					base_y = float(hy)
			route["play_y"].append(base_y)
		_routes.append(route)
	for definition in _spec.get("shops", []):
		_add_shop(definition)
	shop_count = _shops.size()
	var id := 0
	for route_index in _routes.size():
		var route: Dictionary = _routes[route_index]
		var count: int = int(route["walkers"])
		for i in count:
			_spawn_walker(route_index, id, count, i)
			id += 1
	walker_count = _walkers.size()
	print("ISLAND_LIFE_READY | walkers=%d shops=%d routes=%d" % [walker_count, shop_count, _routes.size()])


func _add_shop(definition: Dictionary) -> void:
	var pos := Vector3(float(definition["pos"][0]), float(definition["pos"][1]), float(definition["pos"][2]))
	var face := Vector3(float(definition["face"][0]), 0.0, float(definition["face"][1])).normalized()
	var route_index: int = int(definition.get("route", 0))
	var route: Dictionary = _routes[route_index]
	# route point nearest to the doorway = the pedestrian's pickup/drop-off
	var best_s := 0.0
	var best_d := 1e9
	for i in int(route["length"] / 0.25):
		var s: float = float(i) * 0.25
		var at: Dictionary = _sample(route, s)
		var d: float = Vector2(at["position"].x - pos.x, at["position"].z - pos.z).length()
		if d < best_d:
			best_d = d
			best_s = s
	var p0: Dictionary = _sample(route, best_s)
	var shop := _make_shop(pos, face, definition)
	# per-customer slots so two shoppers of one kiosk never share a point
	shop["slots"] = {}
	shop["node"].position = pos
	add_child(shop["node"])
	var door_world: Vector3 = shop["node"].to_global(Vector3(0.4, 0.0, 1.0))
	# the customer stands on his side of the goods counter (never behind it)
	var interior_world: Vector3 = shop["node"].to_global(Vector3(0.0, 0.0, 0.90))
	var approach_world := Vector3(door_world.x + face.x * 1.15, door_world.y, door_world.z + face.z * 1.15)
	shop["door_world"] = door_world
	shop["interior_world"] = interior_world
	shop["approach_world"] = approach_world
	shop["p0_world"] = p0["position"]
	shop["s"] = best_s
	# s of the point on the loop nearest to the approach spot: this is where a
	# shopper heading to the store should stop and step off the loop
	var app_s := best_s
	var app_d := 1e9
	for i in int(route["length"] / 0.25):
		var s: float = float(i) * 0.25
		var at: Dictionary = _sample(route, s)
		var d: float = Vector2(at["position"].x - approach_world.x, at["position"].z - approach_world.z).length()
		if d < app_d:
			app_d = d
			app_s = s
	shop["approach_s"] = app_s
	shop["route"] = route_index
	# vendor: a shopkeeper who is always inside, behind the goods counter,
	# facing the doorway; a slow body sway keeps him alive, and he sways
	# faster while a customer is browsing
	var vendor_root := Node3D.new()
	vendor_root.name = "Vendor"
	var vendor_visual: Node3D = _models[int(int(definition.get("vendor_model", 3)) % _models.size())].instantiate()
	vendor_root.add_child(vendor_visual)
	vendor_root.position = Vector3(0.35, 0.0, -0.30)
	vendor_root.rotation.y = PI
	shop["node"].add_child(vendor_root)
	var v_players := vendor_visual.find_children("*", "AnimationPlayer", true, false)
	var v_anim: AnimationPlayer = v_players[0] as AnimationPlayer if v_players.size() > 0 else null
	if v_anim:
		var v_clip := v_anim.get_animation("Walk")
		if v_clip:
			v_clip.loop_mode = Animation.LOOP_LINEAR
		v_anim.play("Walk")
		v_anim.seek(_rng.randf(), true)
		v_anim.speed_scale = 0.12
	shop["vendor"] = {"node": vendor_root, "t": _rng.randf() * TAU}
	_shops.append(shop)
	if best_d > 2.5:
		push_warning("IslandLife: shop %s door is %.1f m from its route" % [str(definition.get("pos")), best_d])


# One walker with its own plan: role, model, speed, lateral offset, stand
# offset, shop assignment (shopper -> nearest kiosk), play rotation (child).
func _spawn_walker(route_index: int, id: int, _group_size: int, walker_index: int) -> void:
	var route: Dictionary = _routes[route_index]
	var role := str(route.get("role", ""))
	var roles: Array = route.get("roles", [])
	if walker_index < roles.size():
		role = str(roles[walker_index])
	var model_id := int(route.get("model", -1))
	var models: Array = route.get("models", [])
	if walker_index < models.size():
		model_id = int(models[walker_index])
	if model_id < 0 or model_id >= _models.size():
		model_id = id % _models.size() if _models.size() > 0 else 0
	var speed := lerpf(float(route.get("speed_min", 0.75)), float(route.get("speed_max", 1.05)), _rng.randf())
	var start: float = fposmod(float(id) * float(route["length"]) / 12.0, float(route["length"]))
	# the child starts right before the first piece of playground equipment so
	# the play cycle begins within the first seconds
	if str(route.get("role", "")) == "child" and (route["play_s"] as Array).size() > 0:
		start = fposmod(float((route["play_s"] as Array)[0]) - 1.5, float(route["length"]))
	var at0: Dictionary = _sample(route, start)
	var root := Node3D.new()
	root.name = "Islander_%02d" % id
	add_child(root)
	var visual: Node3D = _models[model_id].instantiate()
	var s: float = float(route.get("scale", 1.0))
	visual.scale = Vector3(s, s, s)
	root.add_child(visual)
	var players := visual.find_children("*", "AnimationPlayer", true, false)
	var animation: AnimationPlayer = players[0] as AnimationPlayer if players.size() > 0 else null
	root.position = at0["position"]
	root.rotation.y = atan2(at0["direction"].x, at0["direction"].z)
	if animation:
		var clip := animation.get_animation("Walk")
		if clip:
			clip.loop_mode = Animation.LOOP_LINEAR
		animation.play("Walk")
		animation.seek(_rng.randf(), true)
	# shop assignment: the shoppers of a route are spread over all its kiosks
	# (walker i -> kiosk i), so every shop gets regular customers
	var shop_index := -1
	if role == "shopper":
		var route_shops: Array = []
		for si in _shops.size():
			var sh: Dictionary = _shops[si]
			if int(sh["route"]) == route_index:
				route_shops.append(si)
		if route_shops.size() > 0:
			# assign by the shopper's order among this route's shoppers (not
			# by raw walker index), so every kiosk of the route gets customers
			var shopper_order := 0
			for j in walker_index:
				var jr: String = str(route.get("role", ""))
				if j < roles.size():
					jr = str(roles[j])
				if jr == "shopper":
					shopper_order += 1
			shop_index = int(route_shops[shopper_order % route_shops.size()])
	# the first shopper of a route is the "lead shopper": he starts right
	# before the kiosk and is already in the mood to buy, so the first store
	# visit of the simulation happens within the first seconds
	var is_lead := false
	if role == "shopper" and shop_index >= 0 and not _route_lead_done.has(route_index):
		_route_lead_done[route_index] = true
		is_lead = true
	if is_lead:
		start = fposmod(float(_shops[shop_index]["approach_s"]) - 2.0, float(route["length"]))
	var cool0: float = 0.0 if is_lead else _rng.randf() * 10.0
	var dest0: float = float(_shops[shop_index]["approach_s"]) if is_lead else fposmod(start + float(route["length"]) * 0.5, float(route["length"]))
	var walker := {
		"node": root, "animation": animation, "route": route_index,
		"s": start, "dest": dest0,
		"speed": speed, "role": role, "shop": shop_index, "uid": id,
		"offset": _lane_offset(walker_index, int(route.get("walkers", 1))),
		"state": "walk",
		"state_left": 0.0, "state_yaw": 0.0,
		"cool": cool0,
		"detour": [], "detour_i": 0, "detour_next": "walk",
		"play_index": id % ((route["play_s"] as Array).size()) if (route["play_s"] as Array).size() > 0 else 0,
		"play_angle": _rng.randf() * TAU,
		"travelled": 0.0,
	}
	_walkers.append(walker)


func _step(delta: float) -> void:
	# shopkeepers sway behind their counters; livelier while a customer
	# is browsing this kiosk
	for si in _shops.size():
		var sh: Dictionary = _shops[si]
		var vendor: Dictionary = sh["vendor"]
		vendor["t"] = float(vendor["t"]) + delta
		var busy := false
		for w in _walkers:
			if str(w["state"]) == "shop_in" and int(w["shop"]) == si:
				busy = true
				break
		vendor["node"].rotation.y = PI + sin(float(vendor["t"]) * (1.8 if busy else 0.6)) * (0.45 if busy else 0.22)
	for walker in _walkers:
		var route: Dictionary = _routes[int(walker["route"])]
		var node: Node3D = walker["node"]
		var animation: AnimationPlayer = walker["animation"]
		var speed: float = float(walker["speed"])
		match str(walker["state"]):
			"loiter":
				_do_loiter(walker, route, node, animation, delta)
			"play":
				_do_play(walker, route, node, animation, delta)
			"shop_go":
				_do_detour(walker, node, animation, delta)
			"shop_in":
				_do_shop_in(walker, node, animation, delta)
			_:
				_do_walk(walker, route, node, animation, delta)


# ---- states -------------------------------------------------------------

func _do_walk(walker: Dictionary, route: Dictionary, node: Node3D, animation: AnimationPlayer, delta: float) -> void:
	var length: float = route["length"]
	var role: String = str(walker["role"])
	# the child's destination is always the next piece of playground equipment
	var play_s: Array = route["play_s"]
	if role == "child" and play_s.size() > 0:
		walker["dest"] = float(play_s[int(walker["play_index"])])
	else:
		# independent destination: a fresh point 25..85% of the loop ahead;
		# shoppers deliberately aim for their kiosk about 60% of the time
		var ahead: float = fposmod(float(walker["dest"]) - float(walker["s"]), length)
		if ahead < 0.2 or ahead > 0.9 * length:
			var shop_index: int = int(walker["shop"])
			if role == "shopper" and shop_index >= 0 and _rng.randf() < 0.6:
				walker["dest"] = float(_shops[shop_index]["approach_s"])
			else:
				walker["dest"] = fposmod(float(walker["s"]) + length * _rng.randf_range(0.25, 0.8), length)
	# yield: a walker close ahead (same loop) gets right of way — the follower
	# creeps at a speed proportional to the gap instead of hard-stopping, which
	# prevents queues, body overlap and synchronized walking
	var move_speed: float = float(walker["speed"])
	for other in _walkers:
		if other == walker or int(other["route"]) != int(walker["route"]):
			continue
		var d: float = fposmod(float(other["s"]) - float(walker["s"]), length)
		if d > 0.25 and d < 1.6:
			move_speed = minf(move_speed, maxf(0.0, (d - 0.30) * 1.5))
	if is_instance_valid(observer):
		var to_obs: Vector3 = observer.global_position - node.global_position
		if Vector3(to_obs.x, 0.0, to_obs.z).length() < 1.0:
			move_speed = 0.0
	# positional yield: a crossing or loitering walker is visible by
	# position, not by s; the even walker breaks stand-offs with a sidestep
	var dir_now: Vector3 = _sample(route, float(walker["s"]))["direction"]
	move_speed = _ped_yield(walker, node, dir_now, move_speed, delta)
	walker["s"] = fposmod(float(walker["s"]) + move_speed * delta, length)
	var at: Dictionary = _sample(route, float(walker["s"]))
	var perp := Vector3(-at["direction"].z, 0.0, at["direction"].x)
	node.position = at["position"] + perp * float(walker["offset"])
	# sidestep pulse (deadlock breaker): a sideways nudge while blocked
	if float(walker.get("sidestep_left", 0.0)) > 0.0:
		var side := perp * float(walker.get("sidestep_dir", 1.0))
		node.position += side * minf(float(walker["sidestep_left"]), 1.2 * delta)
		walker["sidestep_left"] = float(walker["sidestep_left"]) - delta
	var target_yaw: float = atan2(at["direction"].x, at["direction"].z)
	node.rotation.y = lerp_angle(node.rotation.y, target_yaw, 1.0 - exp(-10.0 * delta))
	if animation:
		# ease the gait toward the target speed (smooth start/stop, no freeze
		# mid-stride)
		var target_scale: float = move_speed / 0.9
		animation.speed_scale = lerpf(animation.speed_scale, target_scale, 1.0 - exp(-6.0 * delta))
	var moved: float = move_speed * delta
	walker["travelled"] = float(walker["travelled"]) + moved
	travel_total += moved
	walker["cool"] = float(walker["cool"]) - delta
	# arrived?
	if fposmod(float(walker["s"]) - float(walker["dest"]), length) < 0.25 or fposmod(float(walker["dest"]) - float(walker["s"]), length) < 0.25:
		var shop_index: int = int(walker["shop"])
		if role == "child" and play_s.size() > 0:
			# walk over to the piece of equipment itself (it sits a little
			# below the loop, on its own base), then play on it
			var play_spots: Array = route["play_spots"]
			var idx: int = int(walker["play_index"])
			var spot: Vector3 = Vector3(float(play_spots[idx][0]), float(route["play_y"][idx]), float(play_spots[idx][1]))
			walker["s"] = float(walker["dest"])
			walker["state"] = "shop_go"
			walker["detour"] = [node.global_position, spot]
			walker["detour_i"] = 1
			walker["detour_next"] = "play"
			return
		elif role == "shopper" and shop_index >= 0 and float(walker["cool"]) <= 0.0:
			var sh: Dictionary = _shops[shop_index]
			if node.global_position.distance_to(sh["approach_world"]) < 2.4:
				# a fixed personal slot in front of the goods counter (the
				# customer side, never behind it): two shoppers of this kiosk
				# never occupy the same point
				var slots: Dictionary = sh["slots"]
				var uid: int = int(walker["uid"])
				if not slots.has(uid):
					slots[uid] = slots.size() % 2
				var boff_x: float = (float(slots[uid]) * 2.0 - 1.0) * 0.35
				walker["state"] = "shop_go"
				walker["browse_pos"] = sh["node"].to_global(Vector3(boff_x, 0.0, 0.90))
				walker["detour"] = [
					node.global_position,
					sh["approach_world"] + sh["node"].basis.x * boff_x * 0.5,
					sh["door_world"] + sh["node"].basis.x * boff_x * 0.5,
					walker["browse_pos"],
				]
				walker["detour_i"] = 1
				return
		# default: personal pause — look around, then a new destination
		walker["state"] = "loiter"
		walker["state_left"] = _rng.randf_range(1.5, 4.0)
		walker["state_yaw"] = node.rotation.y + _rng.randf_range(-2.4, 2.4)


# Lane assignment: the walkers of one loop get distinct lateral lanes
# (0..n-1 -> -0.45..+0.45 m), so two passing walkers keep a real gap
# instead of walking the same line shoulder to shoulder.
func _lane_offset(walker_index: int, lane_n: int) -> float:
	if lane_n <= 1:
		return 0.0
	return (float(walker_index) / float(lane_n - 1) - 0.5) * 0.9


# Positional right of way: any walker close by (any direction) earns the
# right of way — creep proportionally to the gap, stop at shoulder distance.
# A side approach is no less dangerous than a head-on one, so the cone is
# full 360 degrees. When a mutual stand-off lasts more than a couple of
# seconds, the even-priority walker resolves it with a sideways sidestep.
func _ped_yield(walker: Dictionary, node: Node3D, dir: Vector3, base_speed: float, delta: float) -> float:
	var speed: float = base_speed
	var blocked := false
	var side_dir: Vector3 = Vector3(-dir.z, 0.0, dir.x)
	for other in _walkers:
		var on: Node3D = other["node"]
		if on == node:
			continue
		var to: Vector3 = on.global_position - node.global_position
		var d: float = Vector3(to.x, 0.0, to.z).length()
		if d > 0.9 or d < 0.001:
			continue
		# smooth following in the own lane is the job of the s-based yield;
		# here we only watch crossers (other routes, corner crossings, side
		# approaches) and standing people (loiter, shop, play)
		var same_lane: bool = int(other["route"]) == int(walker["route"]) and str(other["state"]) == "walk" and absf(to.normalized().dot(side_dir)) <= 0.25
		if same_lane:
			continue
		var ahead: float = to.normalized().dot(dir)
		var stop_dist: float = 0.45 if ahead > 0.3 else 0.6
		var v: float = maxf(0.0, (d - stop_dist) * 2.0)
		if v < speed:
			speed = v
			if v <= 0.02:
				blocked = true
	if blocked:
		walker["blocked_t"] = float(walker.get("blocked_t", 0.0)) + delta
		var clear_ahead := true
		for other in _walkers:
			if other == walker:
				continue
			var to: Vector3 = other["node"].global_position - node.global_position
			var d2: float = Vector3(to.x, 0.0, to.z).length()
			if d2 < 0.5 and d2 > 0.001 and to.normalized().dot(dir) > 0.7:
				clear_ahead = false
				break
		if clear_ahead:
			# the stop is sideways or already passed — creep forward
			speed = maxf(speed, 0.3)
		elif int(walker["uid"]) % 2 == 0 and float(walker["blocked_t"]) > 2.0 and float(walker.get("sidestep_left", 0.0)) <= 0.0:
			if float(walker.get("sidestep_left", 0.0)) <= 0.0:
				# head-on stand-off: the even walker sidesteps AWAY from the
				# nearest blocker to break it
				var side: Vector3 = Vector3(-dir.z, 0.0, dir.x)
				var nearest_to: Vector3 = Vector3.ZERO
				var nearest_d: float = 1e9
				for other in _walkers:
					if other == walker:
						continue
					var to: Vector3 = other["node"].global_position - node.global_position
					var d2: float = Vector3(to.x, 0.0, to.z).length()
					if d2 < nearest_d:
						nearest_d = d2
						nearest_to = to
				if nearest_d < 2.0:
					var sgn: float = -signf(nearest_to.dot(side))
					if sgn == 0.0:
						sgn = 1.0
					walker["sidestep_dir"] = sgn
				else:
					walker["sidestep_dir"] = -float(walker.get("sidestep_dir", 1.0))
				walker["sidestep_left"] = 0.7
	else:
		walker["blocked_t"] = 0.0
	return speed


func _do_loiter(walker: Dictionary, route: Dictionary, node: Node3D, animation: AnimationPlayer, delta: float) -> void:
	# stands on his own lateral spot (never shifts forward onto the path
	# ahead of him) and turns around looking at the square
	var at: Dictionary = _sample(route, float(walker["s"]))
	var perp := Vector3(-at["direction"].z, 0.0, at["direction"].x)
	node.position = at["position"] + perp * float(walker["offset"])
	node.rotation.y = lerp_angle(node.rotation.y, float(walker["state_yaw"]), 1.0 - exp(-2.0 * delta))
	if animation:
		animation.speed_scale = maxf(0.0, animation.speed_scale - 3.0 * delta)
	walker["state_left"] = float(walker["state_left"]) - delta
	if float(walker["state_left"]) <= 0.0:
		walker["state"] = "walk"
		# a small personal tempo change so the walk is not metronomic
		walker["speed"] = clampf(float(walker["speed"]) * _rng.randf_range(0.85, 1.15), float(route["speed_min"]), float(route["speed_max"]))
		walker["dest"] = fposmod(float(walker["s"]) + float(route["length"]) * _rng.randf_range(0.25, 0.8), float(route["length"]))


func _do_play(walker: Dictionary, route: Dictionary, node: Node3D, animation: AnimationPlayer, delta: float) -> void:
	# the child plays AT the equipment: it alternates two phases —
	# "fiddle" (stands at the equipment edge, reaches and touches it with a
	# small gait) and "circle" (runs a lap around it at a fast gait). After a
	# while it walks back to the loop and over to the next equipment.
	var play_s: Array = route["play_s"]
	var idx: int = int(walker["play_index"])
	var play_spots: Array = route["play_spots"]
	var spot_arr: Array = play_spots[idx]
	var center: Vector3 = Vector3(float(spot_arr[0]), float(route["play_y"][idx]), float(spot_arr[1]))
	var equip_r: float = float(spot_arr[2]) if spot_arr.size() > 2 else 0.6
	var loop_point: Vector3 = (route["play_ats"] as Array)[idx]
	# keep the lap inside the promenade (never onto the path of other walkers)
	var clearance: float = center.distance_to(loop_point) - 0.6
	var circle_r: float = maxf(minf(equip_r + 0.45, clearance), equip_r * 0.9)
	var fiddle_r: float = maxf(equip_r + 0.1, circle_r * 0.6)
	walker["play_t"] = float(walker.get("play_t", 0.0)) + delta
	var fiddle: bool = fposmod(float(walker["play_t"]), 3.4) < 1.4
	if not fiddle:
		walker["play_angle"] = float(walker["play_angle"]) + delta * 1.6
	var a: float = float(walker["play_angle"])
	var radius: float = fiddle_r if fiddle else circle_r
	var pos := center + Vector3(cos(a), 0.0, sin(a)) * radius
	pos.y = center.y
	node.position = pos
	if fiddle:
		node.rotation.y = lerp_angle(node.rotation.y, atan2(center.x - pos.x, center.z - pos.z), 1.0 - exp(-8.0 * delta))
		if animation:
			animation.speed_scale = lerpf(animation.speed_scale, 0.3, 1.0 - exp(-6.0 * delta))
	else:
		var tangent := Vector3(-sin(a), 0.0, cos(a))
		node.rotation.y = lerp_angle(node.rotation.y, atan2(tangent.x, tangent.z), 1.0 - exp(-10.0 * delta))
		if animation:
			animation.speed_scale = lerpf(animation.speed_scale, 1.6, 1.0 - exp(-6.0 * delta))
	walker["state_left"] = float(walker["state_left"]) - delta
	walker["s"] = float(play_s[idx])
	var played_moved: float = delta * (0.4 if fiddle else 1.4)
	walker["travelled"] = float(walker["travelled"]) + played_moved
	travel_total += played_moved
	if float(walker["state_left"]) <= 0.0:
		# walk back over to the loop (no teleport), then continue to the
		# next piece of equipment
		walker["play_t"] = 0.0
		# the child runs over to the NEAREST remaining piece of equipment
		# (kids bounce between the nearby bits instead of touring the lot)
		var best_i: int = (idx + 1) % play_s.size()
		var best_d: float = 1e9
		for j in play_s.size():
			if j == idx:
				continue
			var pj: float = float(play_s[j])
			var d: float = minf(fposmod(pj - float(walker["s"]), float(route["length"])), fposmod(float(walker["s"]) - pj, float(route["length"])))
			if d < best_d:
				best_d = d
				best_i = j
		walker["play_index"] = best_i
		walker["s"] = float(play_s[idx])
		walker["state"] = "shop_go"
		walker["detour"] = [node.global_position, loop_point]
		walker["detour_i"] = 1
		walker["detour_next"] = "walk"


# Detour walking (to the kiosk door and back). Waypoints carry their own Y
# (probe level of the plaza), so the path stays glued to the floor.
func _do_detour(walker: Dictionary, node: Node3D, animation: AnimationPlayer, delta: float) -> void:
	var detour: Array = walker["detour"]
	var i: int = int(walker["detour_i"])
	var next_state := str(walker.get("detour_next", "walk"))
	if i >= detour.size():
		# arrived: either back on the loop, or the equipment is reached and
		# the play phase starts
		walker["detour_next"] = "walk"
		if next_state == "play":
			walker["state"] = "play"
			walker["state_left"] = _rng.randf_range(2.5, 5.0)
			walker["play_t"] = 0.0
			walker["play_angle"] = _rng.randf() * TAU
			play_events += 1
			return
		walker["state"] = "walk"
		walker["dest"] = fposmod(float(walker["s"]) + float(_routes[int(walker["route"])]["length"]) * 0.5, float(_routes[int(walker["route"])]["length"]))
		return
	# interior waypoint: the shopper is inside — browse the goods
	if detour.size() == 4 and i == 3:
		node.position = detour[3]
		walker["state"] = "shop_in"
		walker["state_left"] = _rng.randf_range(3.5, 7.0)
		walker["cool"] = _rng.randf_range(25.0, 40.0)
		walker["detour"] = [detour[2], detour[1], detour[0]]
		walker["detour_i"] = 0
		visit_count += 1
		return
	var target: Vector3 = detour[i]
	var to: Vector3 = target - node.global_position
	var dist: float = to.length()
	if dist < 0.12:
		walker["detour_i"] = i + 1
		return
	var dir: Vector3 = to.normalized()
	var detour_speed: float = _ped_yield(walker, node, dir, float(walker["speed"]), delta)
	var moved: float = minf(dist, detour_speed * delta)
	node.position = node.global_position + dir * moved
	# sidestep pulse (deadlock breaker), same as on the main loop
	if float(walker.get("sidestep_left", 0.0)) > 0.0:
		var perp: Vector3 = Vector3(-dir.z, 0.0, dir.x) * float(walker.get("sidestep_dir", 1.0))
		node.position += perp * minf(float(walker["sidestep_left"]), 1.2 * delta)
		walker["sidestep_left"] = float(walker["sidestep_left"]) - delta
	node.rotation.y = lerp_angle(node.rotation.y, atan2(dir.x, dir.z), 1.0 - exp(-12.0 * delta))
	if animation:
		animation.speed_scale = float(walker["speed"]) / 0.9
	walker["travelled"] = float(walker["travelled"]) + moved
	travel_total += moved


func _do_shop_in(walker: Dictionary, node: Node3D, animation: AnimationPlayer, delta: float) -> void:
	# inside the kiosk: stands before the goods shelf (facing the back wall)
	var shop_index: int = int(walker["shop"])
	if shop_index < 0:
		walker["state"] = "walk"
		return
	var sh: Dictionary = _shops[shop_index]
	var face: Vector3 = sh["node"].basis.z
	node.position = walker.get("browse_pos", sh["interior_world"])
	node.rotation.y = lerp_angle(node.rotation.y, atan2(-face.x, -face.z), 1.0 - exp(-4.0 * delta))
	if animation:
		animation.speed_scale = maxf(0.0, animation.speed_scale - 3.0 * delta)
	walker["state_left"] = float(walker["state_left"]) - delta
	if float(walker["state_left"]) <= 0.0:
		walker["state"] = "shop_go"


# ---- geometry -----------------------------------------------------------

# Rounded rectangle loop: the corners are arcs of radius 0.6 m so the lane
# offsets (±0.45 m) stay parallel around the turn — two adjacent-lane
# walkers keep their gap at the corner instead of converging.
func _rounded_rect_loop(x0: float, z0: float, x1: float, z1: float, step: float) -> PackedVector3Array:
	var r: float = minf(minf(0.6, (x1 - x0) * 0.45), (z1 - z0) * 0.45)
	var arc_n := 4
	var points := PackedVector3Array()
	# edge along z0 (east)
	var x: float = x0 + r
	points.append(Vector3(x0 + r, 0.0, z0))
	while x < x1 - r - 0.001:
		x += step
		points.append(Vector3(minf(x, x1 - r), 0.0, z0))
	# SE arc
	for i in range(1, arc_n + 1):
		var th: float = -PI / 2.0 + (PI / 2.0) * float(i) / float(arc_n)
		points.append(Vector3(x1 - r + r * cos(th), 0.0, z0 + r + r * sin(th)))
	# edge along x1 (north)
	var z: float = z0 + r
	while z < z1 - r - 0.001:
		z += step
		points.append(Vector3(x1, 0.0, minf(z, z1 - r)))
	# NE arc
	for i in range(1, arc_n + 1):
		var th: float = (PI / 2.0) * float(i) / float(arc_n)
		points.append(Vector3(x1 - r + r * cos(th), 0.0, z1 - r + r * sin(th)))
	# edge along z1 (west)
	var x2: float = x1 - r
	while x2 > x0 + r + 0.001:
		x2 -= step
		points.append(Vector3(maxf(x2, x0 + r), 0.0, z1))
	# NW arc
	for i in range(1, arc_n + 1):
		var th: float = PI / 2.0 + (PI / 2.0) * float(i) / float(arc_n)
		points.append(Vector3(x0 + r + r * cos(th), 0.0, z1 - r + r * sin(th)))
	# edge along x0 (south)
	var z2: float = z1 - r
	while z2 > z0 + r + 0.001:
		z2 -= step
		points.append(Vector3(x0, 0.0, maxf(z2, z0 + r)))
	# SW arc
	for i in range(1, arc_n + 1):
		var th: float = PI + (PI / 2.0) * float(i) / float(arc_n)
		points.append(Vector3(x0 + r + r * cos(th), 0.0, z0 + r + r * sin(th)))
	return points


func _rect_loop(x0: float, z0: float, x1: float, z1: float, step: float) -> PackedVector3Array:
	var points := PackedVector3Array()
	var x := x0
	points.append(Vector3(x0, 0.0, z0))
	while x < x1 - 0.001:
		x += step
		points.append(Vector3(minf(x, x1), 0.0, z0))
	var z := z0
	while z < z1 - 0.001:
		z += step
		points.append(Vector3(x1, 0.0, minf(z, z1)))
	while x > x0 + 0.001:
		x -= step
		points.append(Vector3(maxf(x, x0), 0.0, z1))
	while z > z0 + 0.001:
		z -= step
		points.append(Vector3(x0, 0.0, maxf(z, z0)))
	return points


func _smooth(points: PackedVector3Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	var n := points.size()
	for i in n:
		var a: Vector3 = points[i]
		var b: Vector3 = points[(i + 1) % n]
		out.append(a.lerp(b, 0.25))
		out.append(a.lerp(b, 0.75))
	return out


func _finalize_route(points: PackedVector3Array) -> Dictionary:
	var space := get_world_3d().direct_space_state
	var first_ys := []
	for point in points:
		var hs: Array = _column_hits(point, space, 45.0, -25.0, 6)
		first_ys.append(float(hs[0]) if hs.size() > 0 else -999.0)
	var level := _median(first_ys)
	var refined := PackedVector3Array()
	var prev_y := level
	for point in points:
		prev_y = _nearest_surface(point, space, prev_y)
		refined.append(Vector3(point.x, prev_y, point.z))
	refined.append(refined[0])
	var cum := PackedFloat32Array([0.0])
	for i in range(1, refined.size()):
		cum.append(cum[-1] + refined[i].distance_to(refined[i - 1]))
	return {"points": refined, "cum": cum, "length": cum[-1]}


func _column_hits(pos: Vector3, space, top: float, bottom: float, max_hits: int) -> Array:
	var out := []
	var from := Vector3(pos.x, top, pos.z)
	for i in max_hits:
		var ray := PhysicsRayQueryParameters3D.create(from, Vector3(pos.x, bottom, pos.z))
		var hit: Dictionary = space.intersect_ray(ray)
		if hit.is_empty():
			break
		out.append(hit.position.y)
		from = Vector3(pos.x, hit.position.y - 0.06, pos.z)
		if from.y < bottom:
			break
	return out


func _median(ys: Array) -> float:
	var good := []
	for y in ys:
		if float(y) > -900.0:
			good.append(float(y))
	good.sort()
	return float(good[good.size() / 2]) if good.size() > 0 else 20.0


func _nearest_surface(pos: Vector3, space, level: float) -> float:
	var best := level
	var best_diff := 1.2
	var hs: Array = _column_hits(pos, space, 45.0, -25.0, 6)
	for y in hs:
		var d := absf(float(y) - level)
		if d < best_diff:
			best = float(y)
			best_diff = d
	return best


func _sample(route: Dictionary, distance: float) -> Dictionary:
	var points: PackedVector3Array = route["points"]
	var cum: PackedFloat32Array = route["cum"]
	distance = fposmod(distance, float(route["length"]))
	var lo := 0
	var hi := cum.size() - 1
	while hi - lo > 1:
		var mid: int = (lo + hi) / 2
		if cum[mid] <= distance:
			lo = mid
		else:
			hi = mid
	var span: float = maxf(cum[hi] - cum[lo], 0.0001)
	var weight: float = (distance - cum[lo]) / span
	var a: Vector3 = points[lo]
	var b: Vector3 = points[hi]
	var position: Vector3 = a.lerp(b, weight)
	var direction := Vector3((b - a).x, 0.0, (b - a).z)
	if direction.length_squared() < 0.0001:
		direction = Vector3.FORWARD
	return {"position": position, "direction": direction.normalized()}


# ---- enterable kiosk ----------------------------------------------------

func _make_shop(pos: Vector3, face: Vector3, definition: Dictionary) -> Dictionary:
	var root := Node3D.new()
	root.name = "Shop_%02d" % _shops.size()
	root.rotation.y = atan2(face.x, face.z)
	var awning_color := Color(definition.get("awning", "#e2574c"))
	var sign_color := Color(definition.get("sign", "#ffd23e"))
	var light_color := Color(definition.get("light", "#ffdf9e"))
	# walls: back, sides, and a FRONT wall with a 0.8 m doorway gap
	_box(root, Vector3(2.6, 1.6, 0.12), Vector3(0, 0.8, -1.0), Color("6b5648"), 0.8)
	_box(root, Vector3(0.12, 1.6, 2.0), Vector3(-1.3, 0.8, 0.0), Color("6b5648"), 0.8)
	_box(root, Vector3(0.12, 1.6, 2.0), Vector3(1.3, 0.8, 0.0), Color("6b5648"), 0.8)
	_box(root, Vector3(0.65, 1.6, 0.12), Vector3(-0.975, 0.8, 1.0), Color("6b5648"), 0.8)
	_box(root, Vector3(0.55, 1.6, 0.12), Vector3(1.075, 0.8, 1.0), Color("6b5648"), 0.8)
	# door frame around the gap
	_box(root, Vector3(0.1, 1.6, 0.16), Vector3(0.0, 0.8, 1.0), Color("3a2f28"), 0.7)
	_box(root, Vector3(0.1, 1.6, 0.16), Vector3(0.8, 0.8, 1.0), Color("3a2f28"), 0.7)
	_box(root, Vector3(0.9, 0.1, 0.16), Vector3(0.4, 1.6, 1.0), Color("3a2f28"), 0.7)
	# roof + front posts + awning
	_box(root, Vector3(3.0, 0.08, 2.5), Vector3(0, 1.72, 0.1), Color("4a3b33"), 0.7)
	_cylinder(root, 0.05, 1.7, Vector3(-1.35, 0.85, 1.2), Color("3a2f28"))
	_cylinder(root, 0.05, 1.7, Vector3(1.35, 0.85, 1.2), Color("3a2f28"))
	var awning := _box(root, Vector3(2.9, 0.07, 1.3), Vector3(0, 1.66, 1.4), awning_color, 0.5)
	awning.rotation.x = -0.12
	# sign (emissive)
	_box(root, Vector3(2.3, 0.5, 0.1), Vector3(0, 2.05, 1.25), sign_color, 0.2, true, sign_color, 2.8)
	# counter + goods + back shelf
	_box(root, Vector3(2.2, 0.95, 0.45), Vector3(0, 0.475, 0.55), Color("8a6d52"), 0.6)
	_box(root, Vector3(2.2, 0.3, 0.25), Vector3(0, 0.95, -0.85), Color("7a5f48"), 0.7)
	var goods := [Color("d84343"), Color("43b0d8"), Color("e8c33e"), Color("58b368")]
	for i in 4:
		_box(root, Vector3(0.34, 0.3, 0.34), Vector3(-0.8 + float(i) * 0.53, 1.18, 0.55), goods[i], 0.4)
	for i in 3:
		_box(root, Vector3(0.4, 0.26, 0.2), Vector3(-0.7 + float(i) * 0.7, 1.1, -0.85), goods[(i + 1) % 4], 0.4)
	var light := SpotLight3D.new()
	light.light_color = light_color
	light.light_energy = 1.2
	light.spot_range = 7.0
	if "spot_attenuation" in light:
		light.spot_attenuation = 1.1
	if "spot_fov" in light:
		light.spot_fov = 75.0
	light.position = Vector3(0, 1.9, 0.3)
	light.rotation.x = -PI / 2.0
	root.add_child(light)
	# collision: the kiosk is solid (the player camera body respects it); the
	# shapes sit at the real wall positions, so the doorway gap is real too
	var body := StaticBody3D.new()
	root.add_child(body)
	for wall in [
		[Vector3(2.6, 1.6, 0.12), Vector3(0.0, 0.8, -1.0)],
		[Vector3(0.12, 1.6, 2.0), Vector3(-1.3, 0.8, 0.0)],
		[Vector3(0.12, 1.6, 2.0), Vector3(1.3, 0.8, 0.0)],
		[Vector3(0.65, 1.6, 0.12), Vector3(-0.975, 0.8, 1.0)],
		[Vector3(0.55, 1.6, 0.12), Vector3(1.075, 0.8, 1.0)]
	]:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = wall[0]
		shape.shape = box
		shape.position = wall[1]
		body.add_child(shape)
	return {"node": root}


func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, roughness: float,
		emissive := false, emit_color: Color = Color.WHITE, energy := 1.0) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	if emissive:
		mat.emission = emit_color
		mat.emission_energy_multiplier = energy
	node.material_override = mat
	parent.add_child(node)
	return node


func _cylinder(parent: Node3D, radius: float, height: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	node.mesh = mesh
	node.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	node.material_override = mat
	parent.add_child(node)
	return node
