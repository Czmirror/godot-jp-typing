extends Node
## 登録したタイプ対象ごとの入力進捗とfocusを管理し、文字・単語完了をsignalで通知するAutoload。
## ゲーム側がタイプ対象のNodeを登録し、TypingDisplayなどが状態を読む。かな→ローマ字候補の生成はRomajiConverterに任せる。
## 実キー入力を小文字1文字へ絞って処理する。対象の寿命はtree_exitingで追跡し、ダメージやスコアは呼び出し元が処理する。

signal word_completed(unit: Node)
signal char_typed(unit: Node)
signal mistype(unit: Node)
signal no_target_hit
signal focus_changed(unit: Node)

const FOCUS_CLEAR_KEYS: Array[Key] = [KEY_TAB, KEY_ESCAPE]
## addonの置き場所に依存しないよう、このscriptと同じフォルダから読む。
const KANA_ROMAJI_FILE := "kana_romaji.json"
const ROMAJI_CONVERTER_FILE := "RomajiConverter.gd"

## ready時にkana_romaji.jsonから作り、Autoloadの寿命中に共有する変換器（RomajiConverter）。
var _converter: RefCounted
## 登録順に走査する対象一覧。同じ先頭候補の対象がある場合は先に登録されたものをfocusする。
var _targets: Array[Node] = []
## Node → TargetState。登録で作成、解除・単語完了・tree_exitingで削除する。
var _states: Dictionary = {}
var _focused_unit: Node = null
## 実キー入力の受付スイッチ。falseでfocusを解除するが、handle_text_inputの直接呼び出しは遮断しない。
var _enabled := true


## 1つのタイプ対象の入力進捗。segmentsはRomajiConverterの出力で、segment_indexの区切りを入力中。
class TargetState:
	var kanji: String
	var kana: String
	var segments: Array[Dictionary]
	## 全区切りの候補を重複なく並べたもの。表示用の参考値で、入力判定には使わない。
	var all_candidates: Array[String] = []
	var segment_index := 0
	## 入力中の区切りで打った文字。区切りを打ち終えると空に戻す。
	var segment_input := ""
	var typed_romaji := ""
	## 入力中の区切りで、ここまでの入力と前方一致する候補。
	var active_candidates: Array[String] = []

	func _init(kanji_text: String, kana_text: String, kana_segments: Array[Dictionary]) -> void:
		kanji = kanji_text
		kana = kana_text
		segments = kana_segments
		for segment in segments:
			for pattern: String in segment["patterns"]:
				if not all_candidates.has(pattern):
					all_candidates.append(pattern)
		reset_progress()

	func reset_progress() -> void:
		segment_index = 0
		segment_input = ""
		typed_romaji = ""
		active_candidates = _patterns_at(0)

	## 1文字を受け付けて進めたらtrue、どの候補にも合わなければ状態を変えずfalse。
	func accept(text: String) -> bool:
		var next_segment_input := segment_input + text
		var valid_candidates: Array[String] = []
		for candidate in active_candidates:
			if candidate.begins_with(next_segment_input):
				valid_candidates.append(candidate)
		if valid_candidates.is_empty():
			return false

		segment_input = next_segment_input
		typed_romaji += text
		active_candidates = valid_candidates
		if valid_candidates.has(next_segment_input):
			segment_index += 1
			segment_input = ""
			active_candidates = _patterns_at(segment_index)
		return true

	func is_completed() -> bool:
		return segment_index >= segments.size()

	## 入力済み文字に、入力中の区切りと残りの区切りの先頭候補をつなげた表示用ローマ字。
	func build_display_romaji() -> String:
		if is_completed():
			return typed_romaji

		var display := typed_romaji
		if not active_candidates.is_empty():
			display += active_candidates[0].substr(segment_input.length())
		for i in range(segment_index + 1, segments.size()):
			var patterns: Array[String] = segments[i]["patterns"]
			if not patterns.is_empty():
				display += patterns[0]
		return display

	func _patterns_at(index: int) -> Array[String]:
		if index >= segments.size():
			return []
		var patterns: Array[String] = segments[index]["patterns"]
		return patterns.duplicate()


