export const NOTE_NAMES = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'] as const;
export const NOTE_NAMES_FLAT = ['C', 'Db', 'D', 'Eb', 'E', 'F', 'Gb', 'G', 'Ab', 'A', 'Bb', 'B'] as const;

export type NoteName = typeof NOTE_NAMES[number];
export type NoteNameFlat = typeof NOTE_NAMES_FLAT[number];
export type AnyNoteName = NoteName | NoteNameFlat;

// Map sharp notes to their flat equivalents
export const SHARP_TO_FLAT: Record<string, string> = {
  'C#': 'Db', 'D#': 'Eb', 'F#': 'Gb', 'G#': 'Ab', 'A#': 'Bb'
};
export const FLAT_TO_SHARP: Record<string, string> = {
  'Db': 'C#', 'Eb': 'D#', 'Gb': 'F#', 'Ab': 'G#', 'Bb': 'A#'
};

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

// Keys that use flats in their key signature (by their sharp-notation root)
// Major keys: F, Bb, Eb, Ab, Db, Gb
// Minor keys: D, G, C, F, Bb, Eb (relative minors of flat major keys)
const FLAT_MAJOR_ROOTS = ['F', 'A#', 'D#', 'G#', 'C#', 'F#']; // A# = Bb, D# = Eb, etc.
const FLAT_MINOR_ROOTS = ['D', 'G', 'C', 'F', 'A#', 'D#'];    // Relative minors

export function keyUsesFlats(key: MusicalKey | null): boolean {
  if (!key) return false;
  if (key.type === 'major') {
    return FLAT_MAJOR_ROOTS.includes(key.root);
  } else {
    return FLAT_MINOR_ROOTS.includes(key.root);
  }
}

export function getKeyDisplayRoot(key: MusicalKey): string {
  if (keyUsesFlats(key)) {
    return SHARP_TO_FLAT[key.root] || key.root;
  }
  return key.root;
}

export function getKeyName(key: MusicalKey, useSharpsOnly: boolean = false): string {
  if (useSharpsOnly) {
    return `${key.root} ${key.type}`;
  }
  const displayRoot = getKeyDisplayRoot(key);
  return `${displayRoot} ${key.type}`;
}

export function getNotesInKeyDisplay(key: MusicalKey, useSharpsOnly: boolean = false): string[] {
  const rootIndex = NOTE_NAMES.indexOf(key.root);
  const intervals = key.type === 'major' ? MAJOR_SCALE : MINOR_SCALE;
  const useFlats = !useSharpsOnly && keyUsesFlats(key);
  const noteNames = useFlats ? NOTE_NAMES_FLAT : NOTE_NAMES;
  return intervals.map(interval => noteNames[(rootIndex + interval) % 12]);
}

// Get the display name for a note based on the selected key
export function getNoteDisplayName(note: string, key: MusicalKey | null): string {
  const { name, octave } = parseNote(note);

  // If no key or key uses sharps, return as-is (sharps)
  if (!key || !keyUsesFlats(key)) {
    return name;
  }

  // Key uses flats - convert sharp notes to flat equivalents
  return SHARP_TO_FLAT[name] || name;
}

export function getNotesInKey(key: MusicalKey): string[] {
  const rootIndex = NOTE_NAMES.indexOf(key.root);
  const intervals = key.type === 'major' ? MAJOR_SCALE : MINOR_SCALE;
  const useFlats = keyUsesFlats(key);
  const noteNames = useFlats ? NOTE_NAMES_FLAT : NOTE_NAMES;
  return intervals.map(interval => noteNames[(rootIndex + interval) % 12]);
}

export function isNoteInKey(note: string, key: MusicalKey | null): boolean {
  if (!key) return true; // No key selected, all notes are "in key"
  const { name } = parseNote(note);
  // Get notes in key using sharp names for comparison (internal representation)
  const rootIndex = NOTE_NAMES.indexOf(key.root);
  const intervals = key.type === 'major' ? MAJOR_SCALE : MINOR_SCALE;
  const notesInKey = intervals.map(interval => NOTE_NAMES[(rootIndex + interval) % 12]);
  return notesInKey.includes(name);
}

