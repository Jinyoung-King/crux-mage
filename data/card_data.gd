class_name CardData
extends Resource
## 카드 정의. 웨이브 사이 보상 선택에 쓸 예정 (이번 단계에선 정의와 샘플 .tres만).

@export var card_name: String = ""
@export var description: String = ""
@export var rarity: String = "common"  ## "common" | "rare" (등장 가중치 3:1)
@export var heal: float = 0.0  ## 선택 즉시 회복량
## 선택 시 BuildState에 더해질 증가량
@export var damage_bonus: float = 0.0
@export var fire_rate_bonus: float = 0.0
@export var projectile_count_bonus: int = 0
# 시너지/체력 계열
@export var damage_per_target_bonus: float = 0.0  ## 동시 표적 1마다 데미지
@export var max_hp_bonus: float = 0.0  ## 최대 체력 증감 (음수 가능 — 트레이드오프 카드)
@export var defense_bonus: float = 0.0  ## 방어력(받는 피해 감소) 증가
# 스킬 강화 (배율에 가산: 0.35 = +35%)
@export var skill_power_bonus: float = 0.0   ## 스킬 위력 +%
@export var skill_radius_bonus: float = 0.0  ## 스킬 범위 +% (meteor/barrage만 유효)
# 스킬 획득 (SkillLib.DEFS의 id) — 보조 스킬을 독립 쿨타임으로 추가
@export var grant_skill_id: String = ""
# 행동(behavior) 부여 — 숫자보다 플레이 변경
@export var explode_power_bonus: float = 0.0  ## 처치 폭발 위력(명중 피해 대비 비율) 가산
@export var extra_targets_bonus: int = 0      ## 표적형 스킬 추가 표적 수
# 원소 반응
@export var grant_burn: bool = false      ## 부여: 화상
@export var grant_slow: bool = false      ## 부여: 둔화
@export var detonate_burn_bonus: float = 0.0  ## 격발: 화상 터뜨리기 위력
@export var frostbite_bonus: float = 0.0      ## 격발: 둔화/빙결 적 추가 피해
@export var grant_echo: bool = false          ## 전설: 메아리(스킬 재발동)
