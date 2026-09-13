class_name MetroAdvert
extends Node2D
## Two real, looping Theora movies shared across four physical screens.

var campaign := 0
var seconds := -1.0
var player := VideoStreamPlayer.new()


func _ready() -> void:
	player.stream = load("res://assets/video/%s.ogv" % ("aer" if campaign == 0 else "rest"))
	player.expand = true
	player.size = Vector2(1920, 1080)
	player.loop = true
	player.volume_db = -80.0
	add_child(player)
	player.play()


func advance(value: float) -> bool:
	player.paused = is_equal_approx(value, seconds)
	if value < seconds:
		# Theora cannot seek: restarting is explicit when replaying the cutscene.
		player.stop()
		player.play()
	seconds = value
	return not player.paused
