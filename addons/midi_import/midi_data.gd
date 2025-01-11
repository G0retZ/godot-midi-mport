@icon("res://addons/midi_import/icons/midi.png")
class_name MidiData
extends Resource
## A representation of contents of a MIDI file in a strict typed form.
##
## It can be consrtucted from a provided PackedByteArray.
## It can be stored and restoreb as a partially parsed Resource.
## Has also some useful utils encapsulated.
##
## @tutorial(MIDI reference):             https://drive.google.com/file/d/1t4jcCCKoi5HMi7YJ6skvZfKcefLhhOgU
## @tutorial(MIDI reference):             http://midi.teragonaudio.com/tech/midispec.htm
## @tutorial(MIDI reference):             https://www.recordingblogs.com/wiki/musical-instrument-digital-interface-midi
## @tutorial(MIDI reference):             https://web.archive.org/web/20141227205754/http://www.sonicspot.com:80/guide/midifiles.html
## @tutorial(MIDI reference):             http://www.music.mcgill.ca/~ich/classes/mumt306/StandardMIDIfileformat.html
## @tutorial(MIDI reference):             https://www.blitter.com/~russtopia/MIDI/~jglatt/tech/midifile.htm
## @tutorial(MIDI notes numbering):       https://inspiredacoustics.com/en/MIDI_note_numbers_and_center_frequencies


const NOTES_KEYS = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

var _bytes: PackedByteArray
var header: Header
var tracks: Array[Track] = []


static func load_packed_byte_array(bytes: PackedByteArray) -> MidiData:
	_log("MIDI import start")
	var chunks := _bytes_to_chunks(bytes)
	if chunks.is_empty():
		_log("error: chunks not found")
		return null
	var data := MidiData.new()
	data._bytes = bytes
	var _header := Header._from_chunk(chunks[0])
	if _header == null:
		_log("error: header not found")
		return null
	data.header = _header
	chunks.remove_at(0)
	for chunk in chunks:
		var track := Track._from_chunk(chunk)
		if track == null:
			_log("chunk: is not a track: %s" % bytes.slice(0, 4).get_string_from_ascii())
		else:
			data.tracks.append(track)
	_log("MIDI import finish")
	return data


static func _log(message: String):
	if OS.is_debug_build():
		# print(message)
		pass


static func _bytes_to_chunks(bytes: PackedByteArray) -> Array[Chunk]:
	var chunks: Array[Chunk] = []
	var remaining_bytes := bytes
	while remaining_bytes.size() >= 8:
		var next_chunk := Chunk.new(remaining_bytes)
		chunks.append(next_chunk)
		remaining_bytes = remaining_bytes.slice(next_chunk.size + 8)
	return chunks


static func _buffer_to_variable_int(bytes: PackedByteArray) -> Vector2i:
	var index: int = 0
	var c: int = 0x80
	var value: int = 0
	while c & 0x80:
		c = bytes[index]
		value = (value << 7) + (c & 0x7f)
		index += 1
	return Vector2i(value, index)


static func _buffer_to_int(bytes: PackedByteArray) -> int:
	var value = 0
	for i in bytes.size():
		value = (value << 8) + bytes[i]
	return value


class Chunk:
	var id: String
	var size: int
	var bytes: PackedByteArray
	
	
	func _init(p_bytes: PackedByteArray):
		id = p_bytes.slice(0, 4).get_string_from_ascii()
		size = MidiData._buffer_to_int(p_bytes.slice(4, 8))
		bytes = p_bytes.slice(8, 8 + size)


