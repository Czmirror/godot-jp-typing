extends Node
## 登録標的ごとにかな由来のローマ字候補と入力進捗を管理し、文字・単語完了をsignalで通知するAutoload。
## 敵・標的・lessonが登録し、TypingDisplayや各モードが状態を読む。kana_romaji.jsonを読み込む。
## 実キー入力を小文字1文字へ絞って処理する。対象の寿命はtree_exitingで追跡し、damageやscoreは呼び出し元が処理する。

signal word_completed(unit)
signal char_typed(unit)
signal mistype(unit)
signal no_target_hit
signal focus_changed(unit)

const FIXED_RELEASE_KEY := KEY_TAB
const DEFAULT_CANCEL_KEY := KEY_ESCAPE
const KANA_ROMAJI_PATH := "res://addons/typing_core/kana_romaji.json"
const SMALL_TSU_DIRECT := ["xtsu", "xtu", "ltsu", "ltu"]

## ready時にかな変換JSONから読み、Autoloadの寿命中に共有する候補表。
var _kana_map: Dictionary = {}
## 登録順に走査する対象一覧。同じ先頭候補の対象がある場合は先に登録されたものをfocusする。
var _targets: Array[Node] = []
## Nodeをkeyとする入力進捗。登録で作成、解除・単語完了・tree_exitingで削除する。
var _states: Dictionary = {}
var _focused_unit: Node = null
## 実キー入力の受付スイッチ。falseでfocusを解除するが、handle_text_inputの直接呼び出しは遮断しない。
var _enabled := true


func _ready() -> void:
	_load_kana_map()
	process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_input(event: InputEvent) -> void:
	if not _enabled:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey
		if key_event.keycode == FIXED_RELEASE_KEY or key_event.keycode == DEFAULT_CANCEL_KEY:
			clear_focus()
			get_viewport().set_input_as_handled()
			return

		var text := key_event.as_text_key_label().to_lower()
		if key_event.keycode == KEY_MINUS or key_event.physical_keycode == KEY_MINUS:
			text = "-"
		if text.length() != 1:
			return
		if not _is_supported_input(text):
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

	var state: Dictionary = _build_state(payload)
	_targets.append(unit)
	_states[unit] = state

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

	var previous: Node = _focused_unit
	var state: Dictionary = _states.get(previous, {})
	if not state.is_empty():
		_reset_progress(state)
		_states[previous] = state

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
		_apply_input_to_target(matched_unit, text)
		return

	_apply_input_to_target(_focused_unit, text)


## 表示用Dictionaryを返す。current_inputは入力済み文字、display_romajiは残り候補込み。未登録なら空で、候補配列はdeep copyしない。
func get_state_for(unit: Node) -> Dictionary:
	if not _states.has(unit):
		return {}

	var state: Dictionary = _states[unit]
	return {
		"kanji": state.get("kanji", ""),
		"kana": state.get("kana", ""),
		"current_input": state.get("typed_romaji", ""),
		"display_romaji": _build_display_string(state),
		"all_candidates": state.get("all_candidates", []),
		"active_candidates": state.get("active_segment_candidates", []),
		"is_focused": unit == _focused_unit
	}


## 現在focus中のNodeを返す。対象がなければnull。
func get_focused_unit() -> Node:
	return _focused_unit


func _build_state(payload: Dictionary) -> Dictionary:
	var kana: String = String(payload.get("kana", ""))
	var kanji: String = String(payload.get("kanji", kana))
	var segments: Array[Dictionary] = _build_kana_segments(kana)
	var state: Dictionary = {
		"kanji": kanji,
		"kana": kana,
		"segments": segments,
		"segment_index": 0,
		"segment_input": "",
		"typed_romaji": "",
		"all_candidates": _flatten_segment_patterns(segments),
		"active_segment_candidates": []
	}
	_reset_progress(state)
	return state


