extends Node3D
# Inspect: island GLB node tree (find static car nodes) + character animation clips.

var _done := false


func _ready() -> void:
	var city: Node = load("res://assets/polygon_mini_free.glb").instantiate()
	add_child(city)
	print("=== ISLAND NODE TREE ===")
	_dump(city, 0)
	print("=== CHARACTERS ===")
	var models := [
		"res://assets/characters/teen-boy_walk.glb",
		"res://assets/characters/cartoon_asian__boy_walk.glb",
		"res://assets/characters/free_stylized_cartoon_girl_rigged_character_walk.glb",
		"res://assets/characters/free_cartoon_game_man_character_rigged_walk.glb",
		"res://assets/characters/everyday_jane_walk.glb",
	]
	for path in models:
		var scene: PackedScene = load(path)
		if scene == null:
			print("MODEL_FAIL ", path)
			continue
		var root: Node = scene.instantiate()
		var players := root.find_children("*", "AnimationPlayer", true, false)
		var anims := []
		for p in players:
			var ap: AnimationPlayer = p
			for name in ap.get_animation_list():
				anims.append(name)
		var meshes := root.find_children("*", "MeshInstance3D", true, false)
		var bones := root.find_children("*", "Bone", true, false)
		var sk := root.find_children("*", "Skeleton3D", true, false)
		print("MODEL %s | anims=%s meshes=%d bones=%d skeletons=%d" % [path.get_file(), str(anims), meshes.size(), bones.size(), sk.size()])
		# root node type and visual bounding box
		var box := AABB()
		var has_box := false
		for m in meshes:
			var mi: MeshInstance3D = m
			if mi.mesh:
				var surf_box: AABB = mi.mesh.get_aabb()
				var global_box: AABB = mi.global_transform * surf_box
				if not has_box:
					box = global_box
					has_box = true
				else:
					box = box.merge(global_box)
		if has_box:
			print("  size=(%.2f,%.2f,%.2f) center=(%.1f,%.1f,%.1f)" % [box.size.x, box.size.y, box.size.z, box.position.x, box.position.y, box.position.z])
	if _done:
		return
	_done = true
	get_tree().quit(0)


func _dump(node: Node, depth: int) -> void:
	var prefix := ""
	for i in depth:
		prefix += "  "
	var extra := ""
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node
		var msize := "no-mesh"
		if mi.mesh:
			var b: AABB = mi.mesh.get_aabb()
			var w: AABB = mi.global_transform * b
			msize = "local %.1fx%.1fx%.1f | world box x %.1f..%.1f z %.1f..%.1f y %.1f..%.1f" % [
				b.size.x, b.size.y, b.size.z,
				w.position.x, w.end.x, w.position.z, w.end.z, w.position.y, w.end.y]
		extra = " [mesh:%s]" % msize
	elif node is StaticBody3D or node is RigidBody3D:
		extra = " [body]"
	print("%s%s (%s)%s" % [prefix, node.name, node.get_class(), extra])
	if depth < 3:
		for child in node.get_children():
			_dump(child, depth + 1)
