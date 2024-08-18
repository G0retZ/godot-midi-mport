###### spent several days working on this and debugging. Inintially I tryed to use [GDScript Midi File Parser](https://github.com/brainfoolong/gdscript-midi-parser) but it turned out confusing and not very convenient to use. So I decided to improve it... And now we are here 🙃

<p align="center">
	<img src="https://github.com/G0retZ/godot-midi-mport/blob/main/icon/icon.svg?raw=true" width="256">
</p>

# Godot 4+ Importer for MIDI (.mid) files.

This addon allows you to import and parse MIDI files in your project as any other resource.
It handles almost all available MIDI files features and also has some encapsulated tools for easier use.

### Some features:

- Importing MIDI files of all currently available formats (0-2): Single track, polyphony multitrack and multi-sequence.
- Supports both SMPTE fps and PPQ timnig parsing and calculations.
- Has built-in tempo-map extraction for any Track.
- Has encapsulated SMPTE offset calculation in seconds.
- The MidiData class itself is thoroghly documented and helps to additionally understand the MIDI format behaviour.

## Installation:

1. Add to the `addons` folder like any other regular plugin.
2. Enable it in the project settings as usually.

## Usage:

Import MIDI file by drag-n-drop as you do with pictures and other resources.
Now you can use in a same way as any other resource: drag-n-drop to Nodes, `load`, `preload` etc.

## Simple example (just plays some sounds from the first track):

```gdscript
var midi_data: MidiData = load("res://samples/smoke-on-the-water.mid")

func _play():
	var inital_delay := midi_data.tracks[0].get_offset_in_seconds()
	match midi_data.header.format:
		MidiData.Header.Format.SINGLE_TRACK, MidiData.Header.Format.MULTI_SONG:
			var us_per_beat: int = 500_000
			for event in midi_data.tracks[0].events:
				inital_delay += midi_data.header.convert_to_seconds(us_per_beat, event.delta_time)
				var tempo := event as MidiData.Tempo
				var note_on := event as MidiData.NoteOn
				if tempo != null:
					us_per_beat = tempo.us_per_beat
				elif note_on != null:
					# TODO: wait for inital_delay and play note_on.note
					inital_delay = 0
		MidiData.Header.Format.MULTI_TRACK:
			var index = 0
			var tempo_map: Array[Vector2i] = midi_data.tracks[0].get_tempo_map()
			var us_per_beat := tempo_map[index].y
			var time: int = 0
			for event in midi_data.tracks[1].events:
				time += event.delta_time
				while time >= tempo_map[index].x:
					index += 1
					us_per_beat = tempo_map[index].y
				inital_delay += midi_data.header.convert_to_seconds(us_per_beat, event.delta_time)
				var note_on := event as MidiData.NoteOn
				if note_on != null:
					# TODO: wait for inital_delay and play note_on.note
					inital_delay = 0
```

## MIDI Specification resources used:

- https://drive.google.com/file/d/1t4jcCCKoi5HMi7YJ6skvZfKcefLhhOgU
- http://midi.teragonaudio.com/tech/midispec.htm
- https://www.recordingblogs.com/wiki/musical-instrument-digital-interface-midi
- https://web.archive.org/web/20141227205754/http://www.sonicspot.com:80/guide/midifiles.html
- http://www.music.mcgill.ca/~ich/classes/mumt306/StandardMIDIfileformat.html
- https://www.blitter.com/~russtopia/MIDI/~jglatt/tech/midifile.htm
- https://inspiredacoustics.com/en/MIDI_note_numbers_and_center_frequencies


## Enjoy using it!

🌻 If you find this addon helpful, please consider supporting my efforts by [**buying me a coffee (donating)**](http://ko-fi.com/g0retz)! I would appreciate it very much 😊
