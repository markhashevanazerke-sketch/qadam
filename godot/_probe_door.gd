extends SceneTree
var game:Node3D
func shoot(at:Vector3,look:Vector3,path:String) -> void:
	game.player.global_position=at
	game.player.rotation=Vector3.ZERO
	var d:Vector3=look-(game.player.global_position+Vector3(0,1.65,0))
	game.yaw=atan2(-d.x,-d.z)
	game.pitch=atan2(d.y,Vector2(d.x,d.z).length())
	game.camera.rotation=Vector3(game.pitch,game.yaw,0)
	await create_timer(1.4).timeout
	await RenderingServer.frame_post_draw
	game.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("DOORK | shot ",path)
func run() -> void:
	print("DOORK | step0 spawn")
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await create_timer(3).timeout
	print("DOORK | step1 world up")
	game.automated=true
	game.set_capture(true)
	if is_instance_valid(game.main_menu) and game.main_menu.active:
		print("DOORK | step2 closing menu")
		game.main_menu.close_menu()
	await create_timer(0.5).timeout
	print("DOORK | step3 ready to transition, shops=",game.town.shops.size())
	var done:bool=false
	game.shop_visits.transition_finished.connect(func():done=true)
	game.shop_visits._transition(4)
	var guard:float=0.0
	while not done and guard<10.0:
		await create_timer(0.1).timeout
		guard+=0.1
	print("DOORK | step4 transition done guard=",guard)
	var room:Node3D=game.shop_visits.rooms[4]
	print("DOORK | step5 room=",room.name)
	await shoot(room.to_global(Vector3(0.0,0.0,3.0)),room.to_global(Vector3(0.0,1.35,5.95)),"res://../previews/door_close.png")
	quit(0)
func _initialize() -> void:
	call_deferred("run")
