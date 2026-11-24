// What the note badges on the instruments say and how they're colored. Mirrors Swift's
// NoteAppearance.swift (NoteLabelContent, NoteLabelContext, NoteAppearance) and IntervalSpeller.

import { type NoteColorRole } from './colors';
import { getChordRootPitchClass } from './chords';
import {
  getChromaticIndex,
  getDegreeLabel,
  getKeyDegree,
  getKeyDegreeLabels,
  getNoteDisplayName,
  getNotesInKeyDisplay,
  getPitchClass,
  isNoteInKey,
  midiToNote,
  mod12,
  noteToMidi,
  type MusicalKey,
} from './notes';

export type { NoteColorRole };

/** Whether out-of-key notes are labeled (dimmed) or left blank. */
export type KeyLabelMode = 'onlyInKey' | 'showAll';
/** Whether names use flats in flat keys or always sharps. */
export type NoteLabelMode = 'sharpsAndFlats' | 'sharpsOnly';

/** What the badges say: note names (C, E♭), scale degrees (1, ♭3), or intervals from the chord root (R, 3, ♭7). */
export type NoteLabelContent = 'names' | 'degrees' | 'intervals';

/** The label options in order, with their titles ('Notes', 'Degrees', 'Intervals'). */
export const NOTE_LABEL_CONTENTS: readonly { id: NoteLabelContent; title: string }[] = [
  { id: 'names', title: 'Notes' },
  { id: 'degrees', title: 'Degrees' },
  { id: 'intervals', title: 'Intervals' },
];

/** The next option, for a shortcut that cycles through them. */
export function getNextNoteLabelContent(content: NoteLabelContent): NoteLabelContent {
  const index = NOTE_LABEL_CONTENTS.findIndex(c => c.id === content);
  return NOTE_LABEL_CONTENTS[(index + 1) % NOTE_LABEL_CONTENTS.length].id;
}

// MARK: - Intervals

/**
 * Names a note by its interval above a chord's root (R, 3, 5, ♭7…), spelled to suit the chord:
 * with a 7th, other notes read as extensions (9, 11, 13); an augmented chord has a ♯5; a dim7 has
 * a 𝄫7. `chordNotes` are the chord's notes (any octave); `root` is its root pitch class.
 */
export function getIntervalLabel(note: string, root: number, chordNotes: readonly string[]): string {
  const r = mod12(root);
  const tones = new Set(chordNotes.map(n => mod12(getPitchClass(n) - r)));
  const has = (s: number) => tones.has(s);
  const hasThird = has(3) || has(4);
  const hasSeventh = has(10) || has(11);
  // Extensions: a seventh chord, or an add9 (a third plus a 2nd).
  const extended = hasThird && (hasSeventh || has(2));
  switch (mod12(getPitchClass(note) - r)) {
    case 0: return 'R';
    case 1: return extended ? '♭9' : '♭2';
    case 2: return extended ? '9' : '2';
    case 3: return has(4) && hasSeventh ? '♯9' : '♭3';
    case 4: return '3';
    case 5: return extended ? '11' : '4';
    case 6: return has(7) && extended ? '♯11' : '♭5';
    case 7: return '5';
    case 8: return has(4) && !has(7) ? '♯5' : (hasSeventh ? '♭13' : '♭6');
    case 9: return has(3) && has(6) && !hasSeventh ? '𝄫7' : (hasSeventh ? '13' : '6');
    case 10: return '♭7';
    default: return '7';
  }
}

// MARK: - Label context

/**
 * Everything besides the note itself that decides how notes are labeled and colored. Build it
 * once per render with `createNoteLabelContext`, not per fret.
 */
export interface NoteLabelContext {
  key: MusicalKey | null;
  keyLabelMode: KeyLabelMode;
  noteLabelMode: NoteLabelMode;
  content: NoteLabelContent;
  /** Set when labeling by interval and there's a chord to measure from. */
  intervals: { root: number; chordNotes: readonly string[] } | null;
}

export interface NoteLabelContextOptions {
  key: MusicalKey | null;
  keyLabelMode?: KeyLabelMode;
  noteLabelMode?: NoteLabelMode;
  content?: NoteLabelContent;
  /** The notes intervals measure from (the selection, or a saved chord being shown). */
  chordNotes?: readonly string[];
  /** Overrides the root found by identifying `chordNotes` (e.g. a saved scale's root). */
  chordRoot?: number | null;
}

/**
 * Builds a label context, like Swift's `AppState.noteLabelContext(for:)`: with `content`
 * 'intervals', the root is the identified chord's root (not the bass). Defaults: 'showAll',
 * 'sharpsAndFlats', 'names'.
 */
export function createNoteLabelContext(options: NoteLabelContextOptions): NoteLabelContext {
  const content = options.content ?? 'names';
  const chordNotes = options.chordNotes ?? [];
  let intervals: NoteLabelContext['intervals'] = null;
  if (content === 'intervals' && chordNotes.length > 0) {
    const root = options.chordRoot ?? getChordRootPitchClass([...chordNotes]);
    if (root !== null) intervals = { root, chordNotes };
  }
  return {
    key: options.key,
    keyLabelMode: options.keyLabelMode ?? 'showAll',
    noteLabelMode: options.noteLabelMode ?? 'sharpsAndFlats',
    content,
    intervals,
  };
}

/**
 * The label for a note. Degrees need a key and intervals need a chord; without them, notes fall
 * back to their names (flats in flat keys unless sharps only).
 */
export function getNoteLabel(note: string, context: NoteLabelContext): string {
  if (context.content === 'degrees' && context.key) return getDegreeLabel(note, context.key);
  if (context.content === 'intervals' && context.intervals) {
    return getIntervalLabel(note, context.intervals.root, context.intervals.chordNotes);
  }
  return getNoteDisplayName(note, context.key, context.noteLabelMode === 'sharpsOnly');
}

