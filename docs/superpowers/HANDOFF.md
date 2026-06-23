# 작업 핸드오프 (다음 세션용)

> 새 기기/세션에서 이어갈 때 이 문서부터 읽으세요. (이전 기기의 Claude 메모리는 전송 안 됨 — 맥락은 여기 + `CLAUDE.md` + `docs/superpowers/`에)

**마지막 작업일:** 2026-06-24 · **현재 버전:** v3.44 (라이브: https://jinyoung-king.github.io/crux-mage/)

---

## 🎯 지금 당장 할 것 — v3.44 가독성 수정 재검증
v3.43 플레이테스트 판정 = **"가독성이 문제"**(결정 구조는 있는데 고를 때 안 읽힘) → 로드맵 △ 경로로 **확장 말고 가독성부터 수정**함.
**v3.44 변경:** 어피니티 정보를 *결정하는 순간*(카드 선택창)에 노출.
- 드래프트 제목 아래에 현재 아키타입 항상 표시: "현재  화 전문화 · 화 70%"(앵커 색).
- 속성 스킬 카드마다 방향 태그 한 줄: "▮ 화 전문화 심화" / "▮ 화+수 콤보" / "▮ 수 분기"(카드 속성색).
- 분류 로직은 드래프트 가중(`_card_synergy`)과 동일 출처(`ElementLib.REACTION_PARTNER`/`build_direction`)로 일원화.

**재검증 질문:** 이제 카드 고를 때 전문화 vs 콤보 갈림길이 *바로 읽히나?* 그래도 밋밋하면 → 가독성이 아니라 **결정 자체(밸런스: 한쪽이 뻔한 정답)** 문제 → 다음은 전문화/콤보 보상 밸런싱.
**검증 전 확장 금지(트레드밀 함정).** 가독성이 해결돼 "고민된다"가 되면 → 아래 ✅ 로드맵.

> ⚠️ 빌드 미검증: 작업 환경(WSL2)에 godot 부재 → 헤드리스 검증 못 함. 코드 리뷰만 통과. 라이브 반영은 push→GitHub Actions 빌드(파스 에러는 거기서 걸림). 로컬 검증하려면 godot 4.6.3 + Web export 템플릿 설치 후 `godot --headless --fixed-fps 60 --quit-after N --path .`

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
