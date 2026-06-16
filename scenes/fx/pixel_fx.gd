extends Sprite2D
## 픽셀 FX 1회 재생 — 가로 스프라이트시트(hframes)를 프레임 진행 후 스스로 사라짐.
## GPU엔 텍스처 사각형 1장이라 절차적 _draw·CPU 파티클보다 저비용이면서 화려.
## 풀링 없음(스킬 캐스트당 1회 수준이라 불필요) — 고빈도 FX로 확장 시 풀링 고려.

var _frames := 1
var _fps := 24.0
var _t := 0.0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # 도트 크리스프(블러 방지 — 임포트 설정과 무관하게 강제)
	z_index = 7  # 적·발사체 위에

## tex=시트, frames=프레임 수, target_px=화면상 지름(px)에 맞춰 스케일, fps=재생 속도, col=틴트(흰색=원본)
func play(tex: Texture2D, frames: int, target_px: float, fps: float = 24.0, col: Color = Color.WHITE) -> void:
	texture = tex
	hframes = frames
	frame = 0
	_frames = frames
	_fps = fps
	_t = 0.0
	modulate = col
	var fw: float = float(tex.get_width()) / float(frames)  # 프레임 1장 폭
	var s: float = (target_px / fw) if fw > 0.0 else 1.0
	scale = Vector2(s, s)

func _process(delta: float) -> void:
	_t += delta * _fps
	var f := int(_t)
	if f >= _frames:
		queue_free()
		return
	frame = f
