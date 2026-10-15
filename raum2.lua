-- raum 2
-- stereo reverb for norns,
-- grid 128 and arc 4,
-- with nb voices as input
--
-- E1 page  E2 select  E3 value
-- K2 freeze  K3 test sounds
--
-- GRID
-- cols 1-12: faders
--   mix, pre-delay, size,
--   decay, damping, bass,
--   diffusion, bloom, mod,
--   shimmer, low cut, high cut
-- row 8: presets 1-8, live,
--   test, file, flush
--   ALT+live: nb input
--   ALT+test: test sounds
--   on raum voices / nb voice
-- cols 13-16: snapshots,
--   arc pages, test sounds,
--   freeze, morph, random, ALT
--
-- ARC: four parameters of
-- the current page

engine.name = "Raum2"

-- nb (nota bene): bundled in lib/nb, or an installed copy in dust/code/nb
local nb
for _, path in ipairs({"lib/nb/lib/nb", "nb/lib/nb"}) do
  local ok, lib = pcall(include, path)
  if ok and type(lib) == "table" then nb = lib; break end
end

---------------------------------------------------------------------------
-- tables
---------------------------------------------------------------------------
local FADERS = {"mix", "predelay", "size", "decay", "damp", "bass", "diffusion", "bloom", "mod_depth", "shimmer", "lowcut", "highcut"}
local PAGES = {
  {name = "SPACE", ids = {"decay", "size", "predelay", "mix"}},
  {name = "TONE", ids = {"damp", "bass", "lowcut", "highcut"}},
  {name = "MOTION", ids = {"diffusion", "bloom", "mod_depth", "mod_rate"}},
  {name = "COLOUR", ids = {"shimmer", "shimmer_interval", "er", "width"}},
  {name = "DYNAMICS", ids = {"duck", "gate", "in_gain", "out_level"}},
}
local LABEL = {
  mix = "mix", predelay = "pre", size = "size", decay = "decay", damp = "damping", bass = "bass",
  diffusion = "diffusion", bloom = "bloom", mod_depth = "mod depth", mod_rate = "mod rate", er = "early refl",
  shimmer = "shimmer", shimmer_interval = "interval", lowcut = "low cut", highcut = "high cut", width = "width",
  duck = "ducking", gate = "gate", in_gain = "input", out_level = "output",
}
local SOUND_PARAMS = {"mix", "predelay", "predelay_sync", "size", "decay", "damp", "bass", "diffusion", "bloom",
  "mod_depth", "mod_rate", "er", "shimmer", "shimmer_interval", "lowcut", "highcut", "width", "duck", "gate"}

local INTERVALS = {"octave up", "fifth up", "fourth up", "2 octaves up", "octave down", "oct + fifth"}
local INTERVAL_SHORT = {"+12", "+7", "+5", "+24", "-12", "+19"}
local RATIOS = {2, 1.4983, 1.3348, 4, 0.5, 2.9966}
local SYNC = {"off", "1/64", "1/32", "1/16", "1/8", "1/8 dot", "1/4", "1/4 dot", "1/2"}
local SYNC_BEATS = {0, 1 / 16, 1 / 8, 1 / 4, 1 / 2, 3 / 4, 1, 1.5, 2}
local MORPH = {"off", "0.5 s", "2 s", "8 s", "1 bar", "4 bars"}
local SOUNDS = {"click", "snare", "kick", "drums", "blip", "pluck", "swell", "stab"}
local VOICE = {click = 1, snare = 2, kick = 3, hat = 4, blip = 5, pluck = 6, swell = 7, stab = 8}
local RATES = {"1/4", "1/2", "1 bar", "2 bars", "4 bars"}
local RATE_STEPS = {4, 8, 16, 32, 64}     -- in 16th notes
local SCALE = {57, 60, 62, 64, 67, 69, 72, 74}
local ER_TIMES = {0.0071, 0.0113, 0.0167, 0.0229, 0.0293, 0.0371, 0.0433, 0.0531}

