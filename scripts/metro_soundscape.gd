class_name MetroSoundscape
extends Node
## Timeline-driven audio shares pause, mute and replay with the cinematic.

const VOICE_CUES: Array[String] = ["station_closed", "station_violation", "station_final"]
const ANNOUNCEMENT_TIMES := [7.4, 31.0, 55.0]
const BANG_TIMES := [20.3, 46.7, 74.1, 85.5]
var hum := AudioStreamPlayer.new()
var machinery := AudioStreamPlayer.new()
var bang := AudioStreamPlayer3D.new()
var voice := AudioStreamPlayer.new()
var voice_streams: Array[AudioStream] = []
var last_time := -1.0
var last_voice := -1
var last_bang := -1
var stopped := false


func build() -> void:
	assert(AudioServer.get_bus_index("NorthlinePA") == -1)
	AudioServer.add_bus()
	var bus := AudioServer.bus_count - 1
	AudioServer.set_bus_name(bus, "NorthlinePA")
	var highpass := AudioEffectHighPassFilter.new()
	highpass.cutoff_hz = 330
	AudioServer.add_bus_effect(bus, highpass)
	var lowpass := AudioEffectLowPassFilter.new()
	lowpass.cutoff_hz = 3500
	AudioServer.add_bus_effect(bus, lowpass)
	var room := AudioEffectReverb.new()
	room.room_size = 0.86
	room.damping = 0.6
	room.wet = 0.22
	AudioServer.add_bus_effect(bus, room)
	voice.bus = "NorthlinePA"
	for cue in VOICE_CUES:
		var stream := load("res://assets/audio/voice/" + cue + ".ogg") as AudioStream
		assert(stream != null)
		voice_streams.append(stream)
	var loop := load("res://assets/audio/electric_hum.wav").duplicate() as AudioStreamWAV
	assert(loop.get_length() > 6.9)
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop.loop_begin = 0
	loop.loop_end = int(loop.get_length() * loop.mix_rate)
	hum.stream = loop
	add_child(hum)
	hum.volume_db = -20.0
	hum.play()
	var metal_loop := load("res://assets/audio/metallic_ambience.wav").duplicate() as AudioStreamWAV
	metal_loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	metal_loop.loop_end = int(metal_loop.get_length() * metal_loop.mix_rate)
	machinery.stream = metal_loop
	add_child(machinery)
	machinery.volume_db = -17.0
	machinery.play()
	bang.stream = load("res://assets/audio/tunnel_bang.wav")
	bang.unit_size = 18.0
	bang.max_distance = 90.0
	add_child(bang)
	add_child(voice)


func tick(seconds: float, moving: bool, muted: bool) -> void:
	if stopped:
		return
	if seconds < last_time:
		voice.stop()
		bang.stop()
		last_voice = -1
		last_bang = -1
	last_time = seconds
	var cycle := int(seconds / 96.0)
	var phase := fposmod(seconds, 96.0)
	for index in ANNOUNCEMENT_TIMES.size():
		var key := cycle * 3 + index
		if phase >= ANNOUNCEMENT_TIMES[index] and key > last_voice:
			last_voice = key
			voice.stream = voice_streams[index]
			voice.play()
	for index in BANG_TIMES.size():
		var key := cycle * 4 + index
		if phase >= BANG_TIMES[index] and key > last_bang:
			last_bang = key
			bang.position = Vector3(2.5, 1.5, -26.0 if index % 2 == 0 else 28.0)
			bang.pitch_scale = [0.85, 1.1, 0.72, 0.94][index]
			bang.play()
	for player in [hum, machinery, bang, voice]:
		player.stream_paused = not moving
	hum.volume_db = -80.0 if muted else (-27.0 if voice.playing else -20.0)
	machinery.volume_db = -80.0 if muted else (-25.0 if voice.playing else -17.0)
	bang.volume_db = -80.0 if muted else -15.0
	voice.volume_db = -80.0 if muted else -4.0


func stop() -> void:
	stopped = true
	for player in [hum, machinery, bang, voice]:
		player.stop()
		player.stream = null


func _exit_tree() -> void:
	stop()
	var bus := AudioServer.get_bus_index("NorthlinePA")
	if bus >= 0:
		AudioServer.remove_bus(bus)