## A representation of a MIDI header.
##
## It is created automatically when parsing MIDI file.
class Header:
## MIDI file format.
	enum Format {
		## File has the only Track chunk that contains all the events.
		SINGLE_TRACK = 0,
		## File has one or more Tracks that can be played simultaneously.
		MULTI_TRACK = 1,
		## File has one or more Tracks. Each Track is independent SINGLE_TRACK.
		MULTI_SONG = 2
	}
	## MIDI format
	var format: Format
	## Number of tracks as recorded in the header.
	## It is technically possible that the MIDI file has more or less track chuks than defined in the header.
	## It's up to you to treat it as an error or disregard this value.
	var tracks: int
	## How long is 1 tick in milliseconds. If -1 then it is PPQ timing format and [ticks_per_beat] should be used for calculations.
	var ms_per_tick: float
	## Number of ticks in one beat. If -1 then it is SMPTE timing format [ms_per_tick] should be used for calculations.
	var ticks_per_beat: int
	
	
	static func _from_chunk(chunk: MidiData.Chunk) -> Header:
		if chunk.id != "MThd" or chunk.size != 6:
			return null
		var _format := MidiData._buffer_to_int(chunk.bytes.slice(0, 2))
		var _tracks := MidiData._buffer_to_int(chunk.bytes.slice(2, 4))
		var division := MidiData._buffer_to_int(chunk.bytes.slice(4, 6))
		var _ms_per_tick := -1.0
		var _ticks_per_beat: int = -1
		if division & 0x8000:
			var fps = division >> 8
			match fps:
				-24: fps = 24
				-25: fps = 25
				-29: fps = 30
				-30: fps = 30
				_: return null
			var _ticks_per_frame = division & 0x0F
			_ms_per_tick = 1000.0 / (fps * _ticks_per_frame)
		else:
			_ticks_per_beat = division
		MidiData._log("header")
		MidiData._log("    format type: %s" % _format)
		MidiData._log("    tracks count: %s" % _tracks)
		MidiData._log("    ticks per beat: %s" % _ticks_per_beat)
		MidiData._log("    ms per tick: %s" % _ms_per_tick)
		var header = Header.new()
		header.format = _format
		header.tracks = _tracks
		header.ticks_per_beat = _ticks_per_beat
		header.ms_per_tick = _ms_per_tick
		return header
	
	
	## Convert the provided [us_per_beat] and [delta_time] to seconds.
	##
	## Calculation depends on the time division set in this header.
	## In case of SMPTE format the [us_per_beat] is ignored and doesn't affect the result.
	## It's preferable to rely on this method than to make calculations by hand.
	func convert_to_seconds(us_per_beat: int, delta_time: int) -> float:
		var sec_per_beat := us_per_beat / 1_000_000.0
		var delay: float = delta_time * ms_per_tick / 1000.0
		if delay < 0:
			delay = delta_time * sec_per_beat / ticks_per_beat
		return delay


## A representation of a MIDI track.
##
## It is created automatically when parsing MIDI file.
class Track:
	## Events in this track in order of appearance
	var events : Array[MidiData.Event] = []
	
	
	static func _from_chunk(chunk: MidiData.Chunk) -> Track:
		if chunk.id != "MTrk":
			return null
		MidiData._log("track")
		MidiData._log("    size: %s" % chunk.size)
		var track := Track.new()
		var remaining_bytes = chunk.bytes
		while not remaining_bytes.is_empty():
			var event = MidiData.Event._from_bytes(remaining_bytes)
			if event == null: break
			remaining_bytes = remaining_bytes.slice(event._full_size)
			track.events.append(event)
		MidiData._log("    events count: %s" % track.events.size())
		return track
	
	
	## Builds and returns a tempo map from this Track.
	##
	## If no Tempo event present at the beginning of the Track then adds an entry
	## with default value of 500_000 for the [us_per_beat] at position 0.
	##
	## SINGLE_TRACK: no additional notes 
	## MULTI_TRACK: no additional notes
	## MULTI_SONG: no additional notes
	func get_tempo_map() -> Array[Vector2i]: # build the tempo map
		var tempo_map: Array[Vector2i] = []
		var time: int = 0
		for event in events:
			time += event.delta_time
			var tempo = event as Tempo
			if tempo != null:
				tempo_map.append(Vector2i(time, tempo.us_per_beat))
		if tempo_map.is_empty() or tempo_map[0].x != 0:
			tempo_map.insert(0, Vector2i(0, 500_000))
		return tempo_map
	
	
	## Returns offset of all events in this Track in seconds. If no SmpteOffset event
	## present in this track returns 0
	func get_offset_in_seconds() -> float:
		for event in events:
			var offset = event as MidiData.SmpteOffset
			if offset != null:
				return offset.get_offset_in_seconds()
		return 0


