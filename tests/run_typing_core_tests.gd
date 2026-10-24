extends SceneTree
## 実TypingEngineへ1文字ずつ入力し、ローマ字の分岐・focus・進捗の現行挙動を固定する回帰試験。
## WordPickerの出題語の絞り込みも検査する。addon化の前後で同じ結果になることを確かめるために使う。--scriptからheadless実行し、外部通信・保存は行わない。

var _failures: int = 0
var _engine: Node
var _completed: Array[Node] = []
var _mistyped: Array[Node] = []
var _no_target_hits: int = 0
var _word_picker: GDScript = load("res://addons/typing_core/WordPicker.gd") as GDScript

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_engine = root.get_node("TypingEngine")
	_engine.connect("word_completed", func(unit: Node) -> void: _completed.append(unit))
	_engine.connect("mistype", func(unit: Node) -> void: _mistyped.append(unit))
	_engine.connect("no_target_hit", func() -> void: _no_target_hits += 1)
	_test_romaji_variants()
	_test_focus_and_progress()
	_test_word_picker()
	_test_keyboard_display()
	print("typing core regression: " + ("passed" if _failures == 0 else "FAILED"))
	quit(0 if _failures == 0 else 1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		print("FAIL: " + message)

func _reset_signals() -> void:
	_completed.clear()
	_mistyped.clear()
	_no_target_hits = 0

## 1語だけを登録して入力し、ミスなく完了したかを返す。
func _types_cleanly(kana: String, romaji: String) -> bool:
	_reset_signals()
	var target: Node = Node.new()
	_engine.call("register_target", target, {"kana": kana})
	for character: String in romaji:
		_engine.call("handle_text_input", character)
	var completed: bool = _completed.size() == 1 and _completed[0] == target and _mistyped.is_empty() and _no_target_hits == 0
	_engine.call("unregister_target", target)
	target.free()
	return completed

func _expect_accepts(kana: String, romaji: String) -> void:
	_check(_types_cleanly(kana, romaji), "受理されるべき入力: " + kana + " / " + romaji)

func _expect_rejects(kana: String, romaji: String) -> void:
	_check(not _types_cleanly(kana, romaji), "拒否されるべき入力: " + kana + " / " + romaji)

func _test_romaji_variants() -> void:
	# UT1 拗音: 合成表記と、基底かな＋小書きかなの分解表記
	for romaji: String in ["sha", "sya", "shixya", "silya", "sixya"]:
		_expect_accepts("しゃ", romaji)
	# UT2 っ: 次の子音の重ね打ちと単独入力
	for romaji: String in ["katta", "kaxtuta", "kaltsuta"]:
		_expect_accepts("かった", romaji)
	for romaji: String in ["maccha", "mattya"]:
		_expect_accepts("まっちゃ", romaji)
	# UT3 ん: 末尾・子音前・母音/や行/な行前
	_expect_accepts("みかん", "mikan")
	for romaji: String in ["kanji", "kannji", "kaxnji"]:
		_expect_accepts("かんじ", romaji)
	_expect_accepts("きんえん", "kinnen")
	_expect_rejects("きんえん", "kinen")
	_expect_accepts("こんや", "konnya")
	_expect_rejects("こんや", "konya")
	_expect_accepts("こんな", "konnna")
	_expect_rejects("こんな", "konna")
	# UT4 長音記号
	_expect_accepts("すー", "su-")
	# UT5 訓令式・ヘボン式などの別表記
	for pair: Array in [["ち", "chi"], ["ち", "ti"], ["ふ", "fu"], ["ふ", "hu"], ["つ", "tsu"], ["つ", "tu"], ["じ", "zi"]]:
		_expect_accepts(String(pair[0]), String(pair[1]))
	# UT6 誤り
	_expect_rejects("か", "ki")

func _test_focus_and_progress() -> void:
	_reset_signals()
	var first: Node = Node.new()
	var second: Node = Node.new()
	var other: Node = Node.new()
	_engine.call("register_target", first, {"kana": "かき"})
	_engine.call("register_target", second, {"kana": "かく"})
	_engine.call("register_target", other, {"kana": "さく"})

	# UT7 同じ先頭候補なら先に登録した標的をfocusする
	_engine.call("handle_text_input", "k")
	_check(_engine.call("get_focused_unit") == first, "先に登録した標的をfocusする")

	# UT8 focus中の誤入力はmistypeで、進捗を保持する
	_engine.call("handle_text_input", "z")
	_check(_mistyped.size() == 1 and _mistyped[0] == first, "focus中の誤入力でmistypeを通知する")
	var state: Dictionary = _engine.call("get_state_for", first)
	_check(String(state.get("current_input", "")) == "k", "誤入力後も入力済み文字を保持する")

	# UT9 clear_focusで進捗を先頭へ戻し、登録は残す
	_engine.call("clear_focus")
	state = _engine.call("get_state_for", first)
	_check(_engine.call("get_focused_unit") == null, "clear_focusでfocusを解除する")
	_check(String(state.get("current_input", "")) == "", "clear_focusで入力進捗を戻す")
	_check(not state.is_empty(), "clear_focus後も登録は残す")

	# UT10 どの標的にも合わない入力はno_target_hit
	_engine.call("handle_text_input", "x")
	_check(_no_target_hits == 1, "合う標的がない入力でno_target_hitを通知する")

	# UT11 表示用ローマ字は入力に合わせて候補が切り替わる
	_engine.call("handle_text_input", "s")
	_check(_engine.call("get_focused_unit") == other, "先頭候補が合う標的だけをfocusする")
	state = _engine.call("get_state_for", other)
	_check(String(state.get("display_romaji", "")) == "saku", "先頭候補で表示用ローマ字を作る")

	# UT12 実キー入力の無効化でfocusを解除する
	_engine.call("set_enabled", false)
	_check(_engine.call("get_focused_unit") == null, "set_enabled(false)でfocusを解除する")
	_engine.call("set_enabled", true)

	# UT13 単語完了で登録を解除する
	_reset_signals()
	for character: String in "kaki":
		_engine.call("handle_text_input", character)
	_check(_completed.size() == 1 and _completed[0] == first, "単語完了でword_completedを通知する")
	_check((_engine.call("get_state_for", first) as Dictionary).is_empty(), "単語完了で登録を解除する")

	for unit: Node in [first, second, other]:
		_engine.call("unregister_target", unit)
		unit.free()

	# UT14 表示用ローマ字は入力した別表記に追従する
	var shortcut: Node = Node.new()
	_engine.call("register_target", shortcut, {"kana": "しゃ"})
	_engine.call("handle_text_input", "s")
	_engine.call("handle_text_input", "y")
	state = _engine.call("get_state_for", shortcut)
	_check(String(state.get("display_romaji", "")) == "sya", "別表記の入力に表示が追従する")
	_engine.call("unregister_target", shortcut)
	shortcut.free()

	# UT15 「ん」の後の表示は、nを重ねない綴りを使う
	for pair: Array in [["せんせい", "sennsei"], ["かんじ", "kannji"], ["あんっ", "annxtsu"]]:
		var word: Node = Node.new()
		_engine.call("register_target", word, {"kana": String(pair[0])})
		state = _engine.call("get_state_for", word)
		_check(String(state.get("display_romaji", "")) == String(pair[1]), "「ん」の後の表示: " + String(pair[0]))
		_engine.call("unregister_target", word)
		word.free()

func _word(id: String, romaji: Array[String]) -> Dictionary:
	return {"id": id, "kanji": id, "kana": id, "romaji": romaji}

## 同じseedの乱数で、候補を何度選んでも結果がexpected_idsの中に収まるかを返す。
func _picks_only(words: Array[Dictionary], expected_ids: Array[String], excluded: Array[String], previous_id: String, length_min: int, length_max: int) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var fallback: Dictionary = {"id": "fallback"}
	for _i in range(40):
		var picked: Dictionary = _word_picker.pick(words, rng, fallback, excluded, previous_id, length_min, length_max)
		if not expected_ids.has(String(picked.get("id", ""))):
			return false
	return true

func _test_word_picker() -> void:
	var words: Array[Dictionary] = [
		_word("ka", ["ka", "ca"]),
		_word("sa", ["sa"]),
		_word("ta", ["ta"]),
		_word("long", ["nagaikotoba"])
	]
	var none: Array[String] = []
	var excluded_kst: Array[String] = ["k", "s", "t"]
	var excluded_k: Array[String] = ["k"]
	# WP1 前回と同じ語を避ける
	_check(_picks_only(words, ["sa", "ta", "long"] as Array[String], none, "ka", 1, 99), "前回の語を除外する")
	# WP2 先頭文字が被る語を避ける。別表記の先頭文字（ca）も対象
	_check(_picks_only(words, ["sa", "ta", "long"] as Array[String], ["c"] as Array[String], "", 1, 99), "別表記の先頭文字も除外する")
	# WP3 ローマ字の長さで絞る
	_check(_picks_only(words, ["long"] as Array[String], none, "", 5, 99), "最長候補の長さで絞る")
	# WP4 先頭文字で全て外れたら先頭文字の条件だけ外す
	_check(_picks_only(words, ["ka", "sa", "ta"] as Array[String], excluded_kst, "", 1, 2), "先頭文字の条件だけを外して選ぶ")
	# WP5 長さ・前回条件でも空なら全語から選ぶ
	_check(_picks_only(words, ["ka", "sa", "ta", "long"] as Array[String], excluded_k, "", 50, 99), "条件に合う語がなければ全語から選ぶ")
	# WP6 語彙が空ならfallbackを返す
	var empty_words: Array[Dictionary] = []
	var fallback: Dictionary = {"id": "fallback", "kana": "まと"}
	var picked_fallback: Dictionary = _word_picker.pick(empty_words, RandomNumberGenerator.new(), fallback)
	_check(picked_fallback == fallback, "語彙が空ならfallbackを返す")
	# WP7 乱数は候補数に対して1回だけ使う
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var expected_rng := RandomNumberGenerator.new()
	expected_rng.seed = 11
	var candidates: Array[String] = ["sa", "ta", "long"]
	for _i in range(10):
		var picked: Dictionary = _word_picker.pick(words, rng, fallback, none, "ka")
		var expected_id: String = candidates[expected_rng.randi_range(0, candidates.size() - 1)]
		_check(String(picked.get("id", "")) == expected_id, "候補の並び順と乱数1回で選ぶ")
	# WP8 先頭文字は小文字・重複なし、返すpayloadは表示に必要なkeyだけ
	var initials: Array = _word_picker.get_initials({"romaji": ["Ka", "ca", "ka", ""]})
	_check(initials == ["k", "c"], "先頭文字を小文字・重複なしで返す")
	var payload: Dictionary = _word_picker.pick([words[1]] as Array[Dictionary], RandomNumberGenerator.new(), fallback)
	_check(payload.keys() == ["id", "kanji", "kana", "romaji"], "id・kanji・kana・romajiだけを返す")

func _test_keyboard_display() -> void:
	var keyboard: Control = (load("res://addons/typing_core/KeyboardDisplay.gd") as GDScript).new() as Control
	root.add_child(keyboard)
	var unassigned_color: Color = keyboard.call("_finger_color_for_key", "UNASSIGNED")
	# KD1 数字の1・0と=にも担当指の色が付く
	for key_id: String in ["1", "0", "="]:
		_check(keyboard.call("_finger_color_for_key", key_id) != unassigned_color, "担当指の色が付く: " + key_id)

	# KD2 キー配列をkeyboard_layouts.jsonから読み、JIS/USとも全キーを作る
	for layout: Array in [["jis", 49], ["us", 49]]:
		keyboard.call("set_layout_id", String(layout[0]))
		var styles: Dictionary = keyboard.get("_key_styles")
		_check(styles.size() == int(layout[1]), "キー数: %s = %d" % [layout[0], styles.size()])

	# KD3 色の更新でStyleBoxを作り直さない
	var styles_before: Dictionary = (keyboard.get("_key_styles") as Dictionary).duplicate()
	var label_f: Label = (keyboard.get("_key_labels") as Dictionary)["F"]
	var panel_f: PanelContainer = label_f.get_parent() as PanelContainer
	var stylebox_before: StyleBox = panel_f.get_theme_stylebox("panel")
	keyboard.call("set_highlight_keys", ["F", "J"] as Array[String])
	keyboard.call("set_expected_key", "f")
	keyboard.call("flash_key", "j")
	keyboard.call("_process", 0.1)
	_check(panel_f.get_theme_stylebox("panel") == stylebox_before, "次のキーの点滅でStyleBoxを使い回す")
	_check(keyboard.get("_key_styles") == styles_before, "色の更新でキーのStyleBoxが変わらない")
	keyboard.free()
