// Notes, tunings, keys and scales. Mirrors the Swift core (Note.swift, Tunings.swift,
// MusicalKey.swift). Notes are strings in scientific pitch notation with sharps, e.g. 'C#4'.

import {
  CHROMATIC_NOTE_COLORS,
  CHROMATIC_OUT_OF_KEY_COLORS,
  SCALE_DEGREE_COLORS,
  type NoteColorClasses,
} from './colors';

export { CHROMATIC_NOTE_COLORS, CHROMATIC_OUT_OF_KEY_COLORS, SCALE_DEGREE_COLORS, type NoteColorClasses };

// MARK: - Note names

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

/** Wraps any integer into a pitch class 0–11. */
export function mod12(n: number): number {
  return ((n % 12) + 12) % 12;
}

// MARK: - Tunings

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

/** Fewest and most strings a fretboard can have. */
export const MIN_STRINGS = 4;
export const MAX_STRINGS = 8;
/** Highest capo position. */
export const MAX_CAPO = 12;
/** Frets drawn on each fretboard. */
export const FRET_COUNT = 24;

// Default tunings for different string counts
const DEFAULT_TUNINGS: Record<number, string[]> = {
  4: ['E1', 'A1', 'D2', 'G2'],                           // Bass guitar
  5: ['B0', 'E1', 'A1', 'D2', 'G2'],                     // 5-string bass
  6: ['E2', 'A2', 'D3', 'G3', 'B3', 'E4'],               // Standard guitar
  7: ['B1', 'E2', 'A2', 'D3', 'G3', 'B3', 'E4'],         // 7-string guitar
  8: ['F#1', 'B1', 'E2', 'A2', 'D3', 'G3', 'B3', 'E4'],  // 8-string guitar
};

/** Tuning (lowest string first) for a fretboard with `stringCount` strings. */
export function getDefaultTuning(stringCount: number): string[] {
  return DEFAULT_TUNINGS[stringCount] || TUNINGS.standard.notes;
}

/** Label for a string in the settings editor; strings are numbered from the highest pitch (1). */
export function getStringLabel(number: number, totalStrings: number): string {
  const standard6: Record<number, string> = { 1: '1 (High E)', 2: '2 (B)', 3: '3 (G)', 4: '4 (D)', 5: '5 (A)', 6: '6 (Low E)' };
  if (totalStrings === 6 && standard6[number]) return standard6[number];
  return `String ${number}`;
}

export interface TuningPreset {
  id: string;
  name: string;
  category: string;
  tuning: string[];
}