## A representation of any Event in the Track.
##
## It is created automatically when parsing MIDI Track.
class Event:
	static var _last_status: int = -1
	## A distance from previous Event in ticks.
	## Use to calculate for how long to wait after previous event before firing this one.
	var delta_time: int
	var _full_size: int = 0
	
	
	static func _from_bytes(bytes: PackedByteArray) -> MidiData.Event:
		var var_time_data := MidiData._buffer_to_variable_int(bytes)
		var status := bytes[var_time_data.y]
		var event_data := bytes.slice(var_time_data.y + 1)
		if status < 0x80: # check for running status
			status = _last_status
			event_data = bytes.slice(var_time_data.y)
		_last_status = status
		var clean_status := (status & 0xF0) if status < 0xF0 else status
		MidiData._log("    event")
		MidiData._log("        delta_time: %d" % var_time_data.x)
		var event: MidiData.Event
		match clean_status :
			0x80: event = MidiData.NoteOff.new(status, event_data)
			0x90: event = MidiData.NoteOn.new(status, event_data)
			0xA0: event = MidiData.AfterTouch.new(status, event_data)
			0xB0: event = MidiData.Controller.new(status, event_data)
			0xC0: event = MidiData.ProgramChange.new(status, event_data)
			0xD0: event = MidiData.ChannelPressure.new(status, event_data)
			0xE0: event = MidiData.PitchWheel.new(status, event_data)
			0xF0: event = MidiData.SystemExclusive.new(true, event_data)
			0xF1: event = MidiData.QuarterFrame.new(event_data)
			0xF2: event = MidiData.SongPositionPointer.new(event_data)
			0xF3: event = MidiData.SongRequest.new(event_data)
			0xF4: event = MidiData.UndefinedSystemCommon.new(event_data)
			0xF5: event = MidiData.UndefinedSystemCommon.new(event_data)
			0xF6: event = MidiData.TuneRequest.new()
			0xF7: event = MidiData.SystemExclusive.new(false, event_data)
			0xF8: event = MidiData.MidiClock.new()
			0xF9: event = MidiData.UndefinedRealTilme.new()
			0xFA: event = MidiData.MidiStart.new()
			0xFB: event = MidiData.MidiContinue.new()
			0xFC: event = MidiData.MidiStop.new()
			0xFD: event = MidiData.UndefinedRealTilme.new()
			0xFE: event = MidiData.ActiveSense.new()
			0xFF: event = MidiData.Meta._from_bytes(event_data)
		var on_event := event as NoteOn
		if on_event != null and on_event.velocity == 0:
			event = MidiData.NoteOff.new(status, event_data)
		event.delta_time = var_time_data.x
		event._full_size += var_time_data.y + 1
		MidiData._log("        size: %d" % event._full_size)
		return event


## Specific to a MIDI channel and directly affect the sound produced by MIDI devices.
##
## SINGLE_TRACK: no additional notes 
## MULTI_TRACK: no additional notes
## MULTI_SONG: no additional notes
class Voice extends Event:
	var channel: int = 0
	func _init(status: int):
		channel = status & 0x0F
		MidiData._log("        channel: %d" % channel)


## A note should be released and should stop sounding.
##
## SINGLE_TRACK: no additional notes 
## MULTI_TRACK: no additional notes
## MULTI_SONG: no additional notes
class NoteOff extends Voice:
	var octave: int # note octave, example 5
	var note: int
	var note_key: String # note key, example E
	var note_name: String # note name, example E5
	var velocity: int
	func _init(status: int, bytes: PackedByteArray):
		super._init(status)
		MidiData._log("        NoteOff < Voice < Event")
		note = bytes[0]
		velocity = bytes[1]
		octave = (note / 12) - 1
		note_key = MidiData.NOTES_KEYS[note % 12]
		note_name = str(note_key, octave)
		_full_size = 2
		MidiData._log("        note: %d" % note)
		MidiData._log("        note name: %s" % note_name)
		MidiData._log("        velocity: %d" % velocity)


## A note should be played and should start sounding.
##
## SINGLE_TRACK: no additional notes 
## MULTI_TRACK: no additional notes
## MULTI_SONG: no additional notes
class NoteOn extends Voice:
	var octave: int # note octave, example 5
	var note: int
	var note_key: String # note key, example E
	var note_name: String # note name, example E5
	var velocity: int
	func _init(status: int, bytes: PackedByteArray):
		super._init(status)
		MidiData._log("        NoteOn < Voice < Event")
		note = bytes[0]
		velocity = bytes[1]
		octave = (note / 12) - 1
		note_key = MidiData.NOTES_KEYS[note % 12]
		note_name = str(note_key, octave)
		_full_size = 2
		MidiData._log("        note: %d" % note)
		MidiData._log("        note name: %s" % note_name)
		MidiData._log("        velocity: %d" % velocity)


