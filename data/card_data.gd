class_name CardData
extends Resource
## 카드 정의. 웨이브 사이 보상 선택에 쓸 예정 (이번 단계에선 정의와 샘플 .tres만).

@export var card_name: String = ""
@export var description: String = ""
## 선택 시 BuildState에 더해질 증가량
@export var damage_bonus: float = 0.0
@export var fire_rate_bonus: float = 0.0
@export var projectile_count_bonus: int = 0
@export var pierce_bonus: int = 0
