extends Node
## 전역 메타 진행 상태(오토로드): 최고 웨이브 기록 + 캐릭터 로스터/선택.
## 씬을 새로 로드해도 유지되며, 최고 기록은 user://에 영속 저장된다.

const SAVE_PATH := "user://save.cfg"

# 컬렉션 로스터 (unlock_wave 오름차순)
var characters: Array = [
	preload("res://resources/characters/char_apprentice.tres"),
	preload("res://resources/characters/char_pyromancer.tres"),
	preload("res://resources/characters/char_archer.tres"),
	preload("res://resources/characters/char_frost.tres"),
]
var selected: CharacterData
var best_wave := 0

func _ready() -> void:
	_load()
	if selected == null:
		selected = characters[0]

func is_unlocked(c: CharacterData) -> bool:
	return best_wave >= c.unlock_wave

## 도달 웨이브 기록 (갱신 시에만 저장). 새로 해금된 게 있으면 true 반환.
func record_wave(reached: int) -> bool:
	if reached <= best_wave:
		return false
	var before := best_wave
	best_wave = reached
	_save()
	# 이번 기록으로 새로 열린 캐릭터가 있는지
	for c in characters:
		if c.unlock_wave > before and c.unlock_wave <= best_wave:
			return true
	return false

func _load() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) == OK:
		best_wave = cf.get_value("record", "best_wave", 0)

func _save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("record", "best_wave", best_wave)
	cf.save(SAVE_PATH)
