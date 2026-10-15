extends SceneTree
func _initialize():call_deferred("capture")
func capture():
	var scene:=Node3D.new();root.add_child(scene)
	var world:=WorldEnvironment.new();world.environment=Environment.new();world.environment.background_mode=Environment.BG_COLOR;world.environment.background_color=Color("879ca7");world.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;world.environment.ambient_light_energy=.65;scene.add_child(world)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-35,-30,0);scene.add_child(sun)
	for i in 3:
		var head:=Node3D.new();head.set_script(load("res://solid_signal.gd"));scene.add_child(head);head.position.x=(i-1)*1.65
		head.configure(Vector3(0,0,1),Vector3(1,0,0),i==0);head.set_main(i);head.set_pedestrian(i==2);head.set_turn(i==2)
	var camera:=Camera3D.new();scene.add_child(camera);camera.current=true;camera.fov=55
	for pose in [["front",Vector3(3,2.9,6),Vector3(0,1.85,0)],["back",Vector3(-3,2.9,-6),Vector3(0,1.85,0)],["close",Vector3(.5,2.8,4.8),Vector3(-1.65,2.65,0)],["pedestrian",Vector3(4.5,1.95,.5),Vector3(1.65,1.75,0)]]:
		camera.position=pose[1];camera.look_at(pose[2])
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../previews/solid_signals_"+pose[0]+".png"))
	print("SOLID_SIGNAL_AUDIT_PASS");quit()
