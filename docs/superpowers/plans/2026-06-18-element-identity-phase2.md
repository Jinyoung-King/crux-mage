# 원소 정체성 2단계 — 상태/반응 카드 제거(상태는 스킬이 담당)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** 상태이상·반응을 카드에서 떼어내고, 속성 스킬 정체성으로만 발동하게 한다. 상태 부여 카드 2장 + 반응 증폭 카드 2장 + 묶음 전설 1장(총 5장) 제거 + 정리 + 반응 베이스라인 보강.

**Architecture:** 핵심 사실 — **불·수 스킬은 이미 자기 상태를 직접 부여한다**(유성·불바다=화상, 빙결·빙하=둔화). 따라서 카드를 제거해도 반응(증발·과부하·감전·파쇄) 연료는 스킬에서 계속 나온다. per-skill 상태 부여 *조회 구조*(용암·동상 확장)는 새 상태(속박)를 들이는 3단계에서 짓는다 — 이번엔 불필요. 이번 작업은 카드 제거 + 풀/필터/모디파이어 정리 + 제거된 증폭(기폭·파쇄)을 보전하기 위한 베이스라인 반응 수치 상향.

**Tech Stack:** Godot 4.6.3, GDScript. 테스트 프레임워크 없음 → 헤드리스 검증(CLAUDE.md).

## Global Constraints

- 응답·코드 주석 한국어.
- 변경 후 헤드리스 검증: `/opt/homebrew/bin/godot --headless --fixed-fps 60 --quit-after N --path .`
- **게임플레이 의도 변경**(밸런스): 카드 제거 = 드래프트 풀 축소, 반응을 스킬 조합으로만. 순수 비주얼 아님.
- 제거된 카드 참조(풀 preload·필터)가 0이어야 — 누락 시 로드 에러.
- 카드 제거 = 드래프트로 안 나올 뿐, `CardData`/`BuildState` 필드(grant_burn 등)는 다른 경로(진화 분기·패시브)가 쓰므로 **스크립트 필드는 남긴다**.

---

## 현재 상태 흐름 지도 (구현자 필독)

상태이상이 적에 적용되는 경로(현재):
1. **카드 → 전역 빌드 플래그**(이번에 제거): `card_brand_fire`→`build.apply_burn`, `card_brand_frost`→`build.apply_slow`, `card_detonate`→`build.detonate_burn`, `card_shatter`→`build.frostbite`, `card_resonance`→넷 다.
2. **빌드 플래그 → hit_modifiers**(`HitModifierLib.build_for`): ApplyBurn/ApplySlow(부여), Detonate/Frostbite(반응).
3. **스킬이 직접 부여**(`skill_executor`, 유지): inferno·meteor=`_skill_aoe(...burn=true)`/`_drop_aoe(...true)`, freeze·glacier=`e.apply_slow(...)`. **→ 불·수 스킬은 카드 없이도 상태를 깐다.**
4. **진화 분기**(element kind, 유지): `player.evolve_branch`가 grant burn/slow → `build.apply_burn/slow` 설정(스킬 진화로 상태 획득 = 철학과 일치).
5. **캐릭터 패시브**(유지): 서리 마도사 `passive_slow`(평타 둔화). 화염술사 화상은 v3.27에 제거됨.
6. **유물 Ignite**(유지): 화상.
7. **베이스라인 원소 반응**(`skill_executor._apply_element_reactions`, 유지·보강): 증발(물+화상)·감전(금+둔화)·빙결파쇄(흙+둔화).

**제거 후**: 상태는 스킬(3)·진화(4)·패시브(5)·유물(6)에서만 나옴. 카드(1)는 사라짐. ApplyBurn/ApplySlow는 (4)(5)가 계속 set하므로 **살아있음**. Detonate/Frostbite는 카드만 set했으므로 **죽음** → 정리.

---

## File Structure

- **Delete**: `resources/cards/card_brand_fire.tres`, `card_brand_frost.tres`, `card_detonate.tres`, `card_shatter.tres`, `card_resonance.tres` (+ `.import` 없음 — .tres는 import 불필요).
- **Modify**: `scenes/main/main.gd` — card_pool preload 5줄 제거, `_is_card_useful`의 기폭/파쇄 가드 2줄 + `_has_burn_source`/`_has_slow_source` 함수 제거.
- **Modify**: `scenes/combat/hit_modifiers.gd` — `build_for`에서 Detonate/Frostbite 등록 제거(클래스는 휴면 보존 또는 삭제).
- **Modify**: `scenes/combat/skill_executor.gd` — `_apply_element_reactions` 증발·빙결파쇄·감전 수치 상향(증폭 카드 보전).

