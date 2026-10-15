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
	var camera:=Camera3D.new();scene.add_child(camera);camera.position=Vector3(0,1.0,5);camera.look_at(Vector3(0,1.0,0));camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=3.8;camera.current=true
	for row in 1:
		for phase in 2:
			var n:=Node3D.new();n.set_script(load("res://citizen_visual.gd"));n.character_id="asel";n.natural_motion=phase==1;n.initial_motion="walk";n.outfit_variant=0
			scene.add_child(n);n.position=Vector3(-.8+phase*1.6,0,0);n.rotation.y=PI
			var animation:Animation=n.animation.get_animation("walk");n.animation.seek(0.0,true);n.animation.active=false;actors.append(n)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../previews/clothing_compare_front.png"))
	for n in actors:n.rotation.y=PI/2
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../previews/clothing_compare_side.png"))
	print("MOTION_AUDIT_CAPTURED")
	quit()
