extends Node
## 게임필(Game Feel): 히트스톱(Hit Stop). 강타격 순간 Engine.time_scale을 잠깐 떨어뜨려 타격감을 강화.
## 오토로드 'GameFeel'로 어디서나 GameFeel.hit_stop(...) 호출.
##
## 핵심 설계:
## - 기존 배속(GameState.game_speed로 설정된 Engine.time_scale)과 '합성'한다. 멈춤 직전 값(_base)을
##   보존했다 복원하므로 1x·2x·3x 어디서든 비율로 동작한다(단순 대입은 배속 설정을 깨뜨림).
## - 시간 계측은 Time.get_ticks_msec()(벽시계, time_scale 무관)로 한다. time_scale을 0 근처로 낮추면
##   프레임 delta가 0에 수렴해 delta 기반 카운트다운은 영원히 안 끝나는 치명 엣지가 있기 때문.
## - process_mode=ALWAYS로 일시정지 중에도 복원을 보장해 time_scale 누수(다음 씬이 느려짐)를 막는다.

const STOP_SCALE := 0.06  # 강도 최대 시 도달 배율(거의 정지)
const _MIN_GAP_MS := 110  # 새 히트스톱 최소 간격(실시간) — 연속·동시 처치가 머신건처럼 깜빡이는 것 방지

var _active := false
var _base := 1.0       # 멈춤 직전 time_scale(배속) — 복원 대상
var _until_ms := 0
var _last_trigger_ms := 0  # 마지막으로 '새' 멈춤이 시작된 시각(throttle 판정용)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

## 히트스톱 발동. duration=실시간 초, strength=0~1(1=거의 정지). force=true면 throttle 무시(보스 처치 등 정점).
## 중첩: 종료시각은 max로 연장, 강도는 '더 강한(더 낮은 time_scale) 멈춤만' 반영 → 약한 호출이 강한 멈춤을 풀지 않음.
func hit_stop(duration: float = 0.08, strength: float = 1.0, force: bool = false) -> void:
	if not is_inside_tree() or get_tree().paused:
		return
	var now := Time.get_ticks_msec()
	if not force and not _active and now - _last_trigger_ms < _MIN_GAP_MS:
		return  # throttle: 직전 발동과 너무 가까운 '새' 멈춤은 생략(force는 예외)
	if not _active:
		_base = Engine.time_scale  # 현재 배속 보존(합성 기준) — 멈춤 시작 1회만 캡처
		_active = true
		_last_trigger_ms = now
	var target := _base * lerpf(1.0, STOP_SCALE, clampf(strength, 0.0, 1.0))
	Engine.time_scale = minf(Engine.time_scale, target)  # 더 강한 멈춤만 반영(겹침 안전)
	_until_ms = maxi(_until_ms, now + int(duration * 1000.0))

func _process(_dt: float) -> void:
	if _active and Time.get_ticks_msec() >= _until_ms:
		Engine.time_scale = _base
		_active = false
