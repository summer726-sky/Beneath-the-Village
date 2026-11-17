extends RefCounted
class_name NarrativeCopy
## 入口、任务与结算的旁白。史实、推演、简化分开写。
## 一九四二年、清苑冉庄、五一扫荡、地道与街心古槐警钟：
## 中央纪委网站对冉庄地道战纪念馆的记述；
## 中国新闻网对清苑区地道战遗址文物保护中心副主任王静宇的采访（2025-08）。
## 十六公里是全村记载，不是这座院子。

const TITLE := "冉庄"
const PLACE := "一九四二年\n保定 · 清苑"

const HISTORY: Array[String] = [
	"冀中没有山。\n五一扫荡之后，炮楼和封锁沟把平原切开。",
	"村里的人把藏身的单口洞挖长，挖成户户相连的地道。\n十字街的老槐上，挂着报警的钟。",
	"眼下只是其中一座院子。院树上的钟，做的是同一件事。\n街心那两棵老槐，不在这里。墙外树洞朝东，留一条窄缝。",
]

const TASK := "东边田埂外，一支小队正朝村子走来。\n钟还没响，人还在院子里。井能灌水，隔板在井下。\n让人进北房夹壁。别让这支小队占住地道。"

const FOOT := "这是一座院子里的推演，不是某一次战斗的记录。\n空格，进树洞。"

const ENTER := "进入树洞"
const LOOK := "先看这座院子"
const AGAIN := "再来一次"

const SOURCE := "据中央纪委网站对冉庄地道战纪念馆的记述，及中国新闻网对遗址保护中心的采访。全村地道约十六公里，不是这座院子，也不是某一次战斗的复原。"

const SILENT_INDEX := 0


static func is_silent(index: int) -> bool:
	return index == SILENT_INDEX


static func outcome_title(result: StringName, reason: String) -> String:
	if result == &"VICTORY":
		return "这支小队没有留下。"
	if "被捕" in reason:
		return "人没有都进夹壁。"
	if "灌水" in reason or "进水" in reason:
		return "水进了掩体。"
	if "团灭" in reason or "阵亡" in reason:
		return "院子里没有人再能打。"
	if reason != "":
		return reason
	return "这一仗停在这里。"


static func outcome_mark(result: StringName) -> String:
	if result == &"VICTORY":
		return "守住了。"
	return "没守住。"


static func record_text() -> String:
	var state = _battle()
	var bell := "钟响过。" if bool(state.alarm_rung) else "钟没有响。"
	var well := "井没有灌水。"
	if bool(state.bunker_flooded):
		well = "水进了掩体。"
	elif bool(state.water_barrier_closed) and bool(state.water_started):
		well = "灌水开始后，隔板关上了。"
	elif bool(state.water_barrier_closed):
		well = "隔板是关上的。"
	elif bool(state.water_started):
		well = "井开始灌水，隔板没关上。"
	var seam := "树缝里开过枪。" if bool(state.recon_exposed) or bool(state.lookout_exposed) else "树缝里没有提前开枪。"
	return "\n".join([
		"进夹壁 %d 人，被带走 %d 人。" % [int(state.villagers_safe), int(state.villagers_captured)],
		"战友还在 %d 人。" % int(state.allies_alive),
		bell,
		well,
		seam,
	])


static func history_note() -> String:
	var state = _battle()
	if bool(state.bunker_flooded) or bool(state.water_started):
		return "地道要防灌水。这一处把挡水做成井下的一块隔板：关上，水留在下层。村子里的做法比这一块隔板完整。"
	if not bool(state.alarm_rung):
		return "十字街的老槐上悬钟报警。钟先响，人再往地道里走。院里这口钟是同一件事，不是那两棵街心古槐。"
	return "记载里，冉庄地道从十字街伸向四条大街。这里只留一座院子，把报警、藏身和挡水走一遍。"


static func _battle() -> Object:
	return Engine.get_main_loop().root.get_node("BattleState")
