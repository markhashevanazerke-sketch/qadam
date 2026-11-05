extends SceneTree
func _initialize():
	create_timer(95).timeout.connect(func():print("CHAT_TIMEOUT");quit(1))
	call_deferred("run")
func run():
	var game=load("res://main.tscn").instantiate();root.add_child(game)
	while not game.town.population.ready_for_walk:await physics_frame
	game.story.set_process(false);game.set_physics_process(false)
	var ui=game.story_ui;ui._register_actors();ui.open_chat("citizen_00")
	print("CHAT_CONFIG | key_present=",not ui.api_key().is_empty())
	ui.draft.text="Сәлеметсіз бе! Менің атым Натан. Жұмысты қайдан табуға болады?"
	game.speech.working=true;game.speech.changed.emit()
	if ui.send_button.disabled:print("CHAT_FAIL | speech blocked writing");quit(1);return
	ui.send_button.pressed.emit()
	if not ui.waiting or not "Натан · жіберілуде" in ui.messages.get_parsed_text():print("CHAT_FAIL | pending message missing");quit(1);return
	if game.speech.working:print("CHAT_FAIL | old speech not cancelled");quit(1);return
	if is_instance_valid(ui.request):
		ui.request.request_completed.connect(func(result,code,_headers,body):
			var data=JSON.parse_string(body.get_string_from_utf8()) if not body.is_empty() else null
			print("CHAT_HTTP | result=",result," code=",code," bytes=",body.size())
			if data is Dictionary:
				print("CHAT_FIELDS | ",data.keys())
				if data.get("choices") is Array and not data.choices.is_empty():print("CHAT_CHOICE | finish=",data.choices[0].get("finish_reason")," text_length=",str(data.choices[0].get("message",{}).get("content","")).length())
		)
	while ui.waiting:await process_frame
	var history:Array=game.story.histories.get("citizen_00",[])
	var ok=history.size()>=2 and ui.draft.text.is_empty() and not ui.send_button.disabled and ui.draft.editable
	print("CHAT_LIVE_DONE | success=",ok," status=",ui.status.text)
	ui.close_modal();
	for audio in game.find_children("*","AudioStreamPlayer",true,false):audio.stop()
	for audio in game.find_children("*","AudioStreamPlayer3D",true,false):audio.stop()
	game.queue_free();await create_timer(.3).timeout;quit(0 if ok else 1)
