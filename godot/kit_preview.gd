extends SceneTree
func _initialize(): call_deferred("go")
func go():
	var world=Node3D.new();root.add_child(world)
	var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("7e9da7");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.7;world.add_child(env)
	var sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-55,-20,0);world.add_child(sun)
	var names=["round_tower","square_tower","apartment","townhouse","solar_house","shops","blue_car","bus","tree","lamp"]
	for i in names.size():
		var n=load("res://assets/nazerke_kit/"+names[i]+".glb").instantiate();world.add_child(n);n.position=Vector3((i%5)*24,0,(i/5)*35)
		var l=Label3D.new();l.text=names[i];l.position=n.position+Vector3(0,0,10);l.billboard=BaseMaterial3D.BILLBOARD_ENABLED;l.font_size=48;l.pixel_size=.025;world.add_child(l)
	var cam=Camera3D.new();world.add_child(cam);cam.position=Vector3(62,85,115);cam.look_at(Vector3(48,5,20));cam.projection=Camera3D.PROJECTION_ORTHOGONAL;cam.size=130
	await create_timer(3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../previews/extracted_models.png")
	quit()
