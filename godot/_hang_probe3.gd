extends SceneTree
func run() -> void:
	print("P | start")
	var game:Node3D=load("res://main.tscn").instantiate();root.add_child(game)
	await create_timer(3).timeout
	var ui:Node=game.story_ui;var state:Node=game.story
	game.set_capture(true)
	game.set_physics_process(false);game.town.set_physics_process(false)
	game.shop_visits._transition(0);await game.shop_visits.transition_finished
	var room:Node3D=game.shop_visits.rooms[0]
	game.player.position=room.to_global(room.checkout_approach)
	game.camera.look_at(room.cashier.global_position+Vector3.UP*1.5)
	await create_timer(.3).timeout
	ui.open_chat("cashier_0");await create_timer(.3).timeout
	ui.draft.text="Сәлеметсіз бе! Мен курьер болып жұмыс іздеймін."
	ui.send_message()
	await create_timer(.5).timeout
	ui._job_action();await create_timer(.3).timeout
	ui._job_action();await create_timer(.3).timeout
	ui.close_modal();game.shop_visits._transition(-1);await game.shop_visits.transition_finished
	var index:int=state.delivery_index()
	var d:Dictionary=game.home_visits.doors[index]
	game.home_visits.place_player(d.landing,0);game.camera.look_at(d.point)
	await create_timer(.3).timeout
	game.interact()
	await game.home_visits.transition_finished
	print("P | inside=",game.home_visits.inside()," door=",game.home_visits.current_door)
	var visits:Node=game.home_visits
	var actor:Node3D=visits.residents[0]
	print("P | actor at ",actor.global_position," valid=",is_instance_valid(actor))
	game.camera.look_at(actor.global_position+Vector3.UP*1.45)
	await create_timer(.3).timeout
	print("P | ray at resident=",ui.ray_target()," can_deliver=",state.can_deliver())
	game.camera.rotation=Vector3(0,PI,0)
	await create_timer(.2).timeout
	print("P | at_exit(PI)=",visits.at_exit())
	var exit_p:Vector3=visits.rooms[visits.current_home].exit_point
	print("P | cam=",game.camera.global_position," exit=",visits.rooms[visits.current_home].to_global(exit_p))
	var dir:Vector3=(visits.rooms[visits.current_home].to_global(exit_p)-game.camera.global_position).normalized()
	print("P | dot with -Z=", -game.camera.global_basis.z.dot(dir))
	quit(0)
func _initialize() -> void:
	create_timer(120).timeout.connect(func():print("P | TIMEOUT");quit(1))
	call_deferred("run")