local PRESETS = {
  {name = "ROOM", v = {mix = 0.25, predelay = 6, size = 0.45, decay = 0.8, damp = 7000, bass = 1.1, diffusion = 0.75,
    bloom = 0, mod_depth = 0.15, mod_rate = 0.4, er = 0.7, shimmer = 0, lowcut = 80, highcut = 12000, width = 1, duck = 0, gate = 0}},
  {name = "PLATE", v = {mix = 0.3, predelay = 12, size = 0.8, decay = 2.2, damp = 12000, bass = 0.8, diffusion = 1,
    bloom = 0, mod_depth = 0.35, mod_rate = 0.7, er = 0, shimmer = 0, lowcut = 150, highcut = 16000, width = 1.3, duck = 0, gate = 0}},
  {name = "HALL", v = {mix = 0.35, predelay = 28, size = 1.6, decay = 3.2, damp = 5500, bass = 1.3, diffusion = 0.85,
    bloom = 0.15, mod_depth = 0.35, mod_rate = 0.4, er = 0.4, shimmer = 0, lowcut = 60, highcut = 11000, width = 1.1, duck = 0, gate = 0}},
  {name = "CATHEDRAL", v = {mix = 0.45, predelay = 60, size = 2.6, decay = 8.5, damp = 3500, bass = 1.6, diffusion = 0.9,
    bloom = 0.45, mod_depth = 0.4, mod_rate = 0.3, er = 0.3, shimmer = 0, lowcut = 40, highcut = 8000, width = 1.2, duck = 0, gate = 0}},
  {name = "SHIMMER", v = {mix = 0.5, predelay = 40, size = 2.2, decay = 9, damp = 7000, bass = 0.7, diffusion = 1,
    bloom = 0.6, mod_depth = 0.5, mod_rate = 0.5, er = 0.1, shimmer = 0.55, shimmer_interval = 1, lowcut = 250, highcut = 13000,
    width = 1.5, duck = 0, gate = 0}},
  {name = "GATED", v = {mix = 0.45, predelay = 1, size = 1.2, decay = 2.5, damp = 9000, bass = 1, diffusion = 1,
    bloom = 0, mod_depth = 0.2, mod_rate = 0.5, er = 0.6, shimmer = 0, lowcut = 120, highcut = 14000, width = 1.2, duck = 0, gate = 0.32}},
  {name = "DUCKED WASH", v = {mix = 0.55, predelay = 120, predelay_sync = 5, size = 2.4, decay = 6, damp = 4500, bass = 1.2,
    diffusion = 0.9, bloom = 0.3, mod_depth = 0.5, mod_rate = 0.3, er = 0.2, shimmer = 0, lowcut = 100, highcut = 9000,
    width = 1.6, duck = 0.7, gate = 0}},
  {name = "INFINITE", v = {mix = 0.6, predelay = 80, size = 2.8, decay = 45, damp = 3000, bass = 1.4, diffusion = 1,
    bloom = 0.85, mod_depth = 0.7, mod_rate = 0.2, er = 0, shimmer = 0.15, shimmer_interval = 2, lowcut = 80, highcut = 7000,
    width = 1.4, duck = 0, gate = 0}},
}

---------------------------------------------------------------------------
-- state
---------------------------------------------------------------------------
local g = grid.connect()
local a = arc.connect()
local page, sel = 1, 1
local alt = false
local freeze_latched, freeze_held = false, false
local flush_held = false
local snapshots = {}
local current = {name = "HALL", kind = "preset", index = 3}
local edited = false
local morph_clock, morph_progress = nil, nil
local in_db, wet_db = -90, -90
local test_step = 0
local flash = {}            -- grid flash timers: key "x,y" -> time
local arc_acc = {0, 0, 0, 0}
local message, message_t = nil, 0
local saved_sys = {}
local midi_in = nil         -- connected MIDI input device (plays the nb voice)
local midi_held = {}        -- notes held from MIDI, to release on device change

local function now() return util.time() end
local function msg(t) message = t; message_t = now() end
local function p(id) return params:lookup_param(id) end
local function is_option(id) return p(id).t == params.tOPTION end

---------------------------------------------------------------------------
-- engine helpers
---------------------------------------------------------------------------
local function send_predelay()
  local s = params:get("predelay_sync")
  local secs = s > 1 and SYNC_BEATS[s] * clock.get_beat_sec() or params:get("predelay") / 1000
  engine.predelay(util.clamp(secs, 0, 2))
end
local function send_live()
  engine.live_level(params:get("live_on") == 2 and util.dbamp(params:get("live_level")) or 0)
end
local function send_nb()
  if not nb then engine.nb_on(0); return end
  engine.nb_on(params:get("nb_in") == 2 and 1 or 0)
  engine.nb_level(util.dbamp(params:get("nb_level")))
end
local function nb_player()
  if not nb then return nil end
  return params:lookup_param("nb_voice"):get_player()
end
local function send_file()
  engine.file_level(params:get("file_on") == 2 and util.dbamp(params:get("file_level")) or 0)
end
local function file_loaded()
  local f = params:get("file")
  return f and f ~= "" and f ~= "-" and string.sub(f, -1) ~= "/"
end

---------------------------------------------------------------------------
-- MIDI in > nb voice
---------------------------------------------------------------------------
local function release_midi_notes()
  local pl = nb_player()
  if pl then for n in pairs(midi_held) do pl:note_off(n) end end
  midi_held = {}
end

local function midi_event(data)
  local m = midi.to_msg(data)
  local ch = params:get("nb_midi_ch") - 1
  if ch > 0 and m.ch ~= ch then return end
  local pl = nb_player(); if not pl then return end
  if m.type == "note_on" and m.vel > 0 then
    pl:note_on(m.note, m.vel / 127); midi_held[m.note] = true
  elseif m.type == "note_off" or (m.type == "note_on" and m.vel == 0) then
    pl:note_off(m.note); midi_held[m.note] = nil
  elseif m.type == "cc" and m.cc == 1 then
    pl:modulate(m.val / 127)
  elseif m.type == "cc" and (m.cc == 123 or m.cc == 120) then
    release_midi_notes()
  end
end

local function connect_midi_in(port)
  release_midi_notes()
  if midi_in then midi_in.event = nil; midi_in = nil end
  if port and port > 0 then
    midi_in = midi.connect(port)
    midi_in.event = midi_event
  end
end

