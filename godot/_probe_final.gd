extends SceneTree
var game:Node3D
func shoot(at:Vector3,look:Vector3,path:String) -> void:
	game.player.global_position=at
	game.player.rotation=Vector3.ZERO
	var d:Vector3=look-(game.player.global_position+Vector3(0,1.65,0))
	game.yaw=atan2(-d.x,-d.z)
	game.pitch=atan2(d.y,Vector2(d.x,d.z).length())
	game.camera.rotation=Vector3(game.pitch,game.yaw,0)
	await create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	game.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("FINAL | shot ",path)
func run() -> void:
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await create_timer(3).timeout
	game.automated=true
	game.set_capture(true)
	if is_instance_valid(game.main_menu) and game.main_menu.active:
		game.main_menu.close_menu()
	await create_timer(0.5).timeout
	game.shop_visits._transition(4)
	var guard:float=0.0
	while game.shop_visits.busy and guard<10.0:
		await create_timer(0.1).timeout;guard+=0.1
	var room:Node3D=game.shop_visits.rooms[4]
	# Player's view from mid-room: the door must be clearly visible ahead.
	await shoot(room.to_global(Vector3(-0.5,0.08,-2.5)),room.to_global(Vector3(0.0,1.5,5.9)),"res://../previews/final_door_view.png")
	# Overview from the west-south corner.
	await shoot(room.to_global(Vector3(-4.4,1.8,4.8)),room.to_global(Vector3(1.5,0.5,-1.0)),"res://../previews/final_overview.png")
	quit(0)
func _initialize() -> void:
	call_deferred("run")