## Pressure should be applied to a note, similarly to applying pressure to
## electronic keyboard keys.
##
## SINGLE_TRACK: no additional notes 
## MULTI_TRACK: no additional notes
## MULTI_SONG: no additional notes
class AfterTouch extends Voice:
	var octave: int # note octave, example 5
	var note: int
	var note_key: String # note key, example E
	var note_name: String # note name, example E5
	var pressure: int
	func _init(status: int, bytes: PackedByteArray):
		super._init(status)
		MidiData._log("        AfterTouch < Voice < Event")
		note = bytes[0]
		pressure = bytes[1]
		octave = (note / 12) - 1
		note_key = MidiData.NOTES_KEYS[note % 12]
		note_name = str(note_key, octave)
		_full_size = 2
		MidiData._log("        note: %d" % note)
		MidiData._log("        note name: %s" % note_name)
		MidiData._log("        pressure: %d" % pressure)


## A controller should be affected. A controller is a virtual slider, knob, or switch.
##
## SINGLE_TRACK: no additional notes 
## MULTI_TRACK: no additional notes
## MULTI_SONG: no additional notes
class Controller extends Voice:
	# TODO: specify all the controllers?
	var number: int
	var value: int
	func _init(status: int, bytes: PackedByteArray):
		super._init(status)
		MidiData._log("        Controller < Voice < Event")
		number = bytes[0]
		value = bytes[1]
		_full_size = 2
		MidiData._log("        number: %d" % number)
		MidiData._log("        value: %d" % value)


## A Program should be assigned to a MIDI channel.
## A Program is virtual instrument, patch, or preset.
##
## SINGLE_TRACK: no additional notes 
## MULTI_TRACK: no additional notes
## MULTI_SONG: no additional notes
class ProgramChange extends Voice:
	var program_number: int
	func _init(status: int, bytes: PackedByteArray):
		super._init(status)
		MidiData._log("        ProgramChange < Voice < Event")
		program_number = bytes[0]
		_full_size = 1
		MidiData._log("        program number: %d" % program_number)


## Pressure should be applied to a MIDI channel, similarly to applying pressure
## to electronic keyboard keys.
##
## SINGLE_TRACK: no additional notes 
## MULTI_TRACK: no additional notes
## MULTI_SONG: no additional notes
class ChannelPressure extends Voice:
	var value: int
	func _init(status: int, bytes: PackedByteArray):
		super._init(status)
		MidiData._log("        ChannelPressure < Voice < Event")
		value = bytes[0]
		_full_size = 1
		MidiData._log("        value: %d" % value)


## A channel pitch should be changed up or down.
##
## SINGLE_TRACK: no additional notes 
## MULTI_TRACK: no additional notes
## MULTI_SONG: no additional notes
class PitchWheel extends Voice:
	var value: int
	func _init(status: int, bytes: PackedByteArray):
		super._init(status)
		MidiData._log("        PitchWheel < Voice < Event")
		value = ((bytes[0] & 0x7F) << 7) + (bytes[1] & 0x7F)
		_full_size = 2

## System common event. Used just for classification purpose.
##
## SINGLE_TRACK: no additional notes 
## MULTI_TRACK: no additional notes
## MULTI_SONG: no additional notes
class SystemCommon extends Event:
	func _init():
		MidiData._log("        SystemCommon < Event")


## Undefined system common event for anyhting not specified. To be ignored.
##
## SINGLE_TRACK: no additional notes 
## MULTI_TRACK: no additional notes
## MULTI_SONG: no additional notes
class UndefinedSystemCommon extends SystemCommon:
	func _init(bytes: PackedByteArray):
		bytes.size()
		# TODO: find a way to add real logic for skipping this event.
		# It's pretty tricky but pretty unprobable case
		MidiData._log("        SystemCommonIgnored < SystemCommon < Event")


## Perform some device specific action.
##
## SINGLE_TRACK: no additional notes 
## MULTI_TRACK: no additional notes
## MULTI_SONG: no additional notes
class SystemExclusive extends SystemCommon:
	var isInitial: bool = false
	var bytes: PackedByteArray
	func _init(initial: bool, _bytes: PackedByteArray):
		isInitial = initial
		var length := MidiData._buffer_to_variable_int(_bytes)
		bytes = _bytes.slice(length.y)
		_full_size = length.x + length.y
		MidiData._log("        SystemExclusive < SystemCommon < Event")
		MidiData._log("        initial: %d" % isInitial)


## Understand the MIDI time to keep in line with some other device.
##
## SINGLE_TRACK: no additional notes 
## MULTI_TRACK: no additional notes
## MULTI_SONG: no additional notes
class QuarterFrame extends SystemCommon:
	var value: int
	func _init(bytes: PackedByteArray):
		value = bytes[0]
		_full_size = 1
		MidiData._log("        QuarterFrame < SystemCommon < Event")


