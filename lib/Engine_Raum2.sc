// Engine_Raum2
// A stereo feedback-delay-network reverb for norns, with its own test sounds,
// that can also take nb voices (SuperCollider voices from nb mods) as input.
//
// Signal path
//   sources (live input, test voices, audio file, nb voices) -> source bus
//   -> input gain -> low cut -> freeze/flush gate -> pre-delay
//   -> early reflections (8 taps, scaled by size)            -> output
//   -> input diffusion (4 allpasses) -> bloom (3 long allpasses)
//   -> tank: 8 modulated delay lines, Hadamard feedback matrix,
//      separate decay for lows (bass) and highs (damping),
//      optional shimmer (pitch-shifted tail fed back in)     -> output
//   -> high cut, low cut, width, ducking, gate -> dry/wet -> limiter
//
// Decay is RT60 in seconds at mid frequencies. Bass multiplies the decay
// below about 250 Hz. Damping is the frequency above which the tail decays
// about four times faster, like air and soft surfaces in a real room. Freeze holds the tail indefinitely and stops new
// input entering the tank. Flush clears the tail.
//
// Polls: in_db (dry input level), wet_db (reverb level), both in dB.
//
// nb capture: nb voices from mods (emplaitress, doubledecker, ...) are SuperCollider
// synths that write straight to the norns output bus (bus 0) from the head of the
// default group, so they run before this engine's group. The capture synth sits at
// the head of the engine group, takes what is on bus 0 at that point, clears it, and
// sends it into the reverb's source bus. The reverb then writes dry + wet to bus 0.
// With capture off the synth is paused and nb voices play dry, as without raum.