export const TUNING_PRESETS: TuningPreset[] = [
  // Guitar - 6 string
  { id: 'guitar-standard', name: 'Standard', category: 'Guitar (6 string)', tuning: ['E2', 'A2', 'D3', 'G3', 'B3', 'E4'] },
  { id: 'guitar-drop-d', name: 'Drop D', category: 'Guitar (6 string)', tuning: ['D2', 'A2', 'D3', 'G3', 'B3', 'E4'] },
  { id: 'guitar-drop-c', name: 'Drop C', category: 'Guitar (6 string)', tuning: ['C2', 'G2', 'C3', 'F3', 'A3', 'D4'] },
  { id: 'guitar-open-g', name: 'Open G', category: 'Guitar (6 string)', tuning: ['D2', 'G2', 'D3', 'G3', 'B3', 'D4'] },
  { id: 'guitar-open-d', name: 'Open D', category: 'Guitar (6 string)', tuning: ['D2', 'A2', 'D3', 'F#3', 'A3', 'D4'] },
  { id: 'guitar-open-e', name: 'Open E', category: 'Guitar (6 string)', tuning: ['E2', 'B2', 'E3', 'G#3', 'B3', 'E4'] },
  { id: 'guitar-dadgad', name: 'DADGAD', category: 'Guitar (6 string)', tuning: ['D2', 'A2', 'D3', 'G3', 'A3', 'D4'] },
  { id: 'guitar-half-step-down', name: 'Half Step Down', category: 'Guitar (6 string)', tuning: ['D#2', 'G#2', 'C#3', 'F#3', 'A#3', 'D#4'] },
  { id: 'guitar-full-step-down', name: 'Full Step Down', category: 'Guitar (6 string)', tuning: ['D2', 'G2', 'C3', 'F3', 'A3', 'D4'] },

  // Guitar - 7 string
  { id: 'guitar-7-standard', name: 'Standard', category: 'Guitar (7 string)', tuning: ['B1', 'E2', 'A2', 'D3', 'G3', 'B3', 'E4'] },
  { id: 'guitar-7-drop-a', name: 'Drop A', category: 'Guitar (7 string)', tuning: ['A1', 'E2', 'A2', 'D3', 'G3', 'B3', 'E4'] },

  // Guitar - 8 string
  { id: 'guitar-8-standard', name: 'Standard', category: 'Guitar (8 string)', tuning: ['F#1', 'B1', 'E2', 'A2', 'D3', 'G3', 'B3', 'E4'] },
  { id: 'guitar-8-drop-e', name: 'Drop E', category: 'Guitar (8 string)', tuning: ['E1', 'B1', 'E2', 'A2', 'D3', 'G3', 'B3', 'E4'] },

  // Bass - 4 string
  { id: 'bass-4-standard', name: 'Standard', category: 'Bass (4 string)', tuning: ['E1', 'A1', 'D2', 'G2'] },
  { id: 'bass-4-drop-d', name: 'Drop D', category: 'Bass (4 string)', tuning: ['D1', 'A1', 'D2', 'G2'] },
  { id: 'bass-4-half-step-down', name: 'Half Step Down', category: 'Bass (4 string)', tuning: ['D#1', 'G#1', 'C#2', 'F#2'] },

  // Bass - 5 string
  { id: 'bass-5-standard', name: 'Standard', category: 'Bass (5 string)', tuning: ['B0', 'E1', 'A1', 'D2', 'G2'] },
  { id: 'bass-5-tenor', name: 'Tenor (High C)', category: 'Bass (5 string)', tuning: ['E1', 'A1', 'D2', 'G2', 'C3'] },

  // Bass - 6 string
  { id: 'bass-6-standard', name: 'Standard', category: 'Bass (6 string)', tuning: ['B0', 'E1', 'A1', 'D2', 'G2', 'C3'] },

  // Ukulele
  { id: 'ukulele-soprano', name: 'Soprano/Concert/Tenor', category: 'Ukulele', tuning: ['G4', 'C4', 'E4', 'A4'] },
  { id: 'ukulele-baritone', name: 'Baritone', category: 'Ukulele', tuning: ['D3', 'G3', 'B3', 'E4'] },
  { id: 'ukulele-low-g', name: 'Low G', category: 'Ukulele', tuning: ['G3', 'C4', 'E4', 'A4'] },

  // Mandolin
  { id: 'mandolin-standard', name: 'Standard', category: 'Mandolin', tuning: ['G3', 'D4', 'A4', 'E5'] },

  // Banjo
  { id: 'banjo-open-g', name: 'Open G', category: 'Banjo (5 string)', tuning: ['G4', 'D3', 'G3', 'B3', 'D4'] },
  { id: 'banjo-standard-c', name: 'Standard C', category: 'Banjo (5 string)', tuning: ['G4', 'C3', 'G3', 'B3', 'D4'] },
];

/** Preset categories in display order. */
export const TUNING_CATEGORIES: string[] = [...new Set(TUNING_PRESETS.map(p => p.category))];

export function findPresetByTuning(tuning: string[]): TuningPreset | null {
  return TUNING_PRESETS.find(preset =>
    preset.tuning.length === tuning.length &&
    preset.tuning.every((note, i) => noteToMidi(note) === tryNoteToMidi(tuning[i]))
  ) || null;
}

// MARK: - Parsing

const LETTER_SEMITONES: Record<string, number> = { C: 0, D: 2, E: 4, F: 5, G: 7, A: 9, B: 11 };

/**
 * MIDI number (C4 = 60) for a note like 'E2', 'F#3', 'Bb4' or 'B♭4' (letter case-insensitive), or
 * null if it isn't one or falls outside 0–127. Same rules as Swift's `Note(parsing:)`.
 */
