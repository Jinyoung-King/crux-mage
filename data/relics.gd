class_name RelicLib
extends RefCounted
## 유물 정의(규칙 변경 패시브). 코인으로 영구 해금 후 런마다 장착(GameState).
## 효과는 id로 코드 훅(player/projectile/main)에서 분기.

const EXECUTE_THRESHOLD := 0.12  ## 수확: 이 비율 이하 적 즉사
const REGEN_PER_SEC := 3.0       ## 재생: 초당 회복
const GREED_MULT := 2            ## 황금: 코인 배수
const BERSERK_MULT := 1.5        ## 격노: 저체력 데미지 배수
const BERSERK_HP_RATIO := 0.5    ## 격노 발동 체력 비율
const RELIC_BURN_DPS := 5.0      ## 점화: 화상 dps
const RELIC_BURN_DUR := 2.5
const RELIC_CHAIN_FACTOR := 0.5  ## 연쇄: 연쇄 데미지 비율

const RELICS := [
	{"id": "execute", "name": "수확의 룬", "desc": "체력 12% 이하 적 즉사", "cost": 160},
	{"id": "chain", "name": "연쇄의 룬", "desc": "발사체가 1회 연쇄", "cost": 120},
	{"id": "ignite", "name": "점화의 룬", "desc": "발사체가 화상 부여", "cost": 110},
	{"id": "regen", "name": "재생의 룬", "desc": "초당 체력 +3", "cost": 90},
	{"id": "greed", "name": "황금의 룬", "desc": "코인 획득 2배", "cost": 100},
	{"id": "berserk", "name": "격노의 룬", "desc": "체력 50% 이하 시 데미지 +50%", "cost": 150},
]

## id로 유물 정의 조회 (없으면 빈 Dictionary)
static func relic_def(id: String) -> Dictionary:
	for r in RELICS:
		if r.id == id:
			return r
	return {}
