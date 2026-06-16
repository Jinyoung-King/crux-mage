class_name SkillLib
extends RefCounted
## 카드로 획득하는 보조 스킬 정의. id는 main._on_skill_cast의 분기와 동일(기존 5종 재사용).
## 밸런스: 캐릭터 고유 스킬보다 위력 낮고 쿨타임 김 — '빈 시간 채우기 + 빌드 다양성'용.

## element = 카드에 표시할 대표 오행 속성(불/물/나무/쇠/흙). 실제 시전 상성은 시전 캐릭터 속성을 따름.
const DEFS := {
	"bolts":   {"name": "가시 화살", "cooldown": 5.5, "power": 10.0, "radius": 0.0, "count": 3, "element": "wood"},
	"meteor":  {"name": "유성", "cooldown": 10.5, "power": 18.0, "radius": 72.0, "count": 0, "element": "fire"},
	"barrage": {"name": "융단폭격", "cooldown": 9.5, "power": 13.0, "radius": 52.0, "count": 3, "element": "earth"},
	"chain":   {"name": "비도", "cooldown": 8.0, "power": 13.0, "radius": 0.0, "count": 4, "element": "metal"},
	"freeze":  {"name": "서리바람", "cooldown": 12.0, "power": 9.0, "radius": 0.0, "count": 0, "element": "water"},
	"thorns":  {"name": "가시밭", "cooldown": 9.0, "power": 9.0, "radius": 88.0, "count": 0, "element": "wood"},
	"inferno": {"name": "불바다", "cooldown": 8.0, "power": 9.0, "radius": 64.0, "count": 0, "element": "fire"},   # 화염 작렬+화상+잔류 장판(DoT)
	"rockfall": {"name": "낙석", "cooldown": 8.5, "power": 8.0, "radius": 50.0, "count": 3, "element": "earth"},   # 여러 바위 분산 낙하(count=바위 수)
	"glacier": {"name": "빙하", "cooldown": 7.0, "power": 13.0, "radius": 70.0, "count": 0, "element": "water"},   # 국지 고피해+강한 둔화
	# 방어형 비행체 — 지속형 동반자(쿨캐스트 아님). cooldown은 쓰이지 않음(player가 캐스트 루프에서 제외).
	# power=tick 피해 기준(build.damage 비례), radius=공전 반경, count=비행체 수.
	"barrier_droid": {"name": "수호 비행체", "cooldown": 99.0, "power": 10.0, "radius": 95.0, "count": 3, "element": "metal"},
}

## 스킬 시전 사거리(마법사로부터). 이 거리 안의 적만 타겟 — 스킬별 차등(기지 y≈1150 기준).
## 가시 화살·메테오·융단은 멀리, 비도(연쇄)는 가까이, 서리는 중거리.
const SKILL_RANGE := {
	"bolts": 1000.0,
	"chain": 850.0,
	"meteor": 1100.0,
	"barrage": 1100.0,
	"freeze": 850.0,
	"thorns": 900.0,
	"inferno": 1000.0,
	"rockfall": 1100.0,
	"glacier": 900.0,
	"barrier_droid": 99999.0,  # 쿨캐스트 아님(사거리 무의미) — 안전값
}