---

## 사전 확인 (시작 전 1회)

- [ ] **제거 대상 카드의 다른 참조 확인**

Run: `grep -rn "card_brand_fire\|card_brand_frost\|card_detonate\|card_shatter\|card_resonance" scenes/ data/ resources/ --include="*.gd" --include="*.tres"`
Expected: `main.gd` card_pool(5줄)만 나와야 함. 다른 곳(이벤트 드래프트 등)에서 직접 preload하면 그것도 목록에 추가.

---

### Task 1: 상태/반응 카드 5장 제거 + 풀 정리

**Files:**
- Delete: `resources/cards/card_brand_fire.tres`, `card_brand_frost.tres`, `card_detonate.tres`, `card_shatter.tres`, `card_resonance.tres`
- Modify: `scenes/main/main.gd` (card_pool, ~111-119)

- [ ] **Step 1: 카드 .tres 5개 삭제**

```bash
git rm resources/cards/card_brand_fire.tres resources/cards/card_brand_frost.tres resources/cards/card_detonate.tres resources/cards/card_shatter.tres resources/cards/card_resonance.tres
```

- [ ] **Step 2: card_pool에서 preload 5줄 제거**

`scenes/main/main.gd`의 `card_pool` 배열에서 아래 5줄을 삭제:

```gdscript
	preload("res://resources/cards/card_brand_fire.tres"),
	preload("res://resources/cards/card_brand_frost.tres"),
	preload("res://resources/cards/card_detonate.tres"),
	preload("res://resources/cards/card_shatter.tres"),
```
및 (배열 뒤쪽)
```gdscript
	preload("res://resources/cards/card_resonance.tres"),
```

- [ ] **Step 3: 로드/파싱 검증 (깨진 preload 0)**

Run: `/opt/homebrew/bin/godot --headless --fixed-fps 60 --quit-after 120 res://scenes/ui/start_screen.tscn --path . 2>&1 | grep -iE "error|parse|SCRIPT|Failed load|Cannot load" | grep -v "resources still in use"`
Expected: 출력 없음.

- [ ] **Step 4: 커밋**

```bash
git add -A resources/cards/ scenes/main/main.gd
git commit -m "원소 정체성 2단계(1/4): 상태/반응 카드 5장 제거 — 화염각인·서리각인·기폭·파쇄·공명

상태이상·반응을 카드에서 떼어냄. 불·수 스킬이 이미 상태를 직접 부여하므로
반응 연료는 스킬에서 계속 나옴(증발·과부하·감전·파쇄).

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01LLGW4otvFtWFeiGMmUiXQX"
```

---

### Task 2: 죽은 드래프트 필터 제거

**Files:**
- Modify: `scenes/main/main.gd` (`_is_card_useful` ~1101-1104, `_has_burn_source`/`_has_slow_source` ~1062-1077)

**Interfaces:**
- Consumes: 없음(제거만).
- Produces: 없음.

- [ ] **Step 1: `_is_card_useful`에서 기폭/파쇄 가드 2줄 제거**

아래 4줄(2개 if 블록)을 삭제:

```gdscript
	if card.detonate_burn_bonus > 0.0 and not _has_burn_source():
		return false  # 화상 부여원 없으면 기폭 무의미
	if card.frostbite_bonus > 0.0 and not _has_slow_source():
		return false  # 둔화 부여원 없으면 파쇄 무의미
```

(이 필드를 쓰는 카드가 사라졌으므로 가드 자체가 무의미.)

- [ ] **Step 2: 미사용된 `_has_burn_source`/`_has_slow_source` 함수 제거**

`func _has_burn_source() -> bool:` 와 `func _has_slow_source() -> bool:` 두 함수 정의 전체를 삭제(Step 1 제거 후 호출처 0).

- [ ] **Step 3: 호출 0 확인 + 파싱**

Run: `grep -n "_has_burn_source\|_has_slow_source" scenes/main/main.gd`
Expected: 출력 없음.
Run: `/opt/homebrew/bin/godot --headless --fixed-fps 60 --quit-after 90 res://scenes/ui/start_screen.tscn --path . 2>&1 | grep -iE "error|parse|SCRIPT" | grep -v "resources still in use"`
Expected: 출력 없음.

