# 전투·상태이상 리팩토링 설계 (Combat / Status Refactor)

확정 방향: **2단계 분리(Phased)** · **실용적 절충(Pragmatic hybrid)** · **기본 반응안 채택**.
GDScript에는 인터페이스/추상클래스가 없으므로 패턴은 관용구(RefCounted 가상 메서드·Callable·signal·duck typing)로 에뮬레이트(emulate)한다.

## 목표
- main.gd / player.gd / enemy.gd의 강결합(Tight Coupling) 전투·상태 로직 분리(SRP).
- 적중 효과를 조합 가능한 전략(Strategy)으로 — 신규 행동(유도·분열 등) 추가가 1개 객체로 끝나게.
- 상태이상을 컴포넌트로 분리하고 옵저버(signal) 훅 마련 → Phase 2 명명 반응 토대.
- Phase 2: 명명 반응(증발·빙결파쇄·과부하) + 히트스톱(Hit Stop) 게임필.

## Phase 1 — 구조 분리 (동작 100% 보존, 검증 가능)

### A. StatusEffects (상태이상 컴포넌트)
- `class_name StatusEffects extends RefCounted` — 적이 소유(노드 아님 → 적 多수 시 트리/노드 탐색 비용 0, GC 부담 최소).
- 필드: `burn_dps, burn_time_left, slow_factor, slow_time_left`.
- API: `tick_burn(delta)->float`(이번 프레임 화상 피해 반환), `apply_move(delta, base_speed)->float`(둔화 반영 속도), `apply_burn/apply_slow`, `is_burning()/is_slowed()`, `consume_burn()`.
- `signal reaction(name, source_element)` — Phase 1에선 선언만(미방출), Phase 2에서 중첩 시 방출.
- enemy.gd: 4개 상태 필드를 `status`로 대체. **`apply_burn/apply_slow`는 위임 래퍼로 유지** → 외부 호출부(main·relic·freeze) 무변경. 화상 틱은 매 프레임(돌진 포함), 둔화 타이머는 일반 이동 블록에서만 감소 — **기존 순서 그대로**.

### B. HitModifier (적중 전략) + HitContext
- `class_name HitModifier extends RefCounted`, 가상 훅: `on_pre_damage(ctx)`(배율), `on_hit(ctx)`(생존 시 상태·격발), `on_kill(ctx)`(처치 시 폭발).
- 보편 피해식(격노·치명·상성·±5% 분산·흡혈)은 SkillExecutor의 코어 계산에 유지(전략 아님). **동적 행동·반응만 모디파이어로** 분리: 점화/화상부여·둔화부여·파쇄(frostbite)·기폭(detonate)·즉사(execute)·넉백(knockback)·처치폭발(explode).
- `HitContext`: 실행기당 **단일 인스턴스 재사용**(reset로 초기화) → 적중 핫패스(hot path)에서 객체 할당/GC 0. 필드: enemy, element, base_damage, damage, is_crit, was_burning, was_slowed, executor.
- player.gd: `hit_modifiers: Array[HitModifier]`를 **apply_card/grant_relic 시 1회 재구성**(매 적중이 아님). 빌드 플래그 → 모디파이어 매핑.

### C. SkillExecutor (전투 연산 분리, SRP)
- `class_name SkillExecutor extends Node`, main의 자식. **의존성 주입(DI)**: `setup(player, fx_root, enemies_provider)`.
- main의 `_on_skill_cast / _skill_hit / _explode / _drop_aoe / _skill_chain / _skill_aoe` + 관련 FX 스폰을 이전.
- main은 `player.skill_cast → executor.execute(s)`만 연결하고 웨이브·스폰·UI에 집중.
- FX/데미지숫자/셰이크는 콜백 또는 fx_root 주입으로 호출(역의존 제거).

### Phase 1 검증 (Golden Behavior)
헤드리스 임시 오토로드로 전투 시나리오 단위 단언(assert):
- 화상 dps·지속, 둔화 속도배수·지속, 화상 틱 사망.
- 상성 배율(강/약/중립), ±5% 분산 범위, 흡혈 회복량.
- 격발: 화상 소모+폭발, 둔화 적 파쇄 추가타.
- 즉사 임계, 넉백(거대 면역), 처치폭발 1회(재귀 없음).
리팩토링 전후 동일 결과 → 회귀 0 확인. 저장 오염 방지(메모리 상태만).

## Phase 2 — 명명 반응 + 게임필 (신규 동작)
### 기본 반응안
| 반응 | 트리거 | 효과 |
|---|---|---|
| 증발 (Vaporize) | 화상 적 + 물 속성 타격 | 화상 소모 + 광역 폭발 |
| 빙결파쇄 (Shatter) | 둔화 적 + 금/토 타격 | 추가 일격 |
| 과부하 (Overload) | 화상 + 둔화 동시 | 광역 폭발 + 넉백 |
- StatusEffects.reaction(signal) → SkillExecutor가 구독(Observer) → 반응 처리 + FX/팝업.

### GameFeelManager (히트스톱)
- `class_name GameFeelManager extends Node`(오토로드 또는 main 자식).
- `hit_stop(duration, strength)` — **배속 설정과 합성**: 기존 `Engine.time_scale`(1/2/3x)을 곱셈 기준으로 잠깐 낮췄다 복원. 큰 타격(보스·치명·처치)에 강도 차등.
- 엣지: 중첩 호출 시 최댓값 유지·타이머 누적 방지, 일시정지/게임오버 중 비활성, 복원 보장(연출 도중 씬 전환 시 time_scale 누수 방지).

## 성능 고려 (Performance Notes)
- `get_tree().get_nodes_in_group("enemies")`는 폭발·광역마다 O(N) 노드 탐색 → 실행기에서 프레임 단위 캐싱 검토.
- 모디파이어/컨텍스트는 인스턴스 재사용으로 핫패스 할당 제거.
- signal 방출은 적 수×상태변화에 비례 → Phase 2 반응은 "중첩 발생 순간"에만 방출(매 틱 아님).
