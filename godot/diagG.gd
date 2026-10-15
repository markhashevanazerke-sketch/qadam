extends Node3D
# diagG v3: renders ORIGINAL and CLEANED island top-down in the same scene
# (same camera/lighting, two sequential captures, synchronous free) and
# diffs them. Only the removed cars should differ.

const OUT_A := "res://../../map_orig2.png"
const OUT_B := "res://../../map_clean.png"
const CAM_SIZE := 142.5
const CAM_Z := 39.44


func _ready() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_title("diagG v3")
	DisplayServer.window_set_size(Vector2i(810, 1064))

	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.05, 0.07)
	env_node.environment = env
	add_child(env_node)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, -30.0, 0.0)
	sun.light_energy = 1.4
	add_child(sun)

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = CAM_SIZE
	cam.position = Vector3(0.0, 200.0, CAM_Z)
	cam.rotation.x = -PI / 2.0
	cam.current = true
	add_child(cam)

	var holder := Node3D.new()
	add_child(holder)

	var t := Transform3D()
	t = t.scaled(Vector3(3.0, 3.0, 3.0))
	t.origin = Vector3(6.3, 26.25, 13.19)

	var a = load("res://assets/polygon_mini_free.glb").instantiate()
	a.transform = t
	holder.add_child(a)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img_a: Image = get_viewport().get_texture().get_image()
	img_a.save_png(ProjectSettings.globalize_path(OUT_A))
	holder.remove_child(a)
	a.free()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw

	var b = load("res://assets/polygon_mini_free_clean.glb").instantiate()
	b.transform = t
	holder.add_child(b)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img_b: Image = get_viewport().get_texture().get_image()
	img_b.save_png(ProjectSettings.globalize_path(OUT_B))
	print("DIAGG | capture a=%dx%d b=%dx%d" % [img_a.get_width(), img_a.get_height(), img_b.get_width(), img_b.get_height()])
	print("DIAGG | a non-bg: %d bg=%s center=%s" % [_count_nonbg(img_a), img_a.get_pixel(0, 0), img_a.get_pixel(img_a.get_width() / 2, img_a.get_height() / 2)])
	print("DIAGG | b non-bg: %d bg=%s center=%s" % [_count_nonbg(img_b), img_b.get_pixel(0, 0), img_b.get_pixel(img_b.get_width() / 2, img_b.get_height() / 2)])

	var w: int = minf(img_a.get_width(), img_b.get_width())
	var h: int = minf(img_a.get_height(), img_b.get_height())
	var span_x: float = CAM_SIZE * float(w) / float(h)

	# pixel shift that minimizes the diff (window asymmetry guard)
	var best := 1e18
	var best_dx := 0
	var best_dy := 0
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var score := 0
			for y in range(0, h, 4):
				var yb: int = y + dy
				if yb < 0 or yb >= h:
					continue
				for x in range(0, w, 4):
					var xb: int = x + dx
					if xb < 0 or xb >= w:
						continue
					var d: float = _dcol(img_a.get_pixel(x, y), img_b.get_pixel(xb, yb))
					if d > 0.25:
						score += 1
			if score < best:
				best = score
				best_dx = dx
				best_dy = dy
	print("DIAGG | best shift dx=%d dy=%d score=%d" % [best_dx, best_dy, best])

	# whole-island changed map: rows z -35..115, cols x -60..60, 5 m cells
	print("DIAGG | whole-island map (cols x -60..60, rows z -35..115, cell 5 m):")
	var zz := -35.0
	while zz < 115.0:
		var line := ""
		var xx := -60.0
		while xx < 60.0:
			var cnt := 0
			var ch := 0
			var sy := int(((zz - CAM_Z) / CAM_SIZE + 0.5) * float(h))
			var sy_end := int(((zz + 5.0 - CAM_Z) / CAM_SIZE + 0.5) * float(h))
			var sx := int(((xx + span_x / 2.0) / span_x) * float(w))
			var sx_end := int(((xx + 5.0 + span_x / 2.0) / span_x) * float(w))
			for y in range(maxi(sy, 0), mini(sy_end, h)):
				for x in range(maxi(sx, 0), mini(sx_end, w)):
					var d: float = _dcol(img_a.get_pixel(x, y), img_b.get_pixel(x, y))
					ch += 1
					if d > 0.25:
						cnt += 1
			var fr: float = float(cnt) / float(ch) if ch > 0 else 0.0
			if fr > 0.5:
				line += "#"
			elif fr > 0.15:
				line += "+"
			elif fr > 0.02:
				line += "."
			else:
				line += " "
			xx += 5.0
		print(line)
		zz += 5.0
	print("DIAGG_DONE")
	get_tree().quit(0)


func _dcol(pa: Color, pb: Color) -> float:
	return absf(pa.r - pb.r) + absf(pa.g - pb.g) + absf(pa.b - pb.b)


func _count_nonbg(img: Image) -> int:
	var n := 0
	for y in range(0, img.get_height(), 2):
		for x in range(0, img.get_width(), 2):
			var c: Color = img.get_pixel(x, y)
			if absf(c.r - 0.05) + absf(c.g - 0.05) + absf(c.b - 0.07) > 0.1:
				n += 1
	return n
