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
# 지그재그 패턴: amplitude > 0이면 좌우로 흔들리며 하강
@export var zigzag_amplitude: float = 0.0  ## 좌우 진폭(px)
@export var zigzag_period: float = 2.0  ## 왕복 주기(초)
# 분열 패턴: 처치 시(도달 제외) split_enemy를 split_count마리 생성
@export var split_count: int = 0
@export var split_enemy: EnemyData
# 원거리 공격 패턴: attack_interval > 0이면 주기적으로 플레이어에게 마탄 발사
@export var attack_interval: float = 0.0
@export var attack_damage: float = 7.0
