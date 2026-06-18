# 감전(感電) 반응 구현 계획 — 원소 정체성 1단계

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 금속(전도체) 스킬이 둔화(젖은) 적을 명중하면 가까운 적들로 연쇄 번개가 터지는 "감전" 원소 반응을 추가한다.

**Architecture:** 기존 명중 시점 반응 엔진(`skill_executor._apply_element_reactions`)에 감전 분기를 추가하고, 같은 슬롯을 쓰던 "빙결파쇄"를 흙(earth) 전속으로 분리한다. 연쇄 피해는 `_skill_hit`를 거치지 않고 직접 적용해 무한 감전을 막는다. 비주얼은 v3.10에서 "향후 감전 연출용"으로 보존해 둔 `_jagged`+`_lightning_line`을 푸른-흰 색으로 부활시킨다. 새 시스템·새 파일 없음 — 한 파일(`skill_executor.gd`) + TIPS 한 줄.

**Tech Stack:** Godot 4.6.3, GDScript. 바이너리 `/opt/homebrew/bin/godot`. 테스트 프레임워크 없음 → 헤드리스 실행으로 검증(CLAUDE.md 규칙).

## Global Constraints

- 응답·코드 주석은 한국어로.
- 변경 후 헤드리스 검증 필수: `/opt/homebrew/bin/godot --headless --fixed-fps 60 --quit-after N --path .` (`--fixed-fps` 없으면 게임 시간이 안 흐름).
- 아트는 단색 도형/기존 FX 재사용 — 새 에셋 금지(번개는 기존 `Line2D` 절차 연출).
- GPU 파티클·셰이더 금지(웹/모바일 GL 불안정). CPU·절차만.
- 멀티 인스턴스(연쇄 N개)는 반드시 개수 상한 — 융단폭격 렉 교훈.
- 화면 텍스트 FX 추가 금지(폰트 셰이핑 = 웹 FPS 최대 적, v2.7에서 반응명 팝업 제거됨). 피드백은 번개 비주얼로만.
- 이 계획은 현재 상태 시스템(화상·둔화)만 사용 — per-skill 상태 부여(2단계)·속박(3단계)은 별도 계획.

---

## 테스트 접근 (이 프로젝트 고유)

유닛 테스트 프레임워크가 없다. 검증은 **헤드리스 통합 실행 + 임시 계측 print**로 한다.
- 임시 `print()`를 넣어 발동·연쇄 수·재귀 여부를 관찰하고, 검증 후 **반드시 제거**한다.
- 게임 전체를 띄워 실제 전투 경로(`_skill_hit` → `_apply_element_reactions`)로 발동시킨다.
- 파싱/런타임 에러는 헤드리스 시작 로그에서 즉시 드러난다(과거 파싱 에러를 헤드리스가 잡은 전례 있음).

---

## File Structure

- **Modify**: `scenes/combat/skill_executor.gd` — 반응 분기(감전/파쇄 분리), `_electrocute`·`_nearest_unhit`·`_arc_lightning` 추가, 감전 상수.
- **Modify**: `scenes/ui/start_screen.gd` — `TIPS` 배열에 감전 안내 한 줄.

전투 로직은 전부 `skill_executor.gd` 한 파일에 모여 있어 감전도 그 안에서 끝난다(SRP 유지). 보존된 `_jagged`/`_lightning_line`/`_hit_ctx`/`EnemyCache`를 재사용한다.

---

## 사전 확인 (구현 시작 전 1회)

- [ ] **현재 반응 코드 위치 확인**

Run: `grep -n "_apply_element_reactions\|빙결파쇄\|_jagged\|_lightning_line\|REACTION_HP_PCT" scenes/combat/skill_executor.gd`
Expected: `_apply_element_reactions`(약 144행), 그 안 metal/earth 분기, `_jagged`(약 342행)·`_lightning_line`(약 353행) 정의, `REACTION_HP_PCT` 상수(약 22행)가 모두 존재.

---

### Task 1: 감전 반응 로직 + 빙결파쇄 흙 전속 분리

**Files:**
- Modify: `scenes/combat/skill_executor.gd` (상수 추가 ~22행 부근, `_apply_element_reactions` ~144행, 신규 함수 추가)

