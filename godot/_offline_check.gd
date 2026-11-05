extends SceneTree
# Full offline loop: no LLM key, no network. The conversation, employment,
# delivery and pay must work end to end; wordbook, neighbour tea and the
# night lamps are verified as well.
var game:Node3D
var failures:Array[String]=[]
func check(ok:bool,label:String) -> void:
	if not ok:failures.append(label);push_error("OFFLINE_CHECK_FAIL: "+label)
func frames(count:int=3) -> void:
	for i in count:await physics_frame
func run() -> void:
	game=load("res://main.tscn").instantiate();root.add_child(game)
	await create_timer(3).timeout
	var ui:Node=game.story_ui;var state:Node=game.story
	var wb:Node=game.wordbook
	var od=load("res://offline_dialog.gd")
	check(game.automated,"--offline-check runs without saving")
	check(ui.api_key().is_empty(),"key lookup disabled in offline mode")
	var wb_xp_before:int=wb.xp
	var wb_size_before:int=wb.entries.size()
	var book_was_empty:bool=wb_xp_before==0 and wb_size_before==0
	game.set_capture(true)
	game.set_physics_process(false);game.town.set_physics_process(false)
	# --- Offline conversation and employment at BEREKE -----------------------
	game.shop_visits._transition(0);await game.shop_visits.transition_finished
	var room:Node3D=game.shop_visits.rooms[0]
	game.player.position=room.to_global(room.checkout_approach)
	game.camera.look_at(room.cashier.global_position+Vector3.UP*1.5)
	await frames()
	check(ui.ray_target()=="cashier_0","cashier selectable")
	ui.open_chat("cashier_0");await frames()
	check(ui.job_button.disabled,"no hire before any conversation")
	ui.draft.text="Сәлеметсіз бе! Мен курьер болып жұмыс іздеймін. Ертең таңертең бастай аламын ба?"
	ui.send_message()
	await frames()
	var h0:Array=state.histories.get("cashier_0",[])
	check(h0.size()>=2 and not h0[-1].content.is_empty(),"offline reply committed to history")
	check(not ui.job_button.disabled,"local conversation unlocks the job button")
	check(str(ui.status.text).contains("дайын сөздерден"),"status shows the local-tree source")
	var said:Array=od.evaluate("Сәлеметсіз бе! Мен курьер болып жұмыс іздеймін. Ертең таңертең бастай аламын ба?")
	var collected:bool=false
	for w in said:
		if wb.entries.has(w):collected=true;break
	check(collected and wb.xp>=wb_xp_before and wb.entries.size()>=wb_size_before,"conversation words collected into the wordbook")
	if book_was_empty:
		check(wb.level_name()=="A1" and wb.xp>0,"fresh wordbook at A1 with earned xp")
	ui._job_action()
	check(state.employer==0,"offline path hires the player")
	ui._job_action()
	check(not state.delivery_id.is_empty(),"offline path gives the first order")
	ui.close_modal();game.shop_visits._transition(-1);await game.shop_visits.transition_finished
	# --- Wordbook phone page ---------------------------------------------------
	ui.open_phone();await frames()
	ui._phone_page("words");await frames()
	check(ui.phone_content.get_child_count()>3,"wordbook phone page renders")
	ui.close_modal();await frames()
	# --- Delivery and pay -----------------------------------------------------
	var index:int=state.delivery_index()
	if index<0 or index==state.home_index():
		print("OFFLINE_CHECK_DONE | failures=1 | no reachable order (index=",index,")")
		quit(1)
	var d:Dictionary=game.home_visits.doors[index]
	var reward:int=state.delivery_reward
	game.home_visits.place_player(d.landing,0);game.camera.look_at(d.point)
	await frames()
	game.interact();await game.home_visits.transition_finished
	var visits:Node=game.home_visits
	check(visits.current_door==index,"entered the delivery home")
	var actor:Node3D=visits.residents[0]
	game.camera.look_at(actor.global_position+Vector3.UP*1.45);await frames()
	check(state.can_deliver(),"recipient selectable")
	var money:int=state.money
	game.interact()
	check(state.delivery_id.is_empty() and state.pending_payment==reward,"offline handoff")
	state.neighbor_favors[d.id]=3;state.favor_done[d.id]=true;state.tea_pending=1
	visits.reset_inside();game.camera.rotation=Vector3(0,PI,0);game.interact()
	await visits.transition_finished
	game.shop_visits._transition(0);await game.shop_visits.transition_finished
	game.player.position=room.to_global(room.checkout_approach)
	game.camera.look_at(room.cashier.global_position+Vector3.UP*1.5);await frames()
	ui.open_chat("cashier_0");ui._job_action()
	check(state.money==money+reward and state.pending_payment==0,"offline pay claim")
	check(state.bonuses>=10,"bonus paid with the salary")
	# --- Coffee with Erlan (bonus spend) ---------------------------------------
	state.money=maxi(state.money,300);state.stamina=50
	check(state.can_buy_coffee(),"coffee offered at the counter after the shift")
	check(ui.coffee_button.visible,"coffee button shown in the chat with Erlan")
	ui._coffee_action()
	check(state.money==maxi(money+reward,300)-state.COFFEE_PRICE,"coffee costs its price")
	check(state.stamina==70,"coffee restores 20 stamina")
	check(state.coffee_day==state.day(),"coffee bought for today")
	check(not state.can_buy_coffee(),"only one coffee per day")
	ui.close_modal();game.shop_visits._transition(-1);await game.shop_visits.transition_finished
	# --- Neighbour tea in the evening ------------------------------------------
	state.elapsed=650.0
	check(not state.work_open(),"evening reached")
	check(not state.tea_ready_name().is_empty(),"tea offered tonight")
	state.stamina=50
	game.home_visits._transition(state.home_index());await game.home_visits.transition_finished
	await frames()
	check(state.tea_served_day==state.day() and state.tea_pending==0,"tea served once tonight")
	check(state.stamina==75,"tea restores 25 stamina")
	check(game.home_visits.rooms[game.home_visits.current_home].find_child("NeighborTea",true,false)!=null,"tea cup placed in the flat")
	state.stamina=50
	game.daily_life._tea_check()
	check(state.stamina==50 and state.tea_pending==0,"second call does not re-serve")
	game.home_visits._transition(-1);await game.home_visits.transition_finished
	# --- Night lamps ------------------------------------------------------------
	state.elapsed=999.0
	game.daily_life.update_daylight()
	check(game.town.lamp_lights.size()>0 and game.town.lamp_lights[0].light_energy>1.0,"street lamps on at night")
	state.elapsed=0.0
	game.daily_life.update_daylight()
	check(game.town.lamp_lights[0].light_energy<0.05,"street lamps off at 09:00")
	# --- Daily drills (spaced repetition) -------------------------------------
	wb.ensure_drills()
	check(wb.drills.size()==3,"three drills scheduled for the day")
	var any_id:String=str(wb.drills.keys()[0])
	var spec:Dictionary=wb.drill_spec(any_id)
	var word0:String=str(spec.words[0])
	var drill_money:int=state.money
	for i in int(spec.target):
		wb.record("Әсел","Мен "+word0+" алдым.","Жақсы, рақмет!")
	check(bool(wb.drills[any_id].done),"drill completes after its target messages")
	check(state.money==drill_money+int(spec.money),"drill pays its reward exactly")
	check(str(state.ledger[-1].text).contains("Тіл жаттығуы"),"drill reward lands in the ledger")
	var other_id:String=str(wb.drills.keys()[1])
	var other_progress:int=int(wb.drills[other_id].progress)
	wb.record("Әсел","Қалай жүр?","Мен "+str(wb.drill_spec(other_id).words[0])+" ұнаттым.")
	check(int(wb.drills[other_id].progress)==other_progress,"hearing a word does not advance the drill")
	check(wb.drills_done()>=1,"drill counter counts completed drills")
	# --- Daily weather (rain / fog / clear) -----------------------------------
	game.daily_life.new_day_weather()
	var w:String=game.daily_life.weather
	check(w in ["clear","rain","fog"],"weather rolled for the day (got "+w+")")
	check(game.daily_life.rain_particles!=null,"rain emitter built")
	var wet_mat:StandardMaterial3D=game.town.surface_materials["343d44"]
	var dry_color:Color=Color(wet_mat.get_meta("dry_albedo",wet_mat.albedo_color))
	game.daily_life.weather="rain";game.daily_life._apply_weather()
	check(game.daily_life.rain_particles.visible and game.town.population.walk_speed_factor>1.0,"forcing rain: particles on, pedestrians hurry")
	check(wet_mat.roughness<0.9,"road material glossy when wet")
	game.daily_life.weather="fog";game.daily_life._apply_weather()
	check(game.daily_life.we_node.environment.fog_density>0.01,"fog day thickens the air")
	game.daily_life.weather="clear";game.daily_life._apply_weather()
	check(not game.daily_life.rain_particles.visible and game.town.population.walk_speed_factor==1.0,"clear weather: no rain, normal pace")
	check(wet_mat.albedo_color.is_equal_approx(dry_color) and wet_mat.roughness==1.0,"clear weather restores the dry roads")
	# --- Player name above the head + the finale letter -------------------
	state.player_name="Сәуле"
	state.money=maxi(state.money,int(state.SHOP_PRICE))
	game.shop_visits._transition(3);await game.shop_visits.transition_finished
	check(state.purchase_shop(),"shop purchase")
	var shop_sign:Label3D=game.town.shops[3].get_node_or_null("ShopSign")
	check(shop_sign!=null and shop_sign.text=="МЕНІН ДҮКЕНІМ","bought shop wears a generic sign, not the player name")
	var head_name:Label3D=game.player.get_node_or_null("PlayerName")
	check(head_name!=null and head_name.text=="Сәуле","player name floats above the character's head")
	ui.open_phone();await frames()
	var letter_found:=false
	ui._phone_page("home")
	await frames()
	for c in ui.phone_content.get_children():
		if not (c is Label):continue
		if "Ата-анам" in str(c.text) and "Сәуле" in str(c.text):letter_found=true
	check(letter_found and state.finale_seen,"finale letter with the player name in the phone")
	# --- Listening quiz -------------------------------------------------------
	ui._phone_page("words");await frames()
	var quiz_button_found:=false
	var stack:Array=ui.phone_content.get_children().duplicate()
	while not stack.is_empty():
		var n:Node=stack.pop_back()
		if n is Button and "Дауыспен жаттау" in str(n.text):quiz_button_found=true
		stack.append_array(n.get_children())
	check(quiz_button_found,"listening quiz button on the wordbook page")
	var qword:String=str(wb.quiz_pool(1)[0])
	check(not wb.translation(qword).is_empty(),"quiz pool contains translatable words")
	var qopts:Array=wb.quiz_options(qword,1234)
	var quniq:=true
	for i in qopts.size():
		for j in range(i+1,qopts.size()):
			if qopts[i]==qopts[j]:quniq=false
	check(qopts.size()==4 and qopts.has(wb.translation(qword)) and quniq,"quiz options: 4 unique including the right one")
	var xp_before:int=wb.xp
	wb.quiz_result(qword,false)
	check(int(wb.entries[qword].miss)==1,"a wrong quiz answer marks the word for review")
	wb.quiz_result(qword,true)
	check(int(wb.entries[qword].miss)==0 and int(wb.entries[qword].known)==1 and wb.xp>xp_before,"a right quiz answer clears review and pays XP")
	ui._quiz_start()
	await frames()
	check(ui.quiz_active and ui.quiz_options.size()==4,"quiz session renders a question with 4 options")
	var wrong:String=""
	for t in ui.quiz_options:
		if str(t)!=wb.translation(ui.quiz_word):wrong=str(t);break
	check(not wrong.is_empty(),"quiz has a wrong option to choose")
	ui._quiz_answer(wrong)
	check(ui.quiz_answered and "Қайталауға жіберілді" in str(ui.quiz_status.text),"quiz reveals the correct word after a wrong answer")
	ui._quiz_next();await frames()
	check(ui.quiz_index==1,"quiz advances to the next word")
	ui.quiz_active=false
	ui.close_modal();await frames()
	game.shop_visits._transition(-1);await game.shop_visits.transition_finished
	# --- Fast offline fallback after an LLM failure ---------------------------
	ui.llm_last_fail=Time.get_ticks_msec()/1000.0
	check(not ui._llm_usable("fake-key"),"after an LLM failure the network is skipped")
	ui.llm_last_fail-=120.0
	check(ui._llm_usable("fake-key"),"the LLM is retried after the cooldown")
	print("OFFLINE_CHECK_DONE | failures=",failures.size()," | words=",wb.entries.size()," | xp=",wb.xp," | money=",state.money," | earned=",state.total_earned," | drills=",wb.drills_done(),"/3 | weather=",w)
	game.soundscape.set_process(false);game.soundscape.set_physics_process(false)
	for player in game.find_children("*","AudioStreamPlayer",true,false):player.stop()
	for player in game.find_children("*","AudioStreamPlayer3D",true,false):player.stop()
	await create_timer(.15).timeout
	game.queue_free();await create_timer(.15).timeout
	quit(0 if failures.is_empty() else 1)
func _initialize() -> void:
	create_timer(240).timeout.connect(func():push_error("OFFLINE_CHECK_TIMEOUT");quit(1))
	call_deferred("run")
