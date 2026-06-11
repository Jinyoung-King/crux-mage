# 프로젝트: crux-mage (Godot 4 게임)

## 게임 개요
세로(포트레이트) 모바일 구도의 레인 디펜스 + 로그라이트 카드 빌더 2D 게임.
하단 중앙에 고정된 마법사가 화면 위에서 아래로 직선 진격해오는 적을
자동 예측 조준 발사체로 막는다. 웨이브 클리어 사이에 카드 3장 중 1장을 골라
빌드를 강화하고, 정의된 웨이브를 다 깨면 무한 모드로 강도가 계속 오른다.
플레이어 입력은 카드 선택과 재시작뿐.

## 환경
- Godot 4.6.3, GDScript (C# 아님) — 바이너리: `/opt/homebrew/bin/godot`
- macOS 개발, 1차 배포 타깃은 웹(HTML5, 모바일 브라우저 포함)
- 응답과 코드 주석은 한국어로

## 구조
- scenes/ — main / player / enemy / projectile / ui (.tscn과 짝 .gd 함께)
- data/ — Resource 정의: build_state, card_data, enemy_data, wave_data, wave_entry
- resources/ — cards/ waves/ enemies/ (.tres 인스턴스)
- assets/ — fonts/(NotoSansKR 번들, OFL) audio/(생성 SFX) sprites/(아직 비움)
- build/web — 웹 빌드 산출물 (git 제외)
- serve_web.py — 캐시 금지(no-store) 로컬 서버 / gen_sfx.py — 효과음 재생성

## 데이터 설계
- BuildState: 반드시 런타임에 `BuildState.new()`로 생성.
  (.tres를 @export로 물리면 플레이 중 변경값이 디스크에 남아 오염됨)
- CardData: 보너스 4종 + rarity("common"/"rare", 등장 가중치 3:1) + heal(즉시 회복)
- EnemyData: 적 종류(체력/속도/접촉피해/크기/색) — 적 추가는 .tres 하나로
- WaveData + WaveEntry: 웨이브 구성을 (적 종류 × 마리 수) 목록으로 선언
- 노드 간 연결은 시그널 우선: died / reached_player / fired / hp_changed / card_chosen

## 작업 규칙
- 요청 범위만 구현, 단일 사용 코드에 추상화 레이어 금지
- 변경 후 헤드리스 검증 필수: `godot --headless --fixed-fps 60 --quit-after N --path .`
  (--fixed-fps 없으면 게임 시간이 흐르지 않음. 클릭 UI는 임시 오토로드로 시그널 발화 후 제거)
- 각 작업 후 무엇을 어떻게 실행 확인하면 되는지 한 줄로 알려줄 것
- 웹 빌드: `godot --headless --export-release "Web" build/web/index.html --path .`
  배포 확인용 버전 표기(main.tscn의 VersionLabel)를 빌드마다 올릴 것
- 아트는 단색 도형 placeholder 유지 (스프라이트/연출은 추후 단계)
