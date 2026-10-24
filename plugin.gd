@tool
extends EditorPlugin
## Project Settings > Pluginsで有効にしたとき、TypingEngineをAutoloadとして登録・解除するだけのEditorPlugin。
## 手動でAutoloadを登録する場合は有効にしなくてよい。

const AUTOLOAD_NAME := "TypingEngine"


func _enable_plugin() -> void:
	var engine_path: String = get_script().resource_path.get_base_dir().path_join("TypingEngine.gd")
	add_autoload_singleton(AUTOLOAD_NAME, engine_path)


func _disable_plugin() -> void:
	remove_autoload_singleton(AUTOLOAD_NAME)
