extends RefCounted
class_name PeriodLines
## 本局口令。按冀中地面吆喝和当前工事来写，不取电影《地道战》台词。
## 敌军行是日语口令的中文译文，不能拿去配中文语音。

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

static func spoken_rows() -> PackedStringArray:
	var rows := PackedStringArray()
	rows.append("%s|%s" % [PLAYER_EXPLORE_ID, PLAYER_EXPLORE])
	for i in PLAYER_COMBAT.size():
		rows.append("%s|%s" % [PLAYER_COMBAT_IDS[i], PLAYER_COMBAT[i]])
	rows.append("%s|%s" % [VILLAGER_ALARM_ID, VILLAGER_ALARM])
	rows.append("%s|%s" % [VILLAGER_WATER_ID, VILLAGER_WATER])
	return rows
