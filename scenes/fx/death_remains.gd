extends Node2D
## 적 사망 연출: 스프라이트를 좌/우 두 조각으로 찢어 튕겨낸 뒤,
## 회전하며 떨어진 조각이 약 1.5초간 사체로 남았다 사라진다.

const SCALE := 3.0  # 적 스프라이트 표시 배율과 동일
const LIFETIME := 1.6

## tex: 죽은 적의 스프라이트. add_child 후 호출할 것.
func setup(tex: Texture2D) -> void:
	if tex == null:
		queue_free()
		return
	var w := tex.get_width()
	var h := tex.get_height()
	var half_w := w / 2
	# 좌/우 절반을 원래 위치에 맞춰 배치 (region으로 잘라서)
	var left := _make_half(tex, Rect2(0, 0, half_w, h), SCALE * (half_w - w) / 2.0)
	var right := _make_half(tex, Rect2(half_w, 0, w - half_w, h), SCALE * half_w / 2.0)
	add_child(left)
	add_child(right)
	_fling(left, -1.0)
	_fling(right, 1.0)
	get_tree().create_timer(LIFETIME + 0.1).timeout.connect(queue_free)

func _make_half(tex: Texture2D, region: Rect2, x: float) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.region_enabled = true
	s.region_rect = region
	s.scale = Vector2(SCALE, SCALE)
	s.position = Vector2(x, 0)
	return s

## 조각을 dir(±1) 방향으로 튕겨 회전시키고(찢김), 중력으로 떨어뜨린 뒤 페이드(사체).
func _fling(half: Sprite2D, dir: float) -> void:
	var base := half.position
	# 가로: 바깥으로 튕겨나가 멈춤
	var tx := create_tween()
	tx.tween_property(half, "position:x", base.x + dir * randf_range(45.0, 85.0), LIFETIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# 세로: 살짝 솟았다가 떨어짐 (포물선)
	var ty := create_tween()
	ty.tween_property(half, "position:y", base.y - randf_range(25.0, 55.0), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	ty.tween_property(half, "position:y", base.y + 150.0, LIFETIME - 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# 회전: 떨어지며 빙글
	var tr := create_tween()
	tr.tween_property(half, "rotation", dir * randf_range(2.5, 5.0), LIFETIME)
	# 페이드: 마지막 0.5초에 사라짐
	var tf := create_tween()
	tf.tween_interval(LIFETIME - 0.5)
	tf.tween_property(half, "modulate:a", 0.0, 0.5)