---------------------------------------------------------------------------
-- params
---------------------------------------------------------------------------
local function fmt_pct(param) return string.format("%d%%", math.floor(param:get() * 100 + 0.5)) end
local function fmt_hz(param)
  local v = param:get()
  return v >= 1000 and string.format("%.1fk", v / 1000) or string.format("%d", math.floor(v + 0.5))
end
local function fmt_s(param)
  local v = param:get()
  return v < 10 and string.format("%.2f s", v) or string.format("%.1f s", v)
end
local function fmt_ms(param)
  local v = param:get()
  return v < 10 and string.format("%.1f ms", v) or string.format("%d ms", math.floor(v + 0.5))
end
local function fmt_x(param) return string.format("x%.2f", param:get()) end
local function fmt_gate(param) local v = param:get(); return v < 0.01 and "off" or string.format("%d ms", math.floor(v * 1000 + 0.5)) end

local function add_control(id, name, spec, fmt, action)
  params:add_control(id, name, spec, fmt)
  params:set_action(id, action)
end

local function add_params()
  params:add_separator("raum_sep", "RAUM")

  params:add_group("raum_space", "SPACE", 6)
  add_control("mix", "mix", controlspec.new(0, 1, "lin", 0, 0.35), fmt_pct, function(v) engine.mix(v) end)
  add_control("predelay", "pre-delay", controlspec.new(1, 1000, "exp", 0, 28, "ms"), fmt_ms, function() send_predelay() end)
  params:add_option("predelay_sync", "pre-delay sync", SYNC, 1)
  params:set_action("predelay_sync", function() send_predelay() end)
  add_control("size", "size", controlspec.new(0.25, 3, "exp", 0, 1.6), fmt_x, function(v) engine.size(v) end)
  add_control("decay", "decay", controlspec.new(0.1, 60, "exp", 0, 3.2, "s"), fmt_s, function(v) engine.decay(v) end)
  add_control("er", "early reflections", controlspec.new(0, 1, "lin", 0, 0.4), fmt_pct, function(v) engine.er(v) end)

  params:add_group("raum_tone", "TONE", 5)
  add_control("damp", "damping", controlspec.new(300, 20000, "exp", 0, 5500, "Hz"), fmt_hz, function(v) engine.damp(v) end)
  add_control("bass", "bass decay", controlspec.new(0.25, 4, "exp", 0, 1.3), fmt_x, function(v) engine.bass(v) end)
  add_control("lowcut", "low cut", controlspec.new(20, 1000, "exp", 0, 60, "Hz"), fmt_hz, function(v) engine.lowcut(v) end)
  add_control("highcut", "high cut", controlspec.new(1000, 20000, "exp", 0, 11000, "Hz"), fmt_hz, function(v) engine.highcut(v) end)
  add_control("width", "width", controlspec.new(0, 2, "lin", 0, 1.1), fmt_pct, function(v) engine.width(v) end)

  params:add_group("raum_motion", "MOTION", 6)
  add_control("diffusion", "diffusion", controlspec.new(0, 1, "lin", 0, 0.85), fmt_pct, function(v) engine.diffusion(v) end)
  add_control("bloom", "bloom", controlspec.new(0, 1, "lin", 0, 0.15), fmt_pct, function(v) engine.bloom(v) end)
  add_control("mod_depth", "mod depth", controlspec.new(0, 1, "lin", 0, 0.35), fmt_pct, function(v) engine.mod_depth(v) end)
  add_control("mod_rate", "mod rate", controlspec.new(0.05, 5, "exp", 0, 0.4, "Hz"),
    function(param) return string.format("%.2f Hz", param:get()) end, function(v) engine.mod_rate(v) end)
  add_control("shimmer", "shimmer", controlspec.new(0, 1, "lin", 0, 0), fmt_pct, function(v) engine.shimmer(v) end)
  params:add_option("shimmer_interval", "shimmer interval", INTERVALS, 1)
  params:set_action("shimmer_interval", function(v) engine.shimmer_ratio(RATIOS[v]) end)

  params:add_group("raum_dyn", "DYNAMICS / LEVELS", 6)
  add_control("duck", "ducking", controlspec.new(0, 1, "lin", 0, 0), fmt_pct, function(v) engine.duck(v) end)
  add_control("gate", "gate", controlspec.new(0, 1.5, "lin", 0, 0, "s"), fmt_gate, function(v) engine.gate(v) end)
  params:add_binary("freeze", "freeze", "toggle", 0)
  params:set_action("freeze", function(v) engine.freeze(v) end)
  params:add_trigger("flush", "flush tail")
  params:set_action("flush", function() engine.flush() end)
  add_control("in_gain", "input gain", controlspec.new(-24, 12, "lin", 0, 0, "dB"), nil, function(v) engine.in_gain(v) end)
  add_control("out_level", "output level", controlspec.new(-24, 6, "lin", 0, 0, "dB"), nil, function(v) engine.out_level(v) end)

  params:add_group("raum_src", "SOURCES", 9)
  params:add_option("live_on", "live input", {"off", "on"}, 2)
  params:set_action("live_on", send_live)
  params:add_control("live_level", "live level", controlspec.new(-60, 6, "db", 0, 0, "dB"))
  params:set_action("live_level", send_live)
  params:add_option("test_on", "test sounds", {"off", "on"}, 1)
  params:add_option("test_sound", "test sound", SOUNDS, 6)
  params:add_option("test_rate", "test rate", RATES, 3)
  params:add_control("test_level", "test level", controlspec.new(-36, 6, "lin", 0, -6, "dB"))
  params:set_action("test_level", function(v) engine.test_level(util.dbamp(v)) end)
  params:add_file("file", "audio file", _path.audio)
  params:set_action("file", function(f)
    if f and f ~= "" and f ~= "-" and string.sub(f, -1) ~= "/" then
      engine.file(f); params:set("file_on", 2)
    end
  end)
  params:add_option("file_on", "file playback", {"off", "on"}, 1)
  params:set_action("file_on", send_file)
  params:add_control("file_level", "file level", controlspec.new(-60, 6, "db", 0, 0, "dB"))
  params:set_action("file_level", send_file)

  params:add_group("raum_nb", "NB VOICE", nb and 7 or 1)
  if nb then
    nb:add_param("nb_voice", "nb voice")
    params:add_option("nb_in", "nb into raum", {"off", "on"}, 2)
    params:set_action("nb_in", send_nb)
    params:add_control("nb_level", "nb level", controlspec.new(-60, 12, "db", 0, 0, "dB"))
    params:set_action("nb_level", send_nb)
    params:add_option("test_voice", "test sounds play", {"raum voices", "nb voice"}, 1)
    local devs = {"off"}
    for i = 1, 16 do
      local v = midi.vports[i]
      table.insert(devs, i .. ": " .. ((v and v.name and v.name ~= "none") and string.sub(v.name, 1, 14) or "none"))
    end
    params:add_option("nb_midi_in", "MIDI in > nb", devs, 1)
    params:set_action("nb_midi_in", function(v) connect_midi_in(v - 1) end)
    local chans = {"omni"}
    for c = 1, 16 do table.insert(chans, tostring(c)) end
    params:add_option("nb_midi_ch", "MIDI channel", chans, 1)
  else
    params:add_text("nb_missing", "nb not found", "see README")
  end

  params:add_group("raum_ctl", "CONTROL", 2)
  params:add_option("morph_time", "morph time", MORPH, 2)
  params:add_option("arc_sens", "arc sensitivity", {"fine", "normal", "coarse"}, 2)
