class_name ElementLib
extends RefCounted
## 오행 속성 상성. 상극(이기는) 순환: 목→토→수→화→금→목.
## 내 속성이 적을 극하면 강타(×1.5), 적이 나를 극하면 약화(×0.7), 그 외 ×1.

const STRONG := 1.5
const WEAK := 0.7

# 키 속성이 "극하는"(강한) 대상 속성
const COUNTERS := {
	"wood": "earth",
	"earth": "water",
	"water": "fire",
	"fire": "metal",
	"metal": "wood",
}

const INFO := {
	"wood":  {"name": "목", "color": Color(0.45, 0.82, 0.45)},
	"fire":  {"name": "화", "color": Color(0.95, 0.45, 0.35)},
	"earth": {"name": "토", "color": Color(0.85, 0.7, 0.4)},
	"metal": {"name": "금", "color": Color(0.82, 0.84, 0.92)},
	"water": {"name": "수", "color": Color(0.45, 0.7, 0.95)},
}

## 공격자 속성이 방어자에게 주는 데미지 배율 (둘 중 빈 값이면 1.0)
static func multiplier(attacker: String, defender: String) -> float:
	if attacker == "" or defender == "":
		return 1.0
	if COUNTERS.get(attacker, "") == defender:
		return STRONG
	if COUNTERS.get(defender, "") == attacker:
		return WEAK
	return 1.0

static func display_name(elem: String) -> String:
	return INFO.get(elem, {}).get("name", "")

static func color(elem: String) -> Color:
	return INFO.get(elem, {}).get("color", Color(1, 1, 1))

## 이 속성이 강한 대상의 표시명 (카드 안내용)
static func strong_against(elem: String) -> String:
	return display_name(COUNTERS.get(elem, ""))
