// Names a set of notes as a chord (e.g. 'Cmaj', 'Am7/G', 'G7*'). Mirrors Swift's ChordIdentifier.

import { mod12, noteToMidi, NOTE_NAMES } from './notes';

interface ChordPattern {
  name: string;
  /** Pitch-class intervals from the root, deduplicated and sorted. */
  intervals: number[];
}

const pattern = (name: string, intervals: number[]): ChordPattern => ({
  name,
  intervals: [...new Set(intervals.map(mod12))].sort((a, b) => a - b),
});

// Order matters: the first exact match wins.
const CHORD_PATTERNS: ChordPattern[] = [
  // Triads
  pattern('maj', [0, 4, 7]),
  pattern('m', [0, 3, 7]),
  pattern('dim', [0, 3, 6]),
  pattern('aug', [0, 4, 8]),
  pattern('sus2', [0, 2, 7]),
  pattern('sus4', [0, 5, 7]),

  // Seventh chords
  pattern('maj7', [0, 4, 7, 11]),
  pattern('7', [0, 4, 7, 10]),
  pattern('m7', [0, 3, 7, 10]),
  pattern('mMaj7', [0, 3, 7, 11]),
  pattern('dim7', [0, 3, 6, 9]),
  pattern('m7b5', [0, 3, 6, 10]),
  pattern('aug7', [0, 4, 8, 10]),
  pattern('augMaj7', [0, 4, 8, 11]),
  pattern('7sus4', [0, 5, 7, 10]),
  pattern('7sus2', [0, 2, 7, 10]),
  pattern('maj7sus4', [0, 5, 7, 11]),
  pattern('maj7sus2', [0, 2, 7, 11]),

  // Sixth chords
  pattern('6', [0, 4, 7, 9]),
  pattern('m6', [0, 3, 7, 9]),
  pattern('6/9', [0, 4, 7, 9, 2]),
  pattern('m6/9', [0, 3, 7, 9, 2]),

  // Ninth chords
  pattern('9', [0, 4, 7, 10, 2]),
  pattern('maj9', [0, 4, 7, 11, 2]),
  pattern('m9', [0, 3, 7, 10, 2]),
  pattern('mMaj9', [0, 3, 7, 11, 2]),
  pattern('9sus4', [0, 5, 7, 10, 2]),
  pattern('add9', [0, 4, 7, 2]),
  pattern('madd9', [0, 3, 7, 2]),
  pattern('7b9', [0, 4, 7, 10, 1]),
  pattern('7#9', [0, 4, 7, 10, 3]),
  pattern('maj7#9', [0, 4, 7, 11, 3]),

  // Eleventh chords
  pattern('11', [0, 4, 7, 10, 2, 5]),
  pattern('maj11', [0, 4, 7, 11, 2, 5]),
  pattern('m11', [0, 3, 7, 10, 2, 5]),
  pattern('7#11', [0, 4, 7, 10, 6]),
  pattern('maj7#11', [0, 4, 7, 11, 6]),
  pattern('add11', [0, 4, 7, 5]),
  pattern('madd11', [0, 3, 7, 5]),
  // Partial 11ths (no 9th)
  pattern('11', [0, 4, 7, 10, 5]),
  pattern('m11', [0, 3, 7, 10, 5]),
  pattern('maj11', [0, 4, 7, 11, 5]),

  // Thirteenth chords
  pattern('13', [0, 4, 7, 10, 2, 9]),
  pattern('maj13', [0, 4, 7, 11, 2, 9]),
  pattern('m13', [0, 3, 7, 10, 2, 9]),
  pattern('13sus4', [0, 5, 7, 10, 2, 9]),
  // Partial 13ths (no 9th or 11th)
  pattern('13', [0, 4, 7, 10, 9]),
  pattern('maj13', [0, 4, 7, 11, 9]),
  pattern('m13', [0, 3, 7, 10, 9]),
  pattern('7add13', [0, 4, 7, 10, 9]),

  // Altered chords
  pattern('7b5', [0, 4, 6, 10]),
  pattern('7#5', [0, 4, 8, 10]),
  pattern('maj7b5', [0, 4, 6, 11]),
  pattern('maj7#5', [0, 4, 8, 11]),
  pattern('7b5b9', [0, 4, 6, 10, 1]),
  pattern('7#5#9', [0, 4, 8, 10, 3]),
  pattern('7alt', [0, 4, 6, 10, 1]),
  pattern('7b9b5', [0, 4, 6, 10, 1]),
  pattern('7#9#5', [0, 4, 8, 10, 3]),

  // Add chords
  pattern('add4', [0, 4, 5, 7]),
  pattern('madd4', [0, 3, 5, 7]),
  pattern('add2', [0, 2, 4, 7]),
  pattern('madd2', [0, 2, 3, 7]),

  // Shell voicings: no 5th
  pattern('maj7', [0, 4, 11]),
  pattern('7', [0, 4, 10]),
  pattern('m7', [0, 3, 10]),
  pattern('mMaj7', [0, 3, 11]),
  // No 3rd
  pattern('7sus', [0, 7, 10]),
  pattern('maj7sus', [0, 7, 11]),
  // Root + 7th only
  pattern('maj7', [0, 11]),
  pattern('7', [0, 10]),

  // Quartal
  pattern('quartal', [0, 5, 10]),
  pattern('quartal', [0, 5, 10, 3]),

  // Power chord
  pattern('5', [0, 7]),

  // Intervals
  pattern(' (octave)', [0]),
  pattern(' (min 2nd)', [0, 1]),
  pattern(' (maj 2nd)', [0, 2]),
  pattern(' (min 3rd)', [0, 3]),
  pattern(' (maj 3rd)', [0, 4]),
  pattern(' (4th)', [0, 5]),
  pattern(' (tritone)', [0, 6]),
  pattern(' (5th)', [0, 7]),
  pattern(' (min 6th)', [0, 8]),
  pattern(' (maj 6th)', [0, 9]),
  pattern(' (min 7th)', [0, 10]),
  pattern(' (maj 7th)', [0, 11]),
];

