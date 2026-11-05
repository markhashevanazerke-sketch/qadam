extends Node
# ---------------------------------------------------------------------------
# Сөздік — a local Kazakh wordbook and language level (A1→B1).
# Words are collected from real conversations (player + NPC sides).
# Honesty principle: we evaluate words used, not accent.
# XP: player word +3, heard word +1 (first time only).
# ---------------------------------------------------------------------------
const SAVE:="user://wordbook_v1.json"
const OFFLINE=preload("res://offline_dialog.gd")
# Russian glosses for the listening quiz: hear the Kazakh word, pick the meaning.
const TRANSLATIONS:Dictionary={
	"сәлем":"привет","сәлеметсіз":"здравствуйте","сау":"пока","рақмет":"спасибо",
	"тапсырыс":"заказ","дүкен":"магазин","жұмыс":"работа","курьер":"курьер",
	"ақша":"деньги","теңге":"тенге","шай":"чай","су":"вода","нән":"хлеб",
	"тамақ":"еда","еңбекақы":"зарплата","көмек":"помощь","сұрақ":"вопрос",
	"айтыңыз":"скажите","атым":"моё имя","аудан":"район","көше":"улица",
	"үй":"дом","пәтер":"квартира","бөлме":"комната","сабақ":"занятие",
	"келдім":"я пришёл","бердім":"я дал","әкелдім":"я принёс",
	"жеткіздім":"я доставил","төле":"плати","баға":"цена","қанша":"сколько",
	"қалай":"как","қайда":"где","кім":"кто","қашан":"когда","неге":"почему",
	"жылы":"тёплый","суық":"холодный","жаңбыр":"дождь","боран":"пурга",
	"күн":"день","түн":"ночь","таңертең":"утро","кеш":"вечер","түс":"полдень",
	"демалыс":"отдых","бүгін":"сегодня","ертең":"завтра","адам":"человек",
	"құрмет":"уважение","қонақ":"гость","кіріңіз":"проходите","шығыңыз":"выходите",
	"жүр":"идёт","иә":"да","жоқ":"нет","мен":"я","сен":"ты","ол":"он","біз":"мы",
}
const LEVELS:Array=[
	{"id":"A1","title":"Бастау","xp":0},
	{"id":"A2","title":"Ортада","xp":150},
	{"id":"B1","title":"Ашылды","xp":400},
]
const MAX_WORDS:=400
# Spaced-repetition drills: three small speaking tasks per day, picked
# deterministically by day number. A drill completes when the player's own
# messages contain its words the required number of times.
const DRILLS:Array=[
	{"id":"greet","text":"Өткендермен сәлемдес: «Сәлем» — 3 рет","words":["сәлем","сәлеметсіз"],"target":3,"xp":6,"money":15},
	{"id":"thanks","text":"«Рақмет» дей бер — 2 рет","words":["рақмет"],"target":2,"xp":4,"money":10},
	{"id":"price","text":"Бағаны сұра: «Қанша?»","words":["қанша","баға"],"target":1,"xp":5,"money":15},
	{"id":"tea","text":"Шай туралы сөз қос: «Шай бар ма?»","words":["шай"],"target":1,"xp":5,"money":10},
	{"id":"weather","text":"Ауа райын айтып бер (жаңбыр · жылы · суық)","words":["жаңбыр","жылы","суық","боран"],"target":1,"xp":5,"money":10},
	{"id":"bye","text":"Қоштас: «Сау бол» — 2 рет","words":["сау"],"target":2,"xp":4,"money":10},
	{"id":"food","text":"Тамақ туралы сөйлес (нән · тамақ)","words":["нән","тамақ"],"target":1,"xp":5,"money":10},
]
var game:Node3D
var entries:Dictionary={} # word -> {example, npc, day, seen, own}
var xp:=0
var drills:Dictionary={} # drill id -> {progress, done}
var drills_day:=0
var last_drill:=""
signal drill_completed(id:String)

func _ready() -> void:
	game=get_parent()
	if not game.automated:load_data()

