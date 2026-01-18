export const NOTE_NAMES = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'] as const;

export type NoteName = typeof NOTE_NAMES[number];

export interface Tuning {
  name: string;
  notes: string[];
}

export const TUNINGS: Record<string, Tuning> = {
  standard: { name: 'Standard (EADGBE)', notes: ['E2', 'A2', 'D3', 'G3', 'B3', 'E4'] },
  dropD: { name: 'Drop D (DADGBE)', notes: ['D2', 'A2', 'D3', 'G3', 'B3', 'E4'] },
  openG: { name: 'Open G (DGDGBD)', notes: ['D2', 'G2', 'D3', 'G3', 'B3', 'D4'] },
  openD: { name: 'Open D (DADF#AD)', notes: ['D2', 'A2', 'D3', 'F#3', 'A3', 'D4'] },
  halfStepDown: { name: 'Half Step Down (Eb)', notes: ['D#2', 'G#2', 'C#3', 'F#3', 'A#3', 'D#4'] },
  fullStepDown: { name: 'Full Step Down (D)', notes: ['D2', 'G2', 'C3', 'F3', 'A3', 'D4'] },
};

export function parseNote(note: string): { name: NoteName; octave: number } {
  const match = note.match(/^([A-G]#?)(\d+)$/);
  if (!match) throw new Error(`Invalid note: ${note}`);
  return { name: match[1] as NoteName, octave: parseInt(match[2], 10) };
}

export function noteToMidi(note: string): number {
  const { name, octave } = parseNote(note);
  const noteIndex = NOTE_NAMES.indexOf(name);
  return (octave + 1) * 12 + noteIndex;
}

export function midiToNote(midi: number): string {
  const octave = Math.floor(midi / 12) - 1;
  const noteIndex = midi % 12;
  return `${NOTE_NAMES[noteIndex]}${octave}`;
}

export function getNoteAtFret(openNote: string, fret: number): string {
  const midi = noteToMidi(openNote) + fret;
  return midiToNote(midi);
}

export function generatePianoRange(startNote: string, endNote: string): string[] {
  const startMidi = noteToMidi(startNote);
  const endMidi = noteToMidi(endNote);
  const notes: string[] = [];
  for (let midi = startMidi; midi <= endMidi; midi++) {
    notes.push(midiToNote(midi));
  }
  return notes;
}

export function isBlackKey(note: string): boolean {
  const { name } = parseNote(note);
  return name.includes('#');
}

// Scale intervals (semitones from root)
const MAJOR_SCALE = [0, 2, 4, 5, 7, 9, 11];
const MINOR_SCALE = [0, 2, 3, 5, 7, 8, 10];

export type KeyType = 'major' | 'minor';

export interface MusicalKey {
  root: NoteName;
  type: KeyType;
}

export const ALL_KEYS: MusicalKey[] = [
  ...NOTE_NAMES.map(root => ({ root, type: 'major' as KeyType })),
  ...NOTE_NAMES.map(root => ({ root, type: 'minor' as KeyType })),
];

export function getKeyName(key: MusicalKey): string {
  return `${key.root} ${key.type}`;
}

export function getNotesInKey(key: MusicalKey): NoteName[] {
  const rootIndex = NOTE_NAMES.indexOf(key.root);
  const intervals = key.type === 'major' ? MAJOR_SCALE : MINOR_SCALE;
  return intervals.map(interval => NOTE_NAMES[(rootIndex + interval) % 12]);
}

export function isNoteInKey(note: string, key: MusicalKey | null): boolean {
  if (!key) return true; // No key selected, all notes are "in key"
  const { name } = parseNote(note);
  const notesInKey = getNotesInKey(key);
  return notesInKey.includes(name);
}