Engine_Raum2 : CroneEngine {
	var <srcGroup, <srcBus, <pollBus, <fileBuf;
	var <verb, <live, <filePlayer, <nbCap;
	var <testAmp = 0.5;
	var voices;

	*new { arg context, doneCallback;
		^super.new(context, doneCallback);
	}

	alloc {
		var s = context.server;
		srcBus = Bus.audio(s, 2);
		pollBus = Bus.control(s, 2);
		fileBuf = Buffer.alloc(s, 64, 2);
		voices = [\raumClick, \raumSnare, \raumKick, \raumHat, \raumBlip, \raumPluck, \raumSwell, \raumStab];

		// --- BEGIN SYNTHDEFS ---
		// sources
		// nb capture: move whatever is on the output bus so far into the source bus
		SynthDef(\raum2NbCapture, {
			var bus = \bus.kr(0);
			var sig = In.ar(bus, 2);
			ReplaceOut.ar(bus, DC.ar(0) ! 2);
			Out.ar(\out.kr(0), sig * Lag.kr(\level.kr(1), 0.05));
		}).add;
		SynthDef(\raumLive, {
			var in = [In.ar(\inL.kr(0)), In.ar(\inR.kr(0))];
			Out.ar(\out.kr(0), in * Lag.kr(\level.kr(1), 0.05));
		}).add;
		SynthDef(\raumFile, {
			var b = \buf.kr(0);
			var sig = PlayBuf.ar(2, b, BufRateScale.kr(b), \t_reset.tr(0), 0, loop: 1);
			Out.ar(\out.kr(0), sig * Lag.kr(\level.kr(0), 0.05));
		}).add;

		// test voices: different attacks and decays, all free themselves
		SynthDef(\raumClick, {        // instant attack, 3 ms
			var env = EnvGen.ar(Env.perc(0, 0.003), doneAction: 2);
			Out.ar(\out.kr(0), Pan2.ar(HPF.ar(WhiteNoise.ar, 1000) * env, \pan.kr(0), \amp.kr(0.5) * 1.6));
		}).add;
		SynthDef(\raumSnare, {        // 1 ms attack, 150 ms
			var env = EnvGen.ar(Env.perc(0.001, 0.15, 1, -4), doneAction: 2);
			var sig = (BPF.ar(WhiteNoise.ar, 3000, 0.8) * 1.5) + (SinOsc.ar(190) * 0.3);
			Out.ar(\out.kr(0), Pan2.ar(sig * env, \pan.kr(0), \amp.kr(0.5) * 1.2));
		}).add;
		SynthDef(\raumKick, {         // 1 ms attack, 400 ms
			var env = EnvGen.ar(Env.perc(0.001, 0.4, 1, -6), doneAction: 2);
			var sig = SinOsc.ar(XLine.kr(140, 45, 0.12));
			Out.ar(\out.kr(0), Pan2.ar(sig * env, \pan.kr(0), \amp.kr(0.5) * 1.3));
		}).add;
		SynthDef(\raumHat, {          // 1 ms attack, 50 ms
			var env = EnvGen.ar(Env.perc(0.001, 0.05, 1, -6), doneAction: 2);
			Out.ar(\out.kr(0), Pan2.ar(HPF.ar(WhiteNoise.ar, 7000) * env, \pan.kr(0), \amp.kr(0.5) * 0.6));
		}).add;
		SynthDef(\raumBlip, {         // staccato synth: 5 ms attack, 80 ms
			var env = EnvGen.ar(Env.perc(0.005, 0.08), doneAction: 2);
			var sig = RLPF.ar(Pulse.ar(\freq.kr(440)), 2500, 0.3);
			Out.ar(\out.kr(0), Pan2.ar(sig * env, \pan.kr(0), \amp.kr(0.5) * 0.6));
		}).add;
		SynthDef(\raumPluck, {        // plucked string: instant attack, about 1.5 s
			var freq = \freq.kr(220);
			var sig = Pluck.ar(WhiteNoise.ar(0.5), Impulse.ar(0), 0.05, freq.reciprocal, 1.5, 0.3);
			DetectSilence.ar(sig, 0.0005, 0.1, doneAction: 2);
			Out.ar(\out.kr(0), Pan2.ar(sig, \pan.kr(0), \amp.kr(0.5) * 1.6));
		}).add;
		SynthDef(\raumSwell, {        // pad chord: 0.8 s attack, 1 s release
			var env = EnvGen.ar(Env([0, 1, 1, 0], [0.8, 0.4, 1.0], [2, 0, -2]), doneAction: 2);
			var sig = LPF.ar(Saw.ar(\freq.kr(220) * [1, 1.25, 1.5, 2.003]).sum, 1800);
			Out.ar(\out.kr(0), Pan2.ar(sig * env, \pan.kr(0), \amp.kr(0.5) * 0.24));
		}).add;
		SynthDef(\raumStab, {         // minor chord stab: 2 ms attack, 250 ms, filter sweep
			var env = EnvGen.ar(Env.perc(0.002, 0.25, 1, -5), doneAction: 2);
			var freq = \freq.kr(220);
			var sig = Saw.ar(freq * [1, 1.189, 1.498, 2.002]).sum;
			sig = RLPF.ar(sig, 300 + (env * 3200), 0.4);
			Out.ar(\out.kr(0), Pan2.ar(sig * env, \pan.kr(0), \amp.kr(0.5) * 0.25));
		}).add;

		// the reverb
		SynthDef(\raumVerb, {
			var dry = In.ar(\in.kr(0), 2) * Lag.kr(\inGain.kr(0), 0.05).dbamp;
			var mix = Lag.kr(\mix.kr(0.35).clip(0, 1), 0.05);
			var size = Lag.kr(\size.kr(1).clip(0.25, 3), 0.4);
			var decay = Lag.kr(\decay.kr(2.5).clip(0.1, 100), 0.2);
			var damp = Lag.kr(\damp.kr(6000).clip(300, 20000), 0.1);
			var bass = Lag.kr(\bass.kr(1).clip(0.2, 4), 0.1);
			var diff = Lag.kr(\diffusion.kr(0.8).clip(0, 1), 0.1);
			var bloom = Lag.kr(\bloom.kr(0).clip(0, 1), 0.1);
			var modDepth = Lag.kr(\modDepth.kr(0.3).clip(0, 1), 0.1);
			var modRate = Lag.kr(\modRate.kr(0.5).clip(0.01, 10), 0.1);
			var er = Lag.kr(\er.kr(0.3).clip(0, 1), 0.1);
			var shimmer = Lag.kr(\shimmer.kr(0).clip(0, 1), 0.1);
			var shimRatio = \shimRatio.kr(2).clip(0.25, 4);
			var freeze = Lag.kr(\freeze.kr(0).clip(0, 1), 0.08);
			var lowcut = Lag.kr(\lowcut.kr(60).clip(10, 2000), 0.1);
			var highcut = Lag.kr(\highcut.kr(12000).clip(500, 20000), 0.1);
			var width = Lag.kr(\width.kr(1).clip(0, 2), 0.1);
			var duck = Lag.kr(\duck.kr(0).clip(0, 1), 0.1);
			var gateTime = \gate.kr(0).clip(0, 4);
			var outLevel = Lag.kr(\outLevel.kr(0), 0.05).dbamp;
			var predelay = Lag.kr(\predelay.kr(0.02).clip(0, 2), 0.15);
			var flushG = LagUD.kr(1 - Trig1.kr(\t_flush.tr(0), 0.15), 0.005, 0.05);

			var erTimes = [0.0071, 0.0113, 0.0167, 0.0229, 0.0293, 0.0371, 0.0433, 0.0531];
			var erGains = [0.9, -0.8, 0.7, -0.62, 0.55, -0.48, 0.42, -0.36];
			var base = [0.0233, 0.0289, 0.0337, 0.0391, 0.0449, 0.0511, 0.0577, 0.0643];
			var hadamard = { |a|
				[1, 2, 4].do { |h|
					a = a.clump(h * 2).collect { |c|
						var l = c.keep(h), r = c.drop(h);
						(l + r) ++ (l - r)
					}.flatten;
				};
				a * 8.sqrt.reciprocal
			};
			var amp, x, pre, erSig, erOut, bl, times, modT, fb, lines, gH, gL, gD, low, high, shim, wet, mid, side;
			var duckG, gateG, open, dryG, wetG, out;

			amp = Amplitude.kr(dry.sum * 0.5, 0.005, 0.15);

			// input to the space
			x = HPF.ar(dry, lowcut) * (1 - freeze) * flushG;
			pre = DelayC.ar(x, 2.0, predelay);

			// early reflections, alternating sides
			erSig = erTimes.collect { |t, i| DelayL.ar(pre[i % 2], 0.2, t * size) * erGains[i] };
			erOut = [erSig[[0, 2, 4, 6]].sum, erSig[[1, 3, 5, 7]].sum] * 0.45;

			// input diffusion and bloom
			x = pre;
			[0.0047, 0.0036, 0.0127, 0.0093].do { |t, i|
				x = AllpassN.ar(x, 0.02, t * [1, 1.13], diff * 0.15 + 0.0001);
			};
			bl = x;
			[0.061, 0.083, 0.107].do { |t|
				bl = AllpassL.ar(bl, 0.4, t * size * [1, 1.07], bloom * 2 + 0.01);
			};
			x = (x * (1 - (bloom * 0.6))) + (bl * bloom);

			// tank: 8 delay lines with slow modulation
			times = base * size;
			modT = SinOsc.kr(modRate * [0.83, 1.0, 1.17, 0.91, 1.09, 0.77, 1.23, 0.97], [0, 0.7, 1.4, 2.1, 2.8, 3.5, 4.2, 4.9])
				+ (LFNoise2.kr(modRate * 0.7 ! 8) * 0.5);
			modT = times + (modT * modDepth * 0.0012 * size.sqrt);
			fb = LocalIn.ar(8);
			lines = DelayC.ar(fb + (x ! 4).flat, 0.25, (modT - ControlDur.ir).max(0.0005));

			// frequency-dependent decay: lows decay over decay * bass, highs are damped
			gH = 0.001 ** (times / decay);
			gL = 0.001 ** (times / (decay * bass));
			gH = gH + ((1 - gH) * freeze);
			gL = gL + ((1 - gL) * freeze);
			gD = 0.001 ** (times / (decay * 0.22));
			gD = gD + ((1 - gD) * freeze);
			low = OnePole.ar(lines, exp(-2pi * 250 / SampleRate.ir));
			high = lines - OnePole.ar(lines, exp(-2pi * damp / SampleRate.ir));
			lines = (lines * gH) + (low * (gL - gH)) + (high * (gD - gH));

			// shimmer: the tail, pitch shifted, goes back into the tank
			shim = PitchShift.ar(lines.sum * 0.35, 0.2, shimRatio, 0.005, 0.01);
			shim = HPF.ar(shim, 180) * (shimmer * 0.45 * (1 - freeze));
			LocalOut.ar(((hadamard.(lines) + (shim * [1, -1, 1, -1, -1, 1, -1, 1])) * 0.5).tanh * 2 * flushG);

			// output
			wet = [lines[[0, 2, 4, 6]].sum, lines[[1, 3, 5, 7]].sum] * 0.35;
			wet = wet + (erOut * er);
			wet = LPF.ar(HPF.ar(wet, lowcut), highcut);
			mid = (wet[0] + wet[1]) * 0.5;
			side = (wet[0] - wet[1]) * 0.5 * width;
			wet = [mid + side, mid - side];

			// ducking: the louder the dry signal, the quieter the tail
			duckG = 1 - (duck * ((amp.ampdb + 60) / 40).clip(0, 1));
			duckG = LagUD.kr(duckG, 0.03, 0.35);
			// gate: the tail is cut gateTime seconds after the input goes quiet (plus pre-delay)
			open = Sweep.kr(Impulse.kr(200) * (amp > -42.dbamp), 1) < gateTime;
			open = DelayN.kr(open, 2.0, predelay);   // the gate times the tail, not the pre-delay gap
			gateG = Select.kr(gateTime > 0.001, [1, LagUD.kr(open, 0.001, 0.04)]);
			wet = wet * duckG * gateG * flushG;

			dryG = (mix * 0.5pi).cos;
			wetG = (mix * 0.5pi).sin;
			// only the reverb goes through the limiter (its look-ahead adds a few ms); the dry signal stays undelayed
			out = (dry * dryG * outLevel) + Limiter.ar(LeakDC.ar(wet * wetG * outLevel, 0.9995), 0.95, 0.0015);
			out = out.clip2(1);
			Out.kr(\pollBus.kr(0), [
				(amp + 1e-5).ampdb,
				(Amplitude.kr(wet.sum * 0.5 * wetG, 0.01, 0.2) + 1e-5).ampdb
			]);
			Out.ar(\out.kr(0), out);
		}).add;
		// --- END SYNTHDEFS ---

		s.sync;

		srcGroup = Group.new(context.xg, \addToHead);
		live = Synth.new(\raumLive, [\inL, context.in_b[0].index, \inR, context.in_b[1].index, \out, srcBus.index], srcGroup);
		filePlayer = Synth.new(\raumFile, [\buf, fileBuf, \out, srcBus.index], srcGroup);
		nbCap = Synth.new(\raum2NbCapture, [\bus, context.out_b.index, \out, srcBus.index], context.xg, \addToHead);
		nbCap.run(false);
		verb = Synth.new(\raumVerb, [\in, srcBus.index, \out, context.out_b.index, \pollBus, pollBus.index], context.xg, \addToTail);

		// --- commands ---
		[
			[\in_gain, \inGain], [\mix, \mix], [\predelay, \predelay], [\size, \size], [\decay, \decay],
			[\damp, \damp], [\bass, \bass], [\diffusion, \diffusion], [\bloom, \bloom],
			[\mod_depth, \modDepth], [\mod_rate, \modRate], [\er, \er], [\shimmer, \shimmer],
			[\shimmer_ratio, \shimRatio], [\freeze, \freeze], [\lowcut, \lowcut], [\highcut, \highcut],
			[\width, \width], [\duck, \duck], [\gate, \gate], [\out_level, \outLevel]
		].do { |p|
			this.addCommand(p[0], "f", { arg msg; verb.set(p[1], msg[1]) });
		};
		this.addCommand("flush", "", { verb.set(\t_flush, 1) });
		this.addCommand("live_level", "f", { arg msg; live.set(\level, msg[1]) });
		this.addCommand("file_level", "f", { arg msg; filePlayer.set(\level, msg[1]) });
		this.addCommand("file", "s", { arg msg; this.loadFile(msg[1].asString) });
		this.addCommand("nb_on", "i", { arg msg; nbCap.run(msg[1] > 0) });
		this.addCommand("nb_level", "f", { arg msg; nbCap.set(\level, msg[1]) });
		this.addCommand("test_level", "f", { arg msg; testAmp = msg[1] });
		// test voice: index 1-8 (click, snare, kick, hat, blip, pluck, swell, stab), frequency, pan
		this.addCommand("trig", "iff", { arg msg;
			var v = voices[(msg[1] - 1).clip(0, voices.size - 1)];
			Synth.new(v, [\out, srcBus.index, \freq, msg[2], \pan, msg[3].clip(-1, 1), \amp, testAmp], srcGroup, \addToTail);
		});

		// --- polls ---
		this.addPoll(\in_db, { pollBus.getnSynchronous(2)[0] });
		this.addPoll(\wet_db, { pollBus.getnSynchronous(2)[1] });
	}

	// load a sound file (mono or stereo) and loop it from the start
	loadFile { arg path;
		var s = context.server, nch = 2;
		if(File.exists(path).not) { ("Raum2: file not found " ++ path).postln; ^this };
		SoundFile.use(path, { |f| nch = f.numChannels });
		Buffer.readChannel(s, path, channels: if(nch > 1) { [0, 1] } { [0, 0] }, action: { |b|
			var old = fileBuf;
			fileBuf = b;
			filePlayer.set(\buf, b, \t_reset, 1);
			old.free;
		});
	}

	free {
		[verb, live, filePlayer, nbCap, srcGroup].do(_.free);
		fileBuf.free;
		[srcBus, pollBus].do(_.free);
	}
}
