extends Control
## JIS/US配列の練習用キーボードを生成し、担当指・次のキー・入力flashを表示する部品。
## ゲーム側が公開setterを通して状態を渡す。キー配列と担当指は同じフォルダのkeyboard_layouts.jsonから読む。
## 寸法はControlのlocal座標、flashの期限は起動後の単調時計のミリ秒。

const FLASH_DURATION_MSEC := 220
## 次のキーの点滅速度。_pulse_timeへdeltaに掛けて足す。
const PULSE_SPEED := 4.0
const KEY_HEIGHT := 52.0
const DEFAULT_KEY_WIDTH := 52.0
const KEY_SEPARATION := 8
const ROW_SEPARATION := 10
const KEY_CORNER_RADIUS := 10
const KEY_FONT_SIZE := 20
const PANEL_MARGIN_HORIZONTAL := 24
const PANEL_MARGIN_TOP := 22
const PANEL_MARGIN_BOTTOM := 20
const PANEL_CORNER_RADIUS := 16
const PANEL_BORDER_WIDTH := 1
const BORDER_WIDTH := 2

## addonの置き場所に依存しないよう、このscriptと同じフォルダから読む。
const LAYOUTS_FILE := "keyboard_layouts.json"
const DEFAULT_LAYOUT_ID := "jis"

const FINGER_COLORS := {
	"pinky": Color("ffb3ba"),
	"ring": Color("ffd9a0"),
	"middle": Color("b3d4ff"),
	"index": Color("b8f0b8"),
	"thumb": Color("e0d4ff")
}
const UNASSIGNED_FINGER_COLOR := Color(0.82, 0.82, 0.82, 1.0)
const ROOT_FILL_COLOR := Color(0.03, 0.03, 0.04, 0.92)
const ROOT_BORDER_COLOR := Color(0.94, 0.78, 0.32, 0.42)
const KEY_FILL_COLOR := Color(0.18, 0.18, 0.2, 0.85)
const KEY_BORDER_COLOR := Color(0.34, 0.34, 0.38, 0.9)
const KEY_FONT_COLOR := Color(0.72, 0.74, 0.8, 1.0)
## 練習対象のキーは担当指の色を、この割合で暗く（枠は明るく）して塗る。
const HIGHLIGHT_FILL_DARKEN := 0.28
const HIGHLIGHT_BORDER_LIGHTEN := 0.08
const HIGHLIGHT_FONT_COLOR := Color(0.12, 0.1, 0.12, 1.0)
## 次のキーは、不透明度をPULSE_ALPHA_MIN〜PULSE_ALPHA_MIN+PULSE_ALPHA_RANGEで点滅させる。
const EXPECTED_FILL_COLOR := Color(0.96, 0.82, 0.28, 1.0)
const PULSE_ALPHA_MIN := 0.72
const PULSE_ALPHA_RANGE := 0.28
const EXPECTED_BORDER_COLOR := Color(1.0, 0.95, 0.7, 1.0)
const EXPECTED_FONT_COLOR := Color(0.08, 0.06, 0.02, 1.0)
const FLASH_FILL_COLOR := Color(0.9, 0.24, 0.24, 1.0)
const FLASH_BORDER_COLOR := Color(1.0, 0.78, 0.78, 1.0)
const FLASH_FONT_COLOR := Color(1.0, 1.0, 1.0, 1.0)

## keyboard_layouts.jsonの "layouts"（配列id → キー行の配列）。各キーはid・任意のlabel・任意のwidth（local寸法）を持つ。
var _layouts: Dictionary = {}
## キーid → 担当指の名前。keyboard_layouts.jsonの "finger_groups" を引きやすい形にしたもの。
var _finger_by_key: Dictionary = {}
var _layout_id := DEFAULT_LAYOUT_ID
## setterで渡された練習対象keyを正規化して保持する集合。再設定ごとに置き換える。
var _highlight_keys: Dictionary = {}
var _expected_key := ""
var _key_labels: Dictionary = {}
## キーごとに1つ作って使い回すStyleBox。色だけを書き換え、毎フレームの生成を避ける。
var _key_styles: Dictionary = {}
## keyごとのflash終了時刻（起動後ms）。期限が来たkeyを_process側で削除する。
var _flash_until: Dictionary = {}
var _pulse_time := 0.0
var _rows_box: VBoxContainer
## 生成したkey行の基準幅。resize時の表示scale計算に使うlocal寸法。
var _base_keyboard_width := 0.0