**Interfaces:**
- Consumes (기존, 변경 없음): `_hit_ctx.dealt: float`(직전 명중 실피해), `EnemyCache.all() -> Array`, `ElementLib.multiplier(atk, def) -> float`, `enemy.take_damage(d)`, `enemy.take_percent_damage(pct)`, `enemy.is_slowed() -> bool`, `enemy.hp`, `enemy.element`, `enemy.global_position`, `REACTION_HP_PCT`.
- Produces (이후 Task가 사용): `_electrocute(origin) -> void`(연쇄 번개 진입점, 내부에서 `_arc_lightning` 호출), `_nearest_unhit(from: Vector2, hit: Dictionary) -> Object|null`. 시각 함수 `_arc_lightning(from, to)`은 Task 2에서 정의 — Task 1에서는 임시로 빈 호출/주석 처리하지 않고 Task 2 완료까지 **호출 줄을 넣되 함수는 Task 2에서 추가**(Task 1 검증은 피해 로직만 print로 확인, 시각은 Task 2). 순서상 Task 1에서 `_arc_lightning` 정의를 같이 넣어도 무방하나, 리뷰 분리를 위해 Task 1은 로직, Task 2는 시각으로 가른다. **구현 편의를 위해 Task 1에서 `_arc_lightning`을 빈 스텁(`pass`)으로 먼저 정의하고 Task 2에서 본문을 채운다.**

- [ ] **Step 1: 감전 상수 추가**

`REACTION_HP_PCT` 상수 정의 바로 아래(약 22행)에 추가:

```gdscript
const ELECTRO_CHAIN := 3                        ## 감전 연쇄 최대 대상 수(멀티 인스턴스 상한 — 렉 방지)
const ELECTRO_DMG_RATIO := 0.5                  ## 감전 연쇄 1타 = 원 명중 피해의 비율
const ELECTRO_COLOR := Color(0.7, 0.85, 1.0)    ## 전기 푸른-흰(비도 강철빛 streak과 구분 → 눈으로 감전 식별)
```

- [ ] **Step 2: 반응 분기 교체 (감전 추가 + 파쇄 흙 전속)**

`_apply_element_reactions`의 기존 `elif (element == "metal" or element == "earth") and e.is_slowed():` 블록을 아래로 교체:

```gdscript
	elif element == "metal" and e.is_slowed():  # 감전: 금속으로 둔화(젖은) 적 → 연쇄 번개
		_electrocute(e)
	elif element == "earth" and e.is_slowed():  # 빙결파쇄: 흙으로 둔화 적 → 추가타 + 복리관통(흙 전속)
		e.take_damage(_hit_ctx.dealt * 0.6)
		if is_instance_valid(e):
			e.take_percent_damage(REACTION_HP_PCT)
```

(증발(water+화상) 분기는 그대로 둔다.)

- [ ] **Step 3: 감전 핵심 함수 + 헬퍼 + 시각 스텁 추가**

`_apply_element_reactions` 함수 정의 끝(다음 함수 `on_reaction` 위)에 추가:

```gdscript
## 감전(感電): 금속 스킬이 둔화(젖은) 적을 명중 → 가까운 미감전 적들로 연쇄 번개.
## _skill_hit를 거치지 않고 직접 피해(무한 감전 방지). 연쇄 수 상한 = ELECTRO_CHAIN.
func _electrocute(origin) -> void:
	var dmg: float = _hit_ctx.dealt * ELECTRO_DMG_RATIO
	var from: Vector2 = origin.global_position
	var hit := {origin: true}  # 이미 맞은 적(중복 연쇄 방지)
	for _i in ELECTRO_CHAIN:
		var nxt = _nearest_unhit(from, hit)
		if nxt == null:
			break
		var to: Vector2 = nxt.global_position
		_arc_lightning(from, to)  # 푸른 지그재그 번개(Task 2)
		nxt.take_damage(dmg * ElementLib.multiplier("metal", nxt.element) * randf_range(0.95, 1.05))
		if is_instance_valid(nxt):
			nxt.take_percent_damage(REACTION_HP_PCT)  # 복리 체력 관통(증발·파쇄와 동일 규칙)
		hit[nxt] = true
		from = to

## from에서 가장 가까운 '아직 안 맞은' 살아있는 적. 없으면 null.
func _nearest_unhit(from: Vector2, hit: Dictionary):
	var best = null
	var best_d := INF
	for e in EnemyCache.all():
		if not is_instance_valid(e) or e.hp <= 0.0 or hit.has(e):
			continue
		var d := from.distance_squared_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best

## 감전 연쇄 번개 시각 — Task 2에서 본문 구현(보존된 _jagged + _lightning_line 부활).
func _arc_lightning(from: Vector2, to: Vector2) -> void:
	pass
```

