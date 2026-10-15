# raum 2

A stereo reverb for norns, played from grid 128 and arc 4. It ranges from small rooms and plates to cathedrals, shimmer, gated reverb, ducked washes and an infinite freeze.

raum 2 is raum plus two changes:
- **nb voices as input.** Any nb voice that runs in SuperCollider (from a mod such as emplaitress or doubledecker) can play into the reverb. You play the voice from a MIDI keyboard, or let raum's test patterns play it.
- **A quiet start.** The test sounds are off when the script opens.

raum 2 and raum can both be installed; they use separate engines and separate snapshot files.

## Install

1. Copy the `raum2` folder into `dust/code/` on norns.
   - **SMB:** connect to `smb://norns.local/dust` (user `we`, password `sleep`).
   - **Terminal:** `scp -r raum2 we@norns.local:~/dust/code/`
2. Restart norns, or type `;restart` in maiden, so the new engine compiles.
3. Plug in grid and arc, then open **SELECT > raum2**.

raum 2 starts silent, on the Hall preset, processing whatever comes into the inputs.

- **K3** starts or stops the test sounds (a plucked note every bar by default).
- **K2** freezes the tail.

## nb voices

[nb](https://github.com/sixolet/nb) ("nota bene") lets a script play voices that are installed separately, mostly as mods. raum 2 has nb built in (in `lib/nb`).

To use it:
1. Install an nb voice mod, for example emplaitress or doubledecker, through maiden.
2. Turn it on under SYSTEM > MODS, then restart norns.
3. In raum 2, open PARAMETERS > NB VOICE and choose the voice under **nb voice**. Its own settings appear further down the parameter list.
4. Play it in one of two ways:
   - **From a MIDI keyboard:** set **MIDI in > nb** to the keyboard and, if needed, the **MIDI channel**. Notes and velocity play the voice. The mod wheel (CC 1) goes to the voice's modulation.
   - **From the test patterns:** set **test sounds play** to *nb voice* (or ALT + TEST on the grid), then start the test sounds with K3 or TEST. The drum pattern plays notes 36, 38 and 42; the other patterns play notes and chords from the test scale.

The NB VOICE parameters:

| parameter | what it does |
|---|---|
| nb voice | which nb voice to play: none, the installed voice mods, and connected MIDI devices. |
| nb into raum | on (default): the nb voice plays through the reverb. Off: it plays dry, past raum. ALT + LIVE on the grid. |
| nb level | level of the nb voice into raum, −60 to +12 dB. |
| test sounds play | *raum voices* (the built-in sounds) or *nb voice*. ALT + TEST on the grid. |
| MIDI in > nb | the MIDI device whose notes play the nb voice, or off. |
| MIDI channel | omni or 1–16. |

How it works: nb voice mods play straight into the norns output and never pass through the script's engine. raum 2 takes everything that has reached the output before its own engine runs, removes it there, and feeds it into the reverb. Because of that:
- With *nb into raum* on, the reverb's *mix* also applies to the nb voice. At 0% you hear it dry; at 100% only its reverb.
- Any other mod that plays sound in SuperCollider is captured the same way.
- nb voices that send MIDI or crow to external gear are not audio inside norns. To put that gear through raum, bring its audio back into the norns inputs and use LIVE.
- If a MIDI device is both the nb voice and the MIDI input and it echoes notes back, you get a loop. Pick different devices or turn off echo on the device.

If raum 2 cannot find nb, PARAMETERS > NB VOICE shows *nb not found* and the script works like raum.

## System settings

While raum runs it turns the system *monitor* level and the system *reverb* off. The dry signal already passes through raum's mix, so you would otherwise hear it twice. Both settings are restored when you leave the script.

## Grid

```
      1    2    3    4    5    6    7    8    9   10   11   12 | 13   14   15   16
 1  mix  pre  size decay damp bass diff bloom mod shim lcut hcut | snapshots 1-4
 2   |    |    |    |    |    |    |    |    |    |    |    |   | snapshots 5-8
 3   |    |    |    |    |    |    |    |    |    |    |    |   | snapshots 9-12
 4   faders: press a row to set the value (top = max)          | snapshots 13-16
 5   |    |    |    |    |    |    |    |    |    |    |    |   | arc page 1-4
 6   |    |    |    |    |    |    |    |    |    |    |    |   | click snare kick drums
 7   |    |    |    |    |    |    |    |    |    |    |    |   | blip pluck swell stab
 8  ROOM PLATE HALL CATH SHIM GATED WASH INF  LIVE TEST FILE FLUSH| FREEZE MORPH RANDOM ALT
```

**Faders (columns 1–12)**
- Each column is one parameter; press a row to jump to that value.
- The top of the fill shows the current value. A dim cell above it means the value lies between two rows.
- Faders lit faintly from the bottom also have a ring on the current arc page.

**Row 8, left side**
- **Presets 1–8** recall the preset and morph to it over the morph time. Hold ALT to recall instantly.
- **LIVE, TEST and FILE** switch each source on or off. They can all run at once.
- **ALT + LIVE** switches *nb into raum* on or off. **ALT + TEST** switches the test sounds between the raum voices and the nb voice. While ALT is held, these two keys show the nb settings.
- **FLUSH** clears the tail immediately.

**Snapshots (columns 13–16, rows 1–4)**
- Press a slot to recall it with morph. ALT + slot saves the current sound to it.
- Bright means current, medium means stored, dim means empty.
- Snapshots are kept in `dust/data/raum2/snapshots.data`.

**Arc pages (row 5)** choose which four parameters the arc controls. ALT + any key in this row opens page 5, DYNAMICS.

**Test sounds (rows 6–7)**
- Pressing a key selects the sound and plays it once, which is handy for auditioning a tail.
- With TEST on, the selected sound repeats in time with the norns clock.

**Row 8, right side**
- **FREEZE**: hold it for a momentary freeze. ALT + FREEZE latches it, and it blinks while latched. New input then plays dry over the frozen tail.
- **MORPH** cycles the morph time: off, 0.5 s, 2 s, 8 s, 1 bar, 4 bars. The key brightens while a morph runs.
- **RANDOM** gives a new random sound within musical ranges. ALT + RANDOM only nudges the current sound a little.
- **ALT** is a modifier: hold it while pressing another key.

## Arc

| page | ring 1 | ring 2 | ring 3 | ring 4 |
|---|---|---|---|---|
| 1 SPACE | decay | size | pre-delay | mix |
| 2 TONE | damping | bass | low cut | high cut |
| 3 MOTION | diffusion | bloom | mod depth | mod rate |
| 4 COLOUR | shimmer | shimmer interval | early reflections | width |
| 5 DYNAMICS | ducking | gate | input gain | output level |

- The rings light from 7 o'clock to 5 o'clock. The decay ring fades along its length, like a tail.
- The gap at the bottom of each ring shows the reverb level.
- During a freeze a dot circles every ring.
- Sensitivity is under PARAMETERS > CONTROL > arc sensitivity.

## norns

- **E1** changes page (same pages as the arc). **E2** selects one of the four parameters, **E3** changes it.
- **K2** latches or releases freeze. **K3** turns the test sounds on or off.

The screen shows:
- The current preset or snapshot. A `*` means it has been edited.
- Which sources are on: L (live), T (test), F (file), N (nb into raum).
- A sketch of the impulse response:
  - the dry hit;
  - the pre-delay gap;
  - the early reflections;
  - the bloom;
  - three decay lines: lows (dim), mids (bright) and highs (dim).

  Gate and freeze change the shape of the sketch.
- Input and reverb meters on the right.

## Parameters

| parameter | what it does |
|---|---|
| mix | dry/wet, equal power. At 100% raum works as a send effect. |
| pre-delay | 1 ms – 1 s before the reverb starts. *pre-delay sync* locks it to the clock (1/64 to 1/2 note). |
| size | scales the space: delay lines, early reflections and bloom (×0.25 – ×3). |
| decay | RT60 at mid frequencies, 0.1 – 60 s. |
| damping | frequency above which the tail decays about four times faster. |
| bass | multiplies the decay below about 250 Hz (×0.25 – ×4). |
| diffusion | low values give audible early echoes; high values give a smooth wash. |
| bloom | a slow, swelling onset. The reverb builds instead of starting at once. |
| mod depth / rate | slow movement of the delay lines. Removes metallic ringing; adds chorus at high depth. |
| early reflections | the first discrete echoes, which tell the ear how large the room is. |
| shimmer | feeds the tail back pitch-shifted (+12, +7, +5, +24, −12 or +19 semitones). |
| low cut / high cut | filter the reverb only; the dry signal is untouched. |
| width | 0 = mono reverb, 100% = natural, up to 200% = extra wide. |
| ducking | the louder the dry signal, the quieter the tail. The tail swells up in the gaps. |
| gate | cuts the tail this long after the input stops (0 = off). The classic 80s drum sound. |
| freeze | holds the tail indefinitely and stops new input entering it. |
| input gain / output level | trim, −24 to +12 dB in, −24 to +6 dB out. |
| sources | live input on/off and level; test sounds on/off (off at start), sound, rate and level; audio file, playback on/off and level. The nb settings are under NB VOICE, above. |

To use an audio file:
1. Put it in `dust/audio/`.
2. Choose it under PARAMETERS > SOURCES > audio file. It loops and switches FILE on.
3. Mono files play on both sides.

Every parameter can be mapped to MIDI with norns' built-in MAP: open PARAMETERS > MAP.

## Presets

1. **ROOM**: small, dense, strong early reflections.
2. **PLATE**: bright, smooth, no reflections, wide.
3. **HALL**: the default. Medium hall with warm lows.
4. **CATHEDRAL**: long, dark, slow bloom.
5. **SHIMMER**: an octave-up shimmer with a long bloom.
6. **GATED**: big room cut after 320 ms.
7. **DUCKED WASH**: tempo-synced pre-delay (1/8). The wash ducks under the playing and blooms in the gaps.
8. **INFINITE**: 45 s decay with a slight fifth shimmer. Pairs well with freeze.

## Test sounds

These are the test sounds from the earlier reverb patch, plus a chord stab and a drum loop. They cover a range of attacks and decays:

- **click**: instant attack, 3 ms long.
- **snare**: 1 ms attack, 150 ms.
- **kick**: 1 ms attack, 400 ms.
- **drums**: a 16th-note kick, snare and hat loop.
- **blip**: 5 ms attack, 80 ms.
- **pluck**: instant attack, about 1.5 s.
- **swell**: 0.8 s attack, 1 s release.
- **stab**: a minor chord, 2 ms attack, 250 ms.

## Files

- `raum2.lua`: the script.
- `lib/Engine_Raum2.sc`: the SuperCollider engine. It is an 8-line feedback delay network with a Hadamard matrix, a separate decay for lows and highs, early reflections, input diffusion, bloom, shimmer, freeze, ducking and gate, plus the nb capture.
- `lib/nb/`: the nb library by sixolet (github.com/sixolet/nb), included unchanged.

## Tested before shipping, not yet on hardware

**The engine**, offline in SuperCollider:
- Measured decay matches the setting within about 3% (1, 3 and 10 s; lows with bass ×2; highs with damping).
- No runaway at shimmer 100% with a 60 s decay.
- Freeze holds for 20 s.
- Gate, ducking, flush and the pre-delay gate timing work.
- The reverb comes out at about the same loudness as the dry signal.
- The left and right tails are decorrelated.

**The engine**, live in a norns-like context:
- Starts in 0.2 s.
- Every command, test voice, file loading and the polls work.
- It uses about 2% of one 2.8 GHz server core. My estimate for norns is roughly 15–25% of the CPU.

**raum 2's nb capture**, live with the real norns audio layout (the norns audio context, and a fake nb voice in its own group at the head of the default group, writing to the output like a mod):
- *nb into raum* off: the voice plays dry, with no reverb.
- On: the voice gets the reverb tail.
- At mix 0% it comes out at the same level as when dry, so it is never doubled. At 100% only the reverb remains.
- nb level 0 silences it; freeze keeps new nb notes out of the tail.
- Freeing the engine leaves no nodes behind.

**raum 2's script** with the real nb library and a fake voice mod:
- MIDI notes, velocity, note off, mod wheel and channel filter reach the voice.
- Changing the MIDI device releases held notes.
- All 8 test patterns play on the nb voice.
- The ALT keys, the N flag, PSET loading and cleanup stop all nb notes.
- With no voice mods installed, the voice list still loads and the script runs.
- The test sounds are off at start, and nothing plays until K3 or TEST.

**The script** ran with the real norns parameter libraries:
- params;
- grid, arc, keys and encoders;
- presets and morphing;
- snapshots;
- random and nudge;
- freeze;
- test sequencer timing;
- tempo-synced pre-delay;
- screen drawing;
- cleanup.

**Not yet confirmed:** behaviour on an actual norns, including the nb voice mods themselves, especially CPU load on the original (Pi CM3) hardware. If you hear crackles, lower *mod depth* and *shimmer* first; they are the heaviest parts.

## Files and license

- `lib/nb`: a copy of the nb library by sixolet (https://github.com/sixolet/nb), included so raum2 runs without extra installs; it keeps its own author's terms.
- `LICENSE`: GPL-3.0 for raum2's own files.
