# typing_core

日本語（かな）をローマ字でタイプするゲーム向けの入力部品です。[TypeGunner](https://github.com/Czmirror/TypeGunner) の `addons/typing_core` から切り出しました（切り出し元commit: `298e873`）。
Godot 4.6系・typed GDScriptで書き、`class_name` と `preload` は使いません。

## 依存

- 依存方向は「ゲーム → typing_core」だけです。このaddonはゲーム固有のAutoload・scene・dataを参照しません。
- 外部依存はありません。

## 導入

このリポジトリのrootが、そのまま `res://addons/typing_core/` の中身になります。

1. ゲームのリポジトリでsubmoduleとして追加する。

   ```sh
   git submodule add https://github.com/Czmirror/godot-jp-typing.git addons/typing_core
   ```

2. `project.godot` の `[autoload]` に `TypingEngine="*res://addons/typing_core/TypingEngine.gd"` を登録する。
3. 更新はsubmodule内でfetchし、確認したcommitをcheckoutしてから、ゲーム側でsubmoduleの参照をcommitする。

## 含まれるもの

| file | 役割 |
| --- | --- |
| `TypingEngine.gd` | Autoload。標的の登録、入力判定とfocus |
| `RomajiConverter.gd` | かなを入力単位に区切り、ローマ字候補を作る。状態を持たない |
| `kana_romaji.json` | かな→ローマ字の変換表。`TypingEngine` がready時に読み、`RomajiConverter` に渡す |
| `TypingDisplay.tscn` / `.gd` | 標的1つ分のかな・入力済み文字・次の文字を表示する部品 |
| `KeyboardDisplay.gd` | JIS/US配列のキーボードと担当指・次のキーを描く練習用部品 |
| `keyboard_layouts.json` | `KeyboardDisplay` のキー配列（キーごとのid・表示文字・幅）と担当指。`width` と `label` は省略でき、省略時は幅52・表示はid |
| `WordPicker.gd` | 語彙から出題語を選ぶstatic関数。同時に出す標的の先頭文字の重複を避ける |
| `tests/run_tests.sh` | このaddon単体で回帰試験を実行する。`GODOT=/path/to/godot sh tests/run_tests.sh`。一時フォルダに最小のプロジェクトを作るので、ゲームへの取り込みは不要 |
| `tests/run_romaji_converter_tests.gd` | `RomajiConverter` の境界ケース（「っ」「ん」の前後など）の試験。Autoloadは不要 |
| `tests/run_typing_core_tests.gd` | `TypingEngine` とWordPicker・KeyboardDisplayの回帰試験。取り込んだゲームのrootで `godot --headless --path . --script res://addons/typing_core/tests/run_typing_core_tests.gd` でも実行できる（`TypingEngine` のAutoload登録が必要） |

## 契約

### TypingEngine

- `register_target(unit: Node, payload: Dictionary)`: `payload` は `kana` が必須、`kanji` は任意（表示用）。同じNodeの再登録は進捗を捨てる。Nodeの `tree_exiting` で自動的に解除する。ツリーに入れていないNodeは `tree_exiting` が来ないため、自分で `unregister_target` する。
- `kana_romaji.json` にない文字（カタカナなど）を含む `kana` は入力できない。登録時に警告を出す。
- `unregister_target(unit)`、`clear_focus()`、`set_enabled(value: bool)`、`get_focused_unit()`
- `get_state_for(unit) -> Dictionary`: `kanji`・`kana`・`current_input`・`display_romaji`・`all_candidates`・`active_candidates`・`is_focused`。未登録なら空。
- `handle_text_input(text)`: 小文字1文字を渡す直接入力。実キーの受け付けは `_unhandled_input` が行い、Tab・Escでfocusを解除する。
- signal: `word_completed(unit)`、`char_typed(unit)`、`mistype(unit)`、`no_target_hit`、`focus_changed(unit)`
- 単語を打ち終えたときは `char_typed` → `focus_changed(null)` → `word_completed` の順に通知する。`word_completed` の時点で登録は解除済みのため、`get_state_for` は空を返す。
- focusの規則: 何もfocusしていないとき、最初の1文字が合う標的のうち先に登録したものをfocusする。ダメージ・スコアは呼び出し側が処理する。

### WordPicker

`load("res://addons/typing_core/WordPicker.gd")` で読み、static関数を呼びます。

- `pick(words, rng, fallback, excluded_initials = [], previous_word_id = "", romaji_length_min = 1, romaji_length_max = 99) -> Dictionary`
  - `words` は `id`・`kanji`・`kana`・`romaji`（配列）を持つDictionaryの配列。
  - 前回の語・除外する先頭文字・最長ローマ字の長さで絞り、空なら先頭文字の条件だけを外し、それでも空なら全語から選ぶ。語彙が空なら `fallback` を返す。
  - `rng.randi_range` を1回だけ使う。返り値は `id`・`kanji`・`kana`・`romaji` だけを持つ。
- `get_initials(word) -> Array[String]`: ローマ字候補の先頭文字（小文字・重複なし）。
- `get_max_romaji_length(word) -> int`

### TypingDisplay

- `target_path` か `set_target_unit(unit)` で表示対象を渡す。`refresh_display()` で再描画する。
- 子nodeに `%KanaLabel`・`%RomajiLabel`・`%FocusPanel` を持つ前提です（`TypingDisplay.tscn`）。

### KeyboardDisplay

- `set_layout_id(layout_id)`（`"jis"` / `"us"`）、`set_highlight_keys(keys)`、`set_expected_key(key_id)`、`flash_key(key_id)`、`clear_flash()`

## ライセンス

未定です。当面は非公開で、公開する場合にライセンスを決めます。
