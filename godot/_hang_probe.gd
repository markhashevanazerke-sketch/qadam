extends SceneTree
func run() -> void:
	print("P | start")
	var game:Node3D=load("res://main.tscn").instantiate();root.add_child(game)
	await create_timer(3).timeout
	print("P | ready automated=",game.automated)
	var ui:Node=game.story_ui
	game.set_capture(true)
	game.set_physics_process(false);game.town.set_physics_process(false)
	print("P | transition begin")
	game.shop_visits._transition(0)
	await game.shop_visits.transition_finished
	print("P | transition ok")
	game.player.position=game.shop_visits.rooms[0].to_global(game.shop_visits.rooms[0].checkout_approach)
	await create_timer(0.3).timeout
	print("P | ray=",ui.ray_target())
	quit(0)
func _initialize() -> void:
	create_timer(90).timeout.connect(func():print("P | TIMEOUT");quit(1))
	call_deferred("run")