// Returns the scale degree (0-6) of a note within a key, or -1 if not in key
export function getScaleDegree(note: string, key: MusicalKey | null): number {
  if (!key) return -1;
  const { name } = parseNote(note);
  const rootIndex = NOTE_NAMES.indexOf(key.root);
  const intervals = key.type === 'major' ? MAJOR_SCALE : MINOR_SCALE;
  const notesInKey = intervals.map(interval => NOTE_NAMES[(rootIndex + interval) % 12]);
  return notesInKey.indexOf(name);
}

// 7 colors for the 7 scale degrees (each with light/dark mode variants for unselected and selected states)
// bg100 = unselected in-key, bg500 = selected (darker with white text), border200 = border for highlighted notes
export const SCALE_DEGREE_COLORS = [
  { name: 'red', bg100: 'bg-red-100', bg500: 'bg-red-500', border200: 'border-red-200', hover100: 'hover:bg-red-200', darkBg100: 'bg-red-900/40', darkBg500: 'bg-red-500', darkBorder: 'border-red-700', darkHover100: 'hover:bg-red-800/50' },
  { name: 'orange', bg100: 'bg-orange-100', bg500: 'bg-orange-500', border200: 'border-orange-200', hover100: 'hover:bg-orange-200', darkBg100: 'bg-orange-900/40', darkBg500: 'bg-orange-500', darkBorder: 'border-orange-700', darkHover100: 'hover:bg-orange-800/50' },
  { name: 'yellow', bg100: 'bg-yellow-100', bg500: 'bg-yellow-500', border200: 'border-yellow-200', hover100: 'hover:bg-yellow-200', darkBg100: 'bg-yellow-900/40', darkBg500: 'bg-yellow-500', darkBorder: 'border-yellow-700', darkHover100: 'hover:bg-yellow-800/50' },
  { name: 'green', bg100: 'bg-green-100', bg500: 'bg-green-500', border200: 'border-green-200', hover100: 'hover:bg-green-200', darkBg100: 'bg-green-900/40', darkBg500: 'bg-green-500', darkBorder: 'border-green-700', darkHover100: 'hover:bg-green-800/50' },
  { name: 'cyan', bg100: 'bg-cyan-100', bg500: 'bg-cyan-500', border200: 'border-cyan-200', hover100: 'hover:bg-cyan-200', darkBg100: 'bg-cyan-900/40', darkBg500: 'bg-cyan-500', darkBorder: 'border-cyan-700', darkHover100: 'hover:bg-cyan-800/50' },
  { name: 'blue', bg100: 'bg-blue-100', bg500: 'bg-blue-500', border200: 'border-blue-200', hover100: 'hover:bg-blue-200', darkBg100: 'bg-blue-900/40', darkBg500: 'bg-blue-500', darkBorder: 'border-blue-700', darkHover100: 'hover:bg-blue-800/50' },
  { name: 'purple', bg100: 'bg-purple-100', bg500: 'bg-purple-500', border200: 'border-purple-200', hover100: 'hover:bg-purple-200', darkBg100: 'bg-purple-900/40', darkBg500: 'bg-purple-500', darkBorder: 'border-purple-700', darkHover100: 'hover:bg-purple-800/50' },
] as const;

export function getScaleDegreeColor(scaleDegree: number) {
  if (scaleDegree < 0 || scaleDegree > 6) return null;
  return SCALE_DEGREE_COLORS[scaleDegree];
}

