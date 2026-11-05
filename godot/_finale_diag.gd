extends SceneTree
var game:Node3D
func run() -> void:
	game=load("res://main.tscn").instantiate();root.add_child(game)
	await create_timer(3).timeout
	var state:Node=game.story;var ui:Node=game.story_ui
	check(game.automated,"automated on --offline-check")
	state.player_name="Сәуле"
	state.money=maxi(state.money,int(state.SHOP_PRICE))
	game.set_capture(true)
	game.set_physics_process(false);game.town.set_physics_process(false)
	game.shop_visits._transition(3)
	await game.shop_visits.transition_finished
	check(state.purchase_shop(),"purchase")
	ui.open_phone()
	for f in 3:await physics_frame
	ui._phone_page("home")
	for f in 3:await physics_frame
	print("D2 | owns=",state.owns_shop," finale_seen=",state.finale_seen," name=",state.player_name)
	for c in ui.phone_content.get_children():
		if c is Label:print("D2 | label: ",str(c.text).left(70).replace("\n","\\n"))
	print("D2 | FAILURES=",failures.size())
	quit(0)
func check(ok:bool,label:String) -> void:
	if not ok:failures.append(label);print("D2-FAIL | ",label)
var failures:Array[String]=[]
func _initialize() -> void:
	call_deferred("run")
