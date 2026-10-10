extends SceneTree
## Writes every song and every sound effect as a .wav file, so they can be played on a computer (docs/AUDIO_PLAN.md).
## Usage: godot --headless --path . --script tools/export_audio.gd -- <output folder>
## The files are made by the same code as in the app (`scripts/audio/`). Songs are one loop; effects are as played.

const Synth = preload("res://scripts/audio/synth.gd")
const Songs = preload("res://scripts/audio/songs.gd")


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		print("Usage: godot --headless --path . --script tools/export_audio.gd -- <output folder>")
		quit(1)
		return
	var dir := String(args[0])
	DirAccess.make_dir_recursive_absolute(dir)
	for id in Songs.SONGS:
		_write(dir.path_join("song_%s.wav" % id), Synth.to_pcm16(Synth.mix(Songs.events(id), Songs.length(id))))
	var fx := Songs.effects()
	for id in fx:
		_write(dir.path_join("fx_%s.wav" % id), Synth.to_pcm16(Synth.mix(fx[id], Songs.effect_length(fx[id]) + 0.02)))
	print("%d songs and %d effects written to %s" % [Songs.SONGS.size(), fx.size(), dir])
	quit()


## A mono 16-bit .wav file at the synth rate.
func _write(path: String, pcm: PackedByteArray) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer("RIFF".to_ascii_buffer())
	f.store_32(36 + pcm.size())
	f.store_buffer("WAVEfmt ".to_ascii_buffer())
	f.store_32(16)
	f.store_16(1)                   # PCM
	f.store_16(1)                   # mono
	f.store_32(Synth.RATE)
	f.store_32(Synth.RATE * 2)
	f.store_16(2)
	f.store_16(16)
	f.store_buffer("data".to_ascii_buffer())
	f.store_32(pcm.size())
	f.store_buffer(pcm)
