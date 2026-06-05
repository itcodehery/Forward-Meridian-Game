extends Resource
class_name GameLog

@export var log_id: String = "unique_log_name"
@export var title: String = "Untitled Log"
@export var date: String = "REDACTED"
@export var author: String = "Unknown"
@export_multiline var content: String = ""