func _ready() -> void:
	_load_layouts()
	_build_base()
	_rebuild_keyboard()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_fit_keyboard_to_width()


## 配列をus/jisへ正規化してkey UIを再生成する。us以外はjis。
func set_layout_id(layout_id: String) -> void:
	var normalized := layout_id.to_lower()
	_layout_id = "us" if normalized == "us" else DEFAULT_LAYOUT_ID
	_rebuild_keyboard()


## 練習対象keyを正規化して置き換える。前回の集合は保持しない。
func set_highlight_keys(keys: Array[String]) -> void:
	_highlight_keys.clear()
	for key in keys:
		_highlight_keys[_normalize_key_id(key)] = true
	_apply_key_visuals()


## 次に入力するkeyを正規化して表示する。
func set_expected_key(key_id: String) -> void:
	var previous := _expected_key
	_expected_key = _normalize_key_id(key_id)
	_apply_key_visual(previous)
	_apply_key_visual(_expected_key)


## 指定keyを起動後時刻からFLASH_DURATION_MSECの間flash表示する。
func flash_key(key_id: String) -> void:
	var normalized := _normalize_key_id(key_id)
	_flash_until[normalized] = Time.get_ticks_msec() + FLASH_DURATION_MSEC
	_apply_key_visual(normalized)


## すべてのkeyのflash期限を解除する。
func clear_flash() -> void:
	var flashed: Array = _flash_until.keys()
	_flash_until.clear()
	for key_id in flashed:
		_apply_key_visual(String(key_id))


func _process(delta: float) -> void:
	_pulse_time += delta * PULSE_SPEED
	for key_id in _prune_flash():
		_apply_key_visual(key_id)
	# 点滅するのは次のキーだけなので、毎フレームはそのキーだけを塗り直す。
	_apply_key_visual(_expected_key)


func _load_layouts() -> void:
	var path: String = get_script().resource_path.get_base_dir().path_join(LAYOUTS_FILE)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("keyboard_layouts.json could not be loaded: %s" % path)
		return

	var data: Dictionary = parsed
	_layouts = data.get("layouts", {})
	var finger_groups: Dictionary = data.get("finger_groups", {})
	for finger_name: String in finger_groups.keys():
		for key_id: String in finger_groups[finger_name]:
			_finger_by_key[key_id] = finger_name


func _build_base() -> void:
	var root_panel := PanelContainer.new()
	root_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var frame_style: StyleBoxFlat = _panel_style(ROOT_FILL_COLOR, ROOT_BORDER_COLOR, PANEL_CORNER_RADIUS)
	# キーの丸みは保ち、外枠だけを細い切り欠きのフレームにする。
	frame_style.corner_detail = 1
	frame_style.set_border_width_all(PANEL_BORDER_WIDTH)
	root_panel.add_theme_stylebox_override("panel", frame_style)
	add_child(root_panel)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", PANEL_MARGIN_HORIZONTAL)
	margin.add_theme_constant_override("margin_top", PANEL_MARGIN_TOP)
	margin.add_theme_constant_override("margin_right", PANEL_MARGIN_HORIZONTAL)
	margin.add_theme_constant_override("margin_bottom", PANEL_MARGIN_BOTTOM)
	root_panel.add_child(margin)

	# Containerの再配置がキー群の中央位置を上書きしないよう、間に表示領域を置く。
	var keyboard_surface: Control = Control.new()
	margin.add_child(keyboard_surface)
	keyboard_surface.resized.connect(_fit_keyboard_to_width)
	_rows_box = VBoxContainer.new()
	_rows_box.add_theme_constant_override("separation", ROW_SEPARATION)
	keyboard_surface.add_child(_rows_box)


func _rebuild_keyboard() -> void:
	if _rows_box == null:
		return
	for child in _rows_box.get_children():
		child.queue_free()
	_key_labels.clear()
	_key_styles.clear()

	var rows: Array = _layouts.get(_layout_id, [])
	_base_keyboard_width = _measure_keyboard_width(rows)
	for row_data: Array in rows:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", KEY_SEPARATION)
		if row_data.size() == 1 and String(row_data[0].get("id", "")) == "SPACE":
			row.alignment = BoxContainer.ALIGNMENT_CENTER
		_rows_box.add_child(row)
		for key_data: Dictionary in row_data:
			_add_key(row, key_data)
	_fit_keyboard_to_width()
	_apply_key_visuals()


