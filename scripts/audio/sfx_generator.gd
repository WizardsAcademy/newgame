extends RefCounted
class_name SFXGenerator
## Procedural retro sound-effect generator using `AudioStreamWAV`.
##
## Instead of shipping external `.wav` / `.ogg` files for early prototyping,
## this script synthesizes tiny 16-bit PCM waveforms in memory at startup.
##
## =========================================================================
## PUNCH SOUND vs HIT SOUND - WHY SEPARATE THEM? (beginner-friendly)
## =========================================================================
## Beginners often attach one sound to the attack button and call it done.
## Splitting melee audio into TWO distinct layers makes combat feel 10x
## clearer to the player:
##
##   1. PUNCH SFX ("swing / whiff", on the Player):
##      Plays the instant you press Attack, whether anything is in front of
##      you or not. Low-pitched airy burst (0.10 s) -> tells the player
##      "your input worked; the fist is swinging through the air".
##
##   2. HIT SFX ("impact / confirm", on the Enemy):
##      Plays ONLY when the hitbox actually overlaps an enemy's Hurtbox.
##      Snappier, slightly higher-pitched pop (0.08 s) -> gives instant audio
##      confirmation that damage landed, even if visual effects overlap.
##      Living on the enemy scene also means a Slime, Skeleton, or Metal Golem
##      can each have its own material impact sound later without changing
##      `player_base.gd`!
##
## =========================================================================
## HOW `AudioStreamWAV` SYNTHESIS WORKS
## =========================================================================
## Digital audio is just a list of air-pressure numbers ("samples") played back
## `MIX_RATE` times per second (11,025 Hz here). For each sample `i`:
##   - `t` is the time in seconds (`i / 11025.0`),
##   - a sine wave `sin(phase)` produces a pure musical pitch,
##   - random numbers in `-1..1` produce percussive white noise,
##   - multiplying by a decaying `envelope` fades the sound smoothly to silence
##     so it does not click at the end,
##   - finally we pack each `-1.0 .. 1.0` float into a signed 16-bit integer
##     (`-32767 .. 32767`, 2 bytes little-endian) inside a `PackedByteArray`.

const MIX_RATE: int = 11025

# Cache generated streams so spawning 50 enemies reuses the same tiny buffer
# instead of re-synthesizing waveforms every time.
static var _punch_cache: AudioStreamWAV = null
static var _hit_cache: AudioStreamWAV = null
static var _death_cache: AudioStreamWAV = null
static var _footstep_cache: AudioStreamWAV = null
static var _hurt_cache: AudioStreamWAV = null
static var _dash_cache: AudioStreamWAV = null
static var _bow_cache: AudioStreamWAV = null
static var _blade_cache: AudioStreamWAV = null
static var _shield_cache: AudioStreamWAV = null
static var _blood_splash_cache: AudioStreamWAV = null
static var _fang_burst_cache: AudioStreamWAV = null
static var _stun_cache: AudioStreamWAV = null


## Short aggressive swing burst (0.10 s): low-frequency thump + airy noise.
static func create_punch_sfx() -> AudioStreamWAV:
	if _punch_cache != null:
		return _punch_cache

	var duration := 0.10
	var count := int(MIX_RATE * duration)
	var rng := RandomNumberGenerator.new()
	rng.seed = 101  # fixed seed = consistent sound every run
	var samples := PackedFloat32Array()
	samples.resize(count)

	var phase := 0.0
	var noise_lp := 0.0
	for i in count:
		var progress := float(i) / float(count)
		# Pitch drops fast from 165 Hz -> 60 Hz for a weighty "whoosh-thump".
		var freq := lerpf(165.0, 60.0, progress)
		phase += TAU * freq / float(MIX_RATE)

		# Simple one-pole low-pass filter on white noise so it sounds punchy
		# rather than hissy.
		var raw_noise := rng.randf_range(-1.0, 1.0)
		noise_lp = lerpf(noise_lp, raw_noise, 0.35)

		var envelope := pow(1.0 - progress, 2.0)
		var sample := (sin(phase) * 0.65 + noise_lp * 0.55) * envelope * 0.7
		samples[i] = sample

	_punch_cache = _build_wav(samples)
	return _punch_cache


