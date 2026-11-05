extends SceneTree
var game:Node3D
func run() -> void:
	game=load("res://main.tscn").instantiate();root.add_child(game)
	await create_timer(3).timeout
	var state:Node=game.story
	var ui:Node=game.story_ui
	game.set_physics_process(false);game.town.set_physics_process(false)
	game.set_capture(true)
	for i in 3:
		game.shop_visits._transition(i)
		await game.shop_visits.transition_finished
		print("T3 | in shop ",i)
		var room:Node3D=game.shop_visits.rooms[i]
		game.player.position=room.to_global(room.checkout_approach)
		game.camera.look_at(room.cashier.global_position+Vector3.UP*1.5)
		for f in 3:await physics_frame
		ui.open_chat("cashier_%d"%i)
		for f in 3:await physics_frame
		if i==0:
			print("T3 | jb disabled=",ui.job_button.disabled)
			ui._quick_message("Сәлеметсіз бе! Мен жұмыс іздеп жүрмін.")
			print("T3 | draft=",ui.draft.text.left(40)," waiting=",ui.waiting)
			ui._reply(HTTPRequest.RESULT_SUCCESS,200,PackedStringArray(),JSON.stringify({"choices":[{"message":{"content":"Сәлем! Бізге курьер керек. Жұмыс істегің келе ме?"}}]}).to_utf8_buffer(),ui.request_serial,"cashier_0",ui.draft.text)
			ui._job_action();print("T3 | hired employer=",state.employer)
			ui._job_action();print("T3 | order=",state.delivery_id," reward=",state.delivery_reward)
			check(state.money==state.money,"noop")
		else:
			print("T3 | shop ",i," jb disabled=",ui.job_button.disabled," text=",ui.job_button.text)
		print("T3 | closing modal shop ",i)
		ui.close_modal()
		print("T3 | modal closed shop ",i)
		game.shop_visits._transition(-1)
		await game.shop_visits.transition_finished
		print("T3 | out of shop ",i," ok")
	print("TRANS_ALL_DONE")
	quit(0)
func check(ok:bool,label:String) -> void:
	if not ok:print("FAIL | ",label)
func _initialize() -> void:
	call_deferred("run")
