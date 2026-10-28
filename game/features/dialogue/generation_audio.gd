extends Node
class_name GenerationAudio
## Small generated UI tone; no external sample or downloaded asset is required.

var _player: AudioStreamPlayer
var _stream: AudioStreamWAV
var _volume: float = 0.65
var _muted: bool = false


func _ready() -> void:
	_stream = _build_tone()
	_player = AudioStreamPlayer.new()
	_player.name = "GenerationBlipPlayer"
	_player.stream = _stream
	add_child(_player)


func play_blip() -> void:
	if _player != null and not _muted:
		_player.volume_linear = _volume
		_player.play()


func stop() -> void:
	if _player != null:
		_player.stop()


func set_volume(value: float) -> void:
	_volume = clampf(value, 0.0, 1.0)
	if _player != null:
		_player.volume_linear = _volume


func set_muted(value: bool) -> void:
	_muted = value
	if _muted:
		stop()


func is_muted() -> bool:
	return _muted


func get_volume() -> float:
	return _volume


func _build_tone() -> AudioStreamWAV:
	const RATE: int = 22050
	const FRAMES: int = 2205
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(FRAMES * 2)
	for frame: int in range(FRAMES):
		var progress: float = float(frame) / float(FRAMES)
		var envelope: float = minf(progress * 18.0, 1.0) * pow(1.0 - progress, 2.2)
		var sample: int = int(sin(TAU * (520.0 + progress * 340.0) * float(frame) / float(RATE)) * envelope * 4800.0)
		bytes.encode_s16(frame * 2, sample)
	var tone: AudioStreamWAV = AudioStreamWAV.new()
	tone.format = AudioStreamWAV.FORMAT_16_BITS
	tone.mix_rate = RATE
	tone.stereo = false
	tone.data = bytes
	return tone
