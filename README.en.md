# typing_core

[日本語](README.md)

Components for games where players type Japanese (kana) with romaji. Extracted from `addons/typing_core` in my game TypeGunner.
Written for Godot 4.6 in typed GDScript, without `class_name` or `preload`.

## Dependencies

- Dependencies go one way only: game → typing_core. This addon never references game-specific autoloads, scenes or data.
- No external dependencies.

## Installation

The repository root is the content of `res://addons/typing_core/`.

1. Add it to your game as a submodule.

   ```sh
   git submodule add https://github.com/Czmirror/godot-jp-typing.git addons/typing_core
   ```

2. Enable `typing_core` in Project Settings > Plugins (this registers the `TypingEngine` autoload), or add `TypingEngine="*res://addons/typing_core/TypingEngine.gd"` to `[autoload]` in `project.godot` yourself.
3. To update, fetch inside the submodule, check out the commit you verified, and commit the submodule reference in your game.

## Contents

| file | role |
| --- | --- |
| `TypingEngine.gd` | Autoload. Registers targets, judges input and manages focus |
| `RomajiConverter.gd` | Splits kana into input units and builds romaji candidates. Stateless |
| `kana_romaji.json` | Kana-to-romaji table. `TypingEngine` reads it on ready and passes it to `RomajiConverter` |
| `TypingDisplay.tscn` / `.gd` | Shows one target's kana, typed letters and the next letter |
| `KeyboardDisplay.gd` | Practice keyboard (JIS/US) showing finger colors and the next key |
| `keyboard_layouts.json` | Key rows (id, optional label, optional width; defaults are the id and 52) and finger groups for `KeyboardDisplay` |
| `WordPicker.gd` | Static functions that pick a word, avoiding first letters already used by other targets on screen |
| `plugin.cfg` / `plugin.gd` | When enabled as an editor plugin, registers `TypingEngine` as an autoload |
| `tests/run_tests.sh` | Runs all tests for the addon alone: `GODOT=/path/to/godot sh tests/run_tests.sh`. It builds a throwaway host project |

## API

### TypingEngine

- `register_target(unit: Node, payload: Dictionary)`: `payload` needs `kana`; `kanji` is optional (for display). Registering the same node again discards its progress. Targets are unregistered on `tree_exiting`; for nodes that never enter the tree, call `unregister_target` yourself.
- Katakana in `kana` is treated as hiragana. Characters missing from `kana_romaji.json` (such as kanji) cannot be typed, and registering them prints a warning.
- `unregister_target(unit)`, `clear_focus()`, `set_enabled(value: bool)`, `get_focused_unit()`
- `get_state_for(unit) -> Dictionary`: `kanji`, `kana`, `current_input`, `display_romaji`, `all_candidates`, `active_candidates`, `is_focused`. Empty when not registered.
- `handle_text_input(text)`: feeds one lowercase letter directly. Real key presses go through `_unhandled_input`; Tab and Esc clear focus.
- Signals: `word_completed(unit)`, `char_typed(unit)`, `mistype(unit)`, `no_target_hit`, `focus_changed(unit)`
- When a word is finished the order is `char_typed` → `focus_changed(null)` → `word_completed`. The target is already unregistered at `word_completed`, so `get_state_for` returns empty.
- Focus rule: with nothing focused, the first letter focuses the earliest registered target that accepts it. Damage and score are up to the caller.

### WordPicker

Load it with `load("res://addons/typing_core/WordPicker.gd")` and call its static functions.

- `pick(words, rng, fallback, excluded_initials = [], previous_word_id = "", romaji_length_min = 1, romaji_length_max = 99) -> Dictionary`
  - `words` is an array of dictionaries with `id`, `kanji`, `kana` and `romaji` (array).
  - Filters by previous word, excluded first letters and longest romaji length. If nothing is left it drops the first-letter condition, then falls back to all words. Returns `fallback` for an empty vocabulary.
  - Calls `rng.randi_range` exactly once. The result holds only `id`, `kanji`, `kana` and `romaji`.
- `get_initials(word) -> Array[String]`: first letters of the romaji candidates (lowercase, unique).
- `get_max_romaji_length(word) -> int`

### TypingDisplay

- Pass the target with `target_path` or `set_target_unit(unit)`. `refresh_display()` redraws.
- Expects the child nodes `%KanaLabel`, `%RomajiLabel` and `%FocusPanel` (see `TypingDisplay.tscn`). Colors are exported properties.

### KeyboardDisplay

- `set_layout_id(layout_id)` (`"jis"` / `"us"`), `set_highlight_keys(keys)`, `set_expected_key(key_id)`, `flash_key(key_id)`, `clear_flash()`

## License

[MIT License](LICENSE)