func level_index() -> int:
	var i:=0
	for l in LEVELS.size():
		if xp>=int(LEVELS[l].xp):i=l
	return i
func level_name() -> String:return str(LEVELS[level_index()].id)
func level_title() -> String:return str(LEVELS[level_index()].title)
func next_level_xp() -> int:
	if level_index()>=LEVELS.size()-1:return xp
	return int(LEVELS[level_index()+1].xp)
# Schedule today's three drills (stable per day, different day to day).
func ensure_drills() -> void:
	var day:int=game.story.day()
	if day==drills_day and not drills.is_empty():return
	drills={};drills_day=day
	var ids:PackedStringArray=[]
	for d in DRILLS:ids.append(str(d.id))
	var rng:=RandomNumberGenerator.new();rng.seed=day*7919+13
	for i in range(ids.size()-1,0,-1):
		var j:int=rng.randi_range(0,i)
		var t:=ids[i];ids[i]=ids[j];ids[j]=t
	for id in ids.slice(0,3):drills[id]={"progress":0,"done":false}
func drill_spec(id:String) -> Dictionary:
	for d in DRILLS:
		if str(d.id)==id:return d
	return {}
func drills_done() -> int:
	var n:=0
	for id in drills:
		if bool(drills[id].done):n+=1
	return n
func level_progress() -> float:
	if level_index()>=LEVELS.size()-1:return 1.0
	var base:=int(LEVELS[level_index()].xp)
	var top:=int(LEVELS[level_index()+1].xp)
	return clampf(float(xp-base)/float(top-base),0.0,1.0)
# Tip bonus paid by the employer for language level: bigger tips when you
# speak Kazakh. 2 bonus points per level above A1.
func language_tip() -> int:return maxi(0,level_index())*2
func sorted_words() -> Array:
	var words:=entries.keys()
	words.sort_custom(func(a,b):
		if int(entries[a].seen)!=int(entries[b].seen):return int(entries[a].seen)>int(entries[b].seen)
		return str(a)<str(b))
	return words
# --- Listening quiz: review words first, then the least-practised new ones.
func translation(word:String) -> String:
	return str(TRANSLATIONS.get(word,""))
func review_count() -> int:
	var n:=0
	for w in entries:
		if int(entries[w].miss)>0:n+=1
	return n
func quiz_pool(count:int=8,only_miss:bool=false) -> Array:
	var pool:Array=[]
	for w in entries:
		if not TRANSLATIONS.has(w):continue
		if only_miss and int(entries[w].miss)==0:continue
		pool.append(str(w))
	pool.sort_custom(func(a,b):
		var ea:Dictionary=entries[a];var eb:Dictionary=entries[b]
		if int(ea.miss)!=int(eb.miss):return int(ea.miss)>int(eb.miss)
		if int(ea.known)!=int(eb.known):return int(ea.known)<int(eb.known)
		return int(eb.day)>int(ea.day))
	return pool.slice(0,int(count))
func quiz_options(word:String,seed:int) -> Array:
	var rng:=RandomNumberGenerator.new();rng.seed=seed
	var others:Array=TRANSLATIONS.keys().filter(func(t):return t!=word)
	others.shuffle()
	var opts:Array=[str(TRANSLATIONS[word])]
	for t in others.slice(0,3):opts.append(str(TRANSLATIONS[t]))
	opts.shuffle()
	return opts
# Apply one answered question; returns XP earned.
func quiz_result(word:String,correct:bool) -> int:
	if not entries.has(word):return 0
	var e:Dictionary=entries[word]
	var gained:=0
	if correct:
		e.miss=0;e.known=int(e.known)+1;gained=2
	else:
		e.miss=int(e.miss)+1
	if gained>0:xp+=gained
	save()
	return gained