- [ ] **Step 4: 커밋**

```bash
git add scenes/main/main.gd
git commit -m "원소 정체성 2단계(2/4): 죽은 드래프트 필터 제거(기폭/파쇄 소스 체크)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01LLGW4otvFtWFeiGMmUiXQX"
```

---

### Task 3: 죽은 모디파이어(Detonate/Frostbite) 정리

**Files:**
- Modify: `scenes/combat/hit_modifiers.gd` (`build_for` ~89-90)

**Interfaces:**
- Consumes: `p.build.detonate_burn`, `p.build.frostbite`(이제 항상 0 — 카드 제거됨).
- Produces: build_for가 Detonate/Frostbite를 더는 추가하지 않음.

**근거:** Detonate/Frostbite는 `build.detonate_burn`/`build.frostbite`가 0보다 클 때만 build_for에 추가됐는데, 그 값은 제거된 카드만 set했다. 이제 항상 0 → 절대 활성화 안 됨(죽은 코드). 반응(증발·빙결파쇄 베이스라인)이 그 역할을 대체.

- [ ] **Step 1: build_for에서 Detonate/Frostbite 등록 줄 제거**

아래 2줄을 삭제:

```gdscript
	if p.build.frostbite > 0.0: mods.append(Frostbite.new(p))
	if p.build.detonate_burn > 0.0: mods.append(Detonate.new(p))
```

- [ ] **Step 2: Detonate/Frostbite 클래스는 휴면 표기(삭제 대신 보존)**

`class Frostbite extends Base:`와 `class Detonate extends Base:` 정의 위 주석에 휴면 표기 추가(향후 재도입 여지·보존 관행):

```gdscript
## (휴면 — v3.27 상태/반응 카드 제거로 build_for 미등록. 반응 베이스라인이 대체. 재도입 시 build_for에 다시 추가)
```

(클래스 본문은 그대로 둔다 — 참조 0이라 무해, 보존.)

- [ ] **Step 3: 파싱 검증**

Run: `/opt/homebrew/bin/godot --headless --fixed-fps 60 --quit-after 90 res://scenes/ui/start_screen.tscn --path . 2>&1 | grep -iE "error|parse|SCRIPT" | grep -v "resources still in use"`
Expected: 출력 없음.

- [ ] **Step 4: 커밋**

```bash
git add scenes/combat/hit_modifiers.gd
git commit -m "원소 정체성 2단계(3/4): Detonate/Frostbite 모디파이어 휴면화(카드 제거로 미사용)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01LLGW4otvFtWFeiGMmUiXQX"
```

---

### Task 4: 베이스라인 반응 보강(증폭 카드 보전) + 검증

**Files:**
- Modify: `scenes/combat/skill_executor.gd` (`_apply_element_reactions`·`_electrocute`·`REACTION_HP_PCT`)

**Interfaces:**
- Consumes: `_hit_ctx.dealt`, `REACTION_HP_PCT`, `ELECTRO_DMG_RATIO`.
- Produces: 강화된 증발·빙결파쇄·감전(제거된 기폭·파쇄 epic 카드의 증폭분 보전).

**근거:** 기폭(detonate_burn_bonus 0.6)·파쇄(frostbite 0.5) epic 카드가 주던 추가 폭발·추가타가 사라졌다. 베이스라인 반응을 올려 "스킬 조합 = 강력한 반응"이 카드 없이도 성립하게 한다. **수치는 초안 — 플레이테스트로 튜닝**.

- [ ] **Step 1: 증발 위력 상향 (물+화상)**

`_apply_element_reactions`의 증발 분기에서 `_explode(pos, _hit_ctx.dealt, element)`의 피해 배수를 키운다(예 ×1.5):

```gdscript
	if element == "water" and e.is_burning():  # 증발: 물로 화상 적 → 화상 소모 + 강한 광역
		var pos: Vector2 = e.global_position
		e.consume_burn()
		e.take_percent_damage(REACTION_HP_PCT)
		_explode(pos, _hit_ctx.dealt * 1.5, element)  # 기폭 카드 보전(베이스라인 강화)
```

- [ ] **Step 2: 빙결파쇄 추가타 상향 (흙+둔화)**

흙 분기의 추가타 배수 `0.6`을 올린다(예 1.0):