## Cue to a point in the MIDI sequence to be ready to play.
##
## SINGLE_TRACK: no additional notes 
## MULTI_TRACK: no additional notes
## MULTI_SONG: no additional notes
class SongPositionPointer extends SystemCommon:
	var position_beat: int
	func _init(bytes: PackedByteArray):
		position_beat = ((bytes[0] & 0x7F) << 7) + (bytes[1] & 0x7F)
		_full_size = 2
		MidiData._log("        SongPositionPointer < SystemCommon < Event")
		MidiData._log("        position beat: %d" % position_beat)


## Set a Sequence (song) for playback.
##
## SINGLE_TRACK: no additional notes 
## MULTI_TRACK: no additional notes
## MULTI_SONG: no additional notes
class SongRequest extends SystemCommon:
	var song_number: int
	func _init(bytes: PackedByteArray):
		song_number = bytes[0]
		_full_size = 1
		MidiData._log("        SongRequest < SystemCommon < Event")


## Tells a MIDI device to tune itself.
##
## SINGLE_TRACK: no additional notes 
## MULTI_TRACK: no additional notes
## MULTI_SONG: no additional notes
class TuneRequest extends SystemCommon:
	func _init():
		MidiData._log("        TuneRequest < SystemCommon < Event")


## Real time event. Used just for classification purpose.
class RealTime extends Event:
	func _init():
		MidiData._log("        RealTime < Event")


## Undefined real time event for anyhting not specified. To be ignored.
##
## SINGLE_TRACK: no additional notes 
## MULTI_TRACK: no additional notes
## MULTI_SONG: no additional notes
class UndefinedRealTilme extends RealTime:
	func _init():
		MidiData._log("        RealTilmeIgnored < RealTime < Event")


## Understand the position of the MIDI clock when synchronized to another device.
##
## SINGLE_TRACK: no additional notes 
## MULTI_TRACK: no additional notes
## MULTI_SONG: no additional notes
class MidiClock extends RealTime:
	func _init():
		MidiData._log("        MidiClock < RealTime < Event")


## Start playback of the current MIDI Sequence (song).
##
## SINGLE_TRACK: no additional notes 
## MULTI_TRACK: no additional notes
## MULTI_SONG: no additional notes
class MidiStart extends RealTime:
	func _init():
		MidiData._log("        MidiStart < RealTime < Event")


## Resume playback of the current MIDI Sequence (song).
##
## SINGLE_TRACK: no additional notes 
## MULTI_TRACK: no additional notes
## MULTI_SONG: no additional notes
class MidiContinue extends RealTime:
	func _init():
		MidiData._log("        MidiContinue < RealTime < Event")


## Stop playback of the current MIDI Sequence (song).
##
## SINGLE_TRACK: no additional notes 
## MULTI_TRACK: no additional notes
## MULTI_SONG: no additional notes
class MidiStop extends RealTime:
	func _init():
		MidiData._log("        MidiStop < RealTime < Event")


## Understand that a MIDI connection exists (when there are no other Voice messages).
##
## SINGLE_TRACK: no additional notes 
## MULTI_TRACK: no additional notes
## MULTI_SONG: no additional notes
class ActiveSense extends RealTime:
	func _init():
		MidiData._log("        ActiveSense < RealTime < Event")


## Meta event. Used for classification purpose. There is a number of meta event types.
## All meta events inherit this one.
class Meta extends Event:
	static func _from_bytes(bytes: PackedByteArray) -> MidiData.Meta:
		var type := bytes[0]
		var length := MidiData._buffer_to_variable_int(bytes.slice(1))
		if length == Vector2i.MIN: return null
		var data_bytes = bytes.slice(length.y + 1, length.y + 1 + length.x)
		var event: Meta
		match type:
			0x00: event = MidiData.SequenceNumber.new(data_bytes)
			0x01: event = MidiData.Text.new(data_bytes)
			0x02: event = MidiData.CopyrightNotice.new(data_bytes)
			0x03: event = MidiData.TrackName.new(data_bytes)
			0x04: event = MidiData.InstrumentName.new(data_bytes)
			0x05: event = MidiData.Lyrics.new(data_bytes)
			0x06: event = MidiData.Marker.new(data_bytes)
			0x07: event = MidiData.CuePoint.new(data_bytes)
			0x08: event = MidiData.ProgramName.new(data_bytes)
			0x09: event = MidiData.DeviceName.new(data_bytes)
			0x20: event = MidiData.MidiChannel.new(data_bytes)
			0x21: event = MidiData.MidiPort.new(data_bytes)
			0x2F: event = MidiData.EndOfTrack.new()
			0x51: event = MidiData.Tempo.new(data_bytes)
			0x54: event = MidiData.SmpteOffset.new(data_bytes)
			0x58: event = MidiData.TimeSignature.new(data_bytes)
			0x59: event = MidiData.KeySignature.new(data_bytes)
			0x7F: event = MidiData.Proprietary.new(data_bytes)
		if event == null:
			event = MidiData.UndefinedMeta.new()
		event._full_size = length.x + length.y + 1
		return event


