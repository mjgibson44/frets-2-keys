// The chord bank: common chord types on any root, the chords in a key, and the scale list.
// Mirrors Swift's ChordBank.swift (ChordBank, DiatonicChord, MusicalKey.diatonicChords) and the
// scale tab of ChordBankPicker.

import {
  getAscendingScaleNotes,
  getKeyDegreeLabels,
  getKeyName,
  getKeyPitchClasses,
  getKeyRootPitchClass,
  getKeyShortName,
  getNotesInKeyDisplay,
  getScaleTypeTitle,
  isHeptatonic,
  midiToNote,
  mod12,
  NOTE_NAMES,
  SCALE_DEGREES,
  SCALE_FAMILIES,
  type MusicalKey,
  type ScaleFamily,
  type ScaleType,
} from './notes';

/** A chord type in the bank, e.g. m7. */
export interface ChordQuality {
  /** The suffix `identifyChord` uses for this chord, e.g. 'maj', 'm7', 'mMaj7'. */
  readonly id: string;
  /** Short label for the picker, e.g. 'Major', 'm7♭5', '5 (power)'. */
  readonly label: string;
  /** Semitones above the root, lowest first; values above 12 reach into the next octave. */
  readonly intervals: readonly number[];
}

/** The 21 chord types, in picker order. */
export const CHORD_QUALITIES: readonly ChordQuality[] = [
  { id: 'maj', label: 'Major', intervals: [0, 4, 7] },
  { id: 'm', label: 'Minor', intervals: [0, 3, 7] },
  { id: '7', label: '7', intervals: [0, 4, 7, 10] },
  { id: 'maj7', label: 'maj7', intervals: [0, 4, 7, 11] },
  { id: 'm7', label: 'm7', intervals: [0, 3, 7, 10] },
  { id: '6', label: '6', intervals: [0, 4, 7, 9] },
  { id: 'm6', label: 'm6', intervals: [0, 3, 7, 9] },
  { id: 'sus2', label: 'sus2', intervals: [0, 2, 7] },
  { id: 'sus4', label: 'sus4', intervals: [0, 5, 7] },
  { id: '7sus4', label: '7sus4', intervals: [0, 5, 7, 10] },
  { id: 'add9', label: 'add9', intervals: [0, 4, 7, 14] },
  { id: '9', label: '9', intervals: [0, 4, 7, 10, 14] },
  { id: 'maj9', label: 'maj9', intervals: [0, 4, 7, 11, 14] },
  { id: 'm9', label: 'm9', intervals: [0, 3, 7, 10, 14] },
  { id: 'dim', label: 'dim', intervals: [0, 3, 6] },
  { id: 'dim7', label: 'dim7', intervals: [0, 3, 6, 9] },
  { id: 'm7b5', label: 'm7♭5', intervals: [0, 3, 6, 10] },
  { id: 'aug', label: 'aug', intervals: [0, 4, 8] },
  { id: 'mMaj7', label: 'm(maj7)', intervals: [0, 3, 7, 11] },
  { id: 'augMaj7', label: 'maj7♯5', intervals: [0, 4, 8, 11] },
  { id: '5', label: '5 (power)', intervals: [0, 7, 12] },
];

/** A quality by id, falling back to Major for an unknown id (as the Swift picker does). */
export function getChordQuality(id: string): ChordQuality {
  return CHORD_QUALITIES.find(q => q.id === id) ?? CHORD_QUALITIES[0];
}

/** MIDI number of the lowest root used for voicings: C3, so roots run C3–B3 around middle C. */
export const CHORD_BANK_BASE_MIDI = 48;

/**
 * The chord's notes as close, root-position piano voicings: root (pitch class, 0 = C) in the C3–B3
 * octave, then each interval above it. E.g. (9, m7) → ['A3', 'C4', 'E4', 'G4'].
 */
export function getChordBankNotes(root: number, quality: ChordQuality): string[] {
  const rootMidi = CHORD_BANK_BASE_MIDI + mod12(root);
  return quality.intervals.map(i => midiToNote(rootMidi + i));
}

/** The chord's name as the app shows it: sharp root + quality id, e.g. 'C#m7', 'Cmaj'. */
export function getChordBankName(root: number, quality: ChordQuality): string {
  return `${NOTE_NAMES[mod12(root)]}${quality.id}`;
}

/** Compact suffix for diatonic chord tiles: '' for major, 'm', '°', '°7', '+', 'ø7', 'maj7', … */
export function getChordTileSuffix(quality: ChordQuality): string {
  switch (quality.id) {
    case 'maj': return '';
    case 'dim': return '°';
    case 'dim7': return '°7';
    case 'aug': return '+';
    case 'augMaj7': return '+maj7';
    case 'mMaj7': return 'm(maj7)';
    case 'm7b5': return 'ø7';
    default: return quality.id;
  }
}

// MARK: - Chords in a key

