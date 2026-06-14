extends Node
## 적("enemies" 그룹) 목록을 물리 프레임당 1회만 스냅샷해 공유하는 오토로드.
##
## 기존: 발사체 명중(연쇄·산탄)·폭발·광역·장판 틱·비행체·타겟팅이 매번
## get_tree().get_nodes_in_group("enemies")로 새 배열을 O(N)로 할당 → 적·발사체가
## 쌓이는 후반 + 고배속(6x)에서 호출 횟수 × O(N) 부담이 곱으로 커져 렉.
## 이제: 같은 프레임 내 호출은 캐시된 한 배열을 공유 → 프레임당 1회 탐색으로 축소.
##
## 주의: 반환 배열은 '공유 스냅샷'이다. 정렬·셔플 등 변형이 필요하면 호출 측에서 반드시
## duplicate() 후 변형할 것(공유 배열을 변형하면 같은 프레임의 다른 소비자가 깨진다).
## get_nodes_in_group과 동일하게 같은 프레임에 막 free된 노드가 섞일 수 있으므로
## 소비 측 is_instance_valid(e) 가드는 그대로 유지한다(스냅샷은 가드를 대체하지 않음).

var _frame: int = -1
var _list: Array = []

## 이번 물리 프레임의 적 목록(읽기 전용 스냅샷). 프레임이 바뀌었을 때만 그룹을 다시 훑는다.
func all() -> Array:
	var f := Engine.get_physics_frames()
	if f != _frame:
		_frame = f
		_list = get_tree().get_nodes_in_group("enemies")
	return _list
