class_name SkillLib
extends RefCounted
## 카드로 획득하는 보조 스킬 정의. id는 main._on_skill_cast의 분기와 동일(기존 5종 재사용).
## 밸런스: 캐릭터 고유 스킬보다 위력 낮고 쿨타임 김 — '빈 시간 채우기 + 빌드 다양성'용.

## element = 카드에 표시할 대표 오행 속성(불/물/나무/쇠/흙). 실제 시전 상성은 시전 캐릭터 속성을 따름.
const DEFS := {
	"bolts":   {"name": "마력탄", "cooldown": 5.5, "power": 10.0, "radius": 0.0, "count": 3, "element": "wood"},
	"meteor":  {"name": "유성", "cooldown": 10.5, "power": 18.0, "radius": 90.0, "count": 0, "element": "fire"},
	"barrage": {"name": "융단폭격", "cooldown": 9.5, "power": 13.0, "radius": 65.0, "count": 3, "element": "earth"},
	"chain":   {"name": "전격", "cooldown": 8.0, "power": 13.0, "radius": 0.0, "count": 4, "element": "metal"},
	"freeze":  {"name": "서리바람", "cooldown": 12.0, "power": 9.0, "radius": 0.0, "count": 0, "element": "water"},
	"thorns":  {"name": "가시밭", "cooldown": 9.0, "power": 9.0, "radius": 110.0, "count": 0, "element": "wood"},
}

## 스킬 시전 사거리(마법사로부터). 이 거리 안의 적만 타겟 — 스킬별 차등(기지 y≈1150 기준).
## 마력탄·메테오·융단은 멀리, 전격(연쇄)은 가까이, 서리는 중거리.
const SKILL_RANGE := {
	"bolts": 1000.0,
	"chain": 650.0,
	"meteor": 1100.0,
	"barrage": 1100.0,
	"freeze": 850.0,
	"thorns": 900.0,
}

## 진화 트리 — 같은 스킬을 다시 획득하면 상위 티어로(현재 스탯에 배율/가산 적용 → 고유·획득 모두 진화).
## 각 항목 = tier N→N+1 효과. 정의 없는 스킬은 진화 대신 새 인스턴스로 누적(다중 스킬).
const EVOLVE := {
	"bolts": [
		{"name": "연발 마력탄", "count": 2, "cd_mult": 0.82, "power_mult": 1.25},
		{"name": "마력 폭풍", "count": 3, "cd_mult": 0.70, "power_mult": 1.55},
		{"name": "비전 노바", "count": 4, "cd_mult": 0.7, "power_mult": 1.6},
	],
	"meteor": [
		{"name": "쌍둥이 메테오", "radius_mult": 1.25, "power_mult": 1.4},
		{"name": "운석 강우", "radius_mult": 1.6, "power_mult": 1.95},
		{"name": "종말의 운석", "radius_mult": 1.4, "power_mult": 2.0},
	],
	"chain": [
		{"name": "폭풍 번개", "count": 2, "cd_mult": 0.85, "power_mult": 1.3},
		{"name": "천벌", "count": 3, "cd_mult": 0.7, "power_mult": 1.6},
		{"name": "뇌신의 분노", "count": 4, "cd_mult": 0.7, "power_mult": 1.7},
	],
	"freeze": [
		{"name": "눈보라", "cd_mult": 0.8, "power_mult": 1.4},
		{"name": "영겁의 겨울", "cd_mult": 0.65, "power_mult": 1.85},
		{"name": "절대 영도", "cd_mult": 0.6, "power_mult": 2.0},
	],
	"barrage": [
		{"name": "집중포화", "count": 1, "radius_mult": 1.2, "power_mult": 1.3},
		{"name": "궤도 포격", "count": 2, "radius_mult": 1.4, "power_mult": 1.7},
		{"name": "행성 붕괴", "count": 3, "radius_mult": 1.4, "power_mult": 1.9},
	],
}

