extends SceneTree
var failures:Array[String]=[]
func _initialize():
	create_timer(60).timeout.connect(func():push_error("VOICE_CACHE_TIMEOUT");quit(1))
	call_deferred("run")
func check(ok:bool,label:String) -> void:
	if not ok:failures.append(label);push_error("VOICE_CACHE_FAIL: "+label)
func run():
	var game=load("res://main.tscn").instantiate();root.add_child(game)
	while not game.town.population.ready_for_walk:await physics_frame
	game.story_ui._register_actors();game.set_physics_process(false)
	var speech:Node=game.speech;speech.enabled=true
	var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://../voice/lines_manifest.json"))
	for key in manifest.lines:
		check(speech.cached_audio(key)!=null,"baked audio exists "+key)
	game.story_ui.open_chat("cashier_3")
	var words:String=game.story_ui.profiles.cashier_3.greeting
	speech.speak(words,"cashier_3")
	check(speech.cache_hits==1 and speech.speaker.playing,"authored greeting plays immediately")
	check(speech.process_id==-1 and speech.request==null and speech.health==null,"no Python service or HTTP for authored greeting")
	var second:Node=Node.new();second.set_script(load("res://speech_bridge.gd"));game.add_child(second);second.enabled=true
	second.speak(words,"cashier_3")
	check(second.cache_hits==1 and second.process_id==-1,"fresh playback node reuses authored file")
	speech.speak(words,"cashier_3")
	check(speech.cache_hits==2 and not speech.working,"replay uses audio file")
	var audio:AudioStreamWAV=speech.speaker.stream
	var folder:="user://voice_cache_test_%d"%OS.get_process_id();speech.cache_dir=folder;second.cache_dir=folder
	var generated:="Бұл тек сақтау сынағы. %d"%OS.get_process_id()
	var key:String=speech.audio_key(generated,speech.speaker_id("cashier_3"))
	speech.cache_audio(audio,key)
	check(speech.cache_writes==1,"new generated reply written atomically")
	second.speak(generated,"cashier_3")
	check(second.cache_hits==2 and second.process_id==-1 and second.speaker.stream.data==audio.data,"new reply survives a fresh playback instance without inference")
	check(second.audio_key(generated,0)!=second.audio_key(generated,1),"different voice has different cache key")
	second.stop();second.enabled=false;second.speak(generated,"cashier_3")
	check(not second.speaker.playing and second.cache_hits==2,"mute respected for cached replies")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(folder+"/"+key+".wav"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(folder))
	game.story_ui.close_modal();second.stop()
	print("VOICE_CACHE_CHECK_DONE | baked=",manifest.lines.size()," failures=",failures)
	game.soundscape.set_process(false);game.soundscape.set_physics_process(false)
	for player in game.find_children("*","AudioStreamPlayer",true,false):player.stop()
	for player in game.find_children("*","AudioStreamPlayer3D",true,false):player.stop()
	await create_timer(.2).timeout;game.queue_free();await create_timer(.2).timeout;quit(0 if failures.is_empty() else 1)
