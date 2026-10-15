extends SceneTree
func _initialize():call_deferred("run")
func run():
	var game=load("res://main.tscn").instantiate();root.add_child(game)
	await create_timer(2).timeout
	for i in game.town.buildings.size():
		var b=game.town.footprints[i]
		if (b.position.z<42 and b.end.z>34) or (b.position.z< -34 and b.end.z> -42):print("BUILDING ",game.town.buildings[i].name," ",b)
	for n in game.town.get_children():
		if n is Node3D and absf(absf(n.position.x)-34)<.01 and absf(absf(n.position.z)-38)<.01:
			var bounds=AABB();var first=true
			for m in n.find_children("*","MeshInstance3D",true,false):
				var b=(game.town.global_transform.affine_inverse()*m.global_transform)*m.get_aabb()
				bounds=b if first else bounds.merge(b);first=false
			print("PARKED ",n.position," ",bounds)
	quit()
