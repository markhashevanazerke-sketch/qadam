extends RefCounted
class_name OfflineDialog
# ---------------------------------------------------------------------------
# Local fallback dialogue: pre-written phrases for when the LLM (Alem) is
# unavailable. The game stays fully playable offline; the LLM only adds
# liveliness on top.
# Honesty principle: we evaluate words, not accent.
# ---------------------------------------------------------------------------

const KAZ_WORDS:PackedStringArray=[
	"сәлем","сәлеметсіз","сау","рақмет","тапсырыс","дүкен","жұмыс","курьер","ақша","теңге",
	"шай","су","нән","тамақ","еңбекақы","көмек","сұрақ","айтыңыз","атым","аудан","көше",
	"үй","пәтер","бөлме","сабақ","алып","келдім","бердім","әкелдім","жеткіздім","төле",
	"баға","қанша","қалай","қайда","кім","қашан","неге","жылы","суық","жаңбыр","боран",
	"ауа","райы","күн","түн","таңертең","кеш","түс","демалыс","бүгін","ертең","адам",
	"құрмет","қонақ","кіріңіз","шығыңыз","отыр","тұр","жүр","бар","кел","көр","есті",
	"сөйле","жаз","оқы","жібер","сақта","қолдас","иә","жоқ","мен","сен","ол","біз",
]

static func reply(id:String,profile:Dictionary,words:String,story=null) -> String:
	var text:=words.to_lower()
	var intent:=_detect(text)
	var turn:int=absi(hash(str(id)+str(intent)))
	var lines:Array=_lines(intent,id,profile,story)
	if lines.is_empty():lines=["Сәлем! Тағы кездескенше."]
	var out:=str(lines[posmod(turn,lines.size())])
	var corr:=_correction(text)
	if not corr.is_empty():out+=" "+corr
	return out
# Recognised Kazakh words in the player's message (hook for future XP levels).
static func evaluate(words:String) -> Array:
	var text:=words.to_lower()
	var found:Array=[]
	for w in KAZ_WORDS:
		if text.contains(w) and not found.has(w):found.append(w)
	return found

static func _has(text:String,variants:Array[String]) -> bool:
	for v in variants:
		if text.contains(v):return true
	return false
static func _detect(text:String) -> String:
	if _has(text,["рақмет","ракмет","спасибо","thanks"]):return "thanks"
	if _has(text,["сау бол","саубол","қош бол","қош","көргенше","кездескенше","сәттілік","пока"]):return "bye"
	if _has(text,["тапсырысыңыз","алып келдім","әкелдім","бердім","жеткіздім","тапсырыс алып","салонға тапсырыс"]):return "delivery"
	if _has(text,["жұмыс","кур","еңбек","жалақы"]):return "job"
	if _has(text,["еңбекақы","ақша","төле","баға","қанша","теңге"]):return "money"
	if _has(text,["шай","су","нән","тамақ","аш"]):return "food"
	if _has(text,["көмек","сұрағым","не істе","қалай істе","мағлұмат"]):return "help"
	if _has(text,["атым","менің атым"]):return "name"
	if _has(text,["қалың","жағдай","жаңалық","амансың","амансыз","жақсысың"]):return "howare"
	if _has(text,["жаңбыр","боран","ауа райы","жылы","суық","түнде","кешкі"]):return "weather"
	if _has(text,["сәлем","салем","салом","привет","хай","хеллоу","hello","здравствуйте","hi"]):return "greeting"
	return "other"