## 진화 분기 — 같은 스킬을 EVOLVE_COST(3)장 모으면 이 3개 분기 중 하나를 골라 진화한다.
## kind: power(강화) / element(속성결합 — 화상·둔화 부여, 다른 카드 효과와 조합) / behavior(행동결합 — 관통·장판·표적·폭발).
## 같은 분기를 여러 번 골라도 됨(누적). EVOLVE 배열 크기(=3)가 최대 진화 횟수 상한을 정한다.
const EVOLVE_BRANCHES := {
	"bolts": [
		{"kind": "power",    "name": "연발 마력탄", "desc": "발사 수 +1 · 위력 +30%", "count_add": 1, "power_mult": 1.3},
		{"kind": "element",  "name": "화염 마력탄", "desc": "명중 시 화상 부여(증발·기폭 연계) · 위력 +10%", "grant": "burn", "power_mult": 1.1},
		{"kind": "behavior", "name": "관통 마력탄", "desc": "적을 1회 더 관통 · 위력 +10%", "behavior": "pierce", "amount": 1, "power_mult": 1.1},
	],
	"meteor": [
		{"kind": "power",    "name": "쌍둥이 메테오", "desc": "위력 +40% · 반경 +20%", "power_mult": 1.4, "radius_mult": 1.2},
		{"kind": "element",  "name": "용암 메테오",   "desc": "명중 시 화상 부여 · 위력 +15%", "grant": "burn", "power_mult": 1.15},
		{"kind": "behavior", "name": "분화구 메테오", "desc": "명중 지점에 잔류 장판 · 위력 +15%", "behavior": "ground_field", "power_mult": 1.15},
	],
	"barrage": [
		{"kind": "power",    "name": "집중포화",   "desc": "폭격 수 +1 · 위력 +30%", "count_add": 1, "power_mult": 1.3},
		{"kind": "behavior", "name": "초토화 포격", "desc": "명중 지점에 잔류 장판 · 위력 +15%", "behavior": "ground_field", "power_mult": 1.15},
		{"kind": "behavior", "name": "확산 포격",   "desc": "표적 수 +1(다발 강화) · 위력 +15%", "behavior": "extra_targets", "amount": 1, "power_mult": 1.15},
	],
	"chain": [
		{"kind": "power",    "name": "폭풍 번개", "desc": "연쇄 수 +1 · 위력 +30%", "count_add": 1, "power_mult": 1.3},
		{"kind": "element",  "name": "한파 번개", "desc": "명중 시 둔화 부여(빙결파쇄 연계) · 위력 +10%", "grant": "slow", "power_mult": 1.1},
		{"kind": "behavior", "name": "확산 번개", "desc": "표적 수 +1 · 위력 +15%", "behavior": "extra_targets", "amount": 1, "power_mult": 1.15},
	],
	"freeze": [
		{"kind": "power",    "name": "눈보라",    "desc": "위력 +40%", "power_mult": 1.4},
		{"kind": "element",  "name": "동상 서리",  "desc": "둔화 부여 + 위력 +15%", "grant": "slow", "power_mult": 1.15},
		{"kind": "behavior", "name": "빙폭 서리",  "desc": "처치 시 폭발(처치 폭발 부여) · 위력 +15%", "behavior": "explode", "amount": 0.3, "power_mult": 1.15},
	],
	"thorns": [
		{"kind": "power",    "name": "가시 숲",      "desc": "범위 +25% · 위력 +35%", "radius_mult": 1.25, "power_mult": 1.35},
		{"kind": "element",  "name": "옭아매는 덩굴", "desc": "명중 시 둔화 부여 · 위력 +10%", "grant": "slow", "power_mult": 1.1},
		{"kind": "behavior", "name": "독가시",        "desc": "처치 시 폭발(처치 폭발 부여) · 위력 +15%", "behavior": "explode", "amount": 0.3, "power_mult": 1.15},
	],
}
