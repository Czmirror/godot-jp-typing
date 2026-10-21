extends Control
## JIS/US配列の練習用キーボードを生成し、担当指・次のキー・入力flashを表示する部品。
## BootCampLessonが公開setterを通して状態を渡す。寸法はControlのlocal座標、flashの期限は起動後の単調時計のミリ秒。

const FINGER_COLORS := {
	"pinky": Color("ffb3ba"),
	"ring": Color("ffd9a0"),
	"middle": Color("b3d4ff"),
	"index": Color("b8f0b8"),
	"thumb": Color("e0d4ff")
}

## 表示用key配列。idは論理key識別子、labelは表示文字、widthはControlのlocal寸法。US_ROWSも同じ形式。
const JIS_ROWS := [
	[
		{"id": "1", "label": "1", "width": 52},
		{"id": "2", "label": "2", "width": 52},
		{"id": "3", "label": "3", "width": 52},
		{"id": "4", "label": "4", "width": 52},
		{"id": "5", "label": "5", "width": 52},
		{"id": "6", "label": "6", "width": 52},
		{"id": "7", "label": "7", "width": 52},
		{"id": "8", "label": "8", "width": 52},
		{"id": "9", "label": "9", "width": 52},
		{"id": "0", "label": "0", "width": 52},
		{"id": "-", "label": "-", "width": 52},
		{"id": "^", "label": "^", "width": 52},
		{"id": "BACKSPACE", "label": "Back", "width": 92}
	],
	[
		{"id": "Q", "label": "Q", "width": 58},
		{"id": "W", "label": "W", "width": 52},
		{"id": "E", "label": "E", "width": 52},
		{"id": "R", "label": "R", "width": 52},
		{"id": "T", "label": "T", "width": 52},
		{"id": "Y", "label": "Y", "width": 52},
		{"id": "U", "label": "U", "width": 52},
		{"id": "I", "label": "I", "width": 52},
		{"id": "O", "label": "O", "width": 52},
		{"id": "P", "label": "P", "width": 52},
		{"id": "@", "label": "@", "width": 52},
		{"id": "[", "label": "[", "width": 52}
	],
	[
		{"id": "A", "label": "A", "width": 68},
		{"id": "S", "label": "S", "width": 52},
		{"id": "D", "label": "D", "width": 52},
		{"id": "F", "label": "F", "width": 52},
		{"id": "G", "label": "G", "width": 52},
		{"id": "H", "label": "H", "width": 52},
		{"id": "J", "label": "J", "width": 52},
		{"id": "K", "label": "K", "width": 52},
		{"id": "L", "label": "L", "width": 52},
		{"id": ";", "label": ";", "width": 52},
		{"id": ":", "label": ":", "width": 52},
		{"id": "ENTER", "label": "Enter", "width": 88}
	],
	[
		{"id": "Z", "label": "Z", "width": 88},
		{"id": "X", "label": "X", "width": 52},
		{"id": "C", "label": "C", "width": 52},
		{"id": "V", "label": "V", "width": 52},
		{"id": "B", "label": "B", "width": 52},
		{"id": "N", "label": "N", "width": 52},
		{"id": "M", "label": "M", "width": 52},
		{"id": ",", "label": ",", "width": 52},
		{"id": ".", "label": ".", "width": 52},
		{"id": "/", "label": "/", "width": 52},
		{"id": "SHIFT", "label": "Shift", "width": 112}
	],
	[
		{"id": "SPACE", "label": "Space", "width": 392}
	]
]

