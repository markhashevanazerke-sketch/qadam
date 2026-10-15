extends SceneTree
func _initialize():call_deferred("run")
func run():
	var game=load("res://main.tscn").instantiate();root.add_child(game)
	while not game.town.population.ready_for_walk:await physics_frame
	game.story_ui._register_actors()
	var jobs:Dictionary={}
	for id in game.story_ui.profiles:
		var words:String=game.story_ui.profiles[id].greeting
		var sid:int=game.speech.speaker_id(id)
		jobs[game.speech.audio_key(words,sid)]={"text":words,"speaker":sid}
	var phrases:=[
		"Сәлеметсіз бе! Мен қазақ тілін үйреніп жүрмін.",
		"Сәлеметсіз бе! Тапсырысымды алып келдіңіз бе?",
		"Сәлем! Кіріңіз, сізді күтіп отырмыз.",
		"Құтты болсын, Натан! Дүкен енді сенікі. Жабдықтауды кейін бастаймыз.",
		"Сәлеметсіз бе! Менің атым Натан.",
		"Сәлеметсіз бе! Мен жұмыс іздеп жүрмін.",
		"Сәлеметсіз бе! Тапсырысыңызды алып келдім."]
	for words in phrases:
		for sid in 6:jobs[game.speech.audio_key(words,sid)]={"text":words,"speaker":sid}
	var file:=FileAccess.open("res://../voice/lines_manifest.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"revision":game.speech.VOICE_REVISION,"lines":jobs},"  "));file.close()
	print("VOICE_MANIFEST | lines=",jobs.size())
	game.soundscape.set_process(false);game.soundscape.set_physics_process(false)
	for player in game.find_children("*","AudioStreamPlayer",true,false):player.stop()
	for player in game.find_children("*","AudioStreamPlayer3D",true,false):player.stop()
	await create_timer(.2).timeout;game.queue_free();await create_timer(.2).timeout;quit()
