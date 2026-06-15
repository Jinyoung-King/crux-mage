# 상승 계층(Ascension) 설계 — 엔드게임 2축

작성 2026-06-16, v2.1~. 목표: "엔드게임/반복성"의 장기 동기 축. 무한=기록 경쟁, **스테이지=상승 사다리**로 역할 분리.

## 결정(브레인스토밍)
- **스테이지 모드 중심**(유한·클리어 가능). 무한 모드는 현행 유지.
- **전역 하나의 사다리**(속성별 X). 아무 속성 스테이지나 현재 계층에서 클리어 → 다음 계층 해금.
- 계층은 **누적** 변형 규칙(N = 규칙 1..N 모두).

## 상태·해금
- `GameState.ascension`(해금된 최고 계층, 영속, 0~MAX) + `run_ascension`(런별 선택, 인메모리).
- `_stage_cleared()`에서 `GameState.try_unlock_ascension(run_ascension)`: 클리어 계층 == 현재 최고면 +1(상한 MAX). 영속 저장.

## 변형 규칙 사다리 (`GameState.ASCENSIONS`, 누적)
데이터 배열. 각 항목 {desc, hp?, dmg?, start_hp?, choices?, elite?}. 헬퍼가 `run_ascension`까지 합산.
- **v2.1(6단계, 쉬운 훅)**: 1 적HP+20% / 2 적피해+20% / 3 카드선택지−1 / 4 시작체력−15% / 5 엘리트↑ / 6 적HP·피해+25%.
- 헬퍼: `asc_hp_mult/asc_dmg_mult/asc_start_hp_mult`(1+합), `asc_choices_delta`(합), `asc_elite_bonus`(합), `asc_coin_mult`(1+0.15×lvl), `ascension_rules(lvl)`(desc 목록), `max_ascension`.
- v2.2: 적 이동속도(+enemy.setup 속도 훅), 보스 광폭 가속 등 추가 단계.

## 훅(기존 스케일러 재활용)
- 적 HP/피해: 스테이지 모드에서 `_start_wave`의 `endless_hp_scale/dmg_scale ×= asc_*_mult`(스테이지는 base 1.0).
- 시작 체력: `player.apply_character` 후 또는 main 셋업에서 `max_hp ×= asc_start_hp_mult`.
- 카드 선택지: `CHOICES_PER_CLEAR + asc_choices_delta`(하한 2).
- 엘리트: `_roll_elite` 확률 + `asc_elite_bonus`.
- 코인: 클리어/처치 보상에 `asc_coin_mult`.

## 선택 UI(시작 화면)
속성 스테이지 줄 위에 `◀ 상승 N ▶`(0~해금치) + 그 계층 규칙 요약 라벨. 속성 버튼 탭 시 `run_ascension`으로 시작. 해금 0이면 선택기 숨김(첫 클리어 전).

## 보상·표시
- 코인 +15%/계층. 인게임 상단 "상승 N"(>0일 때). 클리어 요약 "상승 N 클리어 — 다음 계층 해금!".

## 분할·검증
- **v2.1**: 상태·해금·6규칙·선택기·코인보상·표시.
- **v2.2**: 속도 등 추가 규칙·연출.
- 헤드리스: 계층별 mult 합산, 클리어 시 해금(+1, 최고일 때만), 선택기 범위(0~해금), 모디파이어 적용(hp/dmg/시작체력/선택지/엘리트), 코인 배율.