// Colors for chromatic notes not in the current key (5 accidentals)
// bg500 = selected (darker with white text)
export const CHROMATIC_OUT_OF_KEY_COLORS = [
  { name: 'pink', bg500: 'bg-pink-500', darkBg500: 'bg-pink-500' },
  { name: 'lime', bg500: 'bg-lime-500', darkBg500: 'bg-lime-500' },
  { name: 'teal', bg500: 'bg-teal-500', darkBg500: 'bg-teal-500' },
  { name: 'indigo', bg500: 'bg-indigo-500', darkBg500: 'bg-indigo-500' },
  { name: 'rose', bg500: 'bg-rose-500', darkBg500: 'bg-rose-500' },
] as const;

// Colors for all 12 chromatic notes when no key is selected
// Maps each note (C=0, C#=1, etc.) to a unique color
export const CHROMATIC_NOTE_COLORS = [
  { name: 'red', bg500: 'bg-red-500', darkBg500: 'bg-red-500' },       // C (0)
  { name: 'pink', bg500: 'bg-pink-500', darkBg500: 'bg-pink-500' },    // C# (1)
  { name: 'orange', bg500: 'bg-orange-500', darkBg500: 'bg-orange-500' }, // D (2)
  { name: 'lime', bg500: 'bg-lime-500', darkBg500: 'bg-lime-500' },    // D# (3)
  { name: 'yellow', bg500: 'bg-yellow-500', darkBg500: 'bg-yellow-500' }, // E (4)
  { name: 'green', bg500: 'bg-green-500', darkBg500: 'bg-green-500' }, // F (5)
  { name: 'teal', bg500: 'bg-teal-500', darkBg500: 'bg-teal-500' },    // F# (6)
  { name: 'cyan', bg500: 'bg-cyan-500', darkBg500: 'bg-cyan-500' },    // G (7)
  { name: 'indigo', bg500: 'bg-indigo-500', darkBg500: 'bg-indigo-500' }, // G# (8)
  { name: 'blue', bg500: 'bg-blue-500', darkBg500: 'bg-blue-500' },    // A (9)
  { name: 'rose', bg500: 'bg-rose-500', darkBg500: 'bg-rose-500' },    // A# (10)
  { name: 'purple', bg500: 'bg-purple-500', darkBg500: 'bg-purple-500' }, // B (11)
] as const;

// Get color for a note based on its chromatic position (used when no key is selected)
export function getChromaticNoteColor(note: string) {
  const { name } = parseNote(note);
  const noteIndex = NOTE_NAMES.indexOf(name);
  return CHROMATIC_NOTE_COLORS[noteIndex];
}

// Get color for a note that is selected but not in the current key
// Returns one of 5 colors based on the note's chromatic position
// Parse a note display name into base letter and accidental
export function parseNoteDisplay(displayName: string): { letter: string; accidental: string | null } {
  if (displayName.length === 1) {
    return { letter: displayName, accidental: null };
  }
  return { letter: displayName[0], accidental: displayName.slice(1) };
}

export function getOutOfKeyColor(note: string, key: MusicalKey | null) {
  if (!key) return null;
  const { name } = parseNote(note);
  const noteIndex = NOTE_NAMES.indexOf(name);
  const rootIndex = NOTE_NAMES.indexOf(key.root);

  // Get semitone distance from root
  const semitones = (noteIndex - rootIndex + 12) % 12;

  // Map the 5 chromatic (out-of-key) semitones to colors
  // Major scale: 0, 2, 4, 5, 7, 9, 11 (in key)
  // Minor scale: 0, 2, 3, 5, 7, 8, 10 (in key)
  // We map the remaining semitones to colors
  const intervals = key.type === 'major' ? [0, 2, 4, 5, 7, 9, 11] : [0, 2, 3, 5, 7, 8, 10];

  // Find which chromatic position this is (0-4 for the 5 out-of-key notes)
  const chromaticPositions = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11].filter(s => !intervals.includes(s));
  const chromaticIndex = chromaticPositions.indexOf(semitones);

  if (chromaticIndex === -1) return null; // Note is actually in key
  return CHROMATIC_OUT_OF_KEY_COLORS[chromaticIndex];
}
