extends SceneTree
var game:Node3D
func shoot(path:String) -> void:
	await create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	game.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("VIZ | ",path)
func run() -> void:
	game=load("res://main.tscn").instantiate();root.add_child(game)
	await create_timer(3.5).timeout
	var state:Node=game.story
	state.player_name="Сәуле"
	game._sync_player_name()
	game.set_capture(true)
	var spawn:Vector3=game.player.global_position
	# --- 1. Looking down at the feet: the ground shadow ----------------------
	game.camera.global_position=spawn+Vector3(0,1.65,0)
	game.camera.look_at(spawn+Vector3(0.6,0.0,1.2))
	await shoot("res://../previews/hero_shadow_down.png")
	# --- 2. Looking up: the name over the head --------------------------------
	game.camera.look_at(spawn+Vector3(0,2.1,0.4))
	await shoot("res://../previews/hero_name_up.png")
	# --- 3. Street view from a distance (photo style) -------------------------
	game.camera.global_position=spawn+Vector3(6.5,2.6,6.0)
	game.camera.look_at(spawn+Vector3(0,1.2,0))
	await shoot("res://../previews/hero_street.png")
	# --- 4. Phone: wordbook + the listening quiz card --------------------------
	var ui:Node=game.story_ui
	var wb:Node=game.wordbook
	for pair in ["сәлем","шай","нән","үй","қонақ","рақмет"]:
		wb.entries[pair]={"example":"Менің атым Сәуле.","npc":"Ерлан","day":1,"seen":1,"own":true,"miss":0,"known":0}
	wb.entries["шай"].miss=2
	ui.open_phone()
	await create_timer(0.5).timeout
	ui._phone_page("words")
	await shoot("res://../previews/quiz_wordbook.png")
	ui._quiz_start()
	await create_timer(0.7).timeout
	await shoot("res://../previews/quiz_card.png")
	ui.quiz_active=false
	ui.close_modal()
	await create_timer(0.3).timeout
	# --- 5. Start menu with the new name field caption ------------------------
	game.main_menu.open_menu()
	game.main_menu.name_edit.text="Сәуле"
	await shoot("res://../previews/menu_name2.png")
	print("VIZ_DONE")
	quit(0)
func _initialize() -> void:
	call_deferred("run")
