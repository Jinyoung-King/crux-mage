class_name HitContext
extends RefCounted
## 단일 명중(single hit)의 가변 상태. SkillExecutor가 인스턴스 1개를 reset()으로 재사용해
## 명중 핫패스(hot path)에서 객체 할당·GC를 0으로 만든다(적·타격이 많아도 메모리 안정).

var enemy                          ## 피격 적 노드
var element: String = ""           ## 타격 속성(오행)
var base_damage: float = 0.0       ## 입력 피해(보정 전)
var damage: float = 0.0            ## on_pre_damage 가감 대상(상성·분산 적용 전)
var dealt: float = 0.0             ## 상성·분산까지 반영해 실제로 입힌 피해(반응 비율 기준)
var is_crit: bool = false
var was_burning: bool = false      ## 이번 명중 '부여 전' 화상 여부(격발 판정용)
var was_slowed: bool = false       ## 이번 명중 '부여 전' 둔화 여부
var mult: float = 1.0              ## 오행 상성 배율(데미지 숫자 강조용)
var pos: Vector2 = Vector2.ZERO    ## 명중 좌표(take_damage로 적이 free돼도 폭발·숫자에 쓰려고 미리 캡처)
var executor                       ## 명중 파이프라인 소유자(_explode 등 호출)
var player

## 새 명중을 위해 컨텍스트를 초기화. was_*는 상태 부여 '전' 시점이라 여기서 캡처한다.
func reset(e, dmg: float, elem: String, exec, p) -> void:
	enemy = e
	element = elem
	base_damage = dmg
	damage = dmg
	dealt = 0.0
	is_crit = false
	mult = 1.0
	pos = Vector2.ZERO
	was_burning = e.is_burning()
	was_slowed = e.is_slowed()
	executor = exec
	player = p
