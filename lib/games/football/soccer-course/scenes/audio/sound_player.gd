extends Node

enum Sound {BOUNCE, HURT, PASS, POWERSHOT, SHOT, TACKLING, UI_NAV, UI_SELECT, WHISTLE}

const NB_CHANNELS := 4
const SFX_MAP: Dictionary[Sound, AudioStream] = {
	Sound.BOUNCE: preload("res://assets/sfx/bounce.wav"),
	Sound.HURT: preload("res://assets/sfx/hurt.wav"),
	Sound.PASS: preload("res://assets/sfx/pass.wav"),
	Sound.POWERSHOT: preload("res://assets/sfx/power-shot.wav"),
	Sound.SHOT: preload("res://assets/sfx/shoot.wav"),
	Sound.TACKLING: preload("res://assets/sfx/tackle.wav"),
	Sound.UI_NAV: preload("res://assets/sfx/ui-navigate.wav"),
	Sound.UI_SELECT: preload("res://assets/sfx/ui-select.wav"),
	Sound.WHISTLE: preload("res://assets/sfx/whistle.wav"),
}

var stream_players : Array[AudioStreamPlayer] = []

func _ready() -> void:
	for i in range(NB_CHANNELS):
		var stream_player := AudioStreamPlayer.new()
		# Settings (an earlier autoload) already created the "SFX" bus by the
		# time this runs; routed here rather than left on Master so
		# Settings.set_sfx_volume()/set_sfx_enabled() can control these
		# independently of music/master.
		stream_player.bus = "SFX"
		stream_players.append(stream_player)
		add_child(stream_player)

const PITCH_VARIATION_MIN := 0.95
const PITCH_VARIATION_MAX := 1.05

func play(sound: Sound) -> void:
	var stream_player := find_first_available_player()
	if stream_player != null:
		stream_player.stream = SFX_MAP[sound]
		# Phase 6: subtle randomized pitch per-play so repeated sounds (many
		# kicks/passes/tackles per match) don't all sound identical.
		stream_player.pitch_scale = randf_range(PITCH_VARIATION_MIN, PITCH_VARIATION_MAX)
		stream_player.play()

func find_first_available_player() -> AudioStreamPlayer:
	for stream_player in stream_players:
		if not stream_player.playing:
			return stream_player
	return null
