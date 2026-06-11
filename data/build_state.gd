class_name BuildState
extends Resource
## 플레이어 빌드 상태.
## 반드시 런타임에 BuildState.new()로 생성할 것.
## (.tres를 @export로 물리면 플레이 중 바뀐 값이 에디터 리소스에 남아 디스크가 오염됨)

@export var damage: float = 10.0
@export var fire_rate: float = 2.0  ## 초당 발사 횟수
@export var projectile_count: int = 1  ## 한 번에 노리는 적 수 (가까운 순)
@export var pierce: int = 0  ## 추가 관통 수. 0이면 첫 적에서 소멸
