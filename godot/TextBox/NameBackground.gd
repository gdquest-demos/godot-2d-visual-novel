extends TextureRect

const COLOR_WHITE_TRANSPARENT := Color(1.0, 1.0, 1.0, 0.0)

export var appear_duration := 0.3

onready var _tween: Tween = $Tween


func _ready() -> void:
	modulate = COLOR_WHITE_TRANSPARENT


func appear() -> void:
	_tween.interpolate_property(
		self, "modulate", COLOR_WHITE_TRANSPARENT, Color.white, appear_duration
	)
	_tween.start()
	_tween.seek(0)


func disappear() -> void:
	_tween.interpolate_property(
		self, "modulate", Color.white, COLOR_WHITE_TRANSPARENT, appear_duration / 2.0
	)
	_tween.start()
	_tween.seek(0)
