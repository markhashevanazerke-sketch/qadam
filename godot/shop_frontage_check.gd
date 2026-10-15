extends SceneTree
func _initialize():call_deferred("run")
func run() -> void:
	var game=load("res://main.tscn").instantiate();root.add_child(game)
	await create_timer(2).timeout
	game.set_physics_process(false)
	var town=game.town
	var space=town.get_world_3d().direct_space_state
	for shop in town.shops:
		var index:int=town.buildings.find(shop)
		var box:AABB=town.footprints[index]
		var north_gap:=INF;var south_gap:=INF
		for i in town.buildings.size():
			if town.buildings[i]==shop:continue
			var neighbor:AABB=town.footprints[i]
			assert(not box.intersects(neighbor),"Shop intersects adjacent building")
			if absf(town.buildings[i].position.x-shop.position.x)>8:continue
			if neighbor.end.z<=box.position.z:north_gap=minf(north_gap,box.position.z-neighbor.end.z)
			if neighbor.position.z>=box.end.z:south_gap=minf(south_gap,neighbor.position.z-box.end.z)
		assert(north_gap>.15 and north_gap<3 and south_gap>.15 and south_gap<3,"Shop must sit between two nearby houses")
		var query:=PhysicsShapeQueryParameters3D.new();var capsule:=CapsuleShape3D.new()
		capsule.radius=.35;capsule.height=1.75;query.shape=capsule;query.collision_mask=1
		query.transform.origin=shop.to_global(Vector3(2.8,.12,0))+Vector3(0,.9,0)
		assert(space.intersect_shape(query).is_empty(),"Door landing clear")
		query.motion=shop.global_basis*Vector3(2.5,0,0)
		assert(space.cast_motion(query)[0]>.99,"Door connected to sidewalk")
		print("SHOP_FRONTAGE_PASS | ",shop.get_meta("shop_title")," | gaps=",north_gap," / ",south_gap," | clear entrance")
		if "--capture" in OS.get_cmdline_user_args():
			game.camera.global_position=shop.to_global(Vector3(12,0,1))+Vector3(0,1.75,0)
			game.camera.look_at(shop.to_global(Vector3(0,1.8,0)))
			await process_frame;await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../previews/shop_frontage_%d.png"%town.shops.find(shop)))
	print("SHOP_FRONTAGE_CHECK_PASS");quit()
