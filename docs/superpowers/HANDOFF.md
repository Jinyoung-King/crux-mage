# 작업 핸드오프 (다음 세션용)

> 새 기기/세션에서 이어갈 때 이 문서부터 읽으세요. (이전 기기의 Claude 메모리는 전송 안 됨 — 맥락은 여기 + `CLAUDE.md` + `docs/superpowers/`에)

**마지막 작업일:** 2026-06-23 · **현재 버전:** v3.43 (라이브: https://jinyoung-king.github.io/crux-mage/)

---

## 🎯 지금 당장 할 것 — 어피니티 슬라이스 플레이테스트
v3.43에 **원소 어피니티 검증 슬라이스**를 배포함(빌드 아키타입 = 전문화 vs 콤보로 분기). 이건 *검증용*이라, 확장 전에 **사용자가 폰/브라우저에서 직접 플레이**해 다음을 판정해야 함:
1. "내 빌드" 화면의 어피니티 막대·아키타입("화 전문화"/"화+수 콤보")이 보이고 읽히나?
2. 드래프트가 "전문화(앵커 깊게) vs 콤보(다른 속성)"로 **실제 고민되나** — 아니면 한쪽이 뻔한 정답?
3. 불 투자 시 폭발 FX가 커지는 게 보이고 만족스럽나?
4. 매 판 다르게 느껴지나?

**판정에 따라 다음이 갈림(아래 로드맵).** 검증 전 확장 금지(검증 안 된 토대에 쌓기 = 트레드밀 함정).

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
