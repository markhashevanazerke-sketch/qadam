extends SceneTree
var scene:Node3D
var actors:Array[Node3D]=[]
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	scene=Node3D.new();root.add_child(scene)
	var world:=WorldEnvironment.new();var env:=Environment.new();world.environment=env
	env.background_mode=Environment.BG_COLOR;env.background_color=Color("b2bdc4");env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color.WHITE;env.ambient_light_energy=.7;scene.add_child(world)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-35,-35,0);light.light_energy=1.0;scene.add_child(light)
	var camera:=Camera3D.new();scene.add_child(camera);camera.position=Vector3(0,2.35,12);camera.look_at(Vector3(0,2.35,0));camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=8.0;camera.current=true
	for row in 2:
		for phase in 4:
			var n:=Node3D.new();n.set_script(load("res://citizen_visual.gd"));n.character_id="erlan" if row==0 else "asel";n.initial_motion="walk";n.outfit_variant=0
			scene.add_child(n);n.position=Vector3(-2.7+phase*1.8,row*2.6,0);n.rotation.y=PI
			var animation:Animation=n.animation.get_animation("walk");n.animation.seek(animation.length*phase/4.0,true);n.animation.active=false;actors.append(n)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../previews/natural_walk_front.png"))
	for n in actors:n.rotation.y=PI/2
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../previews/natural_walk_side.png"))
	print("MOTION_AUDIT_CAPTURED")
	quit()
