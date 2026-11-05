extends SceneTree
var game:Node3D
var capture:bool="--capture" in OS.get_cmdline_user_args()
func _initialize():call_deferred("run")
func snap(label:String) -> void:
	if not capture:return
	game._physics_process(0)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../previews/lighting_"+label+".png"))
func run() -> void:
	game=load("res://main.tscn").instantiate();root.add_child(game)
	await create_timer(2).timeout;game.set_physics_process(false)
	assert(game.outdoor_sun.visible,"Sun on outdoors")
	for variant in 5:
		var index:=-1
		for i in game.home_visits.doors.size():
			if game.home_visits.doors[i].variant==variant:index=i;break
		game.story.home_id=game.home_visits.doors[index].id # Authorized interior fixture.
		game.home_visits._transition(index);await game.home_visits.transition_finished
		assert(not game.outdoor_sun.visible,"No world sun indoors")
		game.set_capture(false);game.set_capture(true)
		assert(not game.outdoor_sun.visible,"Pause must not restore indoor sunlight")
		await snap("home_%d"%variant)
		game.home_visits._transition(-1);await game.home_visits.transition_finished
		assert(game.outdoor_sun.visible and game.camera.environment==null,"Outdoor light restored")
	for i in 3:
		game.shop_visits._transition(i);await game.shop_visits.transition_finished
		assert(not game.outdoor_sun.visible,"Shop uses its own lighting")
		await snap("shop_%d"%i)
		game.shop_visits._transition(-1);await game.shop_visits.transition_finished
		assert(game.outdoor_sun.visible,"Sun restored after shop exit")
	print("INTERIOR_LIGHTING_CHECK_PASS | five homes and three shops | pause | outdoor sunlight restored")
	quit()
