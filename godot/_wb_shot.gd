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
	var ui:Node=game.story_ui
	for pair in [
		["Ерлан","Сәлеметсіз бе! Менің атым Натан. Мен курьер болып жұмыс іздеймін.","Сәлем! Бізге курьер керек. Жұмыс істегің келе ме? Еңбекақы әр тапсырысқа."],
		["Әсел","Сәлем! Күн қалай өтті? Мен таңертең нан алдым.","Сәлем! Күнім жақсы өтті. Таңертең жаңа піскен нан алдым. Саған да ұсынамын."],
		["Мирас","Сәлем! Сен велосипед жинап жүрген бе? Қанша ақша қажет?","Сәлем! Иә, велосипедке ақша жинап жүрмін. Тағы сәл ақша қажет."],
		["Аружан","Салом... ой, сәлеметсіз бе! Салонға шампунь алып келдім.","Сәлеметсіз бе! Көп рақмет, шампунь дәл керегіміз еді. Сыйақыңызды қолға алыңыз."]
	]:
		game.wordbook.record(str(pair[0]),str(pair[1]),str(pair[2]))
	ui.open_phone();await create_timer(0.4).timeout
	ui._phone_page("words");await create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	game.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../previews/phone_wordbook.png"))
	print("WB_SHOT | saved | words=",game.wordbook.entries.size()," xp=",game.wordbook.xp)
	quit(0)
func _initialize() -> void:
	call_deferred("run")
