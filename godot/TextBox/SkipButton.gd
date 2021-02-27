extends Button

## Emitted when the DelayTimer times out.
signal timer_ticked

onready var _timer := $DelayTimer


func _ready() -> void:
	connect("button_down", self, "_on_button_down")
	connect("button_up", self, "_on_button_up")
	_timer.connect("timeout", self, "_on_DelayTimer_timeout")


func _on_button_down() -> void:
	_timer.start()


func _on_DelayTimer_timeout() -> void:
	emit_signal("timer_ticked")


func _on_button_up() -> void:
	_timer.stop()