func _apply_input_to_target(unit: Node, text: String) -> void:
	if not _states.has(unit):
		no_target_hit.emit()
		return

	var state: Dictionary = _states[unit]
	var segment_candidates: Array[String] = state.get("active_segment_candidates", [])
	if segment_candidates.is_empty():
		mistype.emit(unit)
		return

	var next_segment_input: String = String(state.get("segment_input", "")) + text
	var valid_candidates: Array[String] = []
	for candidate in segment_candidates:
		var candidate_text: String = String(candidate)
		if candidate_text.begins_with(next_segment_input):
			valid_candidates.append(candidate_text)

	if valid_candidates.is_empty():
		mistype.emit(unit)
		return

	state["segment_input"] = next_segment_input
	state["typed_romaji"] = String(state.get("typed_romaji", "")) + text
	state["active_segment_candidates"] = valid_candidates

	var segment_completed := false
	for candidate in valid_candidates:
		if String(candidate) == next_segment_input:
			segment_completed = true
			break

	if segment_completed:
		_advance_segment(state)

	_states[unit] = state
	char_typed.emit(unit)

	if int(state.get("segment_index", 0)) >= _get_segments(state).size():
		unregister_target(unit)
		word_completed.emit(unit)


func _find_matching_target(text: String) -> Node:
	for unit in _targets:
		var state: Dictionary = _states.get(unit, {})
		for candidate in state.get("active_segment_candidates", []):
			if String(candidate).begins_with(text):
				return unit
	return null


func _focus_target(unit: Node) -> void:
	_focused_unit = unit
	var state: Dictionary = _states[unit]
	_reset_progress(state)
	_states[unit] = state
	focus_changed.emit(unit)


func _reset_progress(state: Dictionary) -> void:
	state["segment_index"] = 0
	state["segment_input"] = ""
	state["typed_romaji"] = ""
	state["active_segment_candidates"] = _get_segment_patterns(state, 0, "")


func _advance_segment(state: Dictionary) -> void:
	var next_index: int = int(state.get("segment_index", 0)) + 1
	state["segment_index"] = next_index
	state["segment_input"] = ""
	state["active_segment_candidates"] = _get_segment_patterns(state, next_index, "")


func _build_display_string(state: Dictionary) -> String:
	var segments: Array[Dictionary] = _get_segments(state)
	var segment_index: int = int(state.get("segment_index", 0))
	var typed_romaji: String = String(state.get("typed_romaji", ""))

	if segment_index >= segments.size():
		return typed_romaji

	var display := typed_romaji
	var segment_input: String = String(state.get("segment_input", ""))
	var active_segment_candidates: Array[String] = state.get("active_segment_candidates", [])
	if not active_segment_candidates.is_empty():
		var current_candidate: String = String(active_segment_candidates[0])
		display += current_candidate.substr(segment_input.length())

	for i in range(segment_index + 1, segments.size()):
		var patterns: Array[String] = segments[i].get("patterns", [])
		if patterns.is_empty():
			continue
		display += String(patterns[0])

	return display


func _build_kana_segments(kana: String) -> Array[Dictionary]:
	var segments: Array[Dictionary] = []
	var index := 0
	while index < kana.length():
		var token := kana.substr(index, 1)
		var patterns: Array[String] = []
		if index + 1 < kana.length():
			var two_char := kana.substr(index, 2)
			if _kana_map.has(two_char):
				token = two_char
				patterns = _build_compound_patterns(kana.substr(index, 1), kana.substr(index + 1, 1), two_char)
				index += 2
			else:
				index += 1
		else:
			index += 1

		if token == "っ":
			patterns = []
		elif patterns.is_empty():
			patterns = _strings_from_variant(_kana_map.get(token, [token]))
		segments.append({
			"kana": token,
			"patterns": patterns
		})

	for i in range(segments.size()):
		if String(segments[i].get("kana", "")) == "っ":
			segments[i]["patterns"] = _build_small_tsu_patterns(segments, i)
		elif String(segments[i].get("kana", "")) == "ん":
			segments[i]["patterns"] = _build_n_patterns(segments, i)

	for i in range(segments.size() - 1):
		if String(segments[i].get("kana", "")) != "ん":
			continue
		var current_patterns: Array[String] = segments[i].get("patterns", [])
		if not current_patterns.has("n"):
			continue
		segments[i + 1]["patterns"] = _extend_patterns_with_leading_n(segments[i + 1].get("patterns", []))

	return segments


