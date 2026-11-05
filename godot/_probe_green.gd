extends SceneTree
var game:Node3D
func scan(node:Node,room:Node3D) -> void:
	var nd:=node as Node3D
	if nd!=null and nd.is_visible_in_tree():
		var col:Color=Color.WHITE
		var tag:=""
		if node is MeshInstance3D:
			var m:MeshInstance3D=node
			if m.mesh and m.mesh.get_surface_count()>0:
				var sm:Material=m.get_active_material(0)
				if sm is StandardMaterial3D:
					col=(sm as StandardMaterial3D).albedo_color
					tag="mesh"
		elif node is MultiMeshInstance3D:
			var mm:MultiMeshInstance3D=node
			var smm:Material=mm.multimesh.get_material()
			if smm is StandardMaterial3D:col=(smm as StandardMaterial3D).albedo_color
			tag="multi"
		else:
			for c in node.get_children():scan(c,room)
			return
		# greenish: g notably higher than r and b
		if tag!="" and col.g>0.45 and col.g>col.r+0.12 and col.g>col.b+0.12:
			var local:Vector3=room.global_transform.affine_inverse()*nd.global_position
			print("GRNG | ",node.name," ",tag," col=",col," local=",local)
	for c in node.get_children():scan(c,room)
func run() -> void:
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await create_timer(3).timeout
	game.automated=true
	game.set_capture(true)
	if is_instance_valid(game.main_menu) and game.main_menu.active:
		game.main_menu.close_menu()
	await create_timer(0.5).timeout
	game.shop_visits._transition(4)
	var guard:float=0.0
	while game.shop_visits.busy and guard<10.0:
		await create_timer(0.1).timeout;guard+=0.1
	var room:Node3D=game.shop_visits.rooms[4]
	print("GRNG | scanning room=",room.name)
	scan(room,room)
	print("GRNG | done")
	quit(0)
func _initialize() -> void:
	call_deferred("run")
