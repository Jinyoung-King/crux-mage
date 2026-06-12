class_name BuildState
extends Resource
## 플레이어 빌드 상태.
## 반드시 런타임에 BuildState.new()로 생성할 것.
## (.tres를 @export로 물리면 플레이 중 바뀐 값이 에디터 리소스에 남아 디스크가 오염됨)

@export var damage: float = 10.0
@export var fire_rate: float = 2.0  ## 초당 발사 횟수
@export var projectile_count: int = 1  ## 한 번에 노리는 적 수 (가까운 순)
@export var pierce: int = 0  ## 추가 관통 수. 0이면 첫 적에서 소멸
# 시너지 스탯 (다른 스탯과 곱해져 효과 발생 — 실효값 계산은 player의 effective_*)
@export var damage_per_target: float = 0.0  ## 동시 표적 1마다 추가 데미지
@export var fire_rate_per_pierce: float = 0.0  ## 관통 1마다 추가 연사
