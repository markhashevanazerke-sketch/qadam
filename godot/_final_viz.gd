extends SceneTree
var game:Node3D
func shoot(path:String) -> void:
	await create_timer(0.7).timeout
	await RenderingServer.frame_post_draw
	game.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("SHOT | ",path)
func run() -> void:
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await create_timer(3).timeout
	var state:Node=game.story
	# --- 1. Start menu with the new title --------------------------------------
	await shoot("res://../previews/menu_title.png")
	game.automated=true
	game.set_capture(true)
	if is_instance_valid(game.main_menu) and game.main_menu.active:
		game.main_menu.close_menu()
	await create_timer(0.6).timeout
	var ui:Node=game.story_ui
	# --- 2. Rain: particles + wet roads ----------------------------------------
	game.daily_life.weather="rain"
	game.daily_life._apply_weather()
	game.player.position=Vector3(6,0.2,20)
	game.camera.rotation=Vector3(-0.25,0.7,0)
	await shoot("res://../previews/rain_street.png")
	# --- 3. Fog day --------------------------------------------------------------
	game.daily_life.weather="fog"
	game.daily_life._apply_weather()
	game.player.position=Vector3(0,0.2,44)
	game.camera.rotation=Vector3(-0.05,0,0)
	await shoot("res://../previews/fog_street.png")
	game.daily_life.weather="clear"
	game.daily_life._apply_weather()
	# --- 4. District sign near the spawn ----------------------------------------
	game.player.position=Vector3(0,0.2,40)
	var eye:Vector3=game.player.global_position+Vector3(0,1.65,0)
	var to:Vector3=game.town.to_global(Vector3(0,4.6,26))
	var dvec:Vector3=to-eye
	game.camera.rotation=Vector3(atan2(dvec.y,dvec.length()),atan2(-dvec.x,-dvec.z),0)
	await shoot("res://../previews/district_sign.png")
	# --- 5. Coffee button in the chat with Erlan --------------------------------
	state.money=maxi(state.money,400)
	game.shop_visits._transition(0);await game.shop_visits.transition_finished
	var room:Node3D=game.shop_visits.rooms[0]
	game.player.position=room.to_global(room.checkout_approach)
	game.camera.look_at(room.cashier.global_position+Vector3.UP*1.5)
	await create_timer(0.3).timeout
	ui.open_chat("cashier_0");await create_timer(0.5).timeout
	await shoot("res://../previews/chat_coffee.png")
	ui.close_modal()
	game.shop_visits._transition(-1);await game.shop_visits.transition_finished
	# --- 6. Phone wordbook with today's drills -----------------------------------
	for pair in [
		["Ерлан","Сәлеметсіз бе! Мен курьер болып жұмыс іздеймін.","Сәлем! Бізге курьер керек."],
		["Әсел","Сәлем! Күн қалай өтті? Жаңбыр жауды.","Сәлем! Күнім жақсы өтті."]
	]:
		game.wordbook.record(str(pair[0]),str(pair[1]),str(pair[2]))
	ui.open_phone();await create_timer(0.4).timeout
	ui._phone_page("words");await create_timer(0.5).timeout
	await shoot("res://../previews/phone_drills.png")
	ui.close_modal()
	# --- 7. Photo mode: enter, save, exit ----------------------------------------
	game.player.position=Vector3(4,0.2,24)
	game.camera.rotation=Vector3(-0.15,2.6,0)
	await create_timer(0.5).timeout
	game._enter_photo()
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	var hud_hidden:bool=not game.hud.get_parent().visible and not game.minimap.visible
	game._save_photo()
	var files:Array=DirAccess.get_files_at(ProjectSettings.globalize_path("user://photos")) if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("user://photos")) else []
	print("PHOTO_MODE | hud_hidden=",hud_hidden," | saved_files=",files.size()," | ui_back=",game.hud.get_parent().visible)
	await shoot("res://../previews/photo_mode_off.png")
	print("FINAL_VIZ_DONE")
	quit(0)
func _initialize() -> void:
	call_deferred("run")