function intervalsFrom(midiNotes: number[], rootMidi: number): number[] {
  return [...new Set(midiNotes.map(midi => mod12(midi - rootMidi)))].sort((a, b) => a - b);
}

function sameIntervals(a: number[], b: number[]): boolean {
  return a.length === b.length && a.every((value, i) => value === b[i]);
}

/** Best pattern whose intervals are all present, preferring the most complete match. */
function subsetMatch(intervals: number[]): ChordPattern | null {
  let best: ChordPattern | null = null;
  let bestScore = 0;
  for (const candidate of CHORD_PATTERNS) {
    if (candidate.intervals.length > intervals.length) continue;
    // Plain intervals aren't meaningful once there are 3+ distinct pitches.
    if (candidate.intervals.length <= 2 && intervals.length > 2) continue;
    if (!candidate.intervals.every(i => intervals.includes(i))) continue;
    const score = candidate.intervals.length * 10 - (intervals.length - candidate.intervals.length);
    if (score > bestScore) {
      bestScore = score;
      best = candidate;
    }
  }
  return best;
}

/**
 * The chord's name: root + suffix, with '/bass' when the lowest note isn't the root and '*' when
 * there are extra notes beyond a known chord. A single note (or one pitch in several octaves) is
 * its sharp name. Null for no notes. Accepts flat note strings too.
 */
export function identifyChord(notes: string[]): string | null {
  if (notes.length === 0) return null;
  if (notes.length === 1) return NOTE_NAMES[mod12(noteToMidi(notes[0]))];

  const midiNotes = notes.map(noteToMidi).sort((a, b) => a - b);
  const bassName = NOTE_NAMES[mod12(midiNotes[0])];
  if (new Set(midiNotes.map(mod12)).size === 1) return bassName;

  const name = (rootMidi: number, suffix: string) => {
    const chord = `${NOTE_NAMES[mod12(rootMidi)]}${suffix}`;
    return NOTE_NAMES[mod12(rootMidi)] === bassName ? chord : `${chord}/${bassName}`;
  };

  // Exact match, trying each note as the root from the bass up.
  for (const rootMidi of midiNotes) {
    const intervals = intervalsFrom(midiNotes, rootMidi);
    const match = CHORD_PATTERNS.find(p => sameIntervals(p.intervals, intervals));
    if (match) return name(rootMidi, match.name);
  }

  // Subset match: a known chord plus extra notes, flagged with '*'.
  for (const rootMidi of midiNotes) {
    const intervals = intervalsFrom(midiNotes, rootMidi);
    const match = subsetMatch(intervals);
    if (match) return name(rootMidi, match.name + (intervals.length > match.intervals.length ? '*' : ''));
  }

  const fromBass = intervalsFrom(midiNotes, midiNotes[0]);
  const hasThird = fromBass.includes(3) || fromBass.includes(4);
  const hasFifth = fromBass.includes(6) || fromBass.includes(7) || fromBass.includes(8);
  if (hasThird && hasFifth) return `${bassName}?`;
  return `${bassName} (unrecognized)`;
}

/**
 * A chord's root pitch class (0 = C), read from its name ('C#m7/G' → 1). Names from
 * `identifyChord` always start with the root; falls back to the lowest note, or null with no notes.
 */
export function getChordRoot(name: string, notes: string[]): number | null {
  const prefix = name.length > 1 && name[1] === '#' ? name.slice(0, 2) : name.slice(0, 1);
  const index = (NOTE_NAMES as readonly string[]).indexOf(prefix);
  if (index >= 0) return index;
  if (notes.length === 0) return null;
  return mod12(Math.min(...notes.map(noteToMidi)));
}

/** The root pitch class of the chord these notes make (not the bass), or null with no notes. */
export function getChordRootPitchClass(notes: string[]): number | null {
  if (notes.length === 0) return null;
  return getChordRoot(identifyChord(notes) ?? '', notes);
}
