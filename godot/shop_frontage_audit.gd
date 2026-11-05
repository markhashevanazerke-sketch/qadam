extends SceneTree
func _initialize():call_deferred("run")
func run():
	var game=load("res://main.tscn").instantiate();root.add_child(game)
	await create_timer(2).timeout
	for i in game.town.buildings.size():
		var n=game.town.buildings[i]
		if absf(absf(n.position.x)-41.5)<.01:print(n.name," center=",n.position," bounds=",game.town.footprints[i])
	quit()
