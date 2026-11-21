extends RefCounted
## Shared, short PCM recordings. No file IO or synthesis during footsteps.
const DIR := "res://assets/audio/wildlife/"
const PAW_SOFT := [DIR+"paw_soft_1.wav", DIR+"paw_soft_2.wav", DIR+"paw_soft_3.wav"]
const PAW_HARD := [DIR+"paw_hard_1.wav", DIR+"paw_hard_2.wav", DIR+"paw_hard_3.wav"]
const HOOF := [DIR+"hoof_1.wav", DIR+"hoof_2.wav", DIR+"hoof_3.wav"]
# Wolf walk/run/eat/growl come from the owner's LOBOS recordings.
# Attack snarls keep the separate fight recording; see SOURCES.json.
const WOLF_WALK := [DIR+"wolf_walk_1.wav", DIR+"wolf_walk_2.wav", DIR+"wolf_walk_3.wav"]
const WOLF_RUN := [DIR+"wolf_run_1.wav", DIR+"wolf_run_2.wav", DIR+"wolf_run_3.wav"]
const WOLF_EAT := [DIR+"wolf_eat_1.wav", DIR+"wolf_eat_2.wav", DIR+"wolf_eat_3.wav"]
const WOLF_GROWL := [DIR+"wolf_growl_1.wav", DIR+"wolf_growl_2.wav", DIR+"wolf_growl_3.wav", DIR+"wolf_growl_4.wav"]
const WOLF_ATTACK := [DIR+"wolf_attack_1.wav", DIR+"wolf_attack_2.wav", DIR+"wolf_attack_3.wav", DIR+"wolf_attack_4.wav", DIR+"wolf_attack_5.wav"]
const BEAR_GROWL := DIR+"bear_growl.wav"
const BEAR_ATTACK := DIR+"bear_attack.wav"
const BITE := "res://assets/audio/wolf_bite.wav"
# Gain, pitch and distance between contacts; paws are soft, hooves sharper.
# run_cycle: seconds per gallop bound at full speed — a quadruped sprint is
# ~3 footfall groups/s with suspension, not a metronome of single taps.
const SPECIES := {
	"wolf": {"db": -10.0, "pitch": 1.0, "walk": .62, "run": 1.05, "range": 22.0, "run_cycle": .30},
	"fox": {"db": -17.0, "pitch": 1.18, "walk": .40, "run": .72, "range": 14.0, "run_cycle": .28},
	"deer": {"db": -7.0, "pitch": 1.12, "walk": .65, "run": 1.15, "range": 28.0, "run_cycle": .30},
	"bear": {"db": -5.0, "pitch": .78, "walk": .78, "run": 1.25, "range": 30.0, "run_cycle": .40},
}
static var _cache: Dictionary = {}

static func stream(path: String) -> AudioStream:
	if _cache.has(path): return _cache[path]
	var audio: AudioStream = load(path) if ResourceLoader.exists(path) else null
	# Newly-generated WAVs can be checked before the editor imports them.
	if audio == null and path.ends_with(".wav") and FileAccess.file_exists(path):
		audio = AudioStreamWAV.load_from_file(ProjectSettings.globalize_path(path))
	if audio != null: _cache[path] = audio
	return audio

static func prepare() -> void:
	for path in PAW_SOFT + PAW_HARD + HOOF + WOLF_WALK + WOLF_RUN + WOLF_EAT + WOLF_GROWL + WOLF_ATTACK + [BEAR_GROWL, BEAR_ATTACK, BITE]:
		stream(path)

static func step(species: String, hard: bool, variation: int, running: bool = false) -> AudioStream:
	var paths: Array = (WOLF_RUN if running else WOLF_WALK) if species == "wolf" else (HOOF if species == "deer" else (PAW_HARD if hard else PAW_SOFT))
	return stream(paths[posmod(variation, paths.size())])