- [ ] **Step 4: 임시 계측 추가 (검증용, Task 1 끝에 제거)**

`_electrocute`의 `hit[nxt] = true` 줄 위에 임시 print를 넣는다:

```gdscript
		print("[ELECTRO] chain ", _i, " -> ", nxt.element, " dmg=", dmg)
```

- [ ] **Step 5: 파싱·런타임 검증 (헤드리스)**

Run: `/opt/homebrew/bin/godot --headless --fixed-fps 60 --quit-after 120 res://scenes/ui/start_screen.tscn --path . 2>&1 | grep -iE "error|parse|invalid|SCRIPT" | grep -v "resources still in use"`
Expected: 출력 없음(파싱·런타임 에러 0). 새 함수가 파스되는지부터 확인.

- [ ] **Step 6: 감전 발동 통합 검증 (헤드리스 + 임시 오토로드)**

`금속 스킬(비도/chain) + 물 스킬(빙하/glacier)` 로드아웃에서 둔화된 적을 금속이 때리면 `[ELECTRO]`가 찍혀야 한다. 임시 검증 스크립트를 만든다:

`test_electro.gd` (프로젝트 루트, 검증 후 삭제):

```gdscript
extends Node
## 임시 검증용 오토로드 — 무한모드 진입 후 플레이어 스킬을 비도+빙하로 강제하고,
## 자동 드래프트 픽으로 진행시켜 감전 발동([ELECTRO] print)을 관찰한다.
func _ready() -> void:
	await get_tree().process_frame
	GameState.game_mode = "endless"
	GameState.start_wave = 8  # 적이 충분히 몰리는 구간
	get_tree().change_scene_to_file("res://scenes/main/main.tscn")
	await get_tree().create_timer(0.5).timeout
	var m = get_tree().current_scene
	if m and m.has_node("Player"):
		var pl = m.get_node("Player")
		pl.skills = [
			pl._make_skill("chain", "비도", 8.0, 13.0, 0.0, 4),
			pl._make_skill("glacier", "빙하", 7.0, 13.0, 70.0, 0),
		]
		if "auto_pick" in m:
			m.auto_pick = true
```

Run: `/opt/homebrew/bin/godot --headless --fixed-fps 60 --quit-after 1800 --path . -- --autoload test_electro.gd 2>&1 | grep -E "ELECTRO|error|SCRIPT" | head -20`

(주: 오토로드 등록 방식이 환경마다 다르면, `project.godot`의 `run/main_scene`를 임시로 위 스크립트를 _ready로 가진 씬으로 바꾸거나, 기존 헤드리스 검증 관행대로 임시 오토로드를 `project.godot [autoload]`에 한 줄 추가 후 검증·복원한다.)

Expected: `[ELECTRO] chain 0 -> <속성> dmg=...`가 한 번 이상 출력. `SCRIPT ERROR`/무한 출력(재귀 폭주) 없음. `chain 0,1,2`까지만(3 상한) 나오고 그 이상 인덱스 없음.

- [ ] **Step 7: 빙결파쇄 흙 전속 회귀 확인**

위 Step 6 스크립트의 `pl.skills`를 `rockfall`(earth)+`glacier`(water)로 바꿔 재실행하고, `_apply_element_reactions`의 earth 분기에 임시 `print("[SHATTER]")`를 넣어 흙이 둔화 적에 여전히 파쇄를 일으키는지 확인. 확인 후 `[SHATTER]` print 제거.

Expected: `[SHATTER]` 출력됨(흙 파쇄 보존), 금속이 아니므로 `[ELECTRO]` 없음.

- [ ] **Step 8: 임시 계측·검증 스크립트 제거**

`_electrocute`의 `[ELECTRO]` print 줄과 earth 분기의 `[SHATTER]` print(있다면)를 제거한다. `test_electro.gd`를 삭제하고 `project.godot`를 원복(임시 오토로드/씬 변경 되돌림).

