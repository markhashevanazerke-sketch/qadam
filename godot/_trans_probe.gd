extends SceneTree
var game:Node3D
func run() -> void:
	game=load("res://main.tscn").instantiate();root.add_child(game)
	await create_timer(3).timeout
	var state:Node=game.story
	game.set_physics_process(false);game.town.set_physics_process(false)
	game.set_capture(true)
	for i in 3:
		game.shop_visits._transition(i)
		await game.shop_visits.transition_finished
		print("TRANS | in shop ",i," ok")
		var room:Node3D=game.shop_visits.rooms[i]
		game.player.position=room.to_global(room.checkout_approach)
		for f in 3:await physics_frame
		print("TRANS | frames ok, ray=",game.story_ui.ray_target())
		game.story_ui.open_chat("cashier_%d"%i)
		for f in 3:await physics_frame
		print("TRANS | chat ok")
		game.story_ui.close_modal()
		print("TRANS | modal closed")
		game.shop_visits._transition(-1)
		await game.shop_visits.transition_finished
		print("TRANS | out of shop ",i," ok")
	print("TRANS_ALL_DONE")
	quit(0)
func _initialize() -> void:
	call_deferred("run")
