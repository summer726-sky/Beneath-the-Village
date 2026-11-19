extends RefCounted
class_name NarrativeCopy
## 入口、任务与结算的旁白。史实、推演、简化分开写。
## 一九四二年、清苑冉庄、五一扫荡、地道与街心古槐警钟：
## 中央纪委网站对冉庄地道战纪念馆的记述；
## 中国新闻网对清苑区地道战遗址文物保护中心副主任王静宇的采访（2025-08）。
## 十六公里是全村记载，不是这座院子。

const TITLE := "冉庄"
const PLACE := "一九四二年\n保定 · 清苑 · 冉庄"

const HISTORY: Array[String] = [
	"冀中没有山。五一扫荡之后，炮楼和封锁沟把平原切开。",
	"藏身的单口洞挖成了地道。十字街的老槐上挂着钟。",
	"这只是其中一座院子。街心那两棵老槐，不在这里。",
]

const TASK := "东边田埂外有一支小队。钟还没响，人还在院子里。\n让人进北房夹壁。井下的隔板不关上，水会灌进来。"

const RULES := "【成功】消灭全部敌军。\n【失败】两村民押到瞭望树；两村民被杀害；掩体进水；团灭。\n村民藏关隔板后不淹的暗室。钟晚了就近入口逃（比敌军慢）。救人质须击毙押送者，否则人质遇害。\n【操作】WASD 移动　鼠标转视角　左键射击　E 交互　Shift 蹲　空格 跳　C 贴墙　F 派任务　G 喊话　B 正式游戏　Q 概况　Esc 暂停（继续/回开头/退出）\n【界面】左上弹药/生命/村民　下方提示对话　右上角是分层地图（藏身/机关）\n开场可选「正式游戏」（树洞开战）或「地图探索」（院子里熟悉地形）。"

const FOOT := "空格，开始正式游戏。"

const ENTER := "正式游戏"
const LOOK := "地图探索"
const AGAIN := "再来一次"

const SOURCE := "据中央纪委网站对冉庄地道战纪念馆的记述，及中国新闻网对遗址保护中心的采访。全村地道约十六公里，不是这座院子，也不是某一次战斗的复原。"

const SILENT_INDEX := 0


static func is_silent(index: int) -> bool:
	return index == SILENT_INDEX


static func outcome_title(result: StringName, reason: String) -> String:
	if result == &"VICTORY":
		return "这支小队没有留下。"
	if "瞭望树" in reason or "被捕" in reason or "押到" in reason:
		return "人没有都进夹壁。"
	if "杀害" in reason:
		return "人质没有保住。"
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
	return "进夹壁 %d 人，押到树下 %d 人，遇害 %d 人。战友还在 %d 人。\n%s%s%s" % [
		int(state.villagers_safe), int(state.villagers_transferred), int(state.villagers_killed), int(state.allies_alive),
		bell, well, seam,
	]


static func history_note() -> String:
	var state = _battle()
	if bool(state.bunker_flooded) or bool(state.water_started):
		return "井下那块隔板是用来挡水的。关上，水留在下层。"
	if not bool(state.alarm_rung):
		return "十字街的老槐上悬钟。钟先响，人再往地道里走。院里这口钟是同一件事。"
	return "冉庄的地道从十字街伸出去。这里只留一座院子。"


static func _battle() -> Object:
	return Engine.get_main_loop().root.get_node("BattleState")
