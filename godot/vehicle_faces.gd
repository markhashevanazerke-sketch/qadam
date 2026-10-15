extends SceneTree
func _initialize():call_deferred("go")
func go():
	var world=Node3D.new();root.add_child(world)
	var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("668697");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.8;world.add_child(env)
	var sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-35,-15,0);world.add_child(sun)
	for i in 4:
		var id="blue_car" if i<2 else "bus"
		var n=load("res://assets/nazerke_kit/"+id+".glb").instantiate();world.add_child(n);n.position=Vector3((i%2)*7,0,(i/2)*10)
		if id=="blue_car":
			for c in n.get_children():c.rotation.y+=.68658856
		if i%2==1:n.rotation.y=PI
		var l=Label3D.new();l.text=id+(" / +Z" if i%2==0 else " / -Z");l.position=n.position+Vector3(0,3.8,0);l.billboard=BaseMaterial3D.BILLBOARD_ENABLED;l.font_size=55;l.pixel_size=.009;world.add_child(l)
	var cam=Camera3D.new();world.add_child(cam);cam.position=Vector3(3.5,10,24);cam.look_at(Vector3(3.5,0,5));cam.projection=Camera3D.PROJECTION_ORTHOGONAL;cam.size=18
	await create_timer(2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../previews/vehicle_front_audit.png");quit()
