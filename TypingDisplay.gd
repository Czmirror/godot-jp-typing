extends Control
## TypingEngineに登録したタイプ対象の状態を、かな・入力済み文字・次の文字の表示へ変換する部品。
## タイプ対象のsceneに置き、target_pathかset_target_unit()で表示対象を渡す。登録状態がない対象の表示は空にする。

@export var target_path: NodePath
@export var typed_color: Color = Color("707070")
@export var next_char_color: Color = Color("ffd54a")
@export var remain_color: Color = Color("ffffff")

@onready var _kana_label: RichTextLabel = %KanaLabel
@onready var _romaji_label: RichTextLabel = %RomajiLabel
@onready var _focus_panel: Panel = %FocusPanel

## 表示対象のNode参照。ready時のpath解決またはsetterで更新し、入力の正本はTypingEngine側に置く。
var _target_unit: Node


func _ready() -> void:
	_target_unit = get_node_or_null(target_path)
	TypingEngine.char_typed.connect(_on_typing_changed)
	TypingEngine.focus_changed.connect(_on_focus_changed)
	TypingEngine.word_completed.connect(_on_word_completed)
	_refresh()


## 表示対象を切り替えて即座に更新する。nullなら空表示へ戻す。
func set_target_unit(unit: Node) -> void:
	_target_unit = unit
	_refresh()


## TypingEngineの現在状態から表示を更新する。対象が未登録なら空表示。
func refresh_display() -> void:
	_refresh()


func _on_typing_changed(unit: Node) -> void:
	if unit == _target_unit:
		_refresh()


func _on_focus_changed(unit: Node) -> void:
	if unit == null or unit == _target_unit:
		_refresh()


func _on_word_completed(unit: Node) -> void:
	if unit == _target_unit:
		_refresh()


func _refresh() -> void:
	if _target_unit == null:
		_clear()
		return

	var state := TypingEngine.get_state_for(_target_unit)
	if state.is_empty():
		_clear()
		return

	_kana_label.text = "[center]%s[/center]" % state.get("kana", "")
	_romaji_label.text = _build_romaji_bbcode(state)
	_focus_panel.visible = state.get("is_focused", false)


func _clear() -> void:
	_kana_label.text = ""
	_romaji_label.text = ""
	_focus_panel.visible = false


func _build_romaji_bbcode(state: Dictionary) -> String:
	var typed := String(state.get("current_input", ""))
	var display := String(state.get("display_romaji", ""))
	var typed_text := typed
	var next_char := ""
	var remain := ""

	if display.length() > typed.length():
		next_char = display.substr(typed.length(), 1)
		if display.length() > typed.length() + 1:
			remain = display.substr(typed.length() + 1)

	var text := "[center]"
	if not typed_text.is_empty():
		text += "[color=#%s]%s[/color]" % [typed_color.to_html(false), typed_text]
	if not next_char.is_empty():
		text += "[color=#%s]%s[/color]" % [next_char_color.to_html(false), next_char]
	if not remain.is_empty():
		text += "[color=#%s]%s[/color]" % [remain_color.to_html(false), remain]
	text += "[/center]"
	return text