```gdscript
	elif element == "earth" and e.is_slowed():  # 빙결파쇄: 흙으로 둔화 적 → 강한 추가타 + 복리관통
		e.take_damage(_hit_ctx.dealt * 1.0)  # 파쇄 카드 보전(0.6→1.0)
		if is_instance_valid(e):
			e.take_percent_damage(REACTION_HP_PCT)
```

- [ ] **Step 3: 감전 연쇄 위력 소폭 상향 (선택)**

`ELECTRO_DMG_RATIO`를 0.5→0.6으로(군중 반응 보상 강화). 상수 한 줄 수정:

```gdscript
const ELECTRO_DMG_RATIO := 0.6                  ## 감전 연쇄 1타 = 원 명중 피해의 비율
```

- [ ] **Step 4: 통합 검증 (헤드리스, 임시 오토로드)**

`docs/superpowers/plans/2026-06-18-electrocute-reaction.md`의 검증 패턴 재사용 — 임시 오토로드로 main 로드 후 `m._start_wave(1)`로 스폰, 적 둔화/화상 부여 후 `_apply_element_reactions(e, "water"/"earth"/"metal")` 직접 호출해 증발·파쇄·감전이 **카드 없이** 강화된 수치로 발동하는지 확인. 임시 print는 검증 후 제거.

Expected: 증발=화상소모+광역(×1.5), 파쇄=추가타(×1.0)+복리, 감전=3연쇄(×0.6). `SCRIPT ERROR` 없음. 드래프트 풀에 제거된 5장 안 나옴.

- [ ] **Step 5: 드래프트 풀 회귀 확인**

Run: `grep -c "card_brand_fire\|card_brand_frost\|card_detonate\|card_shatter\|card_resonance" scenes/main/main.gd`
Expected: `0`.

- [ ] **Step 6: 커밋**

```bash
git add scenes/combat/skill_executor.gd
git commit -m "원소 정체성 2단계(4/4): 베이스라인 반응 보강 — 제거된 기폭·파쇄 증폭 보전

증발 ×1.5 · 빙결파쇄 추가타 0.6→1.0 · 감전 비율 0.5→0.6. 스킬 조합만으로
강력한 반응이 성립하게(카드 없이). 수치는 플레이테스트로 추가 튜닝.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01LLGW4otvFtWFeiGMmUiXQX"
```

---

## Self-Review (작성자 체크)

**스펙 커버리지 (2단계 범위):**
- 상태 부여 카드 제거(화염각인·서리각인) → Task 1 ✓
- 반응 증폭 카드 제거(기폭·파쇄) → Task 1 ✓
- 묶음 전설 제거(공명) → Task 1 ✓
- 풀/필터 정리 → Task 1·2 ✓
- 죽은 모디파이어 처리 → Task 3 ✓
- 반응 베이스라인 상향(증폭 보전) → Task 4 ✓
- (범위 외) per-skill 상태 *조회 구조* + 용암·동상 = 3단계(속박)에서 새 상태와 함께 — 의도적 분리 ✓

**플레이스홀더 스캔:** 수치는 초안값을 명시(×1.5/×1.0/0.6) — "적절히 조정" 같은 모호 표현 없음. 튜닝 여지는 명시적 표기. ✓

**타입 일관성:** `_apply_element_reactions`·`_electrocute`·`build.detonate_burn`·`build.frostbite`·`REACTION_HP_PCT`·`ELECTRO_DMG_RATIO`는 기존 코드 실존 심볼(이번 세션 1단계에서 추가/확인). ✓

**위험 메모(실행 시):**
- 카드 제거 = 드래프트 풀 5장 축소 → 다른 카드 등장 확률↑(의도). 전설 풀에서 공명 빠짐(메아리·만신전·수확자·광전사·arcane·storm 잔존).
- 진화 분기 grant burn/slow는 여전히 전역 플래그 set(per-skill 아님) — 이번 범위 밖, 3단계/추후. 동작은 보존.
- 밸런스는 헤드리스로 '발동/수치'만 검증 가능 — 체감 밸런스는 실플레이 튜닝.

---

## 다음 (3단계, 별도 계획)

목 = 속박(root) 신규 상태 + **이때 per-skill 상태 *조회 구조*(`SkillLib.applied_status`)를 도입**(목 스킬이 element 기본값 아닌 'root'를 선언해야 하므로) → 용암·동상 확장도 이 구조 위에. StatusEffects root 추가·적별 쿨다운·둔화와 격리.
설계 스펙: `docs/superpowers/specs/2026-06-18-element-identity-design.md`