end

---------------------------------------------------------------------------
-- presets, snapshots, morphing
---------------------------------------------------------------------------
local function capture()
  local t = {}
  for _, id in ipairs(SOUND_PARAMS) do t[id] = params:get(id) end
  return t
end

local function preset_values(i)
  local t = {predelay_sync = 1, shimmer_interval = 1}
  for k, v in pairs(PRESETS[i].v) do t[k] = v end
  return t
end

local function morph_seconds()
  local m = params:get("morph_time")
  local beats = ({0, 0, 0, 0, 4, 16})[m]
  if beats > 0 then return beats * clock.get_beat_sec() end
  return ({0, 0.5, 2, 8})[m] or 0
end

local function apply(target, instant)
  if morph_clock then clock.cancel(morph_clock); morph_clock = nil; morph_progress = nil end
  local secs = instant and 0 or morph_seconds()
  if secs < 0.05 then
    for id, v in pairs(target) do if params.lookup[id] then params:set(id, v) end end
    return
  end
  local from, to, opts = {}, {}, {}
  for id, v in pairs(target) do
    if params.lookup[id] then
      if is_option(id) then opts[id] = v
      else from[id] = params:get_raw(id); to[id] = p(id).controlspec:unmap(v) end
    end
  end
  morph_clock = clock.run(function()
    local t0 = now()
    local switched = false
    while true do
      local f = util.clamp((now() - t0) / secs, 0, 1)
      morph_progress = f
      local e = f * f * (3 - 2 * f)     -- smooth in and out
      for id, r in pairs(to) do params:set_raw(id, from[id] + (r - from[id]) * e) end
      if not switched and f >= 0.5 then
        for id, v in pairs(opts) do params:set(id, v) end
        switched = true
      end
      if f >= 1 then break end
      clock.sleep(1 / 30)
    end
    for id, v in pairs(target) do if params.lookup[id] then params:set(id, v) end end
    morph_clock = nil; morph_progress = nil
  end)
end

local function recall_preset(i, instant)
  apply(preset_values(i), instant)
  current = {name = PRESETS[i].name, kind = "preset", index = i}; edited = false
  msg(PRESETS[i].name)
end

local function snap_path() return norns.state.data .. "snapshots.data" end
local function save_snapshots()
  local ok = pcall(function()
    if util.make_dir then util.make_dir(norns.state.data) end
    tab.save(snapshots, snap_path())
  end)
  return ok
end
local function load_snapshots()
  local ok, t = pcall(tab.load, snap_path())
  if ok and type(t) == "table" then snapshots = t end
end

local function store_snapshot(i)
  snapshots[i] = capture()
  save_snapshots()
  current = {name = "SNAP " .. i, kind = "snap", index = i}; edited = false
  msg("saved snapshot " .. i)
