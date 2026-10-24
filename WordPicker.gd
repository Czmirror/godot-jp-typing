extends RefCounted
## 語彙配列から出題語を1つ選ぶstatic関数群。同時に表示する対象どうしで先頭文字が被らないようにする。
## TypingEngineは最初の1文字で先に登録された対象をfocusするため、先頭文字の重複を避けないと後の対象を選べない。
## 語彙・乱数・空のときの代替語は呼び出し側が渡し、このscriptはゲームの状態を持たない。

## 長さ指定がない場合に全語を通す上限。
const ROMAJI_LENGTH_MAX_DEFAULT := 99


## 前回の語・除外する先頭文字・ローマ字の長さで絞って1語を選ぶ。
## 絞り込みで空なら先頭文字の条件を外し、それでも空なら全語から選ぶ。語彙が空ならfallbackを返す。
## 乱数はrandi_rangeを1回だけ使う。
static func pick(
	words: Array[Dictionary],
	rng: RandomNumberGenerator,
	fallback: Dictionary,
	excluded_initials: Array[String] = [],
	previous_word_id: String = "",
	romaji_length_min: int = 1,
	romaji_length_max: int = ROMAJI_LENGTH_MAX_DEFAULT
) -> Dictionary:
	if words.is_empty():
		return fallback

	var candidates: Array[Dictionary] = []
	for word in words:
		if not _is_selectable(word, previous_word_id, romaji_length_min, romaji_length_max):
			continue
		if not _has_excluded_initial(word, excluded_initials):
			candidates.append(word)
	if candidates.is_empty():
		for word in words:
			if _is_selectable(word, previous_word_id, romaji_length_min, romaji_length_max):
				candidates.append(word)
	if candidates.is_empty():
		candidates = words

	var picked: Dictionary = candidates[rng.randi_range(0, candidates.size() - 1)]
	return {
		"id": picked.get("id", ""),
		"kanji": picked.get("kanji", ""),
		"kana": picked.get("kana", ""),
		"romaji": picked.get("romaji", [])
	}


## ローマ字候補ごとの先頭文字を、重複なく小文字で返す。
static func get_initials(word: Dictionary) -> Array[String]:
	var initials: Array[String] = []
	var romaji_value: Variant = word.get("romaji", [])
	if not (romaji_value is Array):
		return initials
	for option in romaji_value:
		var option_text := String(option).to_lower()
		if option_text.is_empty():
			continue
		var initial := option_text.substr(0, 1)
		if not initials.has(initial):
			initials.append(initial)
	return initials


## ローマ字候補のうち最長の文字数を返す。候補がなければ0。
static func get_max_romaji_length(word: Dictionary) -> int:
	var longest := 0
	var romaji_value: Variant = word.get("romaji", [])
	if romaji_value is Array:
		for option in romaji_value:
			longest = maxi(longest, String(option).length())
	return longest


## 前回の語ではなく、最長ローマ字の長さが範囲内なら出題できる。
static func _is_selectable(word: Dictionary, previous_word_id: String, romaji_length_min: int, romaji_length_max: int) -> bool:
	if String(word.get("id", "")) == previous_word_id:
		return false
	var max_romaji_length := get_max_romaji_length(word)
	return max_romaji_length >= romaji_length_min and max_romaji_length <= romaji_length_max


static func _has_excluded_initial(word: Dictionary, excluded_initials: Array[String]) -> bool:
	for initial in get_initials(word):
		if excluded_initials.has(initial):
			return true
	return false
