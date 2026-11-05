extends SceneTree
func _initialize():call_deferred("capture")
func capture():
	var world=Node3D.new();root.add_child(world)
	var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("7e9da7");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.8;world.add_child(env)
	var sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-40,-25,0);world.add_child(sun)
	var cam=Camera3D.new();world.add_child(cam);cam.projection=Camera3D.PROJECTION_ORTHOGONAL;cam.size=24;cam.current=true
	var tag="after" if "--after" in OS.get_cmdline_user_args() else "before"
	for id in ["townhouse","solar_house","apartment","shops","round_tower","square_tower"]:
		var model=load("res://assets/nazerke_kit/"+id+".glb").instantiate();world.add_child(model)
		var height=20.0 if id in ["round_tower","square_tower"] else 10.0
		cam.size=32.0 if height>15 else 24.0
		for side in [-1,1]:
			cam.position=Vector3(20*side,14,22*side);cam.look_at(Vector3(0,height*.48,0))
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../previews/building_"+id+"_"+str(side)+"_"+tag+".png"))
		model.queue_free();await process_frame
	print("BUILDING_AUDIT_CAPTURED ",tag);quit()