end
local function recall_snapshot(i, instant)
  if not snapshots[i] then msg("snapshot " .. i .. " is empty"); return end
  apply(snapshots[i], instant)
  current = {name = "SNAP " .. i, kind = "snap", index = i}; edited = false
  msg("snapshot " .. i)
end

local function randomize(nudge)
  local t = {}
  if nudge then
    for _, id in ipairs(SOUND_PARAMS) do
      if not is_option(id) and id ~= "mix" and id ~= "duck" and id ~= "gate" then
        local r = util.clamp(params:get_raw(id) + (math.random() - 0.5) * 0.16, 0, 1)
        t[id] = p(id).controlspec:map(r)
      end
    end
    msg("nudge")
  else
    local function exp_rand(lo, hi) return lo * (hi / lo) ^ math.random() end
    local function lin_rand(lo, hi) return lo + (hi - lo) * math.random() end
    t = {predelay = exp_rand(1, 150), predelay_sync = 1, size = exp_rand(0.4, 2.8), decay = exp_rand(0.5, 12),
      damp = exp_rand(2000, 14000), bass = exp_rand(0.6, 2), diffusion = lin_rand(0.5, 1), bloom = lin_rand(0, 0.8),
      mod_depth = lin_rand(0.1, 0.7), mod_rate = exp_rand(0.1, 2), er = lin_rand(0, 0.7),
      shimmer = math.random() < 0.3 and lin_rand(0.2, 0.6) or 0, shimmer_interval = math.random(1, 3),
      lowcut = exp_rand(30, 250), highcut = exp_rand(5000, 16000), width = lin_rand(0.8, 1.7)}
    msg("random")
  end
  apply(t)
  edited = true
end

---------------------------------------------------------------------------
-- user changes (grid, arc, encoders): marks the sound as edited
---------------------------------------------------------------------------
local function user_set_raw(id, r)
  if morph_clock then clock.cancel(morph_clock); morph_clock = nil; morph_progress = nil end
  if id == "predelay" then params:set("predelay_sync", 1) end
  params:set_raw(id, r)
  edited = true
end
local function user_delta(id, d)
  if morph_clock then clock.cancel(morph_clock); morph_clock = nil; morph_progress = nil end
  if id == "predelay" and params:get("predelay_sync") > 1 then params:set("predelay_sync", 1) end
  params:delta(id, d)
  if id ~= "in_gain" and id ~= "out_level" then edited = true end
end

local function set_freeze()
  params:set("freeze", (freeze_latched or freeze_held) and 1 or 0)
end

---------------------------------------------------------------------------
-- test sounds
---------------------------------------------------------------------------
local function note(m) return 440 * 2 ^ ((m - 69) / 12) end
local function flash_key(x, y) flash[x .. "," .. y] = now() end

-- the test patterns played on the nb voice: drums as GM drum notes, the rest
-- from the same scale as the raum voices, with lengths in beats
local function nb_chord(root, n, len, vel)
  local pl = nb_player(); if not pl then return end
  local deg = math.random(1, 3)
  for k = 0, n - 1 do pl:play_note(SCALE[deg + k * 2] + root, vel, len) end
