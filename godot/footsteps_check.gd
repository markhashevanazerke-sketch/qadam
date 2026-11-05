extends SceneTree
var game:Node3D
var sound:Node
var failures:Array[String]=[]
func _initialize():call_deferred("run")
func check(value:bool,message:String):
 if not value:failures.append(message);push_error(message)
func frames(count:int):
 for i in count:await physics_frame
func reset_pose():
 game.player.position=game.town.to_global(Vector3(0,.15,45))
 game.player.velocity=Vector3.ZERO;game.yaw=0
 sound.step_guard=.25
 await frames(30)
func run():
 game=load("res://main.tscn").instantiate();root.add_child(game)
 await create_timer(2).timeout
 sound=game.soundscape;game.set_capture(true)
 await reset_pose()
 var before:int=sound.step_count
 await frames(40);check(sound.step_count==before,"standing must be silent")
 Input.action_press("forward");await frames(100);Input.action_release("forward");await frames(10)
 var walking:int=sound.step_count-before
 check(walking>=3 and walking<=5,"walking cadence: "+str(walking))
 await reset_pose();before=sound.step_count
 Input.action_press("forward");Input.action_press("run");await frames(100)
 Input.action_release("forward");Input.action_release("run");await frames(10)
 var running:int=sound.step_count-before
 check(running>=4 and running<=6,"running cadence: "+str(running))
 check(running>=walking,"run faster than walk")
 before=sound.step_count;game.set_capture(false);await frames(30)
 check(sound.step_count==before,"pause silent")
 game.set_capture(true);await reset_pose();before=sound.step_count
 game.player.position=game.town.to_global(Vector3(0,.15,42));await frames(40)
 check(sound.step_count==before,"teleport has no fake landing")
 Input.action_press("jump");await frames(1);Input.action_release("jump");await frames(65)
 check(sound.step_count==before+1,"one landing after a jump: "+str(sound.step_count-before))
 var foot:=-1
 for i in 12:
  sound._step(.1)
  var next:int=sound.last_step/3
  check(next!=foot,"left and right feet alternate");foot=next
 for i in 6:
  check(sound.streams["step_concrete_%d"%i].get_length()>.15,"shoe contact sample duration")
 print("FOOTSTEPS_CHECK | failures=",failures," | walk=",walking," | run=",running," | teleport, pause, landing, L/R")
 game.queue_free()
 await frames(2)
 quit(0 if failures.is_empty() else 1)
