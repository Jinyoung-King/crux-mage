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
