extends SceneTree
var game:Node3D
func shoot(path:String) -> void:
	await create_timer(1.2).timeout
	await RenderingServer.frame_post_draw
	game.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("SHOT | ",path)
func run() -> void:
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await create_timer(3.2).timeout
	game.automated=true
	game.set_capture(true)
	if is_instance_valid(game.main_menu) and game.main_menu.active:
		game.main_menu.close_menu()
	await create_timer(0.6).timeout
	var state:Node=game.story
	state.elapsed=300.0
	game.daily_life.update_daylight()
	# --- Rain, mid-morning, open street looking across the district ------------
	game.daily_life.weather="rain"
	game.daily_life._apply_weather()
	game.player.position=Vector3(10,0.2,10)
	game.camera.rotation=Vector3(-0.06,0.15,0)
	await shoot("res://../previews/rain_street.png")
	# --- Fog day ----------------------------------------------------------------
	game.daily_life.weather="fog"
	game.daily_life._apply_weather()
	game.player.position=Vector3(0,0.2,34)
	game.camera.rotation=Vector3(-0.03,0,0)
	await shoot("res://../previews/fog_street.png")
	print("WEATHER_DONE | fog=",game.daily_life.weather)
	quit(0)
func _initialize() -> void:
	call_deferred("run")
