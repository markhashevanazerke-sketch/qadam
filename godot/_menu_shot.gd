extends SceneTree
var game:Node3D
func run() -> void:
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await create_timer(3.5).timeout
	await create_timer(0.7).timeout
	await RenderingServer.frame_post_draw
	game.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../previews/menu_title.png"))
	print("MENU_SHOT | saved | title_font=",load("res://assets/fonts/NotoSerifDisplay-SemiBold.ttf").has_char("К".unicode_at(0)))
	quit(0)
func _initialize() -> void:
	call_deferred("run")