func _add_key(row: HBoxContainer, key_data: Dictionary) -> void:
	var key_id := _normalize_key_id(String(key_data.get("id", "")))
	var style := _panel_style(KEY_FILL_COLOR, KEY_BORDER_COLOR, KEY_CORNER_RADIUS)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(_key_width(key_data), KEY_HEIGHT)
	panel.add_theme_stylebox_override("panel", style)
	row.add_child(panel)

	var label := Label.new()
	label.text = String(key_data.get("label", key_id))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", KEY_FONT_SIZE)
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(label)

	_key_styles[key_id] = style
	_key_labels[key_id] = label


func _apply_key_visuals() -> void:
	for key_id: String in _key_styles.keys():
		_apply_key_visual(key_id)


## 1キーの色を、flash > 次のキー > 練習対象 > 通常 の優先順で決めて塗る。
func _apply_key_visual(key_id: String) -> void:
	var style: StyleBoxFlat = _key_styles.get(key_id)
	var label: Label = _key_labels.get(key_id)
	if style == null or label == null:
		return

	var fill_color := KEY_FILL_COLOR
	var border_color := KEY_BORDER_COLOR
	var font_color := KEY_FONT_COLOR
	if _flash_until.has(key_id):
		fill_color = FLASH_FILL_COLOR
		border_color = FLASH_BORDER_COLOR
		font_color = FLASH_FONT_COLOR
	elif key_id == _expected_key:
		fill_color = EXPECTED_FILL_COLOR
		fill_color.a = PULSE_ALPHA_MIN + (sin(_pulse_time) + 1.0) * 0.5 * PULSE_ALPHA_RANGE
		border_color = EXPECTED_BORDER_COLOR
		font_color = EXPECTED_FONT_COLOR
	elif _highlight_keys.has(key_id):
		var finger_color := _finger_color_for_key(key_id)
		fill_color = finger_color.darkened(HIGHLIGHT_FILL_DARKEN)
		border_color = finger_color.lightened(HIGHLIGHT_BORDER_LIGHTEN)
		font_color = HIGHLIGHT_FONT_COLOR

	style.bg_color = fill_color
	style.border_color = border_color
	label.add_theme_color_override("font_color", font_color)


## 期限が来たflashを外し、外したキーidを返す。
func _prune_flash() -> Array[String]:
	var expired: Array[String] = []
	var now := Time.get_ticks_msec()
	for key_id: String in _flash_until.keys():
		if int(_flash_until[key_id]) <= now:
			expired.append(key_id)
	for key_id in expired:
		_flash_until.erase(key_id)
	return expired


func _finger_color_for_key(key_id: String) -> Color:
	var finger_name: String = _finger_by_key.get(key_id, "")
	return FINGER_COLORS.get(finger_name, UNASSIGNED_FINGER_COLOR)


func _normalize_key_id(key_id: String) -> String:
	return key_id.strip_edges().to_upper()


func _key_width(key_data: Dictionary) -> float:
	return float(key_data.get("width", DEFAULT_KEY_WIDTH))


func _measure_keyboard_width(rows: Array) -> float:
	var widest := 0.0
	for row_data: Array in rows:
		var row_width := float(maxi(row_data.size() - 1, 0) * KEY_SEPARATION)
		for key_data: Dictionary in row_data:
			row_width += _key_width(key_data)
		widest = maxf(widest, row_width)
	return widest


func _fit_keyboard_to_width() -> void:
	if _rows_box == null or _base_keyboard_width <= 0.0:
		return
	var surface: Control = _rows_box.get_parent() as Control
	var available_width: float = maxf(surface.size.x, 1.0)
	var scale := minf(1.0, available_width / _base_keyboard_width)
	_rows_box.scale = Vector2(scale, scale)
	_rows_box.position = Vector2(maxf((available_width - (_base_keyboard_width * scale)) * 0.5, 0.0), 0.0)


func _panel_style(fill_color: Color, border_color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill_color
	style.set_border_width_all(BORDER_WIDTH)
	style.border_color = border_color
	style.set_corner_radius_all(radius)
	return style
