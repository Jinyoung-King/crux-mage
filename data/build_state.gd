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
# [키스톤] 빌드 정체성 플래그(런마다 BuildState.new()로 false 초기화)
@export var keystone_pierce_chain: bool = false  ## 평타가 관통+연쇄 (레인 꿰뚫기 빌드)
@export var keystone_persist_field: bool = false ## 장판 지속·확대 + 적 사망 시 장판 (바닥 점령 빌드)
@export var keystone_execute_chain: bool = false ## 처형 + 처치 폭발 (도미노 빌드) — 중복 픽 제외용
@export var keystone_overload: bool = false      ## 평타·마력탄이 화상+둔화 동시 부여 → 상시 과부하 (원소 반응 빌드)
@export var keystone_echo: bool = false          ## 모든 스킬이 강하게 메아리 (두 번 시전 빌드)
# 부여형 누적 레벨 — 같은 부여 카드를 또 먹으면 +1씩 쌓여 효과가 강해진다(중복 보상). bool 플래그는 '활성' 게이트로 유지.
@export var burn_level: int = 0   ## 화염 각인 누적 → 화상 dps·지속 ↑
@export var slow_level: int = 0   ## 서리 각인 누적 → 둔화 강도·지속 ↑
@export var echo_level: int = 0   ## 메아리 누적 → 재시전 위력 ↑
@export var field_level: int = 0  ## 잔류 장판 누적 → 장판 피해 ↑
# 원소 균열(이벤트) — 이번 런 한정 속성별 스킬 위력 보너스 {원소: 보너스합}. BuildState.new()마다 새 dict(런 시작 시 초기화).
var element_empower: Dictionary = {}  ## eff_power에서 스킬 속성 일치 시 ×(1+보너스). 균열 중복 시 누적
var affinity: Dictionary = {}  ## [어피니티] {속성:값} — 장착 스킬+앵커로 계산. eff_power·반응 강도·FX 티어에 반영

## 부여형 누적 스케일 — 레벨 1=기본, 이후 레벨당 증가(과누적 방지로 상한). 소비 지점에서 곱/가산해 사용.
# 임의 레벨의 효과값(_at) + 현재 레벨 래퍼(전투용). 카드 미리보기가 현재/다음 레벨 효과를 같은 식으로 표시.
func burn_mult_at(lvl: int) -> float: return 1.0 + 0.6 * float(mini(maxi(lvl - 1, 0), 8))      ## 화상 dps 배율
func burn_mult() -> float: return burn_mult_at(burn_level)
func burn_dur_add_at(lvl: int) -> float: return 0.6 * float(mini(maxi(lvl - 1, 0), 8))          ## 화상 지속 가산(초)
func burn_dur_add() -> float: return burn_dur_add_at(burn_level)
func slow_factor_at(lvl: int) -> float: return maxf(0.6 - 0.07 * float(lvl - 1), 0.3) if lvl > 0 else 1.0  ## 둔화 배수(낮을수록 강함)
func slow_factor_card() -> float: return slow_factor_at(slow_level)
func slow_dur_at(lvl: int) -> float: return 2.0 + 0.5 * float(mini(maxi(lvl - 1, 0), 8)) if lvl > 0 else 0.0  ## 둔화 지속(초)
func slow_dur_card() -> float: return slow_dur_at(slow_level)
func echo_power_at(lvl: int) -> float: return minf(0.6 + 0.2 * float(lvl - 1), 1.2) if lvl > 0 else 0.0  ## 메아리 재시전 위력 비율
func echo_power() -> float: return echo_power_at(echo_level)
func field_mult_at(lvl: int) -> float: return 1.0 + 0.5 * float(mini(maxi(lvl - 1, 0), 8))      ## 장판 피해 배율
func field_mult() -> float: return field_mult_at(field_level)
