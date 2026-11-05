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
	state.elapsed=650.0
	game.home_visits._transition(state.home_index())
	var guard:float=0.0
	while game.home_visits.busy and guard<10.0:
		await create_timer(0.1).timeout;guard+=0.1
	await create_timer(0.5).timeout
	print("DIAG | overview=",game.overview," inside=",game.home_visits.inside()," cam=",game.camera.global_position," player=",game.player.global_position)
	# Look around the entry: face -Z (default room facing).
	game.camera.rotation=Vector3(-0.1,0,0)
	await create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	game.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../previews/_diag_home.png"))
	print("DIAG | shot saved")
	quit(0)
func _initialize() -> void:
	call_deferred("run")
