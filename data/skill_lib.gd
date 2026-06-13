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