# Record one exchange; returns the number of new words the PLAYER used.
func record(npc_name:String,user_words:String,npc_reply:String) -> int:
	var added:=0
	var day:int=game.story.day()
	ensure_drills()
	var used:Array=OFFLINE.evaluate(user_words)
	for w in used:
		if not entries.has(w):
			entries[w]={"example":_sentence_with(user_words,w),"npc":npc_name,"day":day,"seen":1,"own":true,"miss":0,"known":0}
			xp+=3;added+=1
		else:
			entries[w].seen=int(entries[w].seen)+1
	for w in OFFLINE.evaluate(npc_reply):
		if not entries.has(w):
			entries[w]={"example":_sentence_with(npc_reply,w),"npc":npc_name,"day":day,"seen":1,"own":false,"miss":0,"known":0}
			xp+=1
		else:
			entries[w].seen=int(entries[w].seen)+1
	last_drill=_drill_tick(used)
	while entries.size()>MAX_WORDS:
		var oldest:String=""
		var oldest_seen:=INF
		for w in entries:
			if int(entries[w].seen)<oldest_seen or (int(entries[w].seen)==oldest_seen and int(entries[w].day)<int(entries[oldest].day)):
				oldest_seen=int(entries[w].seen);oldest=str(w)
		if oldest.is_empty():break
		entries.erase(oldest)
	save()
	return added
func _sentence_with(words:String,target:String) -> String:
	var best:=""
	for raw in words.split("."):
		var s:=raw.strip_edges()
		if s.to_lower().contains(target) and s.length()<=160 and s.length()>best.length():
			best=s
	return best if not best.is_empty() else words.left(140)
# Advance today's drills with the words the player just used.
# Returns the id of the drill that reached its target (or "").
func _drill_tick(used:Array) -> String:
	var completed:=""
	for id in drills:
		var d:Dictionary=drills[id]
		if bool(d.done):continue
		var spec:Dictionary=drill_spec(str(id))
		var target:Array=spec.words
		var matched:=false
		for w in used:
			if target.has(w):matched=true;break
		if not matched:continue
		d.progress=int(d.progress)+1
		if d.progress>=int(spec.target):
			d.done=true;completed=str(id)
			xp+=int(spec.xp)
			game.story.money+=int(spec.money)
			game.story.ledger.append({"text":"Тіл жаттығуы · %d-күн"%game.story.day(),"amount":int(spec.money)})
			while game.story.ledger.size()>20:game.story.ledger.pop_front()
			game.story.changed.emit();game.story.save()
	if not completed.is_empty():drill_completed.emit(completed)
	return completed
func load_data() -> bool:
	if FileAccess.file_exists(SAVE):
		var value=JSON.parse_string(FileAccess.get_file_as_string(SAVE))
		if value is Dictionary:
			xp=clampi(int(value.get("xp",0)),0,100000)
			if value.get("entries") is Dictionary:
				for w in value.entries:
					var e:Dictionary=value.entries[w]
					entries[str(w)]={"example":str(e.get("example","")),"npc":str(e.get("npc","")),"day":int(e.get("day",1)),"seen":int(e.get("seen",1)),"own":bool(e.get("own",false)),"miss":int(e.get("miss",0)),"known":int(e.get("known",0))}
			if value.get("drills") is Dictionary:
				for id in value.drills:
					var dd:Dictionary=value.drills[id]
					drills[str(id)]={"progress":int(dd.get("progress",0)),"done":bool(dd.get("done",false))}
				drills_day=int(value.get("drills_day",0))
			return true
	return false
func save() -> void:
	if game.automated:return
	var data:Dictionary={"version":1,"xp":xp,"entries":{},"drills":{},"drills_day":drills_day}
	for w in entries:
		data.entries[w]={"example":entries[w].example,"npc":entries[w].npc,"day":entries[w].day,"seen":entries[w].seen,"own":entries[w].own,"miss":int(entries[w].miss),"known":int(entries[w].known)}
	for id in drills:
		data.drills[id]={"progress":int(drills[id].progress),"done":bool(drills[id].done)}
	var file:=FileAccess.open(SAVE+".tmp",FileAccess.WRITE)
	if file==null:return
	file.store_string(JSON.stringify(data));file.close()
	DirAccess.rename_absolute(ProjectSettings.globalize_path(SAVE+".tmp"),ProjectSettings.globalize_path(SAVE))
