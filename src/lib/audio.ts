import { noteToMidi } from './notes';

// Mirrors the Apple app's audio: SynthMixer.swift (sounds, envelopes, chord cutoff), the tempo
// rules in AppState.swift / LoopSequencer.beatInterval, and AppModel.sound's note flashing.

// MARK: - Sounds

/** The sounds playback can use, in menu order. All are synthesized; none are samples. */
export const SOUNDS = [
  { id: 'classic', name: 'Classic' },
  { id: 'keys', name: 'Electric Keys' },
  { id: 'pluck', name: 'Pluck' },
  { id: 'organ', name: 'Organ' },
  { id: 'retro', name: '8-Bit' },
  { id: 'glass', name: 'Glass Bells' },
  { id: 'pad', name: 'Dream Pad' },
] as const;

/** A sound's id; the same strings the Apple app stores, so saved settings carry across. */
export type SoundId = (typeof SOUNDS)[number]['id'];

export const DEFAULT_SOUND: SoundId = 'classic';

export function isSoundId(value: unknown): value is SoundId {
  return SOUNDS.some(sound => sound.id === value);
}

export function getSoundName(sound: SoundId): string {
  return SOUNDS.find(s => s.id === sound)?.name ?? sound;
}

/** Played when the sound changes, so you hear it (Swift's setInstrument). */
export const SOUND_PREVIEW_NOTES = ['C4', 'E4', 'G4', 'C5'];

// MARK: - Tempo and timing

export type PlaybackMode = 'chord' | 'arpeggio';

export const TEMPO_MIN = 60;
export const TEMPO_MAX = 180;
/** The speed playback has always had: a chord every 0.8s, arpeggio notes 0.4s apart. */
export const DEFAULT_TEMPO = 75;

export function clampTempo(tempo: number): number {
  if (!Number.isFinite(tempo)) return DEFAULT_TEMPO;
  return Math.min(Math.max(Math.round(tempo), TEMPO_MIN), TEMPO_MAX);
}

/** Seconds between arpeggio notes at `tempo` (an eighth note). */
export function arpeggioStep(tempo: number = DEFAULT_TEMPO): number {
  return 30 / clampTempo(tempo);
}

/**
 * Seconds from one loop beat to the next: one beat for a chord, or all of an arpeggio's notes
 * (two a beat), so the next arpeggio carries straight on.
 */
export function beatInterval(noteCount: number, mode: PlaybackMode, tempo: number = DEFAULT_TEMPO): number {
  const beat = 60 / clampTempo(tempo);
  return mode === 'chord' ? beat : (noteCount * beat) / 2;
}

/** `beatInterval` in milliseconds, for setTimeout-based callers. */
export function getPlaybackDuration(noteCount: number, mode: PlaybackMode, tempo: number = DEFAULT_TEMPO): number {
  return beatInterval(noteCount, mode, tempo) * 1000;
}

/** How far ahead of each beat a loop should wake to book it on the audio clock. */
export const LOOP_LOOKAHEAD_SECONDS = 0.3;

/** How long a note's flash lasts at most. */
export const FLASH_DURATION_SECONDS = 0.4;

const DEFAULT_NOTE_DURATION = 0.8;
const DEFAULT_CHORD_DURATION = 1.2;
const CUTOFF_FADE = 0.05;
const DETUNE = 1.002;
const MASTER_GAIN = 0.8;

// MARK: - Sound definitions

interface Envelope {
  attack: number;
  /** Sustained sounds: time to fall from the peak to `sustain`. */
  decay: number;
  sustain: number;
  release: number;
  /** Struck or plucked sounds die away exponentially with this time constant instead of sustaining. */
  ringTime?: number;
  /** Notes last this much longer than asked, for sounds that ring on. */
  lengthScale: number;
}

function envelope(e: Partial<Envelope> & Pick<Envelope, 'attack' | 'release'>): Envelope {
  return { decay: 0.1, sustain: 0.7, lengthScale: 1, ...e };
}

