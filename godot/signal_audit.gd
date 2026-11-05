extends SceneTree
func _initialize():call_deferred("go")
func go():
	var world=Node3D.new();root.add_child(world)
	var e=WorldEnvironment.new();e.environment=Environment.new();e.environment.background_mode=Environment.BG_COLOR;e.environment.background_color=Color("7e9da7");e.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;e.environment.ambient_light_color=Color.WHITE;e.environment.ambient_light_energy=.8;world.add_child(e)
	var sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-55,-20,0);world.add_child(sun)
	var ids=[631,1309,1557,1879]
	for i in 4:
		var n=load("res://assets/nazerke_kit/signal_candidate_%d.glb"%ids[i]).instantiate();world.add_child(n);n.position.x=i*4
		var l=Label3D.new();l.text=str(ids[i]);l.position=Vector3(i*4,3.1,0);l.billboard=BaseMaterial3D.BILLBOARD_ENABLED;l.font_size=50;l.pixel_size=.012;world.add_child(l)
	var cam=Camera3D.new();world.add_child(cam);cam.position=Vector3(8,6,14);cam.look_at(Vector3(6,1,0));cam.projection=Camera3D.PROJECTION_ORTHOGONAL;cam.size=17
	await create_timer(2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../previews/signal_source_audit.png");quit()