func _build_compound_patterns(base_kana: String, small_kana: String, combined_kana: String) -> Array[String]:
	var patterns: Array[String] = []

	for combined in _strings_from_variant(_kana_map.get(combined_kana, [combined_kana])):
		patterns.append(combined)

	var base_patterns: Array[String] = _strings_from_variant(_kana_map.get(base_kana, [base_kana]))
	var small_patterns: Array[String] = _strings_from_variant(_kana_map.get(small_kana, [small_kana]))
	for base_pattern in base_patterns:
		for small_pattern in small_patterns:
			patterns.append(base_pattern + small_pattern)

	return _dedupe_candidates(patterns)


func _build_small_tsu_patterns(segments: Array[Dictionary], index: int) -> Array[String]:
	var patterns: Array[String] = []
	for direct_pattern in SMALL_TSU_DIRECT:
		patterns.append(String(direct_pattern))

	if index + 1 < segments.size():
		var next_patterns: Array[String] = segments[index + 1].get("patterns", [])
		for next_pattern in next_patterns:
			var next_text: String = String(next_pattern)
			if next_text.is_empty():
				continue
			var head: String = next_text.substr(0, 1)
			if _is_consonant(head):
				patterns.append(head)

	return _dedupe_candidates(patterns)


func _build_n_patterns(segments: Array[Dictionary], index: int) -> Array[String]:
	if index + 1 >= segments.size():
		return ["n"]

	var patterns: Array[String] = ["nn", "xn"]

	var next_patterns: Array[String] = segments[index + 1].get("patterns", [])
	var requires_double_n := false
	for next_pattern in next_patterns:
		var next_text: String = String(next_pattern)
		if next_text.is_empty():
			continue
		var head: String = next_text.substr(0, 1)
		if head in ["a", "i", "u", "e", "o", "y", "n"]:
			requires_double_n = true
			break

	if not requires_double_n:
		patterns.append("n")
	return _dedupe_candidates(patterns)


func _extend_patterns_with_leading_n(patterns: Array[String]) -> Array[String]:
	var extended: Array[String] = []
	for pattern in patterns:
		var text := String(pattern)
		if text.is_empty():
			continue
		extended.append("n" + text)
	for pattern in patterns:
		extended.append(String(pattern))
	return _dedupe_candidates(extended)


func _flatten_segment_patterns(segments: Array[Dictionary]) -> Array[String]:
	var candidates: Array[String] = []
	for segment in segments:
		for pattern in segment.get("patterns", []):
			var pattern_text: String = String(pattern)
			if not candidates.has(pattern_text):
				candidates.append(pattern_text)
	return candidates


func _get_segment_patterns(state: Dictionary, index: int, fallback: String) -> Array[String]:
	var segments: Array[Dictionary] = _get_segments(state)
	if index >= segments.size():
		return []

	var patterns: Array[String] = segments[index].get("patterns", [])
	if patterns.is_empty() and not fallback.is_empty():
		return [fallback]
	return patterns.duplicate()


func _get_segments(state: Dictionary) -> Array[Dictionary]:
	return state.get("segments", [])


func _load_kana_map() -> void:
	var file: FileAccess = FileAccess.open(KANA_ROMAJI_PATH, FileAccess.READ)
	if file == null:
		push_warning("kana_romaji.json could not be loaded.")
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		_kana_map = parsed as Dictionary


func _strings_from_variant(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for entry in value:
			result.append(String(entry).to_lower())
	elif value != null:
		result.append(String(value).to_lower())
	return result


func _dedupe_candidates(candidates: Array[String]) -> Array[String]:
	var unique: Array[String] = []
	var seen: Dictionary = {}
	for candidate in candidates:
		if seen.has(candidate):
			continue
		seen[candidate] = true
		unique.append(candidate)
	return unique


func _is_supported_input(text: String) -> bool:
	if text == "-":
		return true
	return text.unicode_at(0) >= 97 and text.unicode_at(0) <= 122


func _is_consonant(character: String) -> bool:
	return character in ["b", "c", "d", "f", "g", "h", "j", "k", "l", "m", "p", "q", "r", "s", "t", "v", "w", "x", "y", "z"]


func _on_target_tree_exiting(unit: Node) -> void:
	unregister_target(unit)
