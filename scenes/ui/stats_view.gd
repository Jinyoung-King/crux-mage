class_name StatsView
extends RefCounted
## 빌드 능력치 텍스트 readout — main.gd에서 분리.
## ① 마법사 탭 능력치 오버레이($HUD/StatsPanel, 씬 정의)의 open/close, ② BBCode 본문(bbcode),
## ③ 일시정지 메뉴용 빌드 요약(summary), ④ 룬 이름 헬퍼(relic_name, 결과화면도 사용).
## 패널은 씬에 이미 있으므로 짓지 않고 조작만 한다. host(main)를 통해 노드·트리·game_over에 접근.

var _host: Node     # main (get_tree·game_over)
var _player: Node   # $Player (빌드·스킬 조회)

func setup(host: Node) -> void:
	_host = host
	_player = host.get_node("Player")
	var sp := host.get_node("HUD/StatsPanel")
	sp.get_node("Center/CloseButton").pressed.connect(_close)
	sp.get_node("Dim").gui_input.connect(_on_dim_input)

## 마법사 탭 → 현재 능력치 창. 게임오버·이미 멈춤이면 무시(원래 동작: 열 때 멈추지 않음).
func open() -> void:
	if _host.game_over or _host.get_tree().paused:
		return
	var sp := _host.get_node("HUD/StatsPanel")
	sp.get_node("Center/StatsLabel").text = bbcode()  # 룬 제외 + 쿨 최소치 색 강조(RichTextLabel BBCode)
	sp.show()

func _close() -> void:
	_host.get_node("HUD/StatsPanel").hide()
	_host.get_tree().paused = false

## 어두운 배경을 탭해도 닫힘
func _on_dim_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		_close()

## 능력치 창 본문(BBCode) — 룬은 제외(룬 화면에서 관리), 쿨 최소치 도달 스킬은 쿨 값을 다른 색으로.
func bbcode() -> String:
	var p = _player
	var b = p.build
	var lines := []
	lines.append("기지 내구도 %s / %s" % [NumFmt.compact(int(p.hp)), NumFmt.compact(int(p.max_hp))])
	lines.append("")
	lines.append("공격력 %d   ·   방어 %d" % [roundi(b.damage), int(b.defense)])
	for s in p.skills:
		if s.id == "barrier_droid":  # 지속형 — 쿨 없음
			lines.append("스킬 %s · 지속형 · 비행체 %d기" % [s.name, int(s.get("count", 2))])
			continue
		var cd: float = p.eff_cooldown(s)
		var floor_cd: float = maxf(2.0, s.cooldown * 0.6)
		var cd_str: String = "%.1f초" % cd
		if cd <= floor_cd + 0.01:  # 쿨 최소치 도달 → 더는 안 줄어듦을 다른 색(+최소)으로 표시
			cd_str = "[color=#5fd0ff]%.1f초 (최소)[/color]" % cd
		lines.append("스킬 %s · 쿨 %s · 피해 %d" % [s.name, cd_str, roundi(p.eff_power(s))])
	if p.lifesteal > 0.0:
		lines.append("흡혈 %d%%" % roundi(p.lifesteal * 100.0))
	return "[center]" + "\n".join(lines) + "[/center]"

## 현재 빌드 요약(일시정지 표시) — 카드·강화·숙련·유물이 반영된 실효 스탯
func summary() -> String:
	var p = _player
	var b = p.build
	var lines := []
	lines.append("공격력 %d   ·   방어 %d" % [roundi(b.damage), int(b.defense)])
	for s in p.skills:  # 보유 스킬마다 쿨·피해
		lines.append("스킬 %s · 쿨 %.1f초 · 피해 %d" % [s.name, p.eff_cooldown(s), roundi(p.eff_power(s))])
	var extras := []
	if p.lifesteal > 0.0:
		extras.append("흡혈 %d%%" % roundi(p.lifesteal * 100.0))
	if not extras.is_empty():
		lines.append("   ·   ".join(extras))
	if not p.relic_levels.is_empty():
		var names := []
		for id in p.relic_levels:
			names.append("%s Lv%d" % [relic_name(id), p.relic_levels[id]])
		lines.append("룬: " + ", ".join(names))
	return "\n".join(lines)

## 룬 id → 표시 이름 (결과 화면도 사용)
func relic_name(id: String) -> String:
	for r in RelicLib.RELICS:
		if r.id == id:
			return r.name
	return id
