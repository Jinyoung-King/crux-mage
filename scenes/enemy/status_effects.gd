class_name StatusEffects
extends RefCounted
## 적 1마리의 상태이상(화상·둔화) 컴포넌트.
## 적이 직접 소유(노드가 아님) → 적이 多수여도 씬 트리 노드/그룹 탐색 비용 0, GC 부담 최소.
##
## Phase 2: 다중 상태가 중첩되는 '순간'에만 reaction(signal)을 방출해 명명 반응(증발·과부하 등)을
## 구동한다(매 틱 방출 금지 — signal emit 비용을 적 수에 비례시키지 않기 위함). 현재는 선언만 한다.

signal reaction(name: String, source_element: String)  ## Phase 2 훅 (현재 미방출)

var burn_dps: float = 0.0
var burn_time_left: float = 0.0
var slow_factor: float = 1.0
var slow_time_left: float = 0.0

const OVERLOAD_CD_MS := 2000  ## 적별 과부하 재발화 쿨다운(ms) — 화상 만료↔재적용 반복 시 팝업·폭발 폭주(렉) 방지
var _overload_ms: int = -100000  ## 마지막 과부하 발화 시각(벽시계 ms)

## 이번 프레임의 화상 피해를 반환하고 화상 타이머를 감소시킨다. 화상이 없으면 0.0.
## (기존 enemy._physics_process 화상 블록과 동일 순서·동일 수치)
func tick_burn(delta: float) -> float:
	if burn_time_left <= 0.0:
		return 0.0
	burn_time_left -= delta
	return burn_dps * delta

## 둔화를 반영한 실효 이동 속도를 반환하고 둔화 타이머를 감소시킨다. 둔화가 없으면 base_speed 그대로.
func apply_move(delta: float, base_speed: float) -> float:
	if slow_time_left <= 0.0:
		return base_speed
	slow_time_left -= delta
	return base_speed * slow_factor

## 화상 부여: 더 센 화상으로 갱신하고 지속시간 리프레시. 이미 둔화 중이면 '과부하' 반응 방출(중첩 형성 순간 1회).
func apply_burn(dps: float, dur: float) -> void:
	var forms_combo := not is_burning() and is_slowed()  # 화상 신규 + 둔화 보유 → 중첩 형성
	burn_dps = maxf(burn_dps, dps)
	burn_time_left = maxf(burn_time_left, dur)
	if forms_combo:
		_try_overload("fire")

## 둔화 부여: 속도 배수 갱신, 지속시간 리프레시. 이미 화상 중이면 '과부하' 반응 방출(중첩 형성 순간 1회).
func apply_slow(factor: float, dur: float) -> void:
	var forms_combo := not is_slowed() and is_burning()  # 둔화 신규 + 화상 보유 → 중첩 형성
	slow_factor = factor
	slow_time_left = maxf(slow_time_left, dur)
	if forms_combo:
		_try_overload("water")

## 과부하 반응 방출 — 단, 적별 쿨다운 내면 무시(후반 화상 재적용 반복으로 인한 팝업·폭발 폭주=렉 방지)
func _try_overload(src: String) -> void:
	var now: int = Time.get_ticks_msec()
	if now - _overload_ms < OVERLOAD_CD_MS:
		return
	_overload_ms = now
	reaction.emit("overload", src)

func is_burning() -> bool:
	return burn_time_left > 0.0

func is_slowed() -> bool:
	return slow_time_left > 0.0

## 화상 소모(격발: 기폭) — 이후 is_burning()은 false
func consume_burn() -> void:
	burn_time_left = 0.0
	burn_dps = 0.0
