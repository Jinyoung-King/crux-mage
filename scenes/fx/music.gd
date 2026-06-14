extends Node
## 배경음악(BGM): 상황별 트랙(메뉴/전투/보스)을 루프 재생. 오토로드 'Music'.
## Master 버스로 출력 → 기존 음량 슬라이더·음소거(GameState가 버스0 제어) 설정과 자동 연동.
## 효과음에 묻히지 않도록 음량을 낮게(-11dB). 같은 트랙 재요청은 무시(씬 전환 시 끊김 방지).

const TRACKS := {
	"menu": "res://assets/audio/music_menu.wav",
	"battle": "res://assets/audio/music_battle.wav",
	"boss": "res://assets/audio/music_boss.wav",
}

var _player: AudioStreamPlayer
var _current: String = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # 일시정지 중에도 음악 유지
	_player = AudioStreamPlayer.new()
	_player.bus = "Master"
	_player.volume_db = -11.0
	add_child(_player)

func play(track: String) -> void:
	if track == _current and _player.playing:
		return  # 이미 같은 트랙 재생 중 → 그대로(끊김 방지)
	var path: String = TRACKS.get(track, "")
	if path == "":
		return
	_current = track
	_player.stream = load(path)
	_player.play()

func play_menu() -> void: play("menu")
func play_battle() -> void: play("battle")
func play_boss() -> void: play("boss")