Run: `rm -f test_electro.gd && git status --short`
Expected: `skill_executor.gd`만 수정됨(M), `test_electro.gd` 없음, `project.godot` 변경 없음.

- [ ] **Step 9: 최종 파싱 검증 후 커밋**

Run: `/opt/homebrew/bin/godot --headless --fixed-fps 60 --quit-after 120 res://scenes/ui/start_screen.tscn --path . 2>&1 | grep -iE "error|parse|SCRIPT" | grep -v "resources still in use"`
Expected: 출력 없음.

```bash
git add scenes/combat/skill_executor.gd
git commit -m "감전 반응 1단계: 금속+둔화 → 연쇄 번개 피해, 빙결파쇄 흙 전속 분리

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01LLGW4otvFtWFeiGMmUiXQX"
```

---

### Task 2: 감전 번개 비주얼 (보존된 _jagged + _lightning_line 부활)

**Files:**
- Modify: `scenes/combat/skill_executor.gd` (`_arc_lightning` 스텁 본문 채우기)

**Interfaces:**
- Consumes: `_jagged(from: Vector2, to: Vector2, segs: int, amp: float) -> PackedVector2Array`(보존됨, ~342행), `_lightning_line(pts: PackedVector2Array, w: float, col: Color) -> void`(보존됨, ~353행 — Line2D 생성 후 0.4초 페이드 자멸), `host._hit_spark(pos, color, size)`, `ELECTRO_COLOR`(Task 1).
- Produces: 화면에 적→적 푸른 지그재그 번개 2겹(글로우+코어) + 명중 스파크.

- [ ] **Step 1: `_arc_lightning` 본문 구현**

Task 1에서 넣은 `_arc_lightning` 스텁(`pass`)을 아래로 교체:

```gdscript
## 감전 연쇄 번개 — 보존된 _jagged 지그재그 + _lightning_line 2겹(푸른-흰). 비도의 직선 강철 streak과 색·모양으로 구분.
func _arc_lightning(from: Vector2, to: Vector2) -> void:
	var pts := _jagged(from, to, 5, 14.0)
	_lightning_line(pts, 6.0, Color(ELECTRO_COLOR.r, ELECTRO_COLOR.g, ELECTRO_COLOR.b, 0.4))  # 글로우(굵고 옅게)
	_lightning_line(pts, 2.4, Color(0.9, 0.96, 1.0, 0.98))                                    # 코어(가늘고 밝게)
	host._hit_spark(to, ELECTRO_COLOR, 14.0)
```

- [ ] **Step 2: 비주얼 발동 검증 (헤드리스, 임시 계측)**

`_arc_lightning` 첫 줄에 임시 `print("[ARC] ", from, " -> ", to)`를 넣고, Task 1 Step 6의 `test_electro.gd`를 다시 만들어 동일 실행. (Line2D는 헤드리스에서 화면 없이도 노드로 생성됨 — 과거 _draw FX 검증과 동일 관행.)

Run: `/opt/homebrew/bin/godot --headless --fixed-fps 60 --quit-after 1800 --path . -- --autoload test_electro.gd 2>&1 | grep -E "ARC|error|SCRIPT" | head -10`
Expected: `[ARC] (x,y) -> (x,y)`가 감전 발동마다 출력. `SCRIPT ERROR` 없음(특히 `_jagged`/`_lightning_line` 인자 타입 — `_jagged`는 `PackedVector2Array` 반환, `_lightning_line` 인자와 일치).

- [ ] **Step 3: 임시 계측·검증 스크립트 제거**

`_arc_lightning`의 `[ARC]` print 제거, `test_electro.gd` 삭제, `project.godot` 원복.

Run: `rm -f test_electro.gd && grep -n "ARC\|ELECTRO\|SHATTER" scenes/combat/skill_executor.gd`
Expected: 출력 없음(임시 print 전부 제거됨).

- [ ] **Step 4: 최종 파싱 검증 후 커밋**

Run: `/opt/homebrew/bin/godot --headless --fixed-fps 60 --quit-after 120 res://scenes/ui/start_screen.tscn --path . 2>&1 | grep -iE "error|parse|SCRIPT" | grep -v "resources still in use"`
Expected: 출력 없음.

