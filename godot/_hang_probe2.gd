extends SceneTree
func run() -> void:
	print("P | start")
	var game:Node3D=load("res://main.tscn").instantiate();root.add_child(game)
	await create_timer(3).timeout
	var ui:Node=game.story_ui;var state:Node=game.story
	game.set_capture(true)
	game.set_physics_process(false);game.town.set_physics_process(false)
	# hire + get an order like the real test
	game.shop_visits._transition(0);await game.shop_visits.transition_finished
	var room:Node3D=game.shop_visits.rooms[0]
	game.player.position=room.to_global(room.checkout_approach)
	game.camera.look_at(room.cashier.global_position+Vector3.UP*1.5)
	await create_timer(.3).timeout
	print("P | cashier ray=",ui.ray_target())
	ui.open_chat("cashier_0");await create_timer(.3).timeout
	ui.draft.text="Сәлеметсіз бе! Мен курьер болып жұмыс іздеймін."
	ui.send_message()
	await create_timer(.5).timeout
	ui._job_action();await create_timer(.3).timeout
	ui._job_action();await create_timer(.3).timeout
	print("P | employer=",state.employer," order=",state.delivery_id)
	ui.close_modal();game.shop_visits._transition(-1);await game.shop_visits.transition_finished
	var index:int=state.delivery_index()
	print("P | delivery index=",index)
	if index<0:quit(0)
	var d:Dictionary=game.home_visits.doors[index]
	game.home_visits.place_player(d.landing,0);game.camera.look_at(d.point)
	await create_timer(.3).timeout
	print("P | at door: ray=",ui.ray_target()," nearby_home=",game.home_visits.nearby_home())
	game.interact()
	await create_timer(.5).timeout
	print("P | after interact: hv_busy=",game.home_visits.busy," modal=",ui.modal," ray=",ui.ray_target())
	quit(0)
func _initialize() -> void:
	create_timer(90).timeout.connect(func():print("P | TIMEOUT");quit(1))
	call_deferred("run")