const ENVELOPES: Record<SoundId, Envelope> = {
  classic: envelope({ attack: 0.02, decay: 0.1, sustain: 0.7, release: 0.3 }),
  keys: envelope({ attack: 0.005, release: 0.25, ringTime: 0.9, lengthScale: 1.3 }),
  pluck: envelope({ attack: 0.003, release: 0.1, ringTime: 0.35 }),
  organ: envelope({ attack: 0.01, decay: 0.05, sustain: 0.9, release: 0.08 }),
  retro: envelope({ attack: 0.005, decay: 0.05, sustain: 0.6, release: 0.05 }),
  glass: envelope({ attack: 0.002, release: 0.3, ringTime: 0.8, lengthScale: 2 }),
  pad: envelope({ attack: 0.25, decay: 0.3, sustain: 0.8, release: 0.5, lengthScale: 1.5 }),
};

/** A sine at `ratio` × the note's frequency, `amp` loud, optionally fading as exp(-decayRate·t). */
interface SinePartial {
  ratio: number;
  amp: number;
  decayRate?: number;
}

// Each waveform is a sum of sines, matching SynthInstrument.sample term for term.
// (`keys` is FM and is built separately.)
const PARTIALS: Record<Exclude<SoundId, 'keys'>, SinePartial[]> = {
  classic: [
    { ratio: 1, amp: 1 },
    { ratio: DETUNE, amp: 1 },
  ],
  // Higher harmonics die away faster than the fundamental.
  pluck: [1, 2, 3, 4, 5, 6].map(k => ({ ratio: k, amp: 1.3 / k, decayRate: k * 2.5 })),
  // Steady drawbar-style harmonics.
  organ: [
    { ratio: 1, amp: 0.85 },
    { ratio: 2, amp: 0.85 * 0.6 },
    { ratio: 3, amp: 0.85 * 0.35 },
    { ratio: 4, amp: 0.85 * 0.2 },
    { ratio: 6, amp: 0.85 * 0.1 },
  ],
  // The first few odd harmonics of a square wave: buzzy without harsh aliasing.
  retro: [1, 3, 5, 7, 9].map(k => ({ ratio: k, amp: 1.1 / k })),
  // Shimmering, inharmonic bell partials.
  glass: [
    { ratio: 1, amp: 1.2 },
    { ratio: 2.76, amp: 1.2 * 0.5, decayRate: 3 },
    { ratio: 5.4, amp: 1.2 * 0.25, decayRate: 6 },
    { ratio: 8.93, amp: 1.2 * 0.2, decayRate: 9 },
  ],
  // Three detuned voices plus a soft octave.
  pad: [
    { ratio: 1, amp: 0.7 },
    { ratio: 1.004, amp: 0.7 },
    { ratio: 0.996, amp: 0.7 },
    { ratio: 2, amp: 0.7 * 0.3 },
  ],
};

// MARK: - Audio graph

let audioContext: AudioContext | null = null;
let masterGain: GainNode | null = null;

function getAudioContext(): AudioContext {
  if (!audioContext) {
    audioContext = new AudioContext();

    // Compressor so big chords don't clip: threshold -6 dB, 12:1, 3 ms attack, 100 ms release.
    const compressor = audioContext.createDynamicsCompressor();
    compressor.threshold.value = -6;
    compressor.knee.value = 0; // Swift's compressor has a hard knee
    compressor.ratio.value = 12;
    compressor.attack.value = 0.003;
    compressor.release.value = 0.1;

    masterGain = audioContext.createGain();
    masterGain.gain.value = MASTER_GAIN;

    masterGain.connect(compressor);
    compressor.connect(audioContext.destination);
  }
  // Browsers start contexts suspended until a user gesture; playback is always gesture-driven
  // (or a loop started by one), so resuming here is enough.
  if (audioContext.state === 'suspended') {
    void audioContext.resume();
  }
  return audioContext;
}

/** The audio clock (seconds), the time `at` options are measured on. */
export function getAudioTime(): number {
  return getAudioContext().currentTime;
}

