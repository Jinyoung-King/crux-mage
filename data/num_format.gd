class_name NumFmt
extends RefCounted
## 큰 수를 만/억 단위로 압축 표시 (한글). 1만 미만은 그대로.
## 예: 1234→"1234", 12345→"1.2만", 1234567→"123.5만", 250000000→"2.5억"

static func compact(n: int) -> String:
	if n < 10000:
		return str(n)
	if n < 100000000:           # 1만 ~ 9999만
		return _trim(n / 10000.0) + "만"
	if n < 1000000000000:       # 1억 ~ 9999억
		return _trim(n / 100000000.0) + "억"
	return _trim(n / 1000000000000.0) + "조"

## 소수 1자리, 단 .0이면 정수로 (1.0만 → 1만)
static func _trim(v: float) -> String:
	var s := "%.1f" % v
	return s.substr(0, s.length() - 2) if s.ends_with(".0") else s
