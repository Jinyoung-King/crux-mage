# 작업 핸드오프 (다음 세션용)

> 새 기기/세션에서 이어갈 때 이 문서부터 읽으세요. (이전 기기의 Claude 메모리는 전송 안 됨 — 맥락은 여기 + `CLAUDE.md` + `docs/superpowers/`에)

**마지막 작업일:** 2026-06-25 · **현재 버전:** v3.45 (라이브: https://jinyoung-king.github.io/crux-mage/)

---

## 🎯 지금 당장 할 것 — v3.45 능동 시그니처 플레이테스트
**큰 방향 전환.** v3.43~44 어피니티(스탯) 방식은 검증 실패 — 사용자 평: *"기존이랑 똑같은 플레이"*. 근본 원인 = **플레이어가 관전자**(입력=카드선택+재시작뿐, 전투는 자동 시전 관전). 숫자·FX·라벨을 키워도 *하는 행동*이 안 바뀜.
→ 사용자가 **능동 입력 추가**(잦은 능동 스킬) 방향 선택.

**⚠️ v3.24 교훈(반드시 기억):** 저편에서 탭 조준 스킬을 만들었다 되돌림 — *"수동 조준이 자동 대비 차이 없이 번거롭기만 함"*. 자동이 이미 밀집을 잘 노리니 같은 걸 손으로 조준 = 잡일. **그래서 v3.45 설계 원칙:** ① ADDITIVE(자동은 그대로, 시그니처를 *추가*) ② 자동이 못 하는 결정 = **방어 트리아지**(자동=최대처치/밀집, 사람=돌파위협 차단) ③ 빌드(주력속성)가 발동 스킬을 정함. (메모리: active-input-must-be-additive)

**v3.45 구현:** 시그니처 쿨 5초 충전(하단 게이지) → 전장 탭 시 그 지점에 시전. 속성별 효과(불=inferno/수=glacier/목=thorns/금=chain/토=barrage), 위력 ∝ 어피니티. `skill_executor.execute()`의 기존 `aim` 인프라 재사용.

**재검증 질문:** ① 탭해서 끊는 게 *재밌나/내가 한다는 느낌이 드나?* ② 빌드(속성)마다 시그니처가 다르게 느껴지나? ③ v3.24처럼 "자동이랑 차이 없는 잡일"로 다시 느껴지면 → 능동 자체가 답이 아니거나, 시그니처가 자동과 너무 겹침(역할 차별 강화 필요). **검증 전 확장 금지.**

## 🧱 v3.45 시스템 위치
- `scenes/player/player.gd` — `SIGNATURE_*` 상수, `signature_element()`/`signature_ready()`/`cast_signature(aim)`, `_process`에서 `signature_cd_left` 충전.
- `scenes/main/main.gd` — `_unhandled_input`(전장 탭→시전), `_build_sig_gauge`/`_update_sig_gauge`(하단 충전 게이지), `_flash_sig_reticle`(발동 지점 레티클).
- `scenes/combat/skill_executor.gd` — `_skill_chain`에 `focus` 인자(금속 시그니처 조준).

> ⚠️ 빌드 미검증: 작업 환경(WSL2)에 godot 부재 → 헤드리스 검증 못 함. 정적 점검(괄호·들여쓰기)·코드 리뷰만 통과. 라이브 반영은 push→GitHub Actions 빌드(파스 에러는 거기서 걸림). 로컬 검증하려면 godot 4.6.3 + Web export 템플릿 설치 후 `godot --headless --fixed-fps 60 --quit-after N --path .`

## 🗺 조건부 다음 로드맵
**✅ 재밌으면 → 어피니티 비전 완성(순서):**
1. 궁극기 변신(전문화/콤보 정점 → 시그니처 스킬 변신, 뱀서식 클라이맥스)
2. 5속성 FX 진화(현재 불만 → 전 속성)
3. 상생 콤보(증폭, 목생화 등) + 금극목(금속 반응 복원) — 현재 극-콤보만 작동
4. 진화 시스템(EVOLVE_BRANCHES) 어피니티 구동 재편 — 제일 위험, 마지막
**△ 밋밋하면 → 확장 말고 결정 구조(전문화/콤보 밸런스·가독성)부터 수정.**

설계·계획 상세:
- 스펙: `docs/superpowers/specs/2026-06-22-element-affinity-design.md`
- 계획: `docs/superpowers/plans/2026-06-23-element-affinity-slice.md`

## 🧱 핵심 시스템 위치 (이번 작업)
- `data/build_state.gd` — `affinity: Dictionary{속성:값}`
- `scenes/player/player.gd` — `recompute_affinity()`(rebuild_hit_modifiers에서 호출), `archetype_label()`, `eff_power`가 element_empower+affinity 합산, 상수 `ANCHOR_AFFINITY`/`PER_SKILL_AFFINITY`
- `scenes/combat/skill_executor.gd` — 증발·빙결파쇄 강도 ∝ affinity, `_fire_fx_scale()`(불 FX 티어)
- `scenes/main/main.gd` — 빌드 패널 어피니티 막대(`_open_cards`), `_card_synergy`(어피니티·`REACTION_PARTNER` 가중)

## 📜 최근 흐름 (맥락)
번아웃 → UI 리팩토링 → **원소 정체성 3부작**(감전→상태이상 스킬화→목 속박) → 투사체 칼/화살 → **자동 배포 파이프라인 구축** → **리버스 모드 프로토타입**(검증 후 *구조적 어색*으로 홈 버튼 숨김, 코드 보존 — 재진입 시 호드 로그라이트 재설계) → 감전 제거(오행 정렬) → **어피니티 검증 슬라이스(v3.43, 현재 지점)**.
- 게임 정체성: 세로(레인 디펜스+로그라이트 카드빌더, 자동 시전, 입력=카드선택·재시작). 핵심 과제="성장하나 플레이 안 바뀜" → 어피니티가 본격 답(검증 중).

## ⚙️ 환경 / 운영 (갤럭시북 = Windows 주의)
- Godot **4.6.3** 필요 + **Web export 템플릿** 설치(빌드용). 맥 경로는 `/opt/homebrew/bin/godot`였음 — **Windows는 godot 실행 경로 다름**(설치 경로로 교체).
- 헤드리스 검증: `godot --headless --fixed-fps 60 --quit-after N --path .` (`--fixed-fps` 필수 — 없으면 게임 시간 안 흐름).
- 웹 빌드: `godot --headless --export-release "Web" build/web/index.html --path .` / 로컬 확인: `python serve_web.py` (localhost:8765, no-store).
- **자동 배포:** `main`에 푸시하면 GitHub Actions(`.github/workflows/deploy.yml`)가 빌드→`gh-pages` 배포(legacy 브랜치 방식). 버전 올릴 때 `GameState.VERSION` 한 곳 + CHANGELOG 맨 앞 항목 추가.
- **폰트(NotoSansKR)에 특수기호(⚔·⟡·⚡·🔒 등) 없음 → 두부(□).** UI 텍스트에 쓰지 말 것(지원: ▶·★·●·▮).
- BuildState는 런타임 `BuildState.new()`로 생성(.tres @export 금지 — 오염).
