import { noteToMidi } from './notes';

let audioContext: AudioContext | null = null;

function getAudioContext(): AudioContext {
  if (!audioContext) {
    audioContext = new AudioContext();
  }
  return audioContext;
}

function midiToFrequency(midi: number): number {
  return 440 * Math.pow(2, (midi - 69) / 12);
}

function createNote(
  ctx: AudioContext,
  frequency: number,
  startTime: number,
  duration: number,
  volume: number = 0.3
): void {
  // Use two slightly detuned sine waves for a richer sound
  const oscillator1 = ctx.createOscillator();
  const oscillator2 = ctx.createOscillator();
  const gainNode = ctx.createGain();

  oscillator1.connect(gainNode);
  oscillator2.connect(gainNode);
  gainNode.connect(ctx.destination);

  // Sine waves for clean sound
  oscillator1.type = 'sine';
  oscillator2.type = 'sine';

  // Slight detune for warmth
  oscillator1.frequency.setValueAtTime(frequency, startTime);
  oscillator2.frequency.setValueAtTime(frequency * 1.002, startTime);

  // ADSR envelope for smooth sound
  const attackTime = 0.02;
  const decayTime = 0.1;
  const sustainLevel = volume * 0.7;
  const releaseTime = 0.3;

  // Start silent
  gainNode.gain.setValueAtTime(0, startTime);

  // Attack: quick fade in
  gainNode.gain.linearRampToValueAtTime(volume, startTime + attackTime);

  // Decay to sustain level
  gainNode.gain.linearRampToValueAtTime(sustainLevel, startTime + attackTime + decayTime);

  // Sustain (hold until release)
  const sustainEnd = startTime + duration - releaseTime;
  if (sustainEnd > startTime + attackTime + decayTime) {
    gainNode.gain.setValueAtTime(sustainLevel, sustainEnd);
  }

  // Release: smooth fade out
  gainNode.gain.linearRampToValueAtTime(0, startTime + duration);

  oscillator1.start(startTime);
  oscillator2.start(startTime);
  oscillator1.stop(startTime + duration + 0.1);
  oscillator2.stop(startTime + duration + 0.1);
}

export function playNote(note: string, duration: number = 0.8): void {
  const ctx = getAudioContext();
  const midi = noteToMidi(note);
  const frequency = midiToFrequency(midi);

  createNote(ctx, frequency, ctx.currentTime, duration, 0.25);
}

export function playChord(notes: string[], duration: number = 1.2): void {
  if (notes.length === 0) return;

  const ctx = getAudioContext();
  const volumePerNote = Math.min(0.25, 0.6 / notes.length);

  notes.forEach(note => {
    const midi = noteToMidi(note);
    const frequency = midiToFrequency(midi);
    createNote(ctx, frequency, ctx.currentTime, duration, volumePerNote);
  });
}

export function playArpeggio(notes: string[], noteDuration: number = 0.5, gap: number = 0.1): void {
  if (notes.length === 0) return;

  const ctx = getAudioContext();

  notes.forEach((note, index) => {
    const startTime = ctx.currentTime + index * (noteDuration * 0.6 + gap);
    const midi = noteToMidi(note);
    const frequency = midiToFrequency(midi);
    createNote(ctx, frequency, startTime, noteDuration, 0.25);
  });
}
