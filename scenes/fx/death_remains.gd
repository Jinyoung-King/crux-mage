extends Node2D
## 적 사망 연출: 스프라이트를 4조각으로 산산조각 내어 사방으로 튕겨내고,
## 회전·낙하 후 약 1.5초간 사체로 남았다 사라진다.
## 큰 적일수록 조각이 더 멀리·격하게 튄다(intensity).

const SCALE := 3.0  # 적 스프라이트 표시 배율과 동일
const LIFETIME := 1.6

## tex: 죽은 적의 스프라이트, body_size: 적 크기(px). add_child 후 호출할 것.
func setup(tex: Texture2D, body_size: float) -> void:
	if tex == null:
		queue_free()
		return
	var intensity := clampf(body_size / 36.0, 0.8, 2.2)  # 기본병 1.0, 보스 2.0
	var w := tex.get_width()
	var h := tex.get_height()
	var hw := w / 2
	var hh := h / 2
	# 4분할(좌상/우상/좌하/우하) — 각 조각을 원래 위치에 두고 바깥으로 산산조각
	_piece(tex, Rect2(0, 0, hw, hh), w, h, intensity)
	_piece(tex, Rect2(hw, 0, w - hw, hh), w, h, intensity)
	_piece(tex, Rect2(0, hh, hw, h - hh), w, h, intensity)
	_piece(tex, Rect2(hw, hh, w - hw, h - hh), w, h, intensity)
	get_tree().create_timer(LIFETIME + 0.1).timeout.connect(queue_free)

func _piece(tex: Texture2D, region: Rect2, w: int, h: int, intensity: float) -> void:
	var s := Sprite2D.new()
	s.texture = tex
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.region_enabled = true
	s.region_rect = region
	s.scale = Vector2(SCALE, SCALE)
	# 조각의 원래 화면 위치 (region 중심을 스프라이트 중심에 정렬)
	var px := (region.position.x + region.size.x / 2.0 - w / 2.0) * SCALE
	var py := (region.position.y + region.size.y / 2.0 - h / 2.0) * SCALE
	s.position = Vector2(px, py)
	add_child(s)
	_fling(s, intensity)

## 조각을 중심 바깥 방향으로 튕겨 격하게 회전시키고, 중력으로 떨어뜨린 뒤 페이드.
func _fling(piece: Sprite2D, intensity: float) -> void:
	var base := piece.position
	var dir := base.normalized() if base.length() > 1.0 else Vector2.UP
	# 가로: 바깥으로 튕김 (강도·무작위 가미)
	var horiz := dir.x * randf_range(70.0, 120.0) * intensity + randf_range(-25.0, 25.0)
	var tx := create_tween()
	tx.tween_property(piece, "position:x", base.x + horiz, LIFETIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# 세로: 솟구쳤다가 떨어짐 (포물선)
	var up := randf_range(50.0, 100.0) * intensity
	var ty := create_tween()
	ty.tween_property(piece, "position:y", base.y - up, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	ty.tween_property(piece, "position:y", base.y + 200.0 * intensity, LIFETIME - 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# 회전: 더 격하게 (방향 무작위)
	var spin := randf_range(5.0, 11.0) * (1.0 if randf() < 0.5 else -1.0)
	var tr := create_tween()
	tr.tween_property(piece, "rotation", spin, LIFETIME)
	# 페이드: 마지막 0.5초에 사라짐
	var tf := create_tween()
	tf.tween_interval(LIFETIME - 0.5)
	tf.tween_property(piece, "modulate:a", 0.0, 0.5)
