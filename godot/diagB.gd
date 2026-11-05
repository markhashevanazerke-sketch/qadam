extends Node3D
# Top-down render via the ROOT window (SubViewport 3D is broken in this build).
# Window: 810x1064 (aspect ~108.65/142.5), ortho camera size 142.5 m (vertical).

var _shot := false
var _t := 0


func _ready() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_title("TOPDOWN-SCAN")
	DisplayServer.window_set_size(Vector2i(810, 1064))
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


func _process(_delta: float) -> void:
	if _shot:
		return
	_t += 1
	if _t < 6:
		return
	_shot = true
	RenderingServer.frame_post_draw.connect(_capture_once)


func _capture_once() -> void:
	RenderingServer.frame_post_draw.disconnect(_capture_once)
	var img: Image = get_viewport().get_texture().get_image()
	var w := img.get_width()
	var h := img.get_height()
	print("TOPDOWN_IMAGE %dx%d" % [w, h])
	img.save_png("C:/Users/Леново/map_top3.png")
	# Grid: 108 cols x 142 rows over the island box (x -54.32..54.33, z -31.81..110.69)
	var span_x: float = 142.5 * float(w) / float(h)
	var lines := []
	for wy in range(142):
		var row := ""
		for wx in range(108):
			var xw: float = -54.32 + float(wx) * 108.65 / 108.0
			var zw: float = -31.81 + float(wy) * 142.5 / 142.0
			var px := int((xw + span_x / 2.0) / span_x * float(w))
			var py := int((zw + 31.81) / 142.5 * float(h))
			px = clampi(px, 0, w - 1)
			py = clampi(py, 0, h - 1)
			var c := img.get_pixel(px, py)
			var r := int(c.r * 255)
			var g := int(c.g * 255)
			var b := int(c.b * 255)
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
