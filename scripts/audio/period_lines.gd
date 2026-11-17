extends RefCounted
class_name PeriodLines
## 本局口令。按冀中地面吆喝和当前工事来写，不取电影《地道战》台词。
## 敌军行是日语口令的中文译文。配音用日语，字幕保持这句译文。

const PLAYER_EXPLORE := "先把地道走熟。钟在院子的树下。"
const PLAYER_EXPLORE_ID := "player_explore"

const PLAYER_COMBAT: PackedStringArray = [
	"有敌情！快隐蔽！",
	"往北房夹壁走，别出声！",
	"小声点，别让敌军听见！",
]
const PLAYER_COMBAT_IDS: PackedStringArray = [
	"player_warn",
	"player_hide",
	"player_quiet",
]

const VILLAGER_ALARM := "有敌情！快往北房夹壁躲！"
const VILLAGER_ALARM_ID := "villager_alarm"
const VILLAGER_WATER := "鬼子在灌水，快去关隔板！"
const VILLAGER_WATER_ID := "villager_water"

const ENEMY_ADVANCE := "敌军（日语口令）：向前！"
const ENEMY_FIRE := "敌军（日语口令）：射击！"
const ENEMY_HOLE := "敌军（日语口令）：搜洞口！"
const ENEMY_POUR := "敌军（日语口令）：向井里灌水！"
const ENEMY_ADVANCE_ID := "enemy_advance"
const ENEMY_FIRE_ID := "enemy_fire"
const ENEMY_FIRE_CMD_ID := "enemy_fire_cmd"
const ENEMY_HOLE_ID := "enemy_hole"
const ENEMY_POUR_ID := "enemy_pour"

static func villager_voice_id(slot: int, water: bool) -> String:
	var who := clampi(slot, 1, 3)
	return "villager_%d_%s" % [who, "water" if water else "alarm"]

static func enemy_voice_id(index: int, kind: String) -> String:
	return "enemy_%d_%s" % [index, kind]

static func ally_voice_id(ally_name: String, feedback: String) -> String:
	var who := "jia" if ally_name == "甲" else "yi"
	var act := "standby"
	if feedback.contains("孔"):
		act = "port"
	elif feedback.contains("隔板"):
		act = "barrier"
	elif feedback.contains("待命"):
		act = "standby"
	else:
		return ""
	return "ally_%s_%s" % [who, act]

static func spoken_rows() -> PackedStringArray:
	var rows := PackedStringArray()
	rows.append("%s|%s" % [PLAYER_EXPLORE_ID, PLAYER_EXPLORE])
	for i in PLAYER_COMBAT.size():
		rows.append("%s|%s" % [PLAYER_COMBAT_IDS[i], PLAYER_COMBAT[i]])
	for slot in 3:
		rows.append("%s|%s" % [villager_voice_id(slot + 1, false), VILLAGER_ALARM])
		rows.append("%s|%s" % [villager_voice_id(slot + 1, true), VILLAGER_WATER])
	return rows
