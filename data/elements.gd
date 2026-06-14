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

# 오방색(五方色): 목=청(초록 계열)·화=적·토=황·금=백(하양)·수=흑(먹/짙은 남). 순흑은 어두운 배경에서 안 보여 가독성용으로 띄움.
const INFO := {
	"wood":  {"name": "목", "color": Color(0.45, 0.82, 0.45)},   # 청(靑) — 푸름/초록
	"fire":  {"name": "화", "color": Color(0.95, 0.45, 0.35)},   # 적(赤)
	"earth": {"name": "토", "color": Color(0.85, 0.7, 0.4)},     # 황(黃)
	"metal": {"name": "금", "color": Color(0.92, 0.93, 0.97)},   # 백(白) — 하양
	"water": {"name": "수", "color": Color(0.42, 0.45, 0.60)},   # 흑(黑) — 먹/짙은 남(가독성 위해 살짝 띄움)
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
