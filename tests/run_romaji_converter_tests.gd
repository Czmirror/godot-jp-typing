extends SceneTree
## RomajiConverterをAutoloadなしで直接呼び、かな区切りとローマ字候補の境界ケースを固定する試験。
## addonの置き場所に依存しないよう、このscriptの1つ上のフォルダからscriptと変換表を読む。

var _failures: int = 0
var _converter: RefCounted


func _initialize() -> void:
	var addon_dir: String = (get_script() as Script).resource_path.get_base_dir().get_base_dir()
	var converter_script: GDScript = load(addon_dir.path_join("RomajiConverter.gd")) as GDScript
	var kana_map: Dictionary = converter_script.call("load_kana_map", addon_dir.path_join("kana_romaji.json"))
	_converter = converter_script.new(kana_map)
	_test_segments()
	print("romaji converter: " + ("passed" if _failures == 0 else "FAILED"))
	quit(0 if _failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		print("FAIL: " + message)


## kanaを区切り、各区切りの候補配列を返す。
func _patterns_of(kana: String) -> Array:
	var result: Array = []
	var segments: Array[Dictionary] = _converter.call("build_segments", kana)
	for segment in segments:
		result.append(segment["patterns"])
	return result


func _test_segments() -> void:
	# RC1 拗音は2文字で1区切り。合成表記の後に分解表記が並ぶ
	var sha: Array = _patterns_of("しゃ")
	_check(sha.size() == 1 and sha[0][0] == "sha" and sha[0].has("shixya"), "拗音を1区切りにする")
	# RC2 末尾の「っ」は単独入力だけ
	var katsu: Array = _patterns_of("かっ")
	_check(katsu[1] == ["xtsu", "xtu", "ltsu", "ltu"], "末尾の「っ」は単独入力だけ")
	# RC3 「っ」の後がな行なら、nの重ね打ちは受け付けない（んな と区別する）
	_check(not (_patterns_of("はっな")[1] as Array).has("n"), "「っ」の後のな行でnを重ねない")
	# RC4 「っ」が続くときは、後ろの「っ」だけが次の子音を重ねられる
	var kappa: Array = _patterns_of("かっっぱ")
	_check(not (kappa[1] as Array).has("p") and (kappa[2] as Array).has("p"), "連続する「っ」は後ろだけ子音を重ねる")
	# RC5 「ん」の後が「っ」ならnだけで打て、次の区切りでnを重ねてもよい
	var antsu: Array = _patterns_of("あんっ")
	_check((antsu[1] as Array).has("n") and (antsu[2] as Array).has("nxtu"), "「んっ」はnでもnnでも打てる")
	# RC6 末尾の「ん」はnだけ
	_check(_patterns_of("みかん")[2] == ["n"], "末尾の「ん」はn")
	# RC7 変換表にない文字はその文字自体を候補にする（実キーでは打てない）
	_check(_patterns_of("カ") == [["カ"]], "変換表にない文字はその文字を候補にする")
