extends Node3D
# The world ground: a huge walkable low-poly land ring around the floating
# diorama — the "land" the player lives on. Grass top with a cross of dirt
# paths, ~220 trees, rocks, low hills and lamp posts; a rim wall on the
# outer edge keeps the player from falling into the void. The top sits
# ~14 cm below the island's own perimeter level, so stepping from the land
# onto the island is a small curb. The deck is four slabs (a ring) — it
# never goes under the island itself, so the ground probes of the island
# life keep hitting the real terrain.

var deck_top: float = 25.9

const B_SOUTH := Vector4(-250.0, 86.0, 250.0, 250.0)
const B_NORTH := Vector4(-250.0, -250.0, 250.0, -30.0)
const B_WEST := Vector4(-250.0, -30.0, -50.0, 86.0)
const B_EAST := Vector4(30.0, -30.0, 250.0, 86.0)
const ISLAND_BOX := Vector4(-50.0, -30.0, 30.0, 90.0)

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 424242
	var body := StaticBody3D.new()
	body.name = "DeckBody"
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	var grass := Color("7aa55f")
	for band in [B_SOUTH, B_NORTH, B_WEST, B_EAST]:
		_box(body, _band_size(band), _band_center(band), grass, true)
	# earth rim wall on the outer edge — the player cannot fall into the void
	var rim := Color("8a6f4d")
	_box(body, Vector3(501.2, 1.1, 0.6), Vector3(0.0, deck_top + 0.55, 250.3), rim, true)
	_box(body, Vector3(501.2, 1.1, 0.6), Vector3(0.0, deck_top + 0.55, -250.3), rim, true)
	_box(body, Vector3(0.6, 1.1, 501.2), Vector3(-250.3, deck_top + 0.55, 0.0), rim, true)
	_box(body, Vector3(0.6, 1.1, 501.2), Vector3(250.3, deck_top + 0.55, 0.0), rim, true)
	_decorate()
	print("ISLAND_DECK_READY | land: 4 bands (500x500), top y=%.2f" % deck_top)


func _band_size(b: Vector4) -> Vector3:
	return Vector3(float(b[2]) - float(b[0]), 4.0, float(b[3]) - float(b[1]))


func _band_center(b: Vector4) -> Vector3:
	return Vector3((float(b[0]) + float(b[2])) * 0.5, deck_top - 2.0, (float(b[1]) + float(b[3])) * 0.5)


func _box(parent: Node, size: Vector3, center: Vector3, color: Color, solid: bool) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	bm.material = mat
	mi.mesh = bm
	mi.position = center
	parent.add_child(mi)
	if solid:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		cs.position = center
		parent.add_child(cs)


func _on_deck(x: float, z: float) -> bool:
	for band in [B_SOUTH, B_NORTH, B_WEST, B_EAST]:
		if x > float(band[0]) + 1.5 and x < float(band[2]) - 1.5 and z > float(band[1]) + 1.5 and z < float(band[3]) - 1.5:
			return true
	return false


func _in_island(x: float, z: float, margin: float) -> bool:
	return x > float(ISLAND_BOX[0]) - margin and x < float(ISLAND_BOX[2]) + margin and z > float(ISLAND_BOX[1]) - margin and z < float(ISLAND_BOX[3]) + margin


func _on_path(x: float, z: float, margin: float) -> bool:
	# the four dirt path spines (5 m wide)
	if absf(x - 16.5) < margin + 2.5 and z > 84.0:
		return true
	if absf(x) < margin + 2.5 and z < -28.0:
		return true
	if absf(z - 28.0) < margin + 2.5 and x < -48.0:
		return true
	if absf(z - 28.0) < margin + 2.5 and x > 28.0:
		return true
	return false


func _decor() -> Node:
	var d := Node3D.new()
	d.name = "DeckDecor"
	add_child(d)
	return d


func _box_m(parent: Node, size: Vector3, center: Vector3, color: Color, yaw: float = 0.0) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	bm.material = mat
	mi.mesh = bm
	mi.position = center
	mi.rotation.y = yaw
	parent.add_child(mi)


func _paths(deco: Node) -> void:
	var dirt := Color("cbb289")
	_box_m(deco, Vector3(5.0, 0.06, 164.0), Vector3(16.5, deck_top + 0.03, 168.0), dirt)
	_box_m(deco, Vector3(5.0, 0.06, 220.0), Vector3(0.0, deck_top + 0.03, -140.0), dirt)
	_box_m(deco, Vector3(200.0, 0.06, 5.0), Vector3(-150.0, deck_top + 0.03, 28.0), dirt)
	_box_m(deco, Vector3(220.0, 0.06, 5.0), Vector3(140.0, deck_top + 0.03, 28.0), dirt)


