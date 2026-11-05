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
	await create_timer(0.6).timeout
	var state:Node=game.story
	state.elapsed=560.0
	game.daily_life.update_daylight()
	game.player.position=Vector3(3,0.2,20)
	game.camera.rotation=Vector3(-0.12,2.75,0)
	await create_timer(1.0).timeout
	game._enter_photo()
	await create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	var panel:bool=game.hud.get_parent().visible
	var mini:bool=game.minimap.visible
	var info:bool=game.story_ui.get_child(0).visible
	var daily:bool=game.daily_life.visible
	game._save_photo()
	var dir:="user://photos"
	var files:Array=[]
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(dir)):
		files=DirAccess.get_files_at(ProjectSettings.globalize_path(dir))
	print("PHOTO2 | panel=",panel," mini=",mini," info=",info," daily=",daily," | files=",files)
	await create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	game.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../previews/photo_mode_clean.png"))
	print("PHOTO2 | clean frame shot")
	quit(0)
func _initialize() -> void:
	call_deferred("run")
