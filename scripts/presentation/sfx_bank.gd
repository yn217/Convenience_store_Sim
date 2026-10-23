class_name SfxBank
extends RefCounted
## Sound effects made in code (no recorded or downloaded audio, so nothing to license): short sine
## tones with a fade, mono 48 kHz, peak well under -1 dBFS (14 §3). `NOTES` is the whole "asset":
## (frequency Hz, seconds) lists per sfx_key from the cue data.

const RATE := 48000
const PEAK := 0.45   # about -6.9 dBFS
const NOTES := {
	"door_chime": [[880.0, 0.12], [660.0, 0.22]],
	"register_beep": [[1320.0, 0.07], [0.0, 0.03], [1320.0, 0.07]],
	"warning_soft": [[440.0, 0.14], [392.0, 0.20]],
	"product_pickup": [[620.0, 0.05]],
	"event_start": [[523.0, 0.10], [659.0, 0.10], [784.0, 0.18]],
	"report_open": [[520.0, 0.08], [780.0, 0.14]],
	"milestone": [[523.0, 0.09], [659.0, 0.09], [784.0, 0.09], [1047.0, 0.22]],
	"ui_confirm": [[800.0, 0.06]],
	"ui_cancel": [[400.0, 0.07]],
}


static func has(sfx_key: String) -> bool:
	return NOTES.has(sfx_key)


static func samples(sfx_key: String) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for note in NOTES.get(sfx_key, []):
		var n := int(round(float(note[1]) * RATE))
		for i in n:
			var env := minf(1.0, minf(float(i) / (0.005 * RATE), float(n - i) / (0.02 * RATE)))
			out.append(0.0 if note[0] == 0.0 else sin(TAU * float(note[0]) * float(i) / RATE) * env * PEAK)
	return out


static func peak_dbfs(sfx_key: String) -> float:
	var peak := 0.0
	for s in samples(sfx_key):
		peak = maxf(peak, absf(s))
	return -200.0 if peak <= 0.0 else 20.0 * log(peak) / log(10.0)


static func duration_sec(sfx_key: String) -> float:
	return float(samples(sfx_key).size()) / RATE


static func stream(sfx_key: String) -> AudioStreamWAV:
	var data := samples(sfx_key)
	if data.is_empty():
		return null
	var bytes := PackedByteArray()
	bytes.resize(data.size() * 2)
	for i in data.size():
		bytes.encode_s16(i * 2, int(clampf(data[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	return wav