## Optional event, which must occur at the beginning of a Track, before any
## nonzero delta-times, and before any transmittable Voice events, specifies
## the number of a Sequence (song).
##
## SINGLE_TRACK: no additional notes 
## MULTI_TRACK: Can have only one SequenceNumber for all tracks. If transfer of
##         several multitrack sequences is required, this must be done as a group
##         of MULTI_TRACK files, each with a different sequence number.
## MULTI_SONG: Each Track has unique SequenceNumber to select from.
class SequenceNumber extends Meta:
	var msb_number: int = 0
	var lsb_number: int = 0
	func _init(bytes: PackedByteArray):
		if bytes.size() > 0: msb_number = bytes[0]
		if bytes.size() > 1: lsb_number = bytes[1]
		MidiData._log("        SequenceNumber < Meta < Event")
		MidiData._log("        msb number: %d" % msb_number)
		MidiData._log("        lsb number: %d" % lsb_number)


## Any amount of ASCIi text describing anything.
## 
## Can occur at any delta-time of a track.
##
## SINGLE_TRACK: no additional comment.
## MULTI_TRACK: no additional comment.
## MULTI_SONG: no additional comment.
class Text extends Meta:
	var text: String
	func _init(bytes: PackedByteArray):
		text = bytes.get_string_from_ascii()
		MidiData._log("        text: %s" % text)


## Contains a copyright notice as printable ASCII text.
##
## The notice should contain the characters (C), the year of the copyright, the
## owner of the copyright and should covers all pieces of music in MIDI file.
## This event should be the first event in the first track chunk, at a time 0.
##
## SINGLE_TRACK: no additional comment.
## MULTI_TRACK: no additional comment.
## MULTI_SONG: no additional comment.
class CopyrightNotice extends Text:
	func _init(bytes: PackedByteArray):
		MidiData._log("        CopyrightNotice < Text < Meta < Event")
		super._init(bytes)


## Contains a name of a Track or Sequence (song).
##
## SINGLE_TRACK: Represents name of a Sequence.
## MULTI_TRACK: Represents name of a Sequence for the first Track.
##         Represents name of a Track for all other tracks.
## MULTI_SONG: Represents name of a Sequence.
class TrackName extends Text:
	func _init(bytes: PackedByteArray):
		MidiData._log("        TrackName < Text < Meta < Event")
		super._init(bytes)


## A description of the type of instrumentation to be used in that track.
##
## SINGLE_TRACK: no additional comment.
## MULTI_TRACK: no additional comment.
## MULTI_SONG: no additional comment.
class InstrumentName extends Text:
	func _init(bytes: PackedByteArray):
		MidiData._log("        InstrumentName < Text < Meta < Event")
		super._init(bytes)


## A lyric to be sung.
##
## Generally, each syllable will be a separate lyric event which begins at the event's time.
##
## SINGLE_TRACK: no additional comment.
## MULTI_TRACK: no additional comment.
## MULTI_SONG: no additional comment.
class Lyrics extends Text:
	func _init(bytes: PackedByteArray):
		MidiData._log("        Lyrics < Text < Meta < Event")
		super._init(bytes)


## The name of the point in the sequence, such as a rehearsal letter or section
## name ("First Verse", etc.).
##
## SINGLE_TRACK: no additional notes.
## MULTI_TRACK: Normally can occur in first Track.
## MULTI_SONG: Can occur in any Track.
class Marker extends Text:
	func _init(bytes: PackedByteArray):
		MidiData._log("        Marker < Text < Meta < Event")
		super._init(bytes)


## A description of something happening on a film or video screen or stage
## at that point in the musical score
## ("Car crashes into house", "curtain opens", "she slaps his face", etc.)
##
## SINGLE_TRACK: no additional comment.
## MULTI_TRACK: no additional comment.
## MULTI_SONG: no additional comment.
class CuePoint extends Text:
	func _init(bytes: PackedByteArray):
		MidiData._log("        CuePoint < Text < Meta < Event")
		super._init(bytes)


