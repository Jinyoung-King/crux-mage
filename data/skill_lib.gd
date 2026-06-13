class_name SkillLib
extends RefCounted
## 카드로 획득하는 보조 스킬 정의. id는 main._on_skill_cast의 분기와 동일(기존 5종 재사용).
## 밸런스: 캐릭터 고유 스킬보다 위력 낮고 쿨타임 김 — '빈 시간 채우기 + 빌드 다양성'용.

const DEFS := {
	"bolts":   {"name": "마력탄", "cooldown": 3.0, "power": 10.0, "radius": 0.0, "count": 3},
	"meteor":  {"name": "유성", "cooldown": 4.5, "power": 18.0, "radius": 90.0, "count": 0},
	"barrage": {"name": "융단폭격", "cooldown": 5.0, "power": 13.0, "radius": 65.0, "count": 3},
	"chain":   {"name": "전격", "cooldown": 4.0, "power": 13.0, "radius": 0.0, "count": 4},
	"freeze":  {"name": "서리바람", "cooldown": 5.5, "power": 9.0, "radius": 0.0, "count": 0},
}

## 진화 트리 — 같은 스킬을 다시 획득하면 상위 티어로(현재 스탯에 배율/가산 적용 → 고유·획득 모두 진화).
## 각 항목 = tier N→N+1 효과. 정의 없는 스킬은 진화 대신 새 인스턴스로 누적(다중 스킬).
const EVOLVE := {
	"bolts": [
		{"name": "연발 마력탄", "count": 2, "cd_mult": 0.82, "power_mult": 1.25},
		{"name": "마력 폭풍", "count": 3, "cd_mult": 0.70, "power_mult": 1.55},
	],
	"meteor": [
		{"name": "쌍둥이 메테오", "radius_mult": 1.25, "power_mult": 1.4},
		{"name": "운석 강우", "radius_mult": 1.6, "power_mult": 1.95},
	],
}