/** A chord built on one degree of a key, e.g. 'ii' = Dm in C major. */
export interface DiatonicChord {
  /** Roman numeral with the degree's accidental and quality mark: 'ii', '♭VII', 'vii°', 'V7', 'iiø7'. */
  numeral: string;
  /** Root pitch class, 0 = C. */
  root: number;
  quality: ChordQuality;
}

const NUMERALS = ['I', 'II', 'III', 'IV', 'V', 'VI', 'VII'];

/**
 * The chords built by stacking thirds on each scale degree: triads, or seventh chords with
 * `sevenths`. Numerals carry the degree's accidental, so A minor reads i ii° ♭III iv v ♭VI ♭VII.
 * Empty for scales that don't have seven notes; a degree whose stack isn't a bank chord is skipped.
 */
export function getDiatonicChords(key: MusicalKey, sevenths: boolean = false): DiatonicChord[] {
  if (!isHeptatonic(key)) return [];
  const scale = getKeyPitchClasses(key);
  const degrees = SCALE_DEGREES[key.type];
  const stack = sevenths ? [0, 2, 4, 6] : [0, 2, 4];
  const chords: DiatonicChord[] = [];
  scale.forEach((root, degree) => {
    // Semitones above the root for each stacked scale tone (a seventh stays within the octave).
    const intervals = stack.map(step => mod12(scale[(degree + step) % 7] - root));
    const quality = CHORD_QUALITIES.find(q =>
      q.intervals.length === intervals.length && q.intervals.every((v, i) => v === intervals[i]));
    if (!quality) return;
    const isMinorish = intervals[1] === 3;
    const accidental = degrees[degree].accidental < 0 ? '♭' : degrees[degree].accidental > 0 ? '♯' : '';
    let numeral = accidental + (isMinorish ? NUMERALS[degree].toLowerCase() : NUMERALS[degree]);
    switch (quality.id) {
      case 'dim': numeral += '°'; break;
      case 'dim7': numeral += '°7'; break;
      case 'm7b5': numeral += 'ø7'; break;
      case 'aug': numeral += '+'; break;
      case 'augMaj7': numeral += '+maj7'; break;
      case 'mMaj7': numeral += '(maj7)'; break;
      case 'maj7': numeral += 'maj7'; break;
      case '7': case 'm7': numeral += '7'; break;
    }
    chords.push({ numeral, root, quality });
  });
  return chords;
}

/** The notes of a diatonic chord, voiced like the bank. */
export function getDiatonicChordNotes(chord: DiatonicChord): string[] {
  return getChordBankNotes(chord.root, chord.quality);
}

// MARK: - Scales tab

/** One scale family for the Scales tab: title plus its scale types with capitalized titles. */
export interface ScaleBankFamily {
  id: ScaleFamily;
  /** 'Major & Minor', 'Modes', 'Pentatonic & Other'. */
  title: string;
  types: { type: ScaleType; title: string }[];
}

/** All 15 scales grouped by family, in Swift's order, with tile titles ('Major', 'Minor pentatonic', 'Diminished (W–H)'). */
export const SCALE_BANK_FAMILIES: readonly ScaleBankFamily[] = SCALE_FAMILIES.map(family => ({
  id: family.id,
  title: family.title,
  types: family.types.map(type => ({ type, title: getScaleTypeTitle(type) })),
}));

/** One note of a scale, for the Scales tab footer chips. */
export interface ScaleNoteEntry {
  /** Display name, spelled for the scale (or sharps only). */
  name: string;
  /** Degree label, e.g. '♭3'. */
  degreeLabel: string;
  /** Scale-degree color slot (degree number − 1, 0–6) for `SCALE_DEGREE_COLORS`. */
  colorIndex: number;
}

/** Everything the Scales tab shows (and saves) for a root + scale type. */
export interface ScaleBankEntry {
  key: MusicalKey;
  /** Root pitch class, 0 = C. */
  root: number;
  /** 'A minor pentatonic' (the name a saved scale gets uses sharpsOnly = false, as in Swift). */
  name: string;
  /** 'Am pent.' */
  shortName: string;
  /** One chip per scale note, in degree order. */
  notes: ScaleNoteEntry[];
  /** One octave going up from the root near middle C, ending on the octave: playback and saving. */
  ascendingNotes: string[];
}

/** The scale on `key`, ready for the Scales tab. */
export function getScaleBankEntry(key: MusicalKey, sharpsOnly: boolean = false): ScaleBankEntry {
  const names = getNotesInKeyDisplay(key, sharpsOnly);
  const labels = getKeyDegreeLabels(key);
  return {
    key,
    root: getKeyRootPitchClass(key),
    name: getKeyName(key, sharpsOnly),
    shortName: getKeyShortName(key, sharpsOnly),
    notes: SCALE_DEGREES[key.type].map((degree, i) => ({
      name: names[i],
      degreeLabel: labels[i],
      colorIndex: degree.number - 1,
    })),
    ascendingNotes: getAscendingScaleNotes(key),
  };
}
