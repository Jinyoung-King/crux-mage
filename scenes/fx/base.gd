extends Node2D
## 마법사의 기지(성벽) placeholder — 화면 하단을 따라 성벽 + 총안. 단색 도형(아트는 추후).
## 마법사가 이 위에서 적을 막는 '기지 방어' 연출용. 좌표는 720x1280 월드 기준.

const WALL_TOP := 1150.0
const WALL_COL := Color(0.19, 0.18, 0.24)      # 성벽 본체
const EDGE_COL := Color(0.36, 0.34, 0.46)      # 윗변 강조
const MERLON_W := 46.0                          # 총안 돌출 블록 폭
const MERLON_GAP := 34.0

func _draw() -> void:
	var w := 720.0
	# 성벽 본체
	draw_rect(Rect2(16, WALL_TOP, w - 32, 1280.0 - WALL_TOP), WALL_COL)
	draw_rect(Rect2(16, WALL_TOP, w - 32, 6), EDGE_COL)  # 윗변 라인
	# 총안(크레넬레이션) — 일정 간격 돌출 블록
	var x := 26.0
	while x + MERLON_W < w - 16:
		draw_rect(Rect2(x, WALL_TOP - 22, MERLON_W, 24), WALL_COL)
		draw_rect(Rect2(x, WALL_TOP - 22, MERLON_W, 5), EDGE_COL)
		x += MERLON_W + MERLON_GAP