const US_ROWS := [
	[
		{"id": "1", "label": "1", "width": 52},
		{"id": "2", "label": "2", "width": 52},
		{"id": "3", "label": "3", "width": 52},
		{"id": "4", "label": "4", "width": 52},
		{"id": "5", "label": "5", "width": 52},
		{"id": "6", "label": "6", "width": 52},
		{"id": "7", "label": "7", "width": 52},
		{"id": "8", "label": "8", "width": 52},
		{"id": "9", "label": "9", "width": 52},
		{"id": "0", "label": "0", "width": 52},
		{"id": "-", "label": "-", "width": 52},
		{"id": "=", "label": "=", "width": 52},
		{"id": "BACKSPACE", "label": "Back", "width": 92}
	],
	[
		{"id": "Q", "label": "Q", "width": 58},
		{"id": "W", "label": "W", "width": 52},
		{"id": "E", "label": "E", "width": 52},
		{"id": "R", "label": "R", "width": 52},
		{"id": "T", "label": "T", "width": 52},
		{"id": "Y", "label": "Y", "width": 52},
		{"id": "U", "label": "U", "width": 52},
		{"id": "I", "label": "I", "width": 52},
		{"id": "O", "label": "O", "width": 52},
		{"id": "P", "label": "P", "width": 52},
		{"id": "[", "label": "[", "width": 52},
		{"id": "]", "label": "]", "width": 52}
	],
	[
		{"id": "A", "label": "A", "width": 68},
		{"id": "S", "label": "S", "width": 52},
		{"id": "D", "label": "D", "width": 52},
		{"id": "F", "label": "F", "width": 52},
		{"id": "G", "label": "G", "width": 52},
		{"id": "H", "label": "H", "width": 52},
		{"id": "J", "label": "J", "width": 52},
		{"id": "K", "label": "K", "width": 52},
		{"id": "L", "label": "L", "width": 52},
		{"id": ";", "label": ";", "width": 52},
		{"id": "'", "label": "'", "width": 52},
		{"id": "ENTER", "label": "Enter", "width": 88}
	],
	[
		{"id": "Z", "label": "Z", "width": 88},
		{"id": "X", "label": "X", "width": 52},
		{"id": "C", "label": "C", "width": 52},
		{"id": "V", "label": "V", "width": 52},
		{"id": "B", "label": "B", "width": 52},
		{"id": "N", "label": "N", "width": 52},
		{"id": "M", "label": "M", "width": 52},
		{"id": ",", "label": ",", "width": 52},
		{"id": ".", "label": ".", "width": 52},
		{"id": "/", "label": "/", "width": 52},
		{"id": "SHIFT", "label": "Shift", "width": 112}
	],
	[
		{"id": "SPACE", "label": "Space", "width": 392}
	]
]

const FINGER_GROUPS := {
	"pinky": ["A", ";", "Q", "P", "Z", "/", "-", ":", "@", "[", "]", "'", "^"],
	"ring": ["S", "L", "W", "O", "X", ".", "2", "9"],
	"middle": ["D", "K", "E", "I", "C", ",", "3", "8"],
	"index": ["F", "J", "R", "U", "T", "Y", "V", "B", "N", "M", "G", "H", "4", "5", "6", "7"],
	"thumb": ["SPACE"]
}

var _layout_id := "jis"
## setterで渡された練習対象keyを正規化して保持する集合。再設定ごとに置き換える。
var _highlight_keys: Dictionary = {}
var _expected_key := ""
var _key_panels: Dictionary = {}
var _key_labels: Dictionary = {}
## keyごとのflash終了時刻（起動後ms）。期限が来たkeyを_process側で削除する。
var _flash_until: Dictionary = {}
var _pulse_time := 0.0
var _root_panel: PanelContainer
var _rows_box: VBoxContainer
## 生成したkey行の基準幅。resize時の表示scale計算に使うlocal寸法。
var _base_keyboard_width := 0.0


func _ready() -> void:
	_build_base()
	_rebuild_keyboard()
	set_process(true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_fit_keyboard_to_width()


## 配列をus/jisへ正規化してkey UIを再生成する。us以外はjis。
func set_layout_id(layout_id: String) -> void:
	var normalized := layout_id.to_lower()
	_layout_id = "us" if normalized == "us" else "jis"
	_rebuild_keyboard()


## 練習対象keyを正規化して置き換える。前回の集合は保持しない。
func set_highlight_keys(keys: Array[String]) -> void:
	_highlight_keys.clear()
	for key in keys:
		_highlight_keys[_normalize_key_id(key)] = true
	_apply_key_visuals()


## 次に入力するkeyを正規化して表示する。
func set_expected_key(key_id: String) -> void:
	_expected_key = _normalize_key_id(key_id)
	_apply_key_visuals()


## 指定keyを起動後時刻から220msの間flash表示する。
func flash_key(key_id: String) -> void:
	var normalized := _normalize_key_id(key_id)
	_flash_until[normalized] = Time.get_ticks_msec() + 220
	_apply_key_visuals()


## すべてのkeyのflash期限を解除する。
func clear_flash() -> void:
	_flash_until.clear()
	_apply_key_visuals()


func _process(delta: float) -> void:
	_pulse_time += delta * 4.0
	if _flash_until.is_empty() and _expected_key.is_empty():
		return
	_prune_flash()
	_apply_key_visuals()


func _build_base() -> void:
	_root_panel = PanelContainer.new()
	_root_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.03, 0.03, 0.04, 0.92), Color(0.75, 0.54, 0.28, 0.9), 18))
	add_child(_root_panel)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 20)
	_root_panel.add_child(margin)

	_rows_box = VBoxContainer.new()
	_rows_box.add_theme_constant_override("separation", 10)
	margin.add_child(_rows_box)