## The name of the program (ie, patch) used to play the Track.
##
## This may be different than the Sequence/Track Name.
## For example, maybe the name of your Sequence/Track is "Butterfly", but since
## the track is played upon an electric piano patch, you may also include
## a Program Name of "ELECTRIC PIANO".
##
## SINGLE_TRACK: no additional comment.
## MULTI_TRACK: no additional comment.
## MULTI_SONG: no additional comment.
class ProgramName extends Text:
	func _init(bytes: PackedByteArray):
		MidiData._log("        ProgramName < Text < Meta < Event")
		super._init(bytes)


## The name of the MIDI device (port) where the track is routed.
##
## This replaces the obsolete MidiChannel Meta-Event which some sequencers
## formally used to route MIDI tracks to various MIDI ports (in order to support
## more than 16 MIDI channels).
## All MIDI events that occur in the Track, after a given DeviceName event, will
## be routed to that port.
##
## SINGLE_TRACK: Can have numerous DeviceName events.
## MULTI_TRACK: Usually have one DeviceName event per track.
## MULTI_SONG: Can have numerous DeviceName events per track.
class DeviceName extends Text:
	func _init(bytes: PackedByteArray):
		MidiData._log("        DeviceName < Text < Meta < Event")
		super._init(bytes)


## The MIDI channel (0-15) contained in this event may be used to associate a
## MIDI channel with all events which follow, including SystemExclusive and Meta events.
##
## This channel is "effective" until the next normal Voice event (which contains
## a channel) or the next MidiChannel event. If MIDI channels refer to "tracks",
## this message may help jam several tracks into a SINGLE_TRACK file, keeping
## their non-Voice data associated with a track.
##
## SINGLE_TRACK: no additional comment.
## MULTI_TRACK: no additional comment.
## MULTI_SONG: no additional comment.
class MidiChannel extends Meta:
	var channel: int
	func _init(bytes: PackedByteArray):
		channel = bytes[0]
		MidiData._log("        MidiChannel < Meta < Event")
		MidiData._log("        channel: %d" % channel)


## Optional event which normally occurs at the beginning of an Track, before any
## nonzero delta-times, and before any transmittable Voice events, specifies out
## of which MIDI Port (ie, bus) the Voice events in the Track go.
##
## It is acceptable to have more than one Port event in a given Track, if that
## Track needs to output to another port at some point in the Track.
##
## SINGLE_TRACK: no additional comment.
## MULTI_TRACK: no additional comment.
## MULTI_SONG: no additional comment.
class MidiPort extends Meta:
	var port: int
	func _init(bytes: PackedByteArray):
		port = bytes[0]
		MidiData._log("        MidiPort < Meta < Event")
		MidiData._log("        port: %d" % port)


## Mandatory event, included so that an exact ending point may be specified for
## the Track, so that it has an exact length, which is necessary for Tracks
## which are looped or concatenated.
##
## SINGLE_TRACK: no additional comment.
## MULTI_TRACK: no additional comment.
## MULTI_SONG: no additional comment.
class EndOfTrack extends Meta:
	func _init():
		MidiData._log("        EndOfTrack < Meta < Event")


## Indicates a tempo change.
##
## Another way of putting "microseconds per quarter-note" is "24ths of a microsecond
## per MIDI clock".  Ideally, these events only occur where MIDI clocks would be located.
## If not present then the default values of 500_000 for the [us_per_beat] and 
## of 120.0 for the [bpm] should be considered.
##
## SINGLE_TRACK: Should occur at least at the beginning of the Track.
## MULTI_TRACK: Should occur at least at the beginning of the first Track.
##         Affects all the Tracks.
## MULTI_SONG: Should occur at least at the beginning of each Track.
##         Affects only the Track it appears in.
class Tempo extends Meta:
	var us_per_beat: int # defines how long is one beat in microseconds.
	var bpm: float # calculated BPM value.
	func _init(bytes: PackedByteArray):
		us_per_beat = MidiData._buffer_to_int(bytes.slice(0, 3))
		bpm = 60_000_000.0 / us_per_beat
		MidiData._log("        Tempo < Meta < Event")
		MidiData._log("        us per beat: %d" % us_per_beat)
		MidiData._log("        bpm: %f" % bpm)