func _decorate() -> void:
	var deco := _decor()
	_paths(deco)
	var greens: Array = [Color("5e9e57"), Color("6fae62"), Color("4f8f4a"), Color("7fb97a")]
	var shades: Array = [Color("74a058"), Color("80ac66"), Color("6e9c53"), Color("86b26e")]
	# grass patches — subtle tone variation over the meadow
	var tries := 0
	var patches := 0
	while patches < 120 and tries < 600:
		tries += 1
		var px: float = _rng.randf_range(-244.0, 244.0)
		var pz: float = _rng.randf_range(-244.0, 244.0)
		if _in_island(px, pz, 4.0) or not _on_deck(px, pz):
			continue
		var s: float = _rng.randf_range(3.0, 9.0)
		_box_m(deco, Vector3(s, 0.03, s), Vector3(px, deck_top + 0.015, pz), shades[patches % shades.size()], _rng.randf_range(0.0, TAU))
		patches += 1
	# low hills near the rim — a living horizon
	var mounds: Array = [
		[-210.0, 210.0, 40.0], [210.0, -210.0, 34.0], [215.0, 205.0, 30.0],
		[-215.0, -60.0, 38.0], [90.0, -220.0, 30.0], [-90.0, -220.0, 26.0],
		[-225.0, 150.0, 24.0], [225.0, 140.0, 28.0],
	]
	for m in mounds:
		var h: float = _rng.randf_range(2.0, 5.0)
		_box_m(deco, Vector3(float(m[2]), h, float(m[2]) * 0.8), Vector3(float(m[0]), deck_top + h * 0.5 - 0.3, float(m[1])), Color("6a9a58"))
	# trees: a scattered low-poly forest
	var placed: Array = []
	var count := 0
	tries = 0
	while count < 220 and tries < 4000:
		tries += 1
		var px: float = _rng.randf_range(-244.0, 244.0)
		var pz: float = _rng.randf_range(-244.0, 244.0)
		if _in_island(px, pz, 4.0):
			continue
		if not _on_deck(px, pz):
			continue
		if _on_path(px, pz, 1.5):
			continue
		if Vector2(px, pz).distance_to(Vector2(16.5, 81.9)) < 8.0:
			continue
		var ok := true
		for q in placed:
			if Vector2(px, pz).distance_to(q) < 5.0:
				ok = false
				break
		if not ok:
			continue
		placed.append(Vector2(px, pz))
		count += 1
		_tree(deco, px, pz, greens[count % greens.size()])
	# rocks
	tries = 0
	var rocks := 0
	while rocks < 40 and tries < 400:
		tries += 1
		var px: float = _rng.randf_range(-244.0, 244.0)
		var pz: float = _rng.randf_range(-244.0, 244.0)
		if _in_island(px, pz, 3.0) or not _on_deck(px, pz) or _on_path(px, pz, 1.0):
			continue
		var s: float = _rng.randf_range(0.6, 2.2)
		_box_m(deco, Vector3(s, s * 0.6, s), Vector3(px, deck_top + s * 0.3, pz), Color("9aa0a8"), _rng.randf_range(0.0, TAU))
		rocks += 1
	# lamps on the inner ring around the island
	for lp in _lamp_positions():
		_lamp(deco, float(lp[0]), float(lp[1]))
	# benches
	for bp in _bench_positions():
		_bench(deco, float(bp[0]), float(bp[1]))


func _tree(deco: Node, x: float, z: float, green: Color) -> void:
	_box_m(deco, Vector3(0.35, 1.4, 0.35), Vector3(x, deck_top + 0.7, z), Color("7a5a40"))
	var s2: float = _rng.randf_range(1.8, 2.6)
	var yaw: float = _rng.randf_range(0.0, TAU)
	_box_m(deco, Vector3(s2, 2.2, s2), Vector3(x, deck_top + 2.4, z), green, yaw)
	if _rng.randf() < 0.5:
		var s3: float = s2 * 0.6
		_box_m(deco, Vector3(s3, 1.4, s3), Vector3(x, deck_top + 3.9, z), green, yaw + 0.6)


func _lamp_positions() -> Array:
	var out: Array = []
	for x in [-70.0, -40.0, -10.0, 20.0, 50.0]:
		out.append([x, 103.0])
		out.append([x - 10.0, -53.0])
	for z in [0.0, 40.0, 70.0]:
		out.append([-83.0, z])
		out.append([63.0, z])
	return out


func _lamp(deco: Node, x: float, z: float) -> void:
	_box_m(deco, Vector3(0.18, 3.2, 0.18), Vector3(x, deck_top + 1.6, z), Color("3f444d"))
	var head_mat := StandardMaterial3D.new()
	head_mat.albedo_color = Color("ffdf9e")
	head_mat.emission_enabled = true
	head_mat.emission = Color("ffca6a")
	head_mat.emission_energy_multiplier = 1.5
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.5, 0.22, 0.5)
	bm.material = head_mat
	mi.mesh = bm
	mi.position = Vector3(x, deck_top + 3.3, z)
	deco.add_child(mi)


func _bench_positions() -> Array:
	return [
		[35.0, 98.0], [-25.0, 98.0],
		[-58.0, 50.0], [58.0, 50.0],
		[58.0, 10.0], [-58.0, 10.0],
		[16.5, 130.0], [0.0, -70.0], [-100.0, 28.0], [100.0, 28.0],
	]


func _bench(deco: Node, x: float, z: float) -> void:
	var wood := Color("8a6a4a")
	_box_m(deco, Vector3(1.6, 0.14, 0.55), Vector3(x, deck_top + 0.45, z), wood)
	_box_m(deco, Vector3(0.12, 0.45, 0.45), Vector3(x - 0.65, deck_top + 0.22, z), Color("4a4f57"))
	_box_m(deco, Vector3(0.12, 0.45, 0.45), Vector3(x + 0.65, deck_top + 0.22, z), Color("4a4f57"))
