class_name EnemyData
extends Resource
## 적 종류 정의 (스탯 + 표시).

@export var display_name: String = ""
@export var hp: float = 30.0
@export var speed: float = 60.0  ## 이동 속도(px/s)
@export var contact_damage: float = 10.0  ## 플레이어 도달 시 피해
@export var size: float = 36.0  ## 정사각 한 변(px) — 충돌 크기. 스프라이트는 size/3 그리드로 제작
@export var sprite: Texture2D
@export var effect_color: Color = Color(0.85, 0.25, 0.25)  ## 사망 파편 등 이펙트 대표색
# 소환 패턴 (보스용): summon_interval > 0이면 주기적으로 summon_enemy를 소환
@export var summon_interval: float = 0.0
@export var summon_count: int = 2
@export var summon_enemy: EnemyData
