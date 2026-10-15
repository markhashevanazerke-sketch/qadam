extends Node3D
# Real geometry scan: island + collisions, then
#  1) height map probe (first hit from above) -> road vs building levels
#  2) top-down render (root window) + correct color grid

const GRID_W := 108
const GRID_H := 142
const X0 := -54.32
const Z0 := -31.81
const X1 := 54.33
const Z1 := 110.69

var _shot := false
var _t := 0
var _ok := 0
var _space
var _hmap_done := false


func _ready() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_title("HMAP-SCAN")
	DisplayServer.window_set_size(Vector2i(810, 506))
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.16, 0.35, 0.66)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 20, 0)
	sun.light_energy = 1.2
	add_child(sun)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 142.5
	cam.position = Vector3(0, 200, 39.44)
	cam.rotation.x = -PI / 2.0
	cam.current = true
	add_child(cam)
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
	if _shot:
		return
	_t += 1
	if _t < 5:
		return
	if not _hmap_done:
		if _probe(Vector3(0, 45.0, 40.0)).is_empty():
			if _t > 40:
				print("HMAP_FAIL physics not ready")
				get_tree().quit(1)
			return
		_ok += 1
		if _ok < 3:
			return
		_write_heightmap()
		_hmap_done = true
	_shot = true
	RenderingServer.frame_post_draw.connect(_capture_once)


func _probe(pos: Vector3) -> Dictionary:
	if _space == null:
		return {}
	var ray := PhysicsRayQueryParameters3D.create(pos, pos + Vector3(0, -80.0, 0))
	return _space.intersect_ray(ray)


func _write_heightmap() -> void:
	var rows := []
	var x := X0
	while x <= X1 + 0.01:
		var row := ""
		var z := Z0
		while z <= Z1 + 0.01:
			var hit: Dictionary = _probe(Vector3(x, 45.0, z))
			var h: float = -99.0 if hit.is_empty() else hit.position.y
			row += "%05.1f " % h
			z += 2.0
		rows.append(row)
		x += 2.0
	var f := FileAccess.open("C:/Users/Леново/hmap.txt", FileAccess.WRITE)
	f.store_string("cols x: %.2f..%.2f step 2.0 / rows z: %.2f..%.2f step 2.0\n" % [X0, X1, Z0, Z1])
	f.store_string("\n".join(rows) + "\n")
	f.close()
	print("HMAP_DONE")


func _capture_once() -> void:
	RenderingServer.frame_post_draw.disconnect(_capture_once)
	var img: Image = get_viewport().get_texture().get_image()
	var w := img.get_width()
	var h := img.get_height()
	print("TOPDOWN_IMAGE %dx%d" % [w, h])
	img.save_png("C:/Users/Леново/map_top3.png")
	var span_x: float = 142.5 * float(w) / float(h)
	var lines := []
	for wy in range(GRID_H):
		var row := ""
		for wx in range(GRID_W):
			var xw: float = X0 + float(wx) * (X1 - X0) / float(GRID_W)
			var zw: float = Z0 + float(wy) * (Z1 - Z0) / float(GRID_H)
			var px := int((xw + span_x / 2.0) / span_x * float(w))
			var py := int((zw - Z0) / (Z1 - Z0) * float(h))
			px = clampi(px, 0, w - 1)
			py = clampi(py, 0, h - 1)
			var c := img.get_pixel(px, py)
			var r := int(c.r * 255.0)
			var g := int(c.g * 255.0)
			var b := int(c.b * 255.0)
			var ch := "?"
			if r < 100 and g < 130 and b > 120:
				ch = "."
			elif b > 170 and g >= 105:
				ch = "w"
			elif r > 200 and g > 200 and b > 170:
				ch = "P"
			elif abs(r - g) < 30 and abs(g - b) < 30 and (r + g + b) / 3 >= 75 and (r + g + b) / 3 <= 175:
				ch = "A"
			elif g > r and g >= b:
				ch = "G"
			elif r + g + b < 225:
				ch = "D"
			else:
				ch = "B"
			row += ch
		lines.append(row)
	var f := FileAccess.open("C:/Users/Леново/grid3.txt", FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	print("MAP_TOP3_DONE")
	get_tree().call_deferred("quit", 0)