func _ready() -> void:
	var base_dir: String = get_script().resource_path.get_base_dir()
	var converter_script: GDScript = load(base_dir.path_join(ROMAJI_CONVERTER_FILE)) as GDScript
	var kana_map: Dictionary = converter_script.call("load_kana_map", base_dir.path_join(KANA_ROMAJI_FILE))
	_converter = converter_script.new(kana_map)
	process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_input(event: InputEvent) -> void:
	if not _enabled:
		return
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return

	if FOCUS_CLEAR_KEYS.has(key_event.keycode):
		clear_focus()
		get_viewport().set_input_as_handled()
		return

	var text := key_event.as_text_key_label().to_lower()
	# as_text_key_label()はマイナスキーを"Minus"と返すため、長音記号の入力として置き換える。
	if key_event.keycode == KEY_MINUS or key_event.physical_keycode == KEY_MINUS:
		text = "-"
	if text.length() != 1 or not _is_supported_input(text):
		return

	handle_text_input(text)
	get_viewport().set_input_as_handled()


## 実キー入力を有効・無効にする。無効化時はfocusとその入力進捗を解除する。
func set_enabled(value: bool) -> void:
	_enabled = value
	if not _enabled:
		clear_focus()


## Nodeとkana/任意kanjiのpayloadを登録する。nullは無視し、同じNodeの再登録は旧進捗を捨てる。
func register_target(unit: Node, payload: Dictionary) -> void:
	if unit == null:
		return
	if _states.has(unit):
		unregister_target(unit)

	var kana: String = String(payload.get("kana", ""))
	var kanji: String = String(payload.get("kanji", kana))
	_targets.append(unit)
	var segments: Array[Dictionary] = _converter.call("build_segments", kana)
	_states[unit] = TargetState.new(kanji, kana, segments)

	var exit_callable: Callable = _on_target_tree_exiting.bind(unit)
	if not unit.tree_exiting.is_connected(exit_callable):
		unit.tree_exiting.connect(exit_callable, CONNECT_ONE_SHOT)


## 対象の進捗と一覧を解除する。未登録は無視し、focus対象ならfocus_changed(null)を通知する。
func unregister_target(unit: Node) -> void:
	if not _states.has(unit):
		return

	var was_focused: bool = _focused_unit == unit
	_states.erase(unit)
	_targets.erase(unit)
	if was_focused:
		_focused_unit = null
		focus_changed.emit(null)


## focus中の入力進捗を先頭へ戻し、focus_changed(null)を通知する。対象の登録は保持する。
func clear_focus() -> void:
	if _focused_unit == null:
		return

	var state: TargetState = _states.get(_focused_unit)
	if state != null:
		state.reset_progress()

	_focused_unit = null
	focus_changed.emit(null)


## 小文字の対応文字1文字を渡す直接入力API。実キー側のfilterや_enabled判定はここでは行わない。
func handle_text_input(text: String) -> void:
	if text.is_empty():
		return

	if _focused_unit == null:
		var matched_unit: Node = _find_matching_target(text)
		if matched_unit == null:
			no_target_hit.emit()
			return
		_focus_target(matched_unit)

	_apply_input_to_target(_focused_unit, text)


## 表示用Dictionaryを返す。current_inputは入力済み文字、display_romajiは残り候補込み。未登録なら空で、候補配列はdeep copyしない。
## all_candidatesは全かな区切りの候補を重複なく並べたもので、単語全体の綴りの一覧ではない。
func get_state_for(unit: Node) -> Dictionary:
	if not _states.has(unit):
		return {}

	var state: TargetState = _states[unit]
	return {
		"kanji": state.kanji,
		"kana": state.kana,
		"current_input": state.typed_romaji,
		"display_romaji": state.build_display_romaji(),
		"all_candidates": state.all_candidates,
		"active_candidates": state.active_candidates,
		"is_focused": unit == _focused_unit
	}


## 現在focus中のNodeを返す。対象がなければnull。
func get_focused_unit() -> Node:
	return _focused_unit


func _apply_input_to_target(unit: Node, text: String) -> void:
	var state: TargetState = _states.get(unit)
	if state == null:
		no_target_hit.emit()
		return
	if not state.accept(text):
		mistype.emit(unit)
		return

	char_typed.emit(unit)
	if state.is_completed():
		unregister_target(unit)
		word_completed.emit(unit)


func _find_matching_target(text: String) -> Node:
	for unit in _targets:
		var state: TargetState = _states[unit]
		for candidate in state.active_candidates:
			if candidate.begins_with(text):
				return unit
	return null


func _focus_target(unit: Node) -> void:
	_focused_unit = unit
	(_states[unit] as TargetState).reset_progress()
	focus_changed.emit(unit)


func _is_supported_input(text: String) -> bool:
	if text == "-":
		return true
	return text >= "a" and text <= "z"


func _on_target_tree_exiting(unit: Node) -> void:
	unregister_target(unit)
