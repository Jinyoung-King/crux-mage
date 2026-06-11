class_name WaveData
extends Resource
## 웨이브 1개의 스폰 설정: 어떤 적을 몇 마리, 어떤 간격으로.

@export var spawn_interval: float = 1.0  ## 생성 간격(초)
@export var entries: Array = []  ## WaveEntry 목록

## entries를 펼쳐 섞은 스폰 순서(EnemyData 목록) 반환
func build_spawn_list() -> Array:
	var list: Array = []
	for entry in entries:
		for i in entry.count:
			list.append(entry.enemy)
	list.shuffle()
	return list