```bash
git add scenes/combat/skill_executor.gd
git commit -m "감전 번개 비주얼 — 보존된 _jagged 지그재그 부활(푸른-흰, 비도 강철빛과 구분)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01LLGW4otvFtWFeiGMmUiXQX"
```

---

### Task 3: 발견성 — 공략 팁에 감전 조합 안내

**Files:**
- Modify: `scenes/ui/start_screen.gd` (`TIPS` 배열, ~30행)

**Interfaces:**
- Consumes: `TIPS: Array`(문자열 배열, 홈 '공략 팁 ⓘ' 오버레이가 `_tip_row`로 표시).
- Produces: 없음(데이터 한 줄 추가).

- [ ] **Step 1: TIPS 배열에 감전 안내 추가**

`scenes/ui/start_screen.gd`의 `const TIPS := [` 배열 마지막 항목 뒤(닫는 `]` 직전)에 한 줄 추가:

```gdscript
	"금속 스킬(비도)로 둔화·젖은 적을 치면 감전 연쇄가 터집니다 — 물 스킬과 함께 끼우세요 (금+수 조합).",
```

- [ ] **Step 2: 홈 화면 로드 + 팁 표시 검증 (헤드리스)**

Run: `/opt/homebrew/bin/godot --headless --fixed-fps 60 --quit-after 120 res://scenes/ui/start_screen.tscn --path . 2>&1 | grep -iE "error|parse|SCRIPT" | grep -v "resources still in use"`
Expected: 출력 없음(배열 파싱 정상 — `_build_tips_help`가 TIPS를 순회해 `_tip_row` 생성).

- [ ] **Step 3: 커밋**

```bash
git add scenes/ui/start_screen.gd
git commit -m "감전 조합 발견성 — 공략 팁에 금+수 안내 한 줄

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01LLGW4otvFtWFeiGMmUiXQX"
```

---

## Self-Review (작성자 체크)

**1. 스펙 커버리지 (이 계획 = 1단계 범위만)**
- 감전 트리거(금속+둔화) → Task 1 Step 2 ✓
- 빙결파쇄 흙 전속 분리 → Task 1 Step 2 ✓
- 연쇄 K=3 상한 + 0.5배 + 복리관통 → Task 1 Step 1·3 ✓
- 재귀 차단(_skill_hit 안 거침) → Task 1 Step 3(`_electrocute`가 직접 `take_damage`) ✓
- 보존 코드(_jagged/_lightning_line) 부활, 푸른-흰, 텍스트 없음 → Task 2 ✓
- 발견성(TIPS) → Task 3 ✓
- (범위 외) per-skill 상태·카드 제거·속박 = 2·3단계 별도 계획 — 의도적 분리 ✓

**2. 플레이스홀더 스캔**
- "TBD/TODO/나중에 구현" 없음. `_arc_lightning` 스텁은 Task 1에서 명시적으로 `pass`로 두고 Task 2에서 본문을 보임(코드 제시됨) — 플레이스홀더 아님(의도된 2-스텝 분리).
- 모든 코드 단계에 실제 GDScript 제시 ✓

**3. 타입 일관성**
- `_electrocute(origin)`·`_nearest_unhit(from, hit)`·`_arc_lightning(from, to)` 시그니처가 Task 1 정의와 Task 2 사용에서 일치 ✓
- `_jagged` 반환(`PackedVector2Array`)이 `_lightning_line` 1번째 인자 타입과 일치 ✓
- `_hit_ctx.dealt`·`ElementLib.multiplier`·`take_percent_damage`·`is_slowed`는 기존 코드에서 확인된 실존 심볼 ✓

---

## 다음 단계 (이 계획 완료 후, 기운 날 각자 계획으로)

- **2단계**: per-skill 상태 부여(`SkillLib.applied_status(id)` — 속성 기본 + DEFS override) + 상태/반응 카드 5장 제거 + 풀/필터·죽은 모디파이어 정리 + 반응 베이스라인 상향. (전역 `build.apply_burn` 플래그 → per-skill 전환이 핵심 작업)
- **3단계**: 목 = 속박(root) 신규 상태(StatusEffects) + 목 스킬 적용 + 적별 쿨다운 + 둔화와 격리.

설계 스펙: `docs/superpowers/specs/2026-06-18-element-identity-design.md`