static func _lines(intent:String,id:String,profile:Dictionary,story) -> Array:
	var name:=str(profile.get("name","Көрші"))
	var persona:=str(profile.get("character","erlan"))
	match intent:
		"job":return _job(id,profile,story)
		"delivery":
			if id.begins_with("resident_"):
				return ["Рақмет, келіпсің! Затты алып, E батырмасын бас. Еңбекақыңды дүкенде аласың.",
					"Иә, сені күттік! Енді тапсырысты бер — E батырмасы. Дүкенге қайтқан сайын еңбекақы дайын болады."]
			if id=="cashier_4":
				return ["Көп рақмет! Зат алып келдің. Сыйақың дайын — қолға ал.",
					"Ана, дәл керегін әкеліпсің. Салон үшін пайдалы. Сыйақыңды ал."]
			return ["Жақсы айтасың! Тапсырыс алушыны күтіп отыр. Мекенжай телефонда, еңбекақы дүкенде.",
				"Сөздің анық! Енді E арқылы тапсырысты бер. Еңбекақыны BEREKE-де аласың."]
		"money":
			if id=="cashier_0":
				return ["Еңбекақы — тапсырысты берген соң. Дүкенге кел, батырмадан аласың. Әр тапсырысқа 10 бонус та бар.",
					"Алдымен тапсырыс, содан ақша. Батырмадан тапсырыс ал, мекенжай телефонда болады."]
			if id.begins_with("resident_"):
				return ["Еңбекақыңды дүкендегі Ерландан аласың. Мен азық-түлікті ғана аламын.",
					"Ақша менің ісім емес. Бастысы — тапсырысты бере бер, дүкенде төлейді."]
			return _persona(persona,[
				"Ақша туралы айтсаң… тапсырыс жаса, тапсырыс ақша береді. Қарапайым ереже.",
				"Ақша сұрағы ма? Әр тапсырыс 700–1500 теңге береді. Жүре бер!"],name)
		"food":
			if id.begins_with("salon_"):
				return ["Шай! Жылы шай ішіп алайық. Салонда демалу ұнайды ма?",
					"Тамақ па? Алдымен тапсырысыңды бер, содан кейін шай ішіп демалайық."]
			if persona=="asel":
				return ["Тамақ ма? Мен шығынды дәптерге жазамын. Таңертең нән алу — арзан әдет.",
					"Кешкі ас дүкен кассасында 200 теңге. Өзің асыра алмайсың — тамақ маңызды."]
			if persona=="miras":
				return ["Ашпа? Бір шай ішіп алайық. Жылы шай — барлық нәрсенің басы.",
					"Тамақ — күш. Дүкенден бір нәрсе сатып ал, содан серуенге шық."]
			return ["Кешкі ас ма? Дүкен кассасынан сатып алуға болады — 200 теңге.",
				"Тамақ ішкенше жол қысқа емес. Бірақ аш адам жұмыс істей алмайды."]
		"help":
			return _persona(persona,[
				"Әрине, сұра! Мен қалай көмектесе аламын? Қысқаша айтып бер.",
				"Бола бер. Сұрағыңды жеңіл сөзбен айт — мен тыңдаймын."],name)
		"name":
			return ["Менің атым %s. Танысып қуандым. Сенің атың да жақсы естіледі."%name,
				"%s деп атайды. Атыңды естідім — жақсы таныстық болды."%name]
		"howare":
			return ["Алғысым бар, жақсы! Жұмыс көп, бірақ жақсы. Сен қалайсың?",
				"Жақсы, рақмет! Ауданда өмір қызықты. Сенің күнің қалай өтті?"]
		"weather":
			return ["Бүгін ауа райы тыныш. Кешке салқындайды — жылы киін.",
				"Ауа райы дұрыс. Кешкі серуен үшін жақсы уақыт."]
		"greeting":
			return _persona(persona,[
				"Сәлем! Қалың қалай? Бүгін ауданда адам көп. Сені көріп қуаныштымын.",
				"Сәлеметсіз бе! Ауданға жаңа келдің бе? Осы жер жылы орын."],name)
		_:
			return ["Кешірің, жақсы түсінбедім. Қайта айтасың ба? Мысалы: «Сәлем, менің атым Натан».",
				"Түсінбедім... Жеңіл сөзбен қайта айтшы. Мысал: «Мен жұмыс іздеп жүрмін»."]

static func _job(id:String,profile:Dictionary,story) -> Array:
	var name:=str(profile.get("name","Ерлан"))
	if id=="cashier_0":
		var employed:bool=story!=null and story.employer>=0
		if employed:
			return ["Сен енді біздің курьерімісің. Жауапты іс! Келесі тапсырысты батырмадан ал.",
				"Құттықтаймын! Еңбекке дайынсың ба? Тапсырыс алу — батырмада, мекенжай телефонда."]
		return ["Жақсы! BEREKE дүкені жаңа курьер іздеп жүр. Сені қабылдауға болады. Төмендегі «Курьер болып жұмысқа тұру» батырмасын бас.",
			"Курьер ме? Жарайды. Біздің дүкенде орын бар. Батырманы басып, жұмысқа тұр. Әр тапсырыс — 700–1500 теңге."]
	if int(profile.get("shop",-1))>=0:
		return ["Жұмыс іздесең, BEREKE дүкеніне бар. Басқарушы Ерлан жаңа курьерді қабылдайды.",
			"Бізде қазір жұмыс жоқ. BEREKE-дегі Ерланға баршы, ол курьер алады."]
	return ["Жұмыс іздесең — BEREKE дүкеніне бар. %s жаңа курьерді қабылдайды. Ол сабырлы адам."%name,
		"Курьер болғысы келе ме? BEREKE-дегі Ерлан жұмыс береді. Оған бағыттауға қуаныштымын."]

static func _persona(persona:String,base:Array,name:String) -> Array:
	# Keep the shared line pool but let each persona add a personal touch.
	match persona:
		"asel":return [base[0]+" "+["Мен жаңа таныс адамдарды жақсы көремін. Жалғастырайық.",
			"Кішкентай сөздерден үлкен әңгіме болады. Сәлем!"][absi(hash(name))%2]]
		"miras":return [base[0]+" "+["Дос, айтып тұр: жүре бер, ақша келеді. Шай ішіп демал.",
			"Сен жолдастасымсың. Күшті жүр!"][absi(hash(name))%2]]
		"dana":return [base[0]+" "+["Кел, ішке отыр, жылы шай ішіп демал.",
			"Салонда демалу — ең жақсы серуен."][absi(hash(name))%2]]
		"aruzhan":return [base[0]+" "+["Қонақсыз ғой, қолыңызда не болса — айтыңыз.",
			"Ішке қош келдіңіз. Не керек болса, көмектесемін."][absi(hash(name))%2]]
		_:return [base[0]+" "+["Уақыт — алтын, бірақ әңгіме үшін бар.",
			"Аудандағы жаңалықтарды білгің келе ме?"][absi(hash(name))%2]]

static func _correction(text:String) -> String:
	if text.contains("салем") and not text.contains("сәлем"):return "Былай айтуға болады: Сәлем."
	if text.contains("ракет") or text.contains("ракмет"):return "Былай айтуға болады: Рақмет."
	return ""
