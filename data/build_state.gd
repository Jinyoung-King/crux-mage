class_name BuildState
extends Resource
## 플레이어 빌드 상태.
## 반드시 런타임에 BuildState.new()로 생성할 것.
## (.tres를 @export로 물리면 플레이 중 바뀐 값이 에디터 리소스에 남아 디스크가 오염됨)

@export var damage: float = 10.0
@export var fire_rate: float = 2.0  ## 평타는 캐릭터 기본연사로 고정 — 이 값(연사)은 스킬 쿨타임 감소에 쓰임
@export var projectile_count: int = 1  ## 한 번에 노리는 적 수 (가까운 순)
@export var damage_per_target: float = 0.0  ## 동시 표적 1마다 추가 데미지 (시너지)
@export var defense: float = 0.0  ## 받는 피해 감소(flat, 최소 1은 들어옴)
@export var skill_power_mult: float = 1.0   ## 스킬 위력 배율 (스킬 강화 카드로 증가)
@export var skill_radius_mult: float = 1.0  ## 스킬 범위 배율 (meteor/barrage)
# 행동(behavior) — 카드로 켜는 플레이 변경 효과
@export var explode_power: float = 0.0  ## >0이면 스킬로 적 처치 시 주변 폭발(명중 피해 × 이 값)
@export var extra_targets: int = 0      ## 표적형 스킬(마력탄·융단·체인)이 추가로 노리는 적 수
# 원소 반응 — 상태 부여 / 격발
@export var apply_burn: bool = false    ## 부여: 스킬 명중 시 화상
@export var apply_slow: bool = false    ## 부여: 스킬 명중 시 둔화
@export var detonate_burn: float = 0.0  ## 격발: 화상 중인 적 명중 시 화상을 터뜨려 광역(명중 피해 × 이 값)
@export var frostbite: float = 0.0      ## 격발: 둔화/빙결 적 명중 시 추가 피해(명중 피해 × 이 값)
@export var echo: bool = false          ## 전설: 모든 스킬이 잠시 뒤 60% 위력으로 한 번 더(메아리)
@export var knockback: float = 0.0      ## 행동: 스킬 명중 시 적을 위로 밀어냄(px) — 기지에서 멀어짐
@export var ground_field: bool = false  ## 행동: 광역 스킬(메테오·융단)이 명중 지점에 지속 피해 장판
@export var execute_threshold: float = 0.0  ## 전설(수확자): 체력 이 비율 이하 적 즉사(유물 수확과 별개, 큰 값 적용)
