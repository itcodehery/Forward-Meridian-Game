extends Node

# UI elements can listen to this to know when to show a notification
signal log_unlocked(log: GameLog)

# Stores the actual resource files of logs we have found
var unlocked_logs: Array[GameLog] = []

func unlock(new_log: GameLog):
	# Make sure we haven't already unlocked it
	if not unlocked_logs.has(new_log):
		unlocked_logs.append(new_log)
		log_unlocked.emit(new_log)
		print("Log Unlocked: ", new_log.title)
