extends SceneTree
var game:Node3D
var audio:Node
var failures:Array[String]=[]
var capture:AudioEffectCapture
var captured_frames:=PackedVector2Array()
var recording:=""
var max_voices:=0
func _initialize():call_deferred("run")
func check(ok:bool,label:String) -> void:
	if not ok:failures.append(label);push_error("AUDIO_CHECK_FAIL: "+label)
func wait(seconds:float) -> void:
	var until:=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<until:
		await process_frame
		max_voices=maxi(max_voices,audio.active_engine_count())
		if capture!=null and capture.get_frames_available()>0:
			var frames:=capture.get_buffer(capture.get_frames_available())
			if not recording.is_empty():captured_frames.append_array(frames)
func begin_record(label:String) -> void:
	captured_frames.clear();recording=label
	if capture!=null:capture.clear_buffer()
func end_record() -> void:
	if capture==null:return
	var data:=PackedByteArray();data.resize(captured_frames.size()*4)
	var peak:=0.0;var energy:=0.0
	for i in captured_frames.size():
		var frame:=captured_frames[i];peak=maxf(peak,maxf(absf(frame.x),absf(frame.y)))
		energy+=frame.length_squared()
		data.encode_s16(i*4,int(clampf(frame.x,-1,1)*32767));data.encode_s16(i*4+2,int(clampf(frame.y,-1,1)*32767))
	var wav:=AudioStreamWAV.new();wav.format=AudioStreamWAV.FORMAT_16_BITS
	wav.stereo=true;wav.mix_rate=int(AudioServer.get_mix_rate());wav.data=data
	wav.save_to_wav(ProjectSettings.globalize_path("res://../previews/audio_"+recording+".wav"))
	var rms:=sqrt(energy/maxi(1,captured_frames.size()*2))
	print("AUDIO_MIX | ",recording," | frames=",captured_frames.size()," | peak=",peak," | rms=",rms)
	check(captured_frames.size()>40000,"mixer produces frames "+recording)
	check(peak<.91,"no clipping "+recording)
	check(rms>.0001,"audible output "+recording)
	recording=""
func run() -> void:
	game=load("res://main.tscn").instantiate();root.add_child(game)
	await create_timer(2).timeout
	audio=game.soundscape;game.set_capture(true)
	# Never rewrite the player's saved volume settings from tests.
	audio.muted=false;audio.volumes={"Master":.8,"Music":.65,"Street":.8,"Foley":.8};audio._apply_volumes()
	if "--record" in OS.get_cmdline_user_args():
		capture=AudioEffectCapture.new();capture.buffer_length=2
		AudioServer.add_bus_effect(AudioServer.get_bus_index("Nazerke Master"),capture)
	game.set_physics_process(false)
	game.player.position=game.town.to_global(Vector3(-33,.1,25))
	game.camera.position=Vector3.UP*1.65;game.camera.rotation=Vector3.ZERO
	await wait(1)
	check(audio.context=="street" and not audio.street.stream_paused,"street ambience active")
	check(audio.active_engine_count()>0,"nearby cars audible")
	begin_record("street");await wait(4);end_record()
	# Pitch follows actual simulation speed, including idle, without changing the model or route.
	game.town.set_physics_process(false)
	var entry:Dictionary=audio.engines[audio.selected[0]]
	var saved_speed:float=entry.car.speed
	entry.car.speed=0;await wait(.8);var idle_pitch:float=entry.player.pitch_scale
	entry.car.speed=entry.car.cruise;await wait(.8)
	check(entry.player.pitch_scale>idle_pitch+.15,"engine responds to speed")
	entry.car.speed=saved_speed;game.town.set_physics_process(true)
	for i in 3:
		game.shop_visits._transition(i);await game.shop_visits.transition_finished;await wait(1)
		check(audio.context=="shop" and audio.shop_id==i,"shop music context "+str(i))
		check(audio.music.playing and not audio.music.stream_paused,"music plays "+str(i))
		check(audio.street.stream_paused and audio.active_engine_count()==0,"no street engines indoors "+str(i))
		check(audio.streams.shop_music.loop,"shop track loops")
		if i==0:begin_record("shop");await wait(4);end_record()
		game.set_capture(false);await wait(.4)
		check(audio.pause_gain<.001 and audio.music.stream_paused,"pause suspends audio")
		game.set_capture(true);await wait(.5)
		check(not audio.music.stream_paused,"music resumes after pause")
		game.shop_visits._transition(-1);await game.shop_visits.transition_finished;await wait(1)
		check(audio.context=="street" and audio.music.stream_paused,"outside restores ambience")
	for variant in 5:
		var index:=-1
		for i in game.home_visits.doors.size():
			if game.home_visits.doors[i].variant==variant:index=i;break
		game.story.home_id=game.home_visits.doors[index].id # Authorized interior fixture.
		game.home_visits._transition(index);await game.home_visits.transition_finished;await wait(1)
		check(audio.context=="home" and audio.music.stream_paused and audio.street.stream_paused,"quiet home "+str(variant))
		check(audio.active_engine_count()==0,"home has no engine voices")
		if variant==0:
			begin_record("home");audio._step(.26);await wait(2);end_record()
		game.home_visits._transition(-1);await game.home_visits.transition_finished
	# Walking uses actual displacement: standing, pause and overview cannot generate steps.
	game.reset();game.set_physics_process(true);await wait(.4)
	var count:int=audio.step_count;await wait(.4);check(audio.step_count==count,"standing silent")
	Input.action_press("forward");await wait(1.3);Input.action_release("forward");await wait(.3)
	check(audio.step_count>count,"walking produces footsteps")
	game.set_capture(false);count=audio.step_count;await wait(.4)
	check(audio.step_count==count,"pause has no footsteps")
	game.set_capture(true)
	check(max_voices<=8,"bounded engine mixing")
	check(audio.door_count==16,"doors sound once per transition")
	check(AudioServer.get_bus_effect_count(AudioServer.get_bus_index("Nazerke Master"))>=1,"mix limiter")
	print("AUDIO_CHECK_DONE | failures=",failures," | max voices=",max_voices," | footsteps=",audio.step_count," | doors=",audio.door_count)
	quit(0 if failures.is_empty() else 1)