## 진화 트리 — 같은 스킬을 다시 획득하면 상위 티어로(현재 스탯에 배율/가산 적용 → 고유·획득 모두 진화).
## 각 항목 = tier N→N+1 효과. 정의 없는 스킬은 진화 대신 새 인스턴스로 누적(다중 스킬).
const EVOLVE := {
	"bolts": [
		{"name": "연발 가시 화살", "count": 2, "cd_mult": 0.82, "power_mult": 1.25},
		{"name": "가시 폭풍", "count": 3, "cd_mult": 0.70, "power_mult": 1.55},
		{"name": "가시 만개", "count": 4, "cd_mult": 0.7, "power_mult": 1.6},
	],
	"meteor": [
		{"name": "쌍둥이 메테오", "radius_mult": 1.25, "power_mult": 1.4},
		{"name": "운석 강우", "radius_mult": 1.6, "power_mult": 1.95},
		{"name": "종말의 운석", "radius_mult": 1.4, "power_mult": 2.0},
	],
	"chain": [
		{"name": "강철 비도", "count": 2, "cd_mult": 0.85, "power_mult": 1.3},
		{"name": "비도 난무", "count": 3, "cd_mult": 0.7, "power_mult": 1.6},
		{"name": "참격 폭풍", "count": 4, "cd_mult": 0.7, "power_mult": 1.7},
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
	"inferno": [
		{"name": "겁화", "radius_mult": 1.2, "power_mult": 1.35},
		{"name": "업화", "radius_mult": 1.4, "power_mult": 1.7},
		{"name": "지옥불", "radius_mult": 1.4, "power_mult": 1.9},
	],
	"rockfall": [
		{"name": "암석 강우", "count": 1, "power_mult": 1.25},
		{"name": "유성 낙석", "count": 1, "power_mult": 1.5},
		{"name": "대붕괴", "count": 1, "power_mult": 1.7},
	],
	"glacier": [
		{"name": "빙벽", "radius_mult": 1.2, "power_mult": 1.4},
		{"name": "빙하기", "radius_mult": 1.4, "power_mult": 1.85},
		{"name": "절대 빙하", "radius_mult": 1.4, "power_mult": 2.0},
	],
	"barrier_droid": [  # 비행체 수·위력 증가(진화 횟수 상한=3). 실제 분기 효과는 EVOLVE_BRANCHES 참조.
		{"name": "수호 비행체 II", "count": 1, "power_mult": 1.25},
		{"name": "수호 비행체 III", "count": 1, "power_mult": 1.3},
		{"name": "수호 비행체 IV", "count": 1, "power_mult": 1.3},
	],
}

## 진화 분기 — 같은 스킬을 EVOLVE_COST(3)장 모으면 이 3개 분기 중 하나를 골라 진화한다.
## kind: power(강화) / element(속성결합 — 화상·둔화 부여, 다른 카드 효과와 조합) / behavior(행동결합 — 관통·장판·표적·폭발).
## 같은 분기를 여러 번 골라도 됨(누적). EVOLVE 배열 크기(=3)가 최대 진화 횟수 상한을 정한다.
const EVOLVE_BRANCHES := {
	"bolts": [
		{"kind": "power",    "name": "연발 가시 화살", "desc": "발사 수 +1 · 위력 +30%", "count_add": 1, "power_mult": 1.3},
		{"kind": "element",  "name": "화염 가시 화살", "desc": "명중 시 화상 부여(증발·기폭 연계) · 위력 +10%", "grant": "burn", "power_mult": 1.1},
		{"kind": "behavior", "name": "관통 가시 화살", "desc": "적을 1회 더 관통 · 위력 +10%", "behavior": "pierce", "amount": 1, "power_mult": 1.1},
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
		{"kind": "power",    "name": "강철 비도", "desc": "연쇄 수 +1 · 위력 +30%", "count_add": 1, "power_mult": 1.3},
		{"kind": "element",  "name": "서리 비도", "desc": "명중 시 둔화 부여(빙결파쇄 연계) · 위력 +10%", "grant": "slow", "power_mult": 1.1},
		{"kind": "behavior", "name": "산탄 비도", "desc": "표적 수 +1 · 위력 +15%", "behavior": "extra_targets", "amount": 1, "power_mult": 1.15},
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
	"inferno": [
		{"kind": "power",    "name": "겁화",      "desc": "위력 +35% · 반경 +25%", "power_mult": 1.35, "radius_mult": 1.25},
		{"kind": "element",  "name": "맹독 화염",  "desc": "화상 강화(중첩) · 위력 +15%", "grant": "burn", "power_mult": 1.15},
		{"kind": "behavior", "name": "연쇄 폭발",  "desc": "처치 시 폭발(처치 폭발 부여) · 위력 +15%", "behavior": "explode", "amount": 0.3, "power_mult": 1.15},
	],
	"rockfall": [
		{"kind": "power",    "name": "암석 강우", "desc": "바위 +1 · 위력 +30%", "count_add": 1, "power_mult": 1.3},
		{"kind": "behavior", "name": "여진",      "desc": "명중 지점에 잔류 장판 · 위력 +15%", "behavior": "ground_field", "power_mult": 1.15},
		{"kind": "behavior", "name": "산사태",    "desc": "표적 수 +1(다발 강화) · 위력 +15%", "behavior": "extra_targets", "amount": 1, "power_mult": 1.15},
	],
	"glacier": [
		{"kind": "power",    "name": "빙벽",      "desc": "위력 +40% · 반경 +20%", "power_mult": 1.4, "radius_mult": 1.2},
		{"kind": "element",  "name": "혹한 빙하",  "desc": "둔화 강화(중첩) · 위력 +15%", "grant": "slow", "power_mult": 1.15},
		{"kind": "behavior", "name": "빙결 파편",  "desc": "처치 시 폭발(처치 폭발 부여) · 위력 +15%", "behavior": "explode", "amount": 0.3, "power_mult": 1.15},
	],
	"barrier_droid": [  # 전부 power 계열(부여/행동 플래그 없음) — count/radius/power만 강화
		{"kind": "power", "name": "수호 군단",   "desc": "비행체 +1 · 위력 +25%", "count_add": 1, "power_mult": 1.25},
		{"kind": "power", "name": "확장 궤도",   "desc": "공전 반경 +35% · 위력 +15%", "radius_mult": 1.35, "power_mult": 1.15},
		{"kind": "power", "name": "파괴 비행체", "desc": "비행체 위력 +60%", "power_mult": 1.6},
	],
}
