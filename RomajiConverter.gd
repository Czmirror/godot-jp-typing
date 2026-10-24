extends RefCounted
## かな文字列を、入力単位（かな区切り）ごとのローマ字候補へ変換する。状態を持たず、Autoloadなしで試験できる。
## 候補表はkana_romaji.jsonの形（かな → ローマ字の配列）で受け取る。「っ」「ん」は前後のかなで候補が変わるため、表ではなくここで決める。

## 「っ」単体の入力。kana_romaji.jsonの「っ」は使わず、ここを正本とする。
const SMALL_TSU_DIRECT: Array[String] = ["xtsu", "xtu", "ltsu", "ltu"]
## 「ん」の直後がこの文字で始まるとき、nだけでは次のかなと区別できないためnn/xnを求める（kinen→きねん にならないように）。
const N_AMBIGUOUS_HEADS: Array[String] = ["a", "i", "u", "e", "o", "y", "n"]
const CONSONANTS: Array[String] = ["b", "c", "d", "f", "g", "h", "j", "k", "l", "m", "p", "q", "r", "s", "t", "v", "w", "x", "y", "z"]

var _kana_map: Dictionary = {}


func _init(kana_map: Dictionary) -> void:
	_kana_map = kana_map


## kana_romaji.jsonを読む。読めない・形が違う場合は警告して空の表を返す。
static func load_kana_map(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("kana_romaji.json could not be loaded: %s" % path)
		return {}

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("kana_romaji.json is not a JSON object: %s" % path)
		return {}
	return parsed as Dictionary


## かなを入力単位に区切り、{"kana": String, "patterns": Array[String]} の配列を返す。
## 表にない文字は、その文字自体を候補にして警告する（実キーでは入力できない）。
func build_segments(kana: String) -> Array[Dictionary]:
	var segments: Array[Dictionary] = _split_into_segments(kana)
	_apply_small_tsu_and_n_patterns(segments)
	_allow_extra_n_after_n(segments)
	return segments


## 2文字で表にあるもの（拗音など）を優先して区切る。「っ」の候補は次のかなが決まってから作るため空にしておく。
func _split_into_segments(kana: String) -> Array[Dictionary]:
	var segments: Array[Dictionary] = []
	var index := 0
	while index < kana.length():
		var two_chars := kana.substr(index, 2)
		if two_chars.length() == 2 and _kana_map.has(two_chars):
			segments.append(_segment(two_chars, _build_compound_patterns(two_chars)))
			index += 2
			continue

		var token := kana.substr(index, 1)
		index += 1
		if token == "っ":
			segments.append(_segment(token, []))
			continue
		if not _kana_map.has(token):
			push_warning("kana_romaji.jsonにない文字のため入力できません: %s（%s）" % [token, kana])
		segments.append(_segment(token, _patterns_for(token)))
	return segments


func _apply_small_tsu_and_n_patterns(segments: Array[Dictionary]) -> void:
	for i in range(segments.size()):
		var token: String = segments[i]["kana"]
		if token == "っ":
			segments[i]["patterns"] = _build_small_tsu_patterns(segments, i)
		elif token == "ん":
			segments[i]["patterns"] = _build_n_patterns(segments, i)


## 「ん」をnだけで打てる位置では、続けてもう1つnを打つ入力（kannji）も次のかなの候補として受け付ける。
func _allow_extra_n_after_n(segments: Array[Dictionary]) -> void:
	for i in range(segments.size() - 1):
		if segments[i]["kana"] != "ん":
			continue
		var n_patterns: Array[String] = segments[i]["patterns"]
		if not n_patterns.has("n"):
			continue
		segments[i + 1]["patterns"] = _extend_patterns_with_leading_n(segments[i + 1]["patterns"])


## 拗音などの合成表記に加えて、基底かな＋小書きかなの分解表記（shixya）も候補にする。
func _build_compound_patterns(two_chars: String) -> Array[String]:
	var patterns: Array[String] = _patterns_for(two_chars)
	for base_pattern in _patterns_for(two_chars.substr(0, 1)):
		for small_pattern in _patterns_for(two_chars.substr(1, 1)):
			patterns.append(base_pattern + small_pattern)
	return _dedupe(patterns)


func _build_small_tsu_patterns(segments: Array[Dictionary], index: int) -> Array[String]:
	var patterns: Array[String] = SMALL_TSU_DIRECT.duplicate()

	# 次のかなの子音を重ねて打つ入力（katta）も受け付ける。
	if index + 1 < segments.size():
		var next_patterns: Array[String] = segments[index + 1]["patterns"]
		for next_pattern in next_patterns:
			if next_pattern.is_empty():
				continue
			var head: String = next_pattern.substr(0, 1)
			if CONSONANTS.has(head):
				patterns.append(head)

	return _dedupe(patterns)


func _build_n_patterns(segments: Array[Dictionary], index: int) -> Array[String]:
	if index + 1 >= segments.size():
		return ["n"]

	var patterns: Array[String] = ["nn", "xn"]
	var next_patterns: Array[String] = segments[index + 1]["patterns"]
	var requires_double_n := false
	for next_pattern in next_patterns:
		if next_pattern.is_empty():
			continue
		if N_AMBIGUOUS_HEADS.has(next_pattern.substr(0, 1)):
			requires_double_n = true
			break

	if not requires_double_n:
		patterns.append("n")
	return _dedupe(patterns)


## 元の候補を先に置く。表示は先頭候補を使うため、nを足した候補が先だと「せんせい」が sennnsei と表示される。
func _extend_patterns_with_leading_n(patterns: Array[String]) -> Array[String]:
	var extended: Array[String] = patterns.duplicate()
	for pattern in patterns:
		if pattern.is_empty():
			continue
		extended.append("n" + pattern)
	return _dedupe(extended)


func _patterns_for(token: String) -> Array[String]:
	var value: Variant = _kana_map.get(token, [token])
	var result: Array[String] = []
	if value is Array:
		for entry in value:
			result.append(String(entry).to_lower())
	elif value != null:
		result.append(String(value).to_lower())
	return result


func _segment(token: String, patterns: Array[String]) -> Dictionary:
	return {"kana": token, "patterns": patterns}


func _dedupe(candidates: Array[String]) -> Array[String]:
	var unique: Array[String] = []
	for candidate in candidates:
		if not unique.has(candidate):
			unique.append(candidate)
	return unique