## Crisp enemy impact (0.08 s): higher pitch than punch + sharp transient snap.
static func create_hit_sfx() -> AudioStreamWAV:
	if _hit_cache != null:
		return _hit_cache

	var duration := 0.08
	var count := int(MIX_RATE * duration)
	var rng := RandomNumberGenerator.new()
	rng.seed = 202
	var samples := PackedFloat32Array()
	samples.resize(count)

	var phase := 0.0
	for i in count:
		var progress := float(i) / float(count)
		# Higher pitch than the swing (340 Hz -> 145 Hz) so the impact cuts
		# clearly through the lower punch sound when a hit connects.
		var freq := lerpf(340.0, 145.0, progress)
		phase += TAU * freq / float(MIX_RATE)

		# Short noise snap in the first 20 % of the sound for "slap" attack.
		var snap := rng.randf_range(-1.0, 1.0) * maxf(0.0, 1.0 - progress * 5.0)
		var envelope := pow(1.0 - progress, 1.8)
		var sample := (sin(phase) * 0.75 + snap * 0.45) * envelope * 0.75
		samples[i] = sample

	_hit_cache = _build_wav(samples)
	return _hit_cache


## Slime defeat sound (0.30 s): classic retro descending pitch slide.
static func create_death_sfx() -> AudioStreamWAV:
	if _death_cache != null:
		return _death_cache

	var duration := 0.30
	var count := int(MIX_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(count)

	var phase := 0.0
	for i in count:
		var progress := float(i) / float(count)
		# Smoothly slide downward from 440 Hz (A4) down to 95 Hz as the slime
		# squashes and dissolves.
		var freq := lerpf(440.0, 95.0, pow(progress, 0.85))
		phase += TAU * freq / float(MIX_RATE)

		# Fundamental + soft second harmonic for a bubbly retro character.
		var tone := sin(phase) * 0.75 + sin(phase * 2.0) * 0.25
		var envelope := (1.0 - progress) * minf(1.0, progress * 25.0)
		samples[i] = tone * envelope * 0.65

	_death_cache = _build_wav(samples)
	return _death_cache


## Subtle footstep tick (0.04 s): quiet damped tap played every 0.25 s walking.
static func create_footstep_sfx() -> AudioStreamWAV:
	if _footstep_cache != null:
		return _footstep_cache

	var duration := 0.04
	var count := int(MIX_RATE * duration)
	var rng := RandomNumberGenerator.new()
	rng.seed = 303
	var samples := PackedFloat32Array()
	samples.resize(count)

	var phase := 0.0
	for i in count:
		var progress := float(i) / float(count)
		var freq := lerpf(210.0, 105.0, progress)
		phase += TAU * freq / float(MIX_RATE)

		var tap := rng.randf_range(-1.0, 1.0) * 0.4 + sin(phase) * 0.6
		var envelope := pow(1.0 - progress, 2.6)
		# Kept intentionally subtle (0.30 gain) so walking feels grounded
		# without fatiguing the player's ears.
		samples[i] = tap * envelope * 0.30

	_footstep_cache = _build_wav(samples)
	return _footstep_cache


## Player "oof" (0.12 s): low dull thud - a body taking a hit, deeper and
## softer than the crisp enemy impact so the two never blur together.
static func create_hurt_sfx() -> AudioStreamWAV:
	if _hurt_cache != null:
		return _hurt_cache

	var duration := 0.12
	var count := int(MIX_RATE * duration)
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	var samples := PackedFloat32Array()
	samples.resize(count)

	var phase := 0.0
	var noise_lp := 0.0
	for i in count:
		var progress := float(i) / float(count)
		# Low bouncy thud: 130 Hz dropping to 55 Hz.
		var freq := lerpf(130.0, 55.0, pow(progress, 0.7))
		phase += TAU * freq / float(MIX_RATE)

		var raw_noise := rng.randf_range(-1.0, 1.0)
		noise_lp = lerpf(noise_lp, raw_noise, 0.3)

		var envelope := pow(1.0 - progress, 2.2)
		var sample := (sin(phase) * 0.8 + noise_lp * 0.35) * envelope * 0.6
		samples[i] = sample

	_hurt_cache = _build_wav(samples)
	return _hurt_cache


## Snappy dash burst (0.11 s): crisp airy wind-sweep from 480 Hz -> 160 Hz.
static func create_dash_sfx() -> AudioStreamWAV:
	if _dash_cache != null:
		return _dash_cache

	var duration := 0.11
	var count := int(MIX_RATE * duration)
	var rng := RandomNumberGenerator.new()
	rng.seed = 505
	var samples := PackedFloat32Array()
	samples.resize(count)

	var phase := 0.0
	var noise_lp := 0.0
	for i in count:
		var progress := float(i) / float(count)
		var freq := lerpf(480.0, 160.0, pow(progress, 0.75))
		phase += TAU * freq / float(MIX_RATE)

		var raw_noise := rng.randf_range(-1.0, 1.0)
		noise_lp = lerpf(noise_lp, raw_noise, 0.55)

		var envelope := pow(1.0 - progress, 1.6) * minf(1.0, progress * 20.0)
		samples[i] = (sin(phase) * 0.45 + noise_lp * 0.65) * envelope * 0.65

	_dash_cache = _build_wav(samples)
	return _dash_cache


## Crisp bowstring twang + arrow whoosh (0.09 s) for Sylvara the Elf Ranger.
static func create_bow_sfx() -> AudioStreamWAV:
	if _bow_cache != null:
		return _bow_cache

	var duration := 0.09
	var count := int(MIX_RATE * duration)
	var rng := RandomNumberGenerator.new()
	rng.seed = 606
	var samples := PackedFloat32Array()
	samples.resize(count)

	var phase := 0.0
	for i in count:
		var progress := float(i) / float(count)
		var freq := lerpf(640.0, 290.0, pow(progress, 0.65))
		phase += TAU * freq / float(MIX_RATE)

		var air := rng.randf_range(-1.0, 1.0) * (1.0 - progress) * 0.35
		var tone := sin(phase) * 0.7 + sin(phase * 2.0) * 0.25
		var envelope := pow(1.0 - progress, 2.0)
		samples[i] = (tone + air) * envelope * 0.6

	_bow_cache = _build_wav(samples)
	return _bow_cache


## Metallic crescent / sword cleave resonance (0.11 s) for Knight & Vampire.
static func create_blade_sfx() -> AudioStreamWAV:
	if _blade_cache != null:
		return _blade_cache

	var duration := 0.11
	var count := int(MIX_RATE * duration)
	var rng := RandomNumberGenerator.new()
	rng.seed = 707
	var samples := PackedFloat32Array()
	samples.resize(count)

	var phase := 0.0
	for i in count:
		var progress := float(i) / float(count)
		var freq := lerpf(520.0, 240.0, progress)
		phase += TAU * freq / float(MIX_RATE)

		var shimmer := sin(phase * 2.7) * 0.3 + rng.randf_range(-1.0, 1.0) * 0.25
		var envelope := pow(1.0 - progress, 1.7)
		samples[i] = (sin(phase) * 0.6 + shimmer) * envelope * 0.65

	_blade_cache = _build_wav(samples)
	return _blade_cache


## Heavy steel-shield clang + metallic ring (0.11 s) for Knight's Shield Guard.
static func create_shield_block_sfx() -> AudioStreamWAV:
	if _shield_cache != null:
		return _shield_cache

	var duration := 0.11
	var count := int(MIX_RATE * duration)
	var rng := RandomNumberGenerator.new()
	rng.seed = 808
	var samples := PackedFloat32Array()
	samples.resize(count)

	var phase1 := 0.0
	var phase2 := 0.0
	for i in count:
		var progress := float(i) / float(count)
		phase1 += TAU * 780.0 / float(MIX_RATE)
		phase2 += TAU * 1210.0 / float(MIX_RATE)
		var impact := rng.randf_range(-1.0, 1.0) * pow(1.0 - progress, 4.0) * 0.45
		var ring := (sin(phase1) * 0.55 + sin(phase2) * 0.35) * pow(1.0 - progress, 1.8)
		samples[i] = (ring + impact) * 0.72

	_shield_cache = _build_wav(samples)
	return _shield_cache


## Pressurized crimson liquid splash + dark pulse (0.13 s) for Velmira.
static func create_blood_splash_sfx() -> AudioStreamWAV:
	if _blood_splash_cache != null:
		return _blood_splash_cache

	var duration := 0.13
	var count := int(MIX_RATE * duration)
	var rng := RandomNumberGenerator.new()
	rng.seed = 909
	var samples := PackedFloat32Array()
	samples.resize(count)

	var phase := 0.0
	var lp := 0.0
	for i in count:
		var progress := float(i) / float(count)
		var freq := lerpf(240.0, 420.0, sin(progress * PI))
		phase += TAU * freq / float(MIX_RATE)
		var raw := rng.randf_range(-1.0, 1.0)
		lp = lerpf(lp, raw, 0.38)
		var env := pow(1.0 - progress, 1.45) * minf(1.0, progress * 18.0)
		samples[i] = (lp * 0.65 + sin(phase) * 0.40) * env * 0.70

	_blood_splash_cache = _build_wav(samples)
	return _blood_splash_cache


## Crimson Fang-Mark 30% HP burst snap (0.16 s) for Velmira's debuff pop.
static func create_fang_burst_sfx() -> AudioStreamWAV:
	if _fang_burst_cache != null:
		return _fang_burst_cache

	var duration := 0.16
	var count := int(MIX_RATE * duration)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1010
	var samples := PackedFloat32Array()
	samples.resize(count)

	var p1 := 0.0
	var p2 := 0.0
	for i in count:
		var t := float(i) / float(count)
		p1 += TAU * lerpf(560.0, 140.0, pow(t, 0.6)) / float(MIX_RATE)
		p2 += TAU * 880.0 / float(MIX_RATE)
		var crunch := rng.randf_range(-1.0, 1.0) * pow(1.0 - t, 3.2) * 0.5
		var env := pow(1.0 - t, 1.5)
		samples[i] = (sin(p1) * 0.6 + sin(p2) * 0.25 + crunch) * env * 0.78

	_fang_burst_cache = _build_wav(samples)
	return _fang_burst_cache


## Concussive stun chime (0.12 s) for Behemoth's stunning punches & charge.
static func create_stun_sfx() -> AudioStreamWAV:
	if _stun_cache != null:
		return _stun_cache

	var duration := 0.12
	var count := int(MIX_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(count)

	var p1 := 0.0
	var p2 := 0.0
	for i in count:
		var t := float(i) / float(count)
		p1 += TAU * 660.0 / float(MIX_RATE)
		p2 += TAU * 990.0 / float(MIX_RATE)
		var env := pow(1.0 - t, 2.0)
		samples[i] = (sin(p1) * 0.5 + sin(p2) * 0.4) * env * 0.52

	_stun_cache = _build_wav(samples)
	return _stun_cache


## Pack normalized `-1.0 .. 1.0` float samples into a 16-bit mono AudioStreamWAV.
static func _build_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var pcm := PackedByteArray()
	pcm.resize(samples.size() * 2)

	for i in samples.size():
		var clamped := clampf(samples[i], -1.0, 1.0)
		var s16 := int(roundf(clamped * 32767.0))
		pcm.encode_s16(i * 2, s16)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	stream.data = pcm
	return stream