func _rebuild_keyboard() -> void:
	if _rows_box == null:
		return
	for child in _rows_box.get_children():
		child.queue_free()
	_key_panels.clear()
	_key_labels.clear()

	var rows: Array = JIS_ROWS if _layout_id == "jis" else US_ROWS
	_base_keyboard_width = _measure_keyboard_width(rows)
	for row_data in rows:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_rows_box.add_child(row)
		for key_data in row_data:
			_add_key(row, key_data)
	_fit_keyboard_to_width()
	_apply_key_visuals()


func _add_key(row: HBoxContainer, key_data: Dictionary) -> void:
	var key_id := _normalize_key_id(String(key_data.get("id", "")))
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(float(key_data.get("width", 52)), 52.0)
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.18, 0.18, 0.2, 0.92), Color(0.36, 0.36, 0.4, 0.9), 10))
	row.add_child(panel)

	var label := Label.new()
	label.text = String(key_data.get("label", key_id))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(0.86, 0.88, 0.94, 1.0))
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(label)

	_key_panels[key_id] = panel
	_key_labels[key_id] = label


func _apply_key_visuals() -> void:
	for key_id_value in _key_panels.keys():
		var key_id: String = String(key_id_value)
		var panel := _key_panels[key_id] as PanelContainer
		var label := _key_labels.get(key_id) as Label
		if panel == null or label == null:
			continue

		var is_highlighted: bool = _highlight_keys.has(key_id)
		var is_expected: bool = key_id == _expected_key and not _expected_key.is_empty()
		var is_flashing: bool = _flash_until.has(key_id)
		var base_color: Color = Color(0.18, 0.18, 0.2, 0.85)
		var border_color: Color = Color(0.34, 0.34, 0.38, 0.9)
		var font_color: Color = Color(0.72, 0.74, 0.8, 1.0)

		if is_highlighted:
			var finger_color: Color = _finger_color_for_key(key_id)
			base_color = finger_color.darkened(0.28)
			border_color = finger_color.lightened(0.08)
			font_color = Color(0.12, 0.1, 0.12, 1.0)

		if is_expected:
			var pulse: float = 0.72 + ((sin(_pulse_time) + 1.0) * 0.14)
			base_color = Color(0.96, 0.82, 0.28, pulse)
			border_color = Color(1.0, 0.95, 0.7, 1.0)
			font_color = Color(0.08, 0.06, 0.02, 1.0)

		if is_flashing:
			base_color = Color(0.9, 0.24, 0.24, 1.0)
			border_color = Color(1.0, 0.78, 0.78, 1.0)
			font_color = Color(1, 1, 1, 1.0)

		panel.add_theme_stylebox_override("panel", _panel_style(base_color, border_color, 10))
		label.add_theme_color_override("font_color", font_color)


func _prune_flash() -> void:
	var now := Time.get_ticks_msec()
	for key_id in _flash_until.keys():
		if int(_flash_until[key_id]) <= now:
			_flash_until.erase(key_id)


func _finger_color_for_key(key_id: String) -> Color:
	for finger_name in FINGER_GROUPS.keys():
		if FINGER_GROUPS[finger_name].has(key_id):
			return FINGER_COLORS.get(finger_name, Color(0.82, 0.82, 0.82, 1.0))
	return Color(0.82, 0.82, 0.82, 1.0)


func _normalize_key_id(key_id: String) -> String:
	var normalized := key_id.strip_edges()
	if normalized.is_empty():
		return normalized
	if normalized == "Space" or normalized == "space":
		return "SPACE"
	return normalized.to_upper()


func _measure_keyboard_width(rows: Array) -> float:
	var widest := 0.0
	for row_data in rows:
		var row_width := 0.0
		var key_count := 0
		for key_data in row_data:
			row_width += float(key_data.get("width", 52))
			key_count += 1
		if key_count > 1:
			row_width += float((key_count - 1) * 8)
		widest = maxf(widest, row_width)
	return widest


func _fit_keyboard_to_width() -> void:
	if _rows_box == null or _base_keyboard_width <= 0.0:
		return
	var available_width := maxf(size.x - 48.0, 1.0)
	var scale := minf(1.0, available_width / _base_keyboard_width)
	_rows_box.scale = Vector2(scale, scale)
	_rows_box.position = Vector2(maxf((available_width - (_base_keyboard_width * scale)) * 0.5, 0.0), 0.0)


func _panel_style(fill_color: Color, border_color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill_color
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = border_color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	return style