/** Seconds from now until a sound booked at `audioTime` reaches the speakers. */
export function secondsUntilHeard(audioTime: number): number {
  const ctx = getAudioContext();
  const latency = ctx.outputLatency || ctx.baseLatency || 0;
  return audioTime - ctx.currentTime + latency;
}

function midiToFrequency(midi: number): number {
  return 440 * Math.pow(2, (midi - 69) / 12);
}

/** A chord note that a later chord may cut off. */
interface ChordVoice {
  cutoff: GainNode;
  oscillators: OscillatorNode[];
  start: number;
  end: number;
  fading: boolean;
}

let chordVoices: ChordVoice[] = [];

/**
 * Shapes `gain` like SynthMixer.envelope: linear attack to `volume`, then either an exponential
 * ring (struck sounds) or a linear decay to the sustain level, then a linear release ending
 * exactly at `duration`.
 */
function scheduleEnvelope(gain: AudioParam, shape: Envelope, start: number, duration: number, volume: number): void {
  const attack = Math.min(shape.attack, duration);
  gain.setValueAtTime(0, start);
  gain.linearRampToValueAtTime(volume, start + attack);

  if (shape.ringTime !== undefined) {
    const releaseStart = Math.max(duration - shape.release, attack);
    gain.setTargetAtTime(0, start + attack, shape.ringTime);
    const level = volume * Math.exp(-(releaseStart - attack) / shape.ringTime);
    gain.setValueAtTime(level, start + releaseStart);
  } else {
    const settled = attack + shape.decay;
    if (duration <= settled) {
      // Too short to reach the sustain level (a fast Dream Pad arpeggio): fade straight out.
      // (Swift cuts these off mid-decay.)
      gain.linearRampToValueAtTime(0, start + duration);
      return;
    }
    const sustain = volume * shape.sustain;
    gain.linearRampToValueAtTime(sustain, start + settled);
    gain.setValueAtTime(sustain, start + Math.max(duration - shape.release, settled));
  }
  gain.linearRampToValueAtTime(0, start + duration);
}

/** Builds one note's sound sources into `output`, returning the oscillators to start and stop. */
function createSources(ctx: AudioContext, sound: SoundId, frequency: number, start: number, output: AudioNode): OscillatorNode[] {
  const oscillators: OscillatorNode[] = [];
  const sine = (freq: number, amp: number): { osc: OscillatorNode; gain: GainNode } => {
    const osc = ctx.createOscillator();
    osc.type = 'sine';
    osc.frequency.value = freq;
    const gain = ctx.createGain();
    gain.gain.value = amp;
    osc.connect(gain);
    gain.connect(output);
    oscillators.push(osc);
    return { osc, gain };
  };

  if (sound === 'keys') {
    // FM electric piano: sin(w + I(t)·sin(w)) with I(t) = 1.8·e^(-5t) + 0.2, so the tine's bite
    // softens into a rounder tone. Frequency modulation with deviation I·f gives the same spectrum.
    const carrier = sine(frequency, 1.4).osc;
    const modulator = ctx.createOscillator();
    modulator.type = 'sine';
    modulator.frequency.value = frequency;
    const depth = ctx.createGain();
    depth.gain.setValueAtTime(2.0 * frequency, start);
    depth.gain.setTargetAtTime(0.2 * frequency, start, 1 / 5);
    modulator.connect(depth);
    depth.connect(carrier.frequency);
    oscillators.push(modulator);
    sine(frequency * DETUNE, 0.3);
    return oscillators;
  }

  for (const partial of PARTIALS[sound]) {
    const freq = frequency * partial.ratio;
    // Partials above Nyquist would alias; drop them.
    if (freq >= ctx.sampleRate / 2) continue;
    const { gain } = sine(freq, partial.amp);
    if (partial.decayRate !== undefined) {
      gain.gain.setValueAtTime(partial.amp, start);
      gain.gain.setTargetAtTime(0, start, 1 / partial.decayRate);
    }
  }
  return oscillators;
}

interface Voice {
  cutoff: GainNode;
  oscillators: OscillatorNode[];
  end: number;
}

