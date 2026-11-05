extends Node3D
# Route audit: for sampled points of candidate lanes, report
#  - top ground y (first hit from above)
#  - layer hits (how many surfaces above ground in the column)
#  - horizontal probe ahead (wall/building in the driving direction)

var _t := 0
var _ok := 0
var _space
var _done := false


func _ready() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_title("ROUTE-AUDIT")
	var glb: PackedScene = load("res://assets/polygon_mini_free.glb")
	var inst: Node = glb.instantiate()
	var t := Transform3D()
	t = t.scaled(Vector3(3.0, 3.0, 3.0))
	t.origin = Vector3(6.3, 26.25, 13.19)
	inst.transform = t
	add_child(inst)
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh:
			var body := StaticBody3D.new()
			var shape := CollisionShape3D.new()
			shape.shape = mi.mesh.create_trimesh_shape()
			mi.add_child(body)
			body.add_child(shape)
	_space = get_world_3d().direct_space_state


func _process(_delta: float) -> void:
	if _done:
		return
	_t += 1
	if _t < 5:
		return
	if _down(Vector3(0, 45, 40)).is_empty():
		if _t > 60:
			print("AUDIT_FAIL physics")
			get_tree().quit(1)
		return
	_ok += 1
	if _ok < 3:
		return
	_run()


func _down(pos: Vector3) -> Dictionary:
	var ray := PhysicsRayQueryParameters3D.create(pos, pos + Vector3(0, -80.0, 0))
	return _space.intersect_ray(ray)


func _column(pos: Vector3, max_hits: int) -> Array:
	var out := []
	var from := Vector3(pos.x, 45.0, pos.z)
	for i in max_hits:
		var ray := PhysicsRayQueryParameters3D.create(from, Vector3(pos.x, -25.0, pos.z))
		var hit: Dictionary = _space.intersect_ray(ray)
		if hit.is_empty():
			break
		out.append(hit.position.y)
		from = Vector3(pos.x, hit.position.y - 0.06, pos.z)
	return out


func _forward_hit(pos: Vector3, dir: Vector3, range_m: float) -> Dictionary:
	var ray := PhysicsRayQueryParameters3D.create(pos, pos + dir * range_m)
	return _space.intersect_ray(ray)


func _audit_line(name: String, x: float, z0: float, z1: float, step: float, dir: Vector3) -> void:
	var out := "LANE %s x=%.1f z %.1f..%.1f dir=%s : " % [name, x, z0, z1, str(dir)]
	var problems := 0
	var z := z0
	var first_y := 0.0
	while z <= z1 + 0.001:
		var hs: Array = _column(Vector3(x, 0, z), 6)
		if hs.is_empty():
			out += " [%.1f:VOID]" % z
			problems += 1
		else:
			# road level = first hit, but if a second surface is >1.5m above it
			# the lane is under a roof/overhang
			var top: float = hs[0]
			if first_y == 0.0:
				first_y = top
			var over := 0.0
			for i in range(1, hs.size()):
				if float(hs[i]) - top > 0.4 and float(hs[i]) - top < 4.0:
					over = float(hs[i])
					break
			var wall := _forward_hit(Vector3(x, top + 0.6, z), dir, 2.6)
			var walltag := ""
			if not wall.is_empty():
				var wd: float = wall.position.distance_to(Vector3(x, top + 0.6, z))
				walltag = "W%.1f" % wd
				problems += 1
			var yflag := ""
			if absf(top - first_y) > 1.2:
				yflag = "!"
			var otag := ""
			if over > 0.0:
				otag = "O%.1f" % over
				problems += 1
			out += " z%.1f:y%.2f%s%s%s " % [z, top, yflag, otag, walltag]
		z += step
	if problems == 0:
		out += "  << CLEAR"
	print(out)


func _audit_point(name: String, x: float, z: float) -> void:
	var hs: Array = _column(Vector3(x, 0, z), 8)
	if hs.is_empty():
		print("POINT %s (%.1f,%.1f): VOID" % [name, x, z])
		return
	print("POINT %s (%.1f,%.1f): hits=[%s]" % [name, x, z, " ".join(hs.map(func(v): return "%.2f" % v))])


func _run() -> void:
	_done = true
	print("=== CURRENT ROUTES (audit for building clipping) ===")
	_audit_line("main-south", 5.5, -1.0, 65.0, 2.0, Vector3(0, 0, 1))
	_audit_line("main-north", 8.5, -1.0, 65.0, 2.0, Vector3(0, 0, -1))
	_audit_line("main-branch-s", 16.0, 68.0, 77.0, 2.0, Vector3(0, 0, 1))
	_audit_line("main-branch-n", 15.0, 68.0, 77.0, 2.0, Vector3(0, 0, -1))
	_audit_line("parking-old", 1.5, -11.5, -7.0, 2.0, Vector3(1, 0, 0))
	print("=== CANDIDATE LANES ===")
	_audit_line("west-s", -2.0, 0.0, 60.0, 2.0, Vector3(0, 0, 1))
	_audit_line("west-n", 1.5, 0.0, 60.0, 2.0, Vector3(0, 0, -1))
	_audit_line("east-s", 13.5, 0.0, 62.0, 2.0, Vector3(0, 0, 1))
	_audit_line("east-n", 18.5, 0.0, 62.0, 2.0, Vector3(0, 0, -1))
	_audit_line("ew-mid", 0.0, 63.0, 68.0, 1.0, Vector3(1, 0, 0))
	print("=== POINTS ===")
	_audit_point("junction-e", 16.0, 65.0)
	_audit_point("junction-e2", 20.0, 65.0)
	_audit_point("octagon-c", 15.5, 73.7)
	_audit_point("octagon-e", 18.5, 72.0)
	_audit_point("octagon-w", 12.5, 72.0)
	_audit_point("lot-sw", -3.0, 1.5)
	_audit_point("lot-se", 14.0, 1.5)
	_audit_point("lot-nw", -3.0, -12.0)
	_audit_point("lot-ne", 14.0, -12.0)
	_audit_point("lot-c", 5.0, -5.0)
	_audit_point("play-a", -20.0, 29.0)
	_audit_point("play-b", -16.0, 30.0)
	_audit_point("play-c", -31.0, 31.0)
	_audit_point("play-d", -24.5, 33.0)
	_audit_point("play-old", -37.5, 32.8)
	_audit_point("deck-a", -32.0, 3.0)
	_audit_point("terr-a", -7.5, -10.5)
	_audit_point("mids-a", 5.0, -19.0)
	_audit_point("se-a", 19.5, 83.5)
	_audit_point("wh-a", -44.2, 76.7)
	_audit_point("wp-a", -35.5, 46.5)
	print("AUDIT_DONE")
	get_tree().quit(0)