export function tryNoteToMidi(note: string): number | null {
  const match = note.trim().match(/^([A-Ga-g])([#♯b♭]?)(\d+)$/);
  if (!match) return null;
  const accidental = match[2] === '#' || match[2] === '♯' ? 1 : match[2] ? -1 : 0;
  const midi = (parseInt(match[3], 10) + 1) * 12 + LETTER_SEMITONES[match[1].toUpperCase()] + accidental;
  return midi >= 0 && midi <= 127 ? midi : null;
}

/** Sharp name and octave of a note; accepts flats ('Bb4' → A#, 4). Throws on an invalid note. */
export function parseNote(note: string): { name: NoteName; octave: number } {
  const midi = tryNoteToMidi(note);
  if (midi === null) throw new Error(`Invalid note: ${note}`);
  return { name: NOTE_NAMES[mod12(midi)], octave: Math.floor(midi / 12) - 1 };
}

/** MIDI number of a note string. Throws on an invalid note. */
export function noteToMidi(note: string): number {
  const midi = tryNoteToMidi(note);
  if (midi === null) throw new Error(`Invalid note: ${note}`);
  return midi;
}

/** Note string with a sharp name, e.g. 61 → 'C#4'. */
export function midiToNote(midi: number): string {
  const octave = Math.floor(midi / 12) - 1;
  return `${NOTE_NAMES[mod12(midi)]}${octave}`;
}

/** The canonical (sharp) spelling of a note string: 'Bb4' → 'A#4'. */
export function normalizeNote(note: string): string {
  return midiToNote(noteToMidi(note));
}

/** Pitch class 0–11 of a note string ('C#4' → 1). */
export function getPitchClass(note: string): number {
  return mod12(noteToMidi(note));
}

/** Pitch class of a note name without octave ('C#', 'Db', 'B♭'), or -1 if it isn't one. */
export function noteNameToPitchClass(name: string): number {
  const midi = tryNoteToMidi(`${name}4`);
  return midi === null ? -1 : mod12(midi);
}

export function getNoteAtFret(openNote: string, fret: number): string {
  const midi = noteToMidi(openNote) + fret;
  return midiToNote(midi);
}

/** Every note from `startNote` through `endNote`, inclusive. */
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

/** Frequency in Hz (A4 = 440). */
export function noteFrequency(note: string): number {
  return 440 * Math.pow(2, (noteToMidi(note) - 69) / 12);
}

/** Splits a display name like 'Bb' into its letter ('B') and accidental ('b'). */
export function parseNoteDisplay(displayName: string): { letter: string; accidental: string | null } {
  if (displayName.length <= 1) {
    return { letter: displayName, accidental: null };
  }
  return { letter: displayName[0], accidental: displayName.slice(1) };
}

// MARK: - Degrees

/**
 * A scale degree spelled against the major scale: `{ number: 3, accidental: -1 }` is ♭3.
 * `number` is 1–7; `accidental` is -1 for flat, +1 for sharp (±2 double).
 */
export interface Degree {
  number: number;
  accidental: number;
}

const MAJOR_SEMITONES = [0, 2, 4, 5, 7, 9, 11];

const d = (number: number, accidental = 0): Degree => ({ number, accidental });

/** Semitones above the root (0–11) for a degree. */
export function degreeSemitones(degree: Degree): number {
  return mod12(MAJOR_SEMITONES[degree.number - 1] + degree.accidental);
}

/** Accidental symbol: '𝄫', '♭', '', '♯' or '𝄪'. */
export function accidentalSymbol(accidental: number): string {
  if (accidental < -1) return '𝄫';
  if (accidental === -1) return '♭';
  if (accidental === 1) return '♯';
  if (accidental > 1) return '𝄪';
  return '';
}

/** A degree's label, e.g. '♭3', '♯4', '5'. */
export function degreeLabel(degree: Degree): string {
  return accidentalSymbol(degree.accidental) + degree.number;
}

/** How a note outside the scale is numbered, by semitones above the root (♭2 ♭3 ♯4 ♭6 ♭7). */
export const CHROMATIC_DEGREES: readonly Degree[] = [
  d(1), d(2, -1), d(2), d(3, -1), d(3), d(4), d(4, 1), d(5), d(6, -1), d(6), d(7, -1), d(7),
];

// MARK: - Scale types

/** Every scale or mode, in Swift's `ScaleType.allCases` order. */
export const SCALE_TYPES = [
  'major',
  'minor',
  'harmonicMinor',
  'melodicMinor',
  'dorian',
  'phrygian',
  'lydian',
  'mixolydian',
  'locrian',
  'majorPentatonic',
  'minorPentatonic',
  'blues',
  'wholeTone',
  'diminishedWholeHalf',
  'diminishedHalfWhole',
] as const;

export type ScaleType = typeof SCALE_TYPES[number];
/** Kept for older code: a key's type is any scale type. */
export type KeyType = ScaleType;

/** Each scale's degrees, spelled against major (natural minor is 1 2 ♭3 4 5 ♭6 ♭7). */
export const SCALE_DEGREES: Readonly<Record<ScaleType, readonly Degree[]>> = {
  major: [d(1), d(2), d(3), d(4), d(5), d(6), d(7)],
  minor: [d(1), d(2), d(3, -1), d(4), d(5), d(6, -1), d(7, -1)],
  harmonicMinor: [d(1), d(2), d(3, -1), d(4), d(5), d(6, -1), d(7)],
  melodicMinor: [d(1), d(2), d(3, -1), d(4), d(5), d(6), d(7)],
  dorian: [d(1), d(2), d(3, -1), d(4), d(5), d(6), d(7, -1)],
  phrygian: [d(1), d(2, -1), d(3, -1), d(4), d(5), d(6, -1), d(7, -1)],
  lydian: [d(1), d(2), d(3), d(4, 1), d(5), d(6), d(7)],
  mixolydian: [d(1), d(2), d(3), d(4), d(5), d(6), d(7, -1)],
  locrian: [d(1), d(2, -1), d(3, -1), d(4), d(5, -1), d(6, -1), d(7, -1)],
  majorPentatonic: [d(1), d(2), d(3), d(5), d(6)],
  minorPentatonic: [d(1), d(3, -1), d(4), d(5), d(7, -1)],
  blues: [d(1), d(3, -1), d(4), d(5, -1), d(5), d(7, -1)],
  wholeTone: [d(1), d(2), d(3), d(4, 1), d(5, 1), d(7, -1)],
  diminishedWholeHalf: [d(1), d(2), d(3, -1), d(4), d(5, -1), d(6, -1), d(6), d(7)],
  diminishedHalfWhole: [d(1), d(2, -1), d(3, -1), d(3), d(4, 1), d(5), d(6), d(7, -1)],
};

/** Semitone offsets from the root, in degree order. */
export function getScaleIntervals(type: ScaleType): number[] {
  return SCALE_DEGREES[type].map(degreeSemitones);
}

const SCALE_NAMES: Record<ScaleType, string> = {
  major: 'major',
  minor: 'minor',
  harmonicMinor: 'harmonic minor',
  melodicMinor: 'melodic minor',
  dorian: 'Dorian',
  phrygian: 'Phrygian',
  lydian: 'Lydian',
  mixolydian: 'Mixolydian',
  locrian: 'Locrian',
  majorPentatonic: 'major pentatonic',
  minorPentatonic: 'minor pentatonic',
  blues: 'blues',
  wholeTone: 'whole tone',
  diminishedWholeHalf: 'diminished (W–H)',
  diminishedHalfWhole: 'diminished (H–W)',
};

/** The scale's name as used after a root: 'major', 'Dorian', 'minor pentatonic'. */
export function getScaleTypeName(type: ScaleType): string {
  return SCALE_NAMES[type];
}

/** The name capitalized for a menu item or tile: 'Major', 'Dorian', 'Minor pentatonic'. */
export function getScaleTypeTitle(type: ScaleType): string {
  const name = SCALE_NAMES[type];
  return name.charAt(0).toUpperCase() + name.slice(1);
}

/**
 * Compact suffix for chips and narrow screens. Ones starting with 'm' attach to the root like a
 * chord symbol ('Am pent.'); the rest follow a space ('A Dorian').
 */
export function getScaleTypeShortSuffix(type: ScaleType): string {
  switch (type) {
    case 'harmonicMinor': return 'm harm.';
    case 'melodicMinor': return 'm mel.';
    case 'majorPentatonic': return ' pent.';
    case 'minorPentatonic': return 'm pent.';
    case 'diminishedWholeHalf': return ' dim. W–H';
    case 'diminishedHalfWhole': return ' dim. H–W';
    case 'mixolydian': return ' Mixo.';
    default: return ' ' + SCALE_NAMES[type];
  }
}

export type ScaleFamily = 'keys' | 'modes' | 'other';

/** Scale groups for menus and the scale bank, in order. */
export const SCALE_FAMILIES: readonly { id: ScaleFamily; title: string; types: readonly ScaleType[] }[] = [
  { id: 'keys', title: 'Major & Minor', types: ['major', 'minor', 'harmonicMinor', 'melodicMinor'] },
  { id: 'modes', title: 'Modes', types: ['dorian', 'phrygian', 'lydian', 'mixolydian', 'locrian'] },
  { id: 'other', title: 'Pentatonic & Other', types: ['majorPentatonic', 'minorPentatonic', 'blues', 'wholeTone', 'diminishedWholeHalf', 'diminishedHalfWhole'] },
];

export function getScaleFamily(type: ScaleType): ScaleFamily {
  return SCALE_FAMILIES.find(f => f.types.includes(type))!.id;
}

export function isScaleType(value: unknown): value is ScaleType {
  return typeof value === 'string' && (SCALE_TYPES as readonly string[]).includes(value);
}

// MARK: - Keys

/** A key or scale: a root plus a scale type, e.g. A minor or D Dorian. Root is a sharp name. */
export interface MusicalKey {
  root: NoteName;
  type: ScaleType;
}

/** Builds a key from a pitch class (any integer, wrapped) or a note name (sharps or flats). */
export function makeKey(root: number | string, type: ScaleType): MusicalKey {
  const pc = typeof root === 'number' ? mod12(root) : noteNameToPitchClass(root);
  if (pc < 0) throw new Error(`Invalid root: ${root}`);
  return { root: NOTE_NAMES[pc], type };
}

/** Root pitch class, 0 = C … 11 = B. */
export function getKeyRootPitchClass(key: MusicalKey): number {
  return noteNameToPitchClass(key.root);
}

/** Whether two keys are the same (null matches null). */
export function sameKey(a: MusicalKey | null, b: MusicalKey | null): boolean {
  if (!a || !b) return a === b;
  return a.root === b.root && a.type === b.type;
}

/** Stable id like Swift's `MusicalKey.id`: '9-minor'. */
export function getKeyId(key: MusicalKey): string {
  return `${getKeyRootPitchClass(key)}-${key.type}`;
}

/**
 * Reads a key from saved data: `{ root, type }` with a sharp or flat name or a pitch class, and any
 * scale type id. Returns null for anything else.
 */
export function parseStoredKey(value: unknown): MusicalKey | null {
  if (!value || typeof value !== 'object') return null;
  const { root, type } = value as { root?: unknown; type?: unknown };
  if (!isScaleType(type)) return null;
  if (typeof root === 'number' && Number.isInteger(root)) return makeKey(root, type);
  if (typeof root === 'string' && noteNameToPitchClass(root) >= 0) return makeKey(root, type);
  return null;
}

/** The 24 major and minor keys: 12 major (C…B), then 12 minor. */
export const ALL_KEYS: MusicalKey[] = [
  ...NOTE_NAMES.map(root => ({ root, type: 'major' as ScaleType })),
  ...NOTE_NAMES.map(root => ({ root, type: 'minor' as ScaleType })),
];

/** The 12 keys of one scale type, C through B (for a "More Scales" submenu). */
export function getKeysOfType(type: ScaleType): MusicalKey[] {
  return NOTE_NAMES.map(root => ({ root, type }));
}

// Major keys spelled with flats: F, Bb, Eb, Ab, Db, Gb. Minor: their relatives D, G, C, F, Bb, Eb.
const FLAT_MAJOR_ROOTS = new Set([5, 10, 3, 8, 1, 6]);
const FLAT_MINOR_ROOTS = new Set([2, 7, 0, 5, 10, 3]);

/**
 * The key whose sharps or flats spell a scale: modes borrow their parent major key (D Dorian is
 * spelled like C major); minor-flavored scales use the minor key on their root.
 */
function spellingKey(type: ScaleType, root: number): { root: number; isMajor: boolean } {
  switch (type) {
    case 'major': case 'majorPentatonic': case 'wholeTone': case 'diminishedWholeHalf': case 'diminishedHalfWhole':
      return { root, isMajor: true };
    case 'minor': case 'harmonicMinor': case 'melodicMinor': case 'minorPentatonic': case 'blues':
      return { root, isMajor: false };
    case 'dorian': return { root: root - 2, isMajor: true };
    case 'phrygian': return { root: root - 4, isMajor: true };
    case 'lydian': return { root: root - 5, isMajor: true };
    case 'mixolydian': return { root: root - 7, isMajor: true };
    case 'locrian': return { root: root + 1, isMajor: true };
  }
}

/** Whether the key is spelled with flats (e.g. F major, D minor, C Mixolydian). */
export function keyUsesFlats(key: MusicalKey | null): boolean {
  if (!key) return false;
  const spelling = spellingKey(key.type, getKeyRootPitchClass(key));
  const root = mod12(spelling.root);
  return spelling.isMajor ? FLAT_MAJOR_ROOTS.has(root) : FLAT_MINOR_ROOTS.has(root);
}

/** The key's root as displayed: 'Bb' in a flat key, or 'A#' with `useSharpsOnly`. */
export function getKeyDisplayRoot(key: MusicalKey, useSharpsOnly: boolean = false): string {
  const pc = getKeyRootPitchClass(key);
  return !useSharpsOnly && keyUsesFlats(key) ? NOTE_NAMES_FLAT[pc] : NOTE_NAMES[pc];
}

/** e.g. 'Bb major', 'D Dorian', 'A minor pentatonic' or, with `useSharpsOnly`, 'A# major'. */
export function getKeyName(key: MusicalKey, useSharpsOnly: boolean = false): string {
  return `${getKeyDisplayRoot(key, useSharpsOnly)} ${getScaleTypeName(key.type)}`;
}

/** e.g. 'Am pent.', 'D Dorian', 'Bb major', for chips and narrow screens. */
export function getKeyShortName(key: MusicalKey, useSharpsOnly: boolean = false): string {
  return getKeyDisplayRoot(key, useSharpsOnly) + getScaleTypeShortSuffix(key.type);
}

/** Whether the scale has seven notes, so chords can be built on each degree. */
export function isHeptatonic(key: MusicalKey): boolean {
  return SCALE_DEGREES[key.type].length === 7;
}

/** Pitch classes in the scale, in degree order. */
export function getKeyPitchClasses(key: MusicalKey): number[] {
  const root = getKeyRootPitchClass(key);
  return getScaleIntervals(key.type).map(i => mod12(root + i));
}

/** Note names in the scale, spelled for display (flats in flat keys unless `useSharpsOnly`). */
export function getNotesInKeyDisplay(key: MusicalKey, useSharpsOnly: boolean = false): string[] {
  const names = !useSharpsOnly && keyUsesFlats(key) ? NOTE_NAMES_FLAT : NOTE_NAMES;
  return getKeyPitchClasses(key).map(pc => names[pc]);
}

/** Note names in the scale, spelled for the key (same as `getNotesInKeyDisplay(key)`). */
export function getNotesInKey(key: MusicalKey): string[] {
  return getNotesInKeyDisplay(key, false);
}

/** The scale's degree labels, e.g. ['1', '2', '♭3', '4', '5', '♭6', '♭7']. */
export function getKeyDegreeLabels(key: MusicalKey): string[] {
  return SCALE_DEGREES[key.type].map(degreeLabel);
}

/** True when the note is in the key. With no key selected, every note counts. */
export function isNoteInKey(note: string, key: MusicalKey | null): boolean {
  if (!key) return true;
  return getKeyPitchClasses(key).includes(getPitchClass(note));
}

/** Position of the note in the scale (0 = root), or -1 if it's outside (or there's no key). */
export function getScaleIndex(note: string, key: MusicalKey | null): number {
  if (!key) return -1;
  return getKeyPitchClasses(key).indexOf(getPitchClass(note));
}

/**
 * The note's degree: as spelled by the scale when it's in it, otherwise the usual chromatic
 * spelling (♭2, ♭3, ♯4, ♭6, ♭7). C# in A minor is 3, not ♯♭3.
 */
export function getKeyDegree(note: string, key: MusicalKey): Degree {
  const semitones = mod12(getPitchClass(note) - getKeyRootPitchClass(key));
  return SCALE_DEGREES[key.type].find(deg => degreeSemitones(deg) === semitones) ?? CHROMATIC_DEGREES[semitones];
}

/** The note's degree label in the key, e.g. '♭3'. */
export function getDegreeLabel(note: string, key: MusicalKey): string {
  return degreeLabel(getKeyDegree(note, key));
}

/**
 * The note's scale-degree color slot: degree number − 1 (0–6) when it's in the key, so ♭3 and 3
 * share a color (and a pentatonic's 5 keeps the 5 color); -1 if it's outside or there's no key.
 * For the note's position in the scale use `getScaleIndex`.
 */
export function getScaleDegree(note: string, key: MusicalKey | null): number {
  if (!key || !isNoteInKey(note, key)) return -1;
  return getKeyDegree(note, key).number - 1;
}

/** 0-based index among the semitones outside the scale, or -1 if the note is in it (or no key). */
export function getChromaticIndex(note: string, key: MusicalKey | null): number {
  if (!key) return -1;
  const semitones = mod12(getPitchClass(note) - getKeyRootPitchClass(key));
  const inside = getScaleIntervals(key.type);
  const outside = Array.from({ length: 12 }, (_, i) => i).filter(s => !inside.includes(s));
  return outside.indexOf(semitones);
}

/** One octave of the scale going up from the root near middle C, ending on the octave. */
export function getAscendingScaleNotes(key: MusicalKey): string[] {
  const root = getKeyRootPitchClass(key);
  const start = 48 + root + (root < 5 ? 12 : 0);
  return [...getScaleIntervals(key.type), 12].map(i => midiToNote(start + i));
}

/** Note name (no octave) as displayed for the key: flats in flat keys unless `useSharpsOnly`. */
export function getNoteDisplayName(note: string, key: MusicalKey | null, useSharpsOnly: boolean = false): string {
  const pc = getPitchClass(note);
  return !useSharpsOnly && keyUsesFlats(key) ? NOTE_NAMES_FLAT[pc] : NOTE_NAMES[pc];
}

/** A pitch class's name as displayed for the key (root tiles): flats in flat keys unless `useSharpsOnly`. */
export function getPitchClassDisplayName(pitchClass: number, key: MusicalKey | null, useSharpsOnly: boolean = false): string {
  const pc = mod12(pitchClass);
  return !useSharpsOnly && keyUsesFlats(key) ? NOTE_NAMES_FLAT[pc] : NOTE_NAMES[pc];
}

// MARK: - Colors (palettes live in colors.ts)

/** Scale-degree color for a slot from `getScaleDegree` (0–6), or null for -1 / out of range. */
export function getScaleDegreeColor(scaleDegree: number): NoteColorClasses | null {
  if (scaleDegree < 0 || scaleDegree > 6) return null;
  return SCALE_DEGREE_COLORS[scaleDegree];
}

/** Color for a note when no key is selected, by pitch class. */
export function getChromaticNoteColor(note: string): NoteColorClasses {
  return CHROMATIC_NOTE_COLORS[getPitchClass(note)];
}

/**
 * Color for a selected note outside the key, by its position among the key's out-of-key semitones
 * (up to 7 for pentatonic scales). Null with no key or when the note is in the key.
 */
export function getOutOfKeyColor(note: string, key: MusicalKey | null): NoteColorClasses | null {
  const index = getChromaticIndex(note, key);
  if (index < 0) return null;
  return CHROMATIC_OUT_OF_KEY_COLORS[index % CHROMATIC_OUT_OF_KEY_COLORS.length];
}
