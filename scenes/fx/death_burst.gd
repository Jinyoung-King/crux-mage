extends CPUParticles2D
## 적 사망 파편 — 한 번 터지고 스스로 사라진다. color는 스폰하는 쪽에서 지정.

func _ready() -> void:
	emitting = true
	get_tree().create_timer(lifetime + 0.2).timeout.connect(queue_free)
