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
	await create_timer(0.5).timeout
	game._enter_photo()
	print("PHOTO_DIAG | panel=",game.hud.get_parent().visible," | minimap=",game.minimap.visible," | info=",game.story_ui.get_child(0).visible," | daily=",game.daily_life.visible)
	game._exit_photo()
	print("PHOTO_DIAG | after exit: panel=",game.hud.get_parent().visible," | minimap=",game.minimap.visible," | info=",game.story_ui.get_child(0).visible," | daily=",game.daily_life.visible)
	quit(0)
func _initialize() -> void:
	call_deferred("run")