## If present, designates the SMPTE time at which the track chunk is supposed to start.
##
## It should be present at the beginning of the track, that is, before any nonzero
## delta-times, and before any transmittable MIDI events.
##
## SINGLE_TRACK: Can occur only at the beginning of the Track.
## MULTI_TRACK: Can occur only at the beginning of the first Track. Affects all the Tracks.
## MULTI_SONG: Can occur only at the beginning of any Track. Affects only the Track it appears in.
class SmpteOffset extends Meta:
	var fps: int
	var hours: int
	var minutes: int
	var seconds: int
	var frames: int
	var fractional_frames: int
	func _init(bytes: PackedByteArray):
		hours = bytes[0]
		fps = (hours >> 5) & 0b11
		match fps:
			0b00: fps = 24
			0b01: fps = 25
			0b10: fps = 30
			0b11: fps = 30
		hours = hours & 0x1F
		minutes = bytes[1] & 0x3F
		seconds = bytes[2] & 0x3F
		frames = bytes[3] & 0x1F
		fractional_frames = bytes[4] & 0x7F
		MidiData._log("        SmpteOffset < Meta < Event")
		MidiData._log("        fps: %d" % fps)
		MidiData._log("        hours: %d" % hours)
		MidiData._log("        minutes: %d" % minutes)
		MidiData._log("        seconds: %d" % seconds)
		MidiData._log("        frames: %d" % frames)
		MidiData._log("        fractional frames: %d" % fractional_frames)
	
	
	## Returns offset calculated in seconds.
	func get_offset_in_seconds() -> float:
		return hours * 3600 + minutes * 60 + seconds + (frames * 1.0 / fps) + (fractional_frames * 0.01 / fps)


## The time signature is expressed as four numbers. nn and dd represent the numerator
## and denominator of the time signature as it would be notated.
##
## It should be present at the beginning of the track, that is, before any nonzero
## delta-times, and before any transmittable MIDI events.
## if missing then should default to the 4/4.
##
## SINGLE_TRACK: Should occur at least at the beginning of the Track.
## MULTI_TRACK: Should occur at least at the beginning of the first Track.
##         Affects all the Tracks.
## MULTI_SONG: Should occur at least at the beginning of each Track.
##         Affects only the Track it appears in.
class TimeSignature extends Meta:
	var numerator: int
	var denominator: int
	var metronome_pulse: int #number of MIDI clocks per click. Usually there are 24 MIDI clocks per beat.
	var thirty_seconds: int #number of 32nd notes per bit. Usually there are 8 32nd per beat.
	func _init(bytes: PackedByteArray):
		numerator = bytes[0]
		denominator = 2 ** bytes[1]
		metronome_pulse = bytes[2]
		thirty_seconds = bytes[3]
		MidiData._log("        TimeSignature < Meta < Event")
		MidiData._log("        numerator: %d" % numerator)
		MidiData._log("        denominator: %d" % denominator)
		MidiData._log("        metronome pulse: %d" % metronome_pulse)
		MidiData._log("        thirty seconds: %d" % thirty_seconds)


## Used to specify the key (number of sharps or flats) and scale (major or minor)
## of a Sequence (song).
##
## SINGLE_TRACK: no additional comment.
## MULTI_TRACK: Should occur only at the first Track. Specifies for all the Tracks.
## MULTI_SONG: Specifies for each Track it appears in.
class KeySignature extends Meta:
	enum Scale {
		MAJOR = 0,
		MINOR = 1
	}
	var key: int # -7 to -1 specifies number of flats. 1 to 7 specifies number of sharps.
	var scale: Scale
	func _init(bytes: PackedByteArray):
		key = bytes[0]
		scale = Scale.MAJOR if bytes[1] == 0 else Scale.MINOR
		MidiData._log("        KeySignature < Meta < Event")
		MidiData._log("        key: %d" % key)
		MidiData._log("        scale: %d" % scale)


## Information specific to a hardware or software sequencer.
##
## SINGLE_TRACK: no additional comment.
## MULTI_TRACK: no additional comment.
## MULTI_SONG: no additional comment.
class Proprietary extends Meta:
	var bytes: PackedByteArray
	func _init(_bytes: PackedByteArray):
		bytes = _bytes
		MidiData._log("        Proprietary < Meta < Event")


## Undefined meta event for anyhting not specified. To be ignored.
##
## SINGLE_TRACK: no additional comment.
## MULTI_TRACK: no additional comment.
## MULTI_SONG: no additional comment.
class UndefinedMeta extends Meta:
	func _init():
		MidiData._log("        Unknown < Meta < Event")
