extends SceneTree
var game:Node3D
func run() -> void:
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await create_timer(3).timeout
	game.automated=true
	game.set_capture(true)
	if is_instance_valid(game.main_menu) and game.main_menu.active:
		game.main_menu.close_menu()
	await create_timer(0.5).timeout
	var state:Node=game.story
	state.elapsed=999.0
	game.daily_life.update_daylight()
	await create_timer(1.2).timeout
	var light:OmniLight3D=game.town.lamp_lights[0]
	var lp:Vector3=light.global_position
	print("LAMPPOS | ",lp," energy=",light.light_energy)
	game.player.position=lp+Vector3(-4,0.2,-2.5)
	var eye:Vector3=game.player.position+Vector3(0,1.65,0)
	var target:Vector3=lp+Vector3(0,-2.2,0)
	var dvec:Vector3=target-eye
	game.camera.rotation=Vector3(atan2(dvec.y,dvec.length()),atan2(-dvec.x,-dvec.z),0)
	await create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	game.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../previews/evening_lamp.png"))
	print("LAMP_SHOT | saved")
	quit(0)
func _initialize() -> void:
	call_deferred("run")
