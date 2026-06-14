class_name RelicLib
extends RefCounted
## 유물 정의(규칙 변경 패시브). 코인으로 영구 해금 후 런마다 장착(GameState).
## 효과는 id로 코드 훅(player/projectile/main)에서 분기.

const EXECUTE_THRESHOLD := 0.12  ## 수확: 이 비율 이하 적 즉사
const REGEN_PER_SEC := 3.0       ## 재생: 초당 회복
const GREED_MULT := 2            ## 황금: 코인 배수
const BERSERK_MULT := 1.5        ## 격노: 저체력 데미지 배수
const BERSERK_HP_RATIO := 0.5    ## 격노 발동 체력 비율
const RELIC_BURN_DPS := 5.0      ## 점화: 화상 dps
const RELIC_BURN_DUR := 2.5
const RELIC_CHAIN_FACTOR := 0.5  ## 연쇄: 연쇄 데미지 비율

const RELICS := [
	{"id": "execute", "name": "수확의 룬", "desc": "체력 12% 이하 적 즉사", "cost": 160, "color": Color(0.9, 0.32, 0.34)},
	{"id": "chain", "name": "연쇄의 룬", "desc": "마력탄이 1회 연쇄", "cost": 120, "color": Color(0.5, 0.85, 1.0)},
	{"id": "ignite", "name": "점화의 룬", "desc": "스킬 명중 시 화상 부여", "cost": 110, "color": Color(1.0, 0.55, 0.25)},
	{"id": "regen", "name": "재생의 룬", "desc": "초당 체력 +3", "cost": 90, "color": Color(0.5, 0.9, 0.5)},
	{"id": "greed", "name": "황금의 룬", "desc": "코인 획득 2배", "cost": 100, "color": Color(1.0, 0.84, 0.4)},
	{"id": "berserk", "name": "격노의 룬", "desc": "체력 50% 이하 시 데미지 +50%", "cost": 150, "color": Color(0.95, 0.35, 0.42)},
	{"id": "bulwark", "name": "방벽의 룬", "desc": "받는 피해를 줄임", "color": Color(0.55, 0.7, 0.95)},
	{"id": "twin", "name": "쌍둥이의 룬", "desc": "스킬이 적을 더 노림", "color": Color(0.5, 0.85, 0.8)},
	{"id": "vamp", "name": "흡혈의 룬", "desc": "스킬 명중 시 흡혈", "color": Color(0.9, 0.4, 0.7)},
	{"id": "swift", "name": "신속의 룬", "desc": "스킬 쿨타임 단축", "color": Color(0.95, 0.9, 0.4)},
	{"id": "split", "name": "분열의 룬", "desc": "처치 시 주변 폭발", "color": Color(1.0, 0.5, 0.3)},
	{"id": "giant", "name": "거인의 룬", "desc": "최대 체력 증가", "color": Color(0.82, 0.62, 0.42)},
]

## id로 유물 정의 조회 (없으면 빈 Dictionary)
static func relic_def(id: String) -> Dictionary:
	for r in RELICS:
		if r.id == id:
			return r
	return {}

## --- 레벨별 효과(같은 유물 중복 뽑기로 강화). lv는 1부터(0이면 미보유). ---
static func execute_threshold(lv: int) -> float:
	return 0.12 + 0.04 * (lv - 1)   # 즉사 체력 비율: 12% → 레벨당 +4%p
static func chain_count(lv: int) -> int:
	return lv                        # 마력탄 연쇄 횟수: 레벨당 +1
static func burn_dps(lv: int) -> float:
	return 5.0 + 2.0 * (lv - 1)      # 화상 dps: 5 → 레벨당 +2
static func regen_per_sec(lv: int) -> float:
	return 3.0 * lv                  # 초당 회복: 레벨당 +3
static func greed_mult(lv: int) -> float:
	return 1.5 + 0.5 * lv            # 코인 배수: lv1=2.0배, 레벨당 +0.5
static func berserk_mult(lv: int) -> float:
	return 1.4 + 0.1 * lv            # 저체력 데미지 배수: lv1=1.5, 레벨당 +0.1

## 유물 효과를 현재 레벨 기준 한 줄로 (뽑기 화면 표시용)
static func effect_text(id: String, lv: int) -> String:
	match id:
		"execute": return "체력 %d%% 이하 적 즉사" % int(round(execute_threshold(lv) * 100.0))
		"chain":   return "마력탄이 %d회 연쇄" % chain_count(lv)
		"ignite":  return "스킬 명중 시 화상 %d/초" % int(burn_dps(lv))
		"regen":   return "초당 체력 +%d" % int(regen_per_sec(lv))
		"greed":   return "코인 획득 %.1f배" % greed_mult(lv)
		"berserk": return "체력 50%% 이하 시 데미지 +%d%%" % int(round((berserk_mult(lv) - 1.0) * 100.0))
		"bulwark": return "받는 피해 -%d" % int(2 * lv)
		"twin":    return "스킬이 적 +%d명 더 타격" % lv
		"vamp":    return "스킬 흡혈 %d%%" % int(3 * lv)
		"swift":   return "연사 +%.1f (쿨 단축)" % (0.3 * lv)
		"split":   return "처치 시 폭발(피해 ×%.1f)" % (0.3 * lv)
		"giant":   return "최대 체력 +%d" % int(20 * lv)
		_: return ""