function createVoice(ctx: AudioContext, note: string, sound: SoundId, start: number, duration: number, volume: number): Voice {
  const shape = ENVELOPES[sound];
  const length = duration * shape.lengthScale;

  // sources → envelope → cutoff (for a newer chord fading this one) → master
  const env = ctx.createGain();
  const cutoff = ctx.createGain();
  env.connect(cutoff);
  cutoff.connect(masterGain!);

  const oscillators = createSources(ctx, sound, midiToFrequency(noteToMidi(note)), start, env);
  scheduleEnvelope(env.gain, shape, start, length, volume);

  const end = start + length + 0.1;
  for (const osc of oscillators) {
    osc.start(start);
    osc.stop(end);
  }
  // Free the nodes once the note is done.
  oscillators[0]?.addEventListener('ended', () => cutoff.disconnect());
  return { cutoff, oscillators, end };
}

/** Fades out chord notes that started before `start`, over 50ms from `start`. */
function cutOffChordsBefore(start: number, now: number): void {
  chordVoices = chordVoices.filter(voice => voice.end > now);
  for (const voice of chordVoices) {
    if (voice.fading || voice.start >= start) continue;
    voice.fading = true;
    voice.cutoff.gain.setValueAtTime(1, start);
    voice.cutoff.gain.linearRampToValueAtTime(0, start + CUTOFF_FADE);
    const stopAt = start + CUTOFF_FADE + 0.01;
    if (stopAt < voice.end) {
      for (const osc of voice.oscillators) {
        try {
          osc.stop(stopAt);
        } catch {
          // Some browsers refuse a second stop(); the fade has silenced it anyway.
        }
      }
    }
  }
}

// MARK: - Sounding notes (for flashing them on the instruments)

/** A note lit on the instruments: `startMs` after the play call returned, for `durationMs`. */
export interface SoundingNote {
  note: string;
  startMs: number;
  durationMs: number;
}

const flashCounts = new Map<string, number>();
let soundingNotes: ReadonlySet<string> = new Set();
const soundingListeners = new Set<(notes: ReadonlySet<string>) => void>();

function setSounding(next: Set<string>): void {
  soundingNotes = next;
  soundingListeners.forEach(listener => listener(next));
}

/** Notes sounding right now. A new Set each time it changes, so it works as a React snapshot. */
export function getSoundingNotes(): ReadonlySet<string> {
  return soundingNotes;
}

const NO_SOUNDING_NOTES: ReadonlySet<string> = new Set();

/** Server snapshot for useSyncExternalStore. */
export function getServerSoundingNotes(): ReadonlySet<string> {
  return NO_SOUNDING_NOTES;
}

/**
 * Calls `listener` whenever the sounding notes change; returns an unsubscribe function.
 * In React: `useSyncExternalStore(subscribeSoundingNotes, getSoundingNotes, getServerSoundingNotes)`.
 */
export function subscribeSoundingNotes(listener: (notes: ReadonlySet<string>) => void): () => void {
  soundingListeners.add(listener);
  return () => {
    soundingListeners.delete(listener);
  };
}

/** Lights each note when it's heard, counting overlaps so a repeat doesn't end a flash early. */
function flash(schedule: SoundingNote[]): void {
  for (const { note, startMs, durationMs } of schedule) {
    setTimeout(() => {
      flashCounts.set(note, (flashCounts.get(note) ?? 0) + 1);
      if (!soundingNotes.has(note)) setSounding(new Set(soundingNotes).add(note));
      setTimeout(() => {
        const count = (flashCounts.get(note) ?? 1) - 1;
        if (count > 0) {
          flashCounts.set(note, count);
        } else {
          flashCounts.delete(note);
          const next = new Set(soundingNotes);
          next.delete(note);
          setSounding(next);
        }
      }, durationMs);
    }, startMs);
  }
}

// MARK: - Playback

export interface PlayOptions {
  /** When to start, on the `getAudioTime()` clock; omitted or in the past means now. */
  at?: number;
  /** Light the notes on the instruments as they sound (default true). */
  flash?: boolean;
}

export interface ChordOptions extends PlayOptions {
  /** Seconds each note lasts before the sound's lengthScale (default 1.2). */
  duration?: number;
}

