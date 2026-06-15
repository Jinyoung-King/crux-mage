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
@export var pierce: int = 0  ## 행동: 마력탄이 적을 꿰뚫고 지나가는 추가 횟수 (bolts 발사체에만 적용)
# 부여형 누적 레벨 — 같은 부여 카드를 또 먹으면 +1씩 쌓여 효과가 강해진다(중복 보상). bool 플래그는 '활성' 게이트로 유지.
@export var burn_level: int = 0   ## 화염 각인 누적 → 화상 dps·지속 ↑
@export var slow_level: int = 0   ## 서리 각인 누적 → 둔화 강도·지속 ↑
@export var echo_level: int = 0   ## 메아리 누적 → 재시전 위력 ↑
@export var field_level: int = 0  ## 잔류 장판 누적 → 장판 피해 ↑

## 부여형 누적 스케일 — 레벨 1=기본, 이후 레벨당 증가(과누적 방지로 상한). 소비 지점에서 곱/가산해 사용.
func burn_mult() -> float: return 1.0 + 0.6 * float(mini(maxi(burn_level - 1, 0), 8))      ## 화상 dps 배율
func burn_dur_add() -> float: return 0.6 * float(mini(maxi(burn_level - 1, 0), 8))           ## 화상 지속 가산(초)
func slow_factor_card() -> float: return maxf(0.6 - 0.07 * float(slow_level - 1), 0.3) if slow_level > 0 else 1.0  ## 둔화 배수(낮을수록 강함)
func slow_dur_card() -> float: return 2.0 + 0.5 * float(mini(maxi(slow_level - 1, 0), 8)) if slow_level > 0 else 0.0  ## 둔화 지속(초)
func echo_power() -> float: return minf(0.6 + 0.2 * float(echo_level - 1), 1.2) if echo_level > 0 else 0.0  ## 메아리 재시전 위력 비율
func field_mult() -> float: return 1.0 + 0.5 * float(mini(maxi(field_level - 1, 0), 8))      ## 장판 피해 배율