/**
 * One-shot label text without building a context first. `chordNotes` (or `chordRoot`) are only
 * used for 'intervals'. Prefer `createNoteLabelContext` + `getNoteLabel` in render loops.
 */
export function getNoteLabelText(
  note: string,
  key: MusicalKey | null,
  content: NoteLabelContent,
  options: { chordNotes?: readonly string[]; chordRoot?: number | null; sharpsOnly?: boolean } = {},
): string {
  return getNoteLabel(note, createNoteLabelContext({
    key,
    content,
    chordNotes: options.chordNotes,
    chordRoot: options.chordRoot,
    noteLabelMode: options.sharpsOnly ? 'sharpsOnly' : 'sharpsAndFlats',
  }));
}

/** Spoken name: 'Bb3', plus the degree or interval when those are showing ('Bb3, ♭7'). */
export function getNoteAccessibilityName(note: string, context: NoteLabelContext): string {
  const name = getNoteDisplayName(note, context.key, context.noteLabelMode === 'sharpsOnly');
  const withOctave = `${name}${Math.floor(noteToMidi(note) / 12) - 1}`;
  const label = getNoteLabel(note, context);
  return label === name ? withOctave : `${withOctave}, ${label}`;
}

/**
 * Splits a label for drawing with a small raised accidental. Names put it after the letter
 * ('Bb' → B + b); degrees and intervals put it first ('♭3' → ♭ + 3). `smallDigits` is true for
 * two-digit intervals (11, 13), which Swift draws a point smaller.
 */
export function splitNoteLabel(label: string): {
  main: string;
  accidental: string | null;
  accidentalFirst: boolean;
  smallDigits: boolean;
} {
  const chars = Array.from(label);
  const leading = ['♭', '♯', '𝄫', '𝄪'];
  if (chars.length > 1 && leading.includes(chars[0])) {
    const main = chars.slice(1).join('');
    return { main, accidental: chars[0], accidentalFirst: true, smallDigits: /^\d{2,}$/.test(main) };
  }
  if (chars.length <= 1) {
    return { main: label, accidental: null, accidentalFirst: false, smallDigits: false };
  }
  if (/^\d+$/.test(label)) {
    return { main: label, accidental: null, accidentalFirst: false, smallDigits: true };
  }
  return { main: chars[0], accidental: chars.slice(1).join(''), accidentalFirst: false, smallDigits: false };
}

// MARK: - Colors and appearance

/** Color role for a note (selected notes and header/bank chips): scale degree, out of key, or chromatic. */
export function getNoteColorRole(note: string, key: MusicalKey | null): NoteColorRole {
  if (key) {
    if (isNoteInKey(note, key)) return { kind: 'scaleDegree', index: getKeyDegree(note, key).number - 1 };
    const index = getChromaticIndex(note, key);
    if (index >= 0) return { kind: 'outOfKey', index };
  }
  return { kind: 'chromatic', index: getPitchClass(note) };
}

/** Color role for a pitch class (root tiles in the chord bank). */
export function getPitchClassColorRole(pitchClass: number, key: MusicalKey | null): NoteColorRole {
  return getNoteColorRole(midiToNote(60 + mod12(pitchClass)), key);
}

/**
 * How a badge is drawn:
 * - `selected`: solid in `role`'s color, white text.
 * - `inKey`: unselected in-key note, tinted with scale-degree color `scaleDegree` (0–6) plus border.
 * - `plain`: plain text.
 */
export type NoteBadgeStyle =
  | { kind: 'selected'; role: NoteColorRole }
  | { kind: 'inKey'; scaleDegree: number }
  | { kind: 'plain' };

/** How one note position (a fret or piano key) should be drawn. */
export interface NoteAppearance {
  style: NoteBadgeStyle;
  isSelected: boolean;
  /** False for out-of-key, unselected notes in 'onlyInKey' mode. */
  showsLabel: boolean;
  /** Out-of-key, unselected notes in 'showAll' mode (Swift draws them at 30% opacity). */
  isDimmed: boolean;
  label: string;
}

/** Works out a note's badge, like Swift's `NoteAppearance(note:isSelected:context:)`. */
export function getNoteAppearance(note: string, isSelected: boolean, context: NoteLabelContext): NoteAppearance {
  const { key } = context;
  const inKey = isNoteInKey(note, key);
  let style: NoteBadgeStyle;
  if (isSelected) {
    style = { kind: 'selected', role: getNoteColorRole(note, key) };
  } else if (key && inKey) {
    style = { kind: 'inKey', scaleDegree: getKeyDegree(note, key).number - 1 };
  } else {
    style = { kind: 'plain' };
  }
  return {
    style,
    isSelected,
    showsLabel: !(context.keyLabelMode === 'onlyInKey' && !inKey && !isSelected),
    isDimmed: context.keyLabelMode === 'showAll' && !inKey && !isSelected,
    label: getNoteLabel(note, context),
  };
}

// MARK: - Key menu

/** Degree labels for a key, e.g. ['1', '2', '♭3', …] (re-exported for the key menu). */
export { getKeyDegreeLabels };

/**
 * The line under/next to the key name in the key menu: degree labels when labeling by degree,
 * otherwise the scale's note names, joined by spaces ('1 2 ♭3 4 5 ♭6 ♭7' or 'A B C D E F G').
 */
export function getKeySummaryText(key: MusicalKey, content: NoteLabelContent, sharpsOnly: boolean = false): string {
  return (content === 'degrees' ? getKeyDegreeLabels(key) : getNotesInKeyDisplay(key, sharpsOnly)).join(' ');
}