end
local function play_nb(name, step)
  local pl = nb_player(); if not pl then return end
  if name == "drums" then
    local s = step % 16
    if s == 0 or s == 6 or s == 10 then pl:play_note(36, 0.9, 1 / 8) end
    if s == 4 or s == 12 then pl:play_note(38, 0.8, 1 / 8) end
    if s % 2 == 0 then pl:play_note(42, 0.45, 1 / 16) end
  elseif name == "click" then pl:play_note(84, 0.6, 1 / 16)
  elseif name == "snare" then pl:play_note(38, 0.8, 1 / 8)
  elseif name == "kick" then pl:play_note(36, 0.9, 1 / 8)
  elseif name == "swell" then nb_chord(-12, 3, 2, 0.5)
  elseif name == "stab" then nb_chord(-12, 3, 1 / 4, 0.75)
  elseif name == "pluck" then pl:play_note(SCALE[math.random(1, #SCALE)] - 12, 0.8, 1 / 2)
  else pl:play_note(SCALE[math.random(1, #SCALE)], 0.7, 1 / 8) end
end

local function play_sound(name, step)
  step = step or 0
  if nb and params:get("test_voice") == 2 then return play_nb(name, step) end
  if name == "drums" then
    local s = step % 16
    if s == 0 or s == 6 or s == 10 then engine.trig(VOICE.kick, 50, 0) end
    if s == 4 or s == 12 then engine.trig(VOICE.snare, 200, 0) end
    if s % 2 == 0 then engine.trig(VOICE.hat, 0, (math.random() - 0.5) * 0.3) end
  elseif name == "click" or name == "snare" or name == "kick" then
    engine.trig(VOICE[name], 100, 0)
  elseif name == "swell" then
    engine.trig(VOICE.swell, note(SCALE[math.random(1, 4)] - 12), (math.random() - 0.5) * 0.4)
  elseif name == "stab" then
    engine.trig(VOICE.stab, note(SCALE[math.random(1, 5)] - 12), (math.random() - 0.5) * 0.4)
  else
    engine.trig(VOICE[name], note(SCALE[math.random(1, #SCALE)] - (name == "pluck" and 12 or 0)), (math.random() - 0.5) * 0.8)
  end
end

local function sound_key(i) return 12 + ((i - 1) % 4) + 1, i <= 4 and 6 or 7 end

local function test_tick()
  if params:get("test_on") ~= 2 then return end
  local i = params:get("test_sound")
  local name = SOUNDS[i]
  if name == "drums" then
    play_sound(name, test_step)
    if test_step % 4 == 0 then flash_key(sound_key(i)) end
  elseif test_step % RATE_STEPS[params:get("test_rate")] == 0 then
    play_sound(name, test_step); flash_key(sound_key(i))
  end
end

---------------------------------------------------------------------------
-- grid
---------------------------------------------------------------------------
local function on_page(id)
  for _, pid in ipairs(PAGES[page].ids) do if pid == id then return true end end
  return false
end

local function grid_redraw()
  g:all(0)
  local t = now()
  -- faders
  for c, id in ipairs(FADERS) do
    local r = params:get_raw(id) * 6                 -- 0..6, row 7 = 0, row 1 = 6
    local head = math.floor(r + 0.5)
    local base = on_page(id) and 1 or 0
    for row = 1, 7 do
      local level = 7 - row                           -- 0..6
      local l = base
      if level < head then l = 4
      elseif level == head then l = 13 end
      if level == head + 1 and r - head > 0.25 then l = math.max(l, 2) end
      g:led(c, row, l)
    end
  end
  -- row 8: presets, sources, flush
  for i = 1, 8 do
    local l = 3
    if current.kind == "preset" and current.index == i then l = edited and 8 or 13 end
    g:led(i, 8, l)
  end
  if alt and nb then
    -- ALT shows the nb state on these keys
    g:led(9, 8, params:get("nb_in") == 2 and 11 or 2)
    g:led(10, 8, params:get("test_voice") == 2 and 11 or 2)
  else
    g:led(9, 8, params:get("live_on") == 2 and 11 or 2)
    g:led(10, 8, params:get("test_on") == 2 and 11 or 2)
  end
  g:led(11, 8, params:get("file_on") == 2 and 11 or (file_loaded() and 3 or 1))
  g:led(12, 8, flush_held and 15 or 4)
  -- snapshots
  for i = 1, 16 do
    local x, y = 12 + ((i - 1) % 4) + 1, math.floor((i - 1) / 4) + 1
    local l = snapshots[i] and 5 or 1
    if current.kind == "snap" and current.index == i then l = edited and 9 or 14 end
    g:led(x, y, l)
  end
  -- arc pages
  for i = 1, 4 do g:led(12 + i, 5, page == i and 12 or 3) end
  if page == 5 then for i = 1, 4 do g:led(12 + i, 5, 6) end end
  -- test sounds
  local ts = params:get("test_sound")
  for i = 1, 8 do
    local x, y = sound_key(i)
    local l = (i == ts) and 10 or 3
    local f = flash[x .. "," .. y]
    if f and t - f < 0.12 then l = 15 end
    g:led(x, y, l)
  end
  -- row 8 right: freeze, morph, random, alt
  local fz = params:get("freeze") == 1
  g:led(13, 8, fz and (freeze_latched and (math.floor(t * 3) % 2 == 0 and 15 or 9) or 15) or 4)
  local mt = params:get("morph_time")
  g:led(14, 8, morph_progress and math.floor(4 + morph_progress * 11) or (mt == 1 and 2 or 3 + mt))
  g:led(15, 8, 4)
  g:led(16, 8, alt and 15 or 5)
  g:refresh()
end

g.key = function(x, y, z)
  if x == 16 and y == 8 then alt = (z == 1); return end
  if x == 13 and y == 8 then
    if z == 1 then
      if alt then freeze_latched = not freeze_latched; msg(freeze_latched and "freeze latched" or "freeze off")
      else freeze_held = true end
    else freeze_held = false end
    set_freeze(); return
  end
  if x == 12 and y == 8 then
    flush_held = (z == 1)
    if z == 1 then params:set("flush", 1); msg("flush") end
    return
  end
  if z == 0 then return end

  if x <= 12 and y <= 7 then
    user_set_raw(FADERS[x], (7 - y) / 6)
  elseif x <= 8 and y == 8 then
    recall_preset(x, alt)
  elseif x == 9 and y == 8 and alt then
    if not nb then msg("nb not found") return end
    params:set("nb_in", params:get("nb_in") == 2 and 1 or 2)
    msg(params:get("nb_in") == 2 and "nb into raum" or "nb dry")
  elseif x == 10 and y == 8 and alt then
    if not nb then msg("nb not found") return end
    params:set("test_voice", params:get("test_voice") == 2 and 1 or 2)
    msg(params:get("test_voice") == 2 and "test on nb voice" or "test on raum voices")
  elseif x == 9 and y == 8 then
    params:set("live_on", params:get("live_on") == 2 and 1 or 2)
  elseif x == 10 and y == 8 then
    params:set("test_on", params:get("test_on") == 2 and 1 or 2)
  elseif x == 11 and y == 8 then
    if file_loaded() then params:set("file_on", params:get("file_on") == 2 and 1 or 2)
    else msg("load a file in PARAMS") end
  elseif x >= 13 and y <= 4 then
    local i = (y - 1) * 4 + (x - 12)
    if alt then store_snapshot(i) else recall_snapshot(i) end
  elseif x >= 13 and y == 5 then
    page = alt and 5 or (x - 12); sel = 1
  elseif x >= 13 and (y == 6 or y == 7) then
    local i = (y - 6) * 4 + (x - 12)
    params:set("test_sound", i)
    play_sound(SOUNDS[i], 0); flash_key(x, y)
  elseif x == 14 and y == 8 then
    params:set("morph_time", params:get("morph_time") % #MORPH + 1)
    msg("morph " .. MORPH[params:get("morph_time")])
  elseif x == 15 and y == 8 then
    randomize(alt)
  end
end

---------------------------------------------------------------------------
-- arc
---------------------------------------------------------------------------
local function ring_pos(i) return ((40 + i) % 64) + 1 end   -- i = 0..47, 7 o'clock to 5 o'clock

local function arc_redraw()
  local t = now()
  local fz = params:get("freeze") == 1
  for n = 1, 4 do
    for i = 1, 64 do a:led(n, i, 0) end
    local id = PAGES[page].ids[n]
    if is_option(id) then
      local count, v = #p(id).options, params:get(id)
      for k = 1, count do
        local center = math.floor((k - 0.5) / count * 48)
        for w = -1, 1 do a:led(n, ring_pos(util.clamp(center + w, 0, 47)), k == v and 15 or 3) end
      end
    else
      local tip = math.floor(params:get_raw(id) * 47 + 0.5)
      for i = 0, 47 do
        local l = 1
        if i < tip then
          l = (id == "decay") and math.max(2, math.floor(12 - 10 * i / math.max(1, tip))) or 4
        elseif i == tip then l = 15 end
        a:led(n, ring_pos(i), l)
      end
    end
    -- wet level glow in the gap at the bottom
    local w = util.clamp(math.floor((wet_db + 60) / 60 * 8), 0, 8)
    for k = 1, w do a:led(n, ((40 - k) % 64) + 1, 3); a:led(n, ((40 + 48 + k - 1) % 64) + 1, 3) end
    if fz then a:led(n, (math.floor(t * 20) + n * 16) % 64 + 1, 10) end
  end
  a:refresh()
end

a.delta = function(n, d)
  local id = PAGES[page].ids[n]
  local div = ({20, 8, 3})[params:get("arc_sens")]
  if is_option(id) then
    arc_acc[n] = arc_acc[n] + d
    if math.abs(arc_acc[n]) >= 60 then
      user_delta(id, arc_acc[n] > 0 and 1 or -1); arc_acc[n] = 0
    end
  else
    user_delta(id, d / div)
  end
  sel = n
end

---------------------------------------------------------------------------
-- norns keys and encoders
---------------------------------------------------------------------------
function enc(n, d)
  if n == 1 then page = util.clamp(page + d, 1, #PAGES); sel = util.clamp(sel, 1, 4)
  elseif n == 2 then sel = util.clamp(sel + d, 1, 4)
  else user_delta(PAGES[page].ids[sel], d) end
end

function key(n, z)
  if z == 0 then return end
  if n == 2 then
    freeze_latched = not freeze_latched; set_freeze()
    msg(freeze_latched and "freeze" or "freeze off")
  elseif n == 3 then
    params:set("test_on", params:get("test_on") == 2 and 1 or 2)
    msg(params:get("test_on") == 2 and ("test: " .. SOUNDS[params:get("test_sound")]) or "test off")
  end
end

---------------------------------------------------------------------------
-- screen
---------------------------------------------------------------------------
local function short_value(id)
  if id == "shimmer_interval" then return INTERVAL_SHORT[params:get(id)] end
  local s = params:string(id)
  s = string.gsub(s, " (%a+)$", "%1")
  return s
end

-- sketch of the impulse response: level (dB) over time
local function draw_response()
  local x0, x1, y0, y1 = 2, 116, 13, 41
  local pre = params:get("predelay_sync") > 1 and SYNC_BEATS[params:get("predelay_sync")] * clock.get_beat_sec()
    or params:get("predelay") / 1000
  local decay, fz = params:get("decay"), params:get("freeze") == 1
  local span = math.max(0.4, math.min(pre + decay * 1.15, 60))
  local function tx(t) return x0 + (x1 - x0) * util.clamp(t / span, 0, 1) end
  local function ty(db) return y0 + (y1 - y0) * util.clamp(-db / 60, 0, 1) end
  -- axis
  screen.level(1); screen.move(x0, y1 + 0.5); screen.line(x1, y1 + 0.5); screen.stroke()
  -- dry impulse
  screen.level(6); screen.move(x0 + 0.5, y1); screen.line(x0 + 0.5, y0 + 2); screen.stroke()
  -- early reflections
  local er, size = params:get("er"), params:get("size")
  if er > 0.02 then
    screen.level(5)
    for i, et in ipairs(ER_TIMES) do
      local x = math.floor(tx(pre + et * size)) + 0.5
      screen.move(x, y1); screen.line(x, ty(-6 - i * 2.5 - (1 - er) * 30)); screen.stroke()
    end
  end
  -- three decay lines: low, mid, high
  local bloom = params:get("bloom")
  local rise = 0.05 + bloom * 0.35 * size
  local function curve(rt, level)
    screen.level(level)
    local gate = params:get("gate")
    local start = pre + 0.01
    screen.move(tx(start), ty(-28))
    screen.line(tx(start + rise), ty(-4))
    if fz then
      screen.line(tx(start + rise + 0.2), ty(-14)); screen.line(x1, ty(-14))
    else
      local t_end = start + rise + rt
      if gate > 0.01 and start + gate < t_end then
        local tg = math.max(start + gate, start + rise)
        screen.line(tx(tg), ty(-4 - 60 * (tg - start - rise) / rt)); screen.line(tx(tg), y1)
      else
        screen.line(tx(t_end), y1)
      end
    end
    screen.stroke()
  end
  local damp = params:get("damp")
  local hf = 0.22 + 0.78 * util.clamp(math.log(damp / 300) / math.log(20000 / 300), 0, 1) ^ 2
  curve(decay * math.min(params:get("bass"), 4), 3)
  curve(decay * hf, 3)
  curve(decay, 13)
  -- time label
  screen.level(4); screen.move(x1, y0 + 3)
  screen.text_right(fz and "freeze" or (span < 10 and string.format("%.1fs", span) or string.format("%ds", math.floor(span + 0.5))))
  -- meters: input and wet
  local function meter(x, db, l)
    local h = util.clamp((db + 60) / 60, 0, 1) * (y1 - y0)
    screen.level(l); screen.rect(x, y1 - h, 3, h); screen.fill()
  end
  meter(120, in_db, 5); meter(124, wet_db, 12)
end

local function draw_params()
  local ids = PAGES[page].ids
  for i, id in ipairs(ids) do
    local x = (i - 1) % 2 == 0 and 0 or 66
    local y = i <= 2 and 51 or 61
    local s = (i == sel)
    screen.level(s and 15 or 4); screen.move(x, y); screen.text(LABEL[id])
    screen.level(s and 15 or 8); screen.move(x + 61, y); screen.text_right(short_value(id))
  end
end

function redraw()
  screen.clear()
  screen.font_face(1); screen.font_size(8)
  -- header
  screen.level(15); screen.move(0, 7)
  screen.text(current.name .. (edited and "*" or ""))
  screen.level(4); screen.move(64, 7); screen.text_center(PAGES[page].name)
  local flags = (params:get("live_on") == 2 and "L" or "-") .. (params:get("test_on") == 2 and "T" or "-") ..
    (params:get("file_on") == 2 and "F" or "-") .. ((nb and params:get("nb_in") == 2) and "N" or "-")
  screen.level(params:get("freeze") == 1 and 15 or 6); screen.move(127, 7)
  screen.text_right((params:get("freeze") == 1 and "FRZ " or "") .. flags)
  if morph_progress then screen.level(10); screen.rect(0, 9, 128 * morph_progress, 1); screen.fill() end
  draw_response()
  draw_params()
  if message and now() - message_t < 1.4 then
    screen.level(0); screen.rect(14, 20, 100, 15); screen.fill()
    screen.level(15); screen.rect(14.5, 20.5, 99, 14); screen.stroke()
    screen.move(64, 30); screen.text_center(message)
  end
  screen.update()
end

---------------------------------------------------------------------------
-- init / cleanup
---------------------------------------------------------------------------
function init()
  if nb then nb:init() end
  add_params()
  if nb then
    nb:add_player_params()
    params.action_read = function() nb:stop_all() end
  end
  params:bang()
  send_nb()
  load_snapshots()

  -- the dry signal comes through the engine: mute the system monitor and the
  -- system reverb while raum runs (restored in cleanup)
  for _, id in ipairs({"monitor_level", "reverb"}) do
    if params.lookup[id] then saved_sys[id] = params:get(id) end
  end
  if params.lookup["monitor_level"] then params:set("monitor_level", -math.huge) end
  if params.lookup["reverb"] then params:set("reverb", 1) end

  local pi = poll.set("in_db", function(v) in_db = v end)
  if pi then pi.time = 1 / 20; pi:start() end
  local pw = poll.set("wet_db", function(v) wet_db = v end)
  if pw then pw.time = 1 / 20; pw:start() end

  clock.tempo_change_handler = function() send_predelay() end

  -- test sound sequencer, in 16th notes
  clock.run(function()
    while true do
      clock.sync(1 / 4)
      test_tick()
      test_step = test_step + 1
    end
  end)
  -- screen, grid and arc at 30 fps
  clock.run(function()
    while true do
      clock.sleep(1 / 30)
      redraw(); grid_redraw(); arc_redraw()
    end
  end)
  msg(nb and "raum 2" or "raum 2 (no nb)")
end

function cleanup()
  save_snapshots()
  if nb then release_midi_notes(); nb:stop_all() end
  if midi_in then midi_in.event = nil end
  if saved_sys.monitor_level and params.lookup["monitor_level"] then params:set("monitor_level", saved_sys.monitor_level) end
  if saved_sys.reverb and params.lookup["reverb"] then params:set("reverb", saved_sys.reverb) end
end
