extends SceneTree
func _initialize():call_deferred("run")
func run() -> void:
	var game=load("res://main.tscn").instantiate();root.add_child(game)
	await create_timer(2).timeout
	game.set_physics_process(false)
	var town=game.town
	var space=town.get_world_3d().direct_space_state
	assert(town.parked_vehicles.size()==2)
	for i in town.parked_vehicles.size():
		var car:Node3D=town.parked_vehicles[i]
		var b:AABB=car.get_meta("local_bounds")
		assert(car.global_basis.get_scale().is_equal_approx(Vector3.ONE),"Original car size")
		assert(absf(b.position.x)<23.3 and absf(b.end.x)<23.3,"Outside traffic lane")
		for j in town.buildings.size():assert(not b.grow(.5).intersects(town.footprints[j]),"Car clear of facade")
		var shape:=BoxShape3D.new();shape.size=(b.size-Vector3(0,.1,0))*town.scale+Vector3(.2,0,.2)
		var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.collision_mask=1
		query.transform.origin=town.to_global(b.get_center()+Vector3(0,.05,0))
		# Godot returns a copy of the exclusion array, assign the completed list.
		var exclusions:Array[RID]=[]
		for body in car.find_children("*","StaticBody3D",true,false):exclusions.append(body.get_rid())
		query.exclude=exclusions
		assert(space.intersect_shape(query).is_empty(),"No walls, trees or lamps intersect car")
		# A pedestrian can pass on the courtyard side of the entire parking bay.
		var capsule:=CapsuleShape3D.new();capsule.radius=.35;capsule.height=1.75
		query.shape=capsule;query.exclude=[]
		var walk_x:float=b.end.x+.8 if car.position.x<0 else b.position.x-.8
		query.transform.origin=town.to_global(Vector3(walk_x,.035,b.position.z-.6))+Vector3(0,.92,0)
		query.motion=town.global_basis*Vector3(0,0,b.size.z+1.2)
		assert(space.intersect_shape(query).is_empty() and space.cast_motion(query)[0]>.99,"Clear pedestrian passage")
		print("PARKING_CLEARANCE_PASS | ",car.name," | bounds=",b," | no facade overlap | original size | walkable passage")
		if "--capture" in OS.get_cmdline_user_args():
			game.camera.global_position=town.to_global(car.position+Vector3(5,0,6))+Vector3(0,1.65,0)
			game.camera.look_at(car.global_position+Vector3(0,.8,0))
			await process_frame;await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../previews/parking_fixed_%d.png"%i))
	print("PARKING_CHECK_PASS");quit()
