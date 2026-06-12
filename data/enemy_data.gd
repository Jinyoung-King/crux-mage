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
@export var show_hp_bar: bool = false  ## 중간보스·보스만 머리 위 HP바 표시
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
@export var attack_count: int = 1  ## >1이면 플레이어 방향 부채꼴 탄막(중간보스·보스)
@export var attack_spread_deg: float = 0.0  ## 부채 전체 각도(도) — attack_count>1일 때만 의미
@export var attack_bolt_scale: float = 1.0  ## 마탄 시각 배율(보스 탄막은 더 굵게)
# 특수공격 예고: > 0이면 탄막/돌진 직전 telegraph_time초 동안 번쩍·움찔로 "온다" 신호
@export var telegraph_time: float = 0.0
# 돌진 패턴(보스): charge_interval > 0이면 주기적으로 예고 후 아래로 돌진했다 복귀
@export var charge_interval: float = 0.0
@export var charge_speed: float = 600.0  ## 돌진/복귀 속도(px/s)
@export var charge_damage: float = 0.0  ## 돌진이 플레이어에 닿을 때 피해(접촉피해와 별개)
