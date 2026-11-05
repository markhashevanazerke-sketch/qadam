extends SceneTree
var scene:Node3D
func _initialize():call_deferred("run")
func run():
	root.size=Vector2i(900,600)
	scene=Node3D.new();root.add_child(scene)
	var environment=WorldEnvironment.new();var env=Environment.new();environment.environment=env
	env.background_mode=Environment.BG_COLOR;env.background_color=Color("78848a")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_energy=.85;scene.add_child(environment)
	var sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-40,-30,0);scene.add_child(sun)
	var camera=Camera3D.new();scene.add_child(camera);camera.current=true;camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	for id in ["townhouse","solar_house","apartment","shops","round_tower","square_tower"]:
		var model=load("res://assets/nazerke_kit/"+id+".glb").instantiate();scene.add_child(model)
		var box=AABB();var first=true
		for m in model.find_children("*","MeshInstance3D",true,false):
			var b=m.global_transform*m.get_aabb();box=b if first else box.merge(b);first=false
			for i in m.mesh.get_surface_count():
				var material=m.get_active_material(i).duplicate();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;m.set_surface_override_material(i,material)
		for side in 4:
			var direction:Vector3=[Vector3(0,0,1),Vector3(1,0,0),Vector3(0,0,-1),Vector3(-1,0,0)][side]
			var center=Vector3(box.get_center().x,2.0,box.get_center().z)
			camera.size=maxf(box.size.x,box.size.z)+1.0
			camera.position=center+direction*30+Vector3(0,1,0);camera.look_at(center)
			await process_frame;await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/doors_%s_%d.png"%[id,side])
		model.free()
	quit()