/** What a play call booked. */
export interface Playback {
  /** Audio-clock time the first note starts. */
  startTime: number;
  /** Milliseconds from now until the first note is heard (output latency included). */
  heardInMs: number;
  /** Each note's flash, relative to now; already applied to the sounding notes if `flash` is on. */
  sounding: SoundingNote[];
}

function startTimeFor(ctx: AudioContext, at: number | undefined): number {
  return at === undefined ? ctx.currentTime : Math.max(ctx.currentTime, at);
}

/** Plays one note now, as when a note is tapped. Like the Apple app, it doesn't flash. */
export function playNote(note: string, sound: SoundId = DEFAULT_SOUND, duration: number = DEFAULT_NOTE_DURATION): void {
  const ctx = getAudioContext();
  createVoice(ctx, note, sound, ctx.currentTime, duration, 0.25);
}

/**
 * Plays all notes together, quickly fading out the previous chord so repeats don't pile up.
 * Each note flashes for 0.4s.
 */
export function playChord(notes: string[], sound: SoundId = DEFAULT_SOUND, options: ChordOptions = {}): Playback {
  const ctx = getAudioContext();
  const start = startTimeFor(ctx, options.at);
  const heardInMs = Math.max(0, secondsUntilHeard(start)) * 1000;
  if (notes.length === 0) return { startTime: start, heardInMs, sounding: [] };

  cutOffChordsBefore(start, ctx.currentTime);
  const duration = options.duration ?? DEFAULT_CHORD_DURATION;
  const volume = Math.min(0.25, 0.6 / notes.length);
  for (const note of notes) {
    const voice = createVoice(ctx, note, sound, start, duration, volume);
    chordVoices.push({ ...voice, start, fading: false });
  }

  const sounding = notes.map(note => ({ note, startMs: heardInMs, durationMs: FLASH_DURATION_SECONDS * 1000 }));
  if (options.flash !== false) flash(sounding);
  return { startTime: start, heardInMs, sounding };
}

/**
 * Plays the notes one after another, an eighth note apart at `tempo` (two a beat). Each note rings
 * a little past the next one's start, and flashes for min(0.4s, 90% of the step).
 */
export function playArpeggio(
  notes: string[],
  sound: SoundId = DEFAULT_SOUND,
  tempo: number = DEFAULT_TEMPO,
  options: PlayOptions = {},
): Playback {
  const ctx = getAudioContext();
  const start = startTimeFor(ctx, options.at);
  const heardInMs = Math.max(0, secondsUntilHeard(start)) * 1000;
  const step = arpeggioStep(tempo);
  const noteDuration = Math.min(Math.max(step * 1.25, 0.3), 0.8);

  notes.forEach((note, index) => {
    createVoice(ctx, note, sound, start + index * step, noteDuration, 0.25);
  });

  const flashMs = Math.min(FLASH_DURATION_SECONDS, step * 0.9) * 1000;
  const sounding = notes.map((note, index) => ({ note, startMs: heardInMs + index * step * 1000, durationMs: flashMs }));
  if (options.flash !== false) flash(sounding);
  return { startTime: start, heardInMs, sounding };
}

/** Plays notes as a chord or an arpeggio at `tempo`, like Swift's `play(_:mode:at:)`. */
export function play(
  notes: string[],
  mode: PlaybackMode,
  sound: SoundId = DEFAULT_SOUND,
  tempo: number = DEFAULT_TEMPO,
  options: PlayOptions = {},
): Playback & { nextBeatTime: number } {
  const playback = mode === 'chord' ? playChord(notes, sound, options) : playArpeggio(notes, sound, tempo, options);
  return { ...playback, nextBeatTime: playback.startTime + beatInterval(notes.length, mode, tempo) };
}

/** Plays a C major arpeggio in `sound`, for when the sound is changed (skip it while looping). */
export function previewSound(sound: SoundId, tempo: number = DEFAULT_TEMPO): Playback {
  return playArpeggio(SOUND_PREVIEW_NOTES, sound, tempo);
}
