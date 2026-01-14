import { noteToMidi, NOTE_NAMES } from './notes';

interface ChordPattern {
  name: string;
  intervals: number[];
}

// Intervals from root (in semitones)
const CHORD_PATTERNS: ChordPattern[] = [
  // === TRIADS ===
  { name: 'maj', intervals: [0, 4, 7] },
  { name: 'm', intervals: [0, 3, 7] },
  { name: 'dim', intervals: [0, 3, 6] },
  { name: 'aug', intervals: [0, 4, 8] },
  { name: 'sus2', intervals: [0, 2, 7] },
  { name: 'sus4', intervals: [0, 5, 7] },

  // === SEVENTH CHORDS ===
  { name: 'maj7', intervals: [0, 4, 7, 11] },
  { name: '7', intervals: [0, 4, 7, 10] },
  { name: 'm7', intervals: [0, 3, 7, 10] },
  { name: 'mMaj7', intervals: [0, 3, 7, 11] },
  { name: 'dim7', intervals: [0, 3, 6, 9] },
  { name: 'm7b5', intervals: [0, 3, 6, 10] },
  { name: 'aug7', intervals: [0, 4, 8, 10] },
  { name: 'augMaj7', intervals: [0, 4, 8, 11] },
  { name: '7sus4', intervals: [0, 5, 7, 10] },
  { name: '7sus2', intervals: [0, 2, 7, 10] },
  { name: 'maj7sus4', intervals: [0, 5, 7, 11] },
  { name: 'maj7sus2', intervals: [0, 2, 7, 11] },

  // === SIXTH CHORDS ===
  { name: '6', intervals: [0, 4, 7, 9] },
  { name: 'm6', intervals: [0, 3, 7, 9] },
  { name: '6/9', intervals: [0, 4, 7, 9, 2] },
  { name: 'm6/9', intervals: [0, 3, 7, 9, 2] },

  // === NINTH CHORDS ===
  { name: '9', intervals: [0, 4, 7, 10, 2] },
  { name: 'maj9', intervals: [0, 4, 7, 11, 2] },
  { name: 'm9', intervals: [0, 3, 7, 10, 2] },
  { name: 'mMaj9', intervals: [0, 3, 7, 11, 2] },
  { name: '9sus4', intervals: [0, 5, 7, 10, 2] },
  { name: 'add9', intervals: [0, 4, 7, 2] },
  { name: 'madd9', intervals: [0, 3, 7, 2] },
  { name: '7b9', intervals: [0, 4, 7, 10, 1] },
  { name: '7#9', intervals: [0, 4, 7, 10, 3] },
  { name: 'maj7#9', intervals: [0, 4, 7, 11, 3] },

  // === ELEVENTH CHORDS ===
  { name: '11', intervals: [0, 4, 7, 10, 2, 5] },
  { name: 'maj11', intervals: [0, 4, 7, 11, 2, 5] },
  { name: 'm11', intervals: [0, 3, 7, 10, 2, 5] },
  { name: '7#11', intervals: [0, 4, 7, 10, 6] },
  { name: 'maj7#11', intervals: [0, 4, 7, 11, 6] },
  { name: 'add11', intervals: [0, 4, 7, 5] },
  { name: 'madd11', intervals: [0, 3, 7, 5] },
  // Partial 11ths (no 9th)
  { name: '11', intervals: [0, 4, 7, 10, 5] },
  { name: 'm11', intervals: [0, 3, 7, 10, 5] },
  { name: 'maj11', intervals: [0, 4, 7, 11, 5] },

  // === THIRTEENTH CHORDS ===
  { name: '13', intervals: [0, 4, 7, 10, 2, 9] },
  { name: 'maj13', intervals: [0, 4, 7, 11, 2, 9] },
  { name: 'm13', intervals: [0, 3, 7, 10, 2, 9] },
  { name: '13sus4', intervals: [0, 5, 7, 10, 2, 9] },
  // Partial 13ths (no 9th or 11th)
  { name: '13', intervals: [0, 4, 7, 10, 9] },
  { name: 'maj13', intervals: [0, 4, 7, 11, 9] },
  { name: 'm13', intervals: [0, 3, 7, 10, 9] },
  { name: '7add13', intervals: [0, 4, 7, 10, 9] },

  // === ALTERED CHORDS ===
  { name: '7b5', intervals: [0, 4, 6, 10] },
  { name: '7#5', intervals: [0, 4, 8, 10] },
  { name: 'maj7b5', intervals: [0, 4, 6, 11] },
  { name: 'maj7#5', intervals: [0, 4, 8, 11] },
  { name: '7b5b9', intervals: [0, 4, 6, 10, 1] },
  { name: '7#5#9', intervals: [0, 4, 8, 10, 3] },
  { name: '7alt', intervals: [0, 4, 6, 10, 1] },
  { name: '7b9b5', intervals: [0, 4, 6, 10, 1] },
  { name: '7#9#5', intervals: [0, 4, 8, 10, 3] },

  // === ADD CHORDS ===
  { name: 'add4', intervals: [0, 4, 5, 7] },
  { name: 'madd4', intervals: [0, 3, 5, 7] },
  { name: 'add2', intervals: [0, 2, 4, 7] },
  { name: 'madd2', intervals: [0, 2, 3, 7] },

  // === PARTIAL/SHELL VOICINGS ===
  // No 5th voicings
  { name: 'maj7', intervals: [0, 4, 11] },
  { name: '7', intervals: [0, 4, 10] },
  { name: 'm7', intervals: [0, 3, 10] },
  { name: 'mMaj7', intervals: [0, 3, 11] },
  // No 3rd voicings
  { name: '7sus', intervals: [0, 7, 10] },
  { name: 'maj7sus', intervals: [0, 7, 11] },
  // Root + 7th only
  { name: 'maj7', intervals: [0, 11] },
  { name: '7', intervals: [0, 10] },

  // === CLUSTERS AND QUARTAL ===
  { name: 'quartal', intervals: [0, 5, 10] },
  { name: 'quartal', intervals: [0, 5, 10, 3] },

  // === POWER CHORD ===
  { name: '5', intervals: [0, 7] },

  // === INTERVALS (2 notes) ===
  { name: ' (octave)', intervals: [0] },
  { name: ' (min 2nd)', intervals: [0, 1] },
  { name: ' (maj 2nd)', intervals: [0, 2] },
  { name: ' (min 3rd)', intervals: [0, 3] },
  { name: ' (maj 3rd)', intervals: [0, 4] },
  { name: ' (4th)', intervals: [0, 5] },
  { name: ' (tritone)', intervals: [0, 6] },
  { name: ' (5th)', intervals: [0, 7] },
  { name: ' (min 6th)', intervals: [0, 8] },
  { name: ' (maj 6th)', intervals: [0, 9] },
  { name: ' (min 7th)', intervals: [0, 10] },
  { name: ' (maj 7th)', intervals: [0, 11] },
];

function getNoteNameFromMidi(midi: number): string {
  return NOTE_NAMES[midi % 12];
}

function getIntervalsFromRoot(midiNotes: number[], rootMidi: number): number[] {
  return midiNotes
    .map(midi => ((midi - rootMidi) % 12 + 12) % 12)
    .sort((a, b) => a - b)
    .filter((interval, index, arr) => arr.indexOf(interval) === index); // unique
}

function normalizePatternIntervals(intervals: number[]): number[] {
  // Normalize all intervals to be within 0-11 (one octave)
  return [...new Set(intervals.map(i => ((i % 12) + 12) % 12))].sort((a, b) => a - b);
}

function matchChordPattern(intervals: number[]): ChordPattern | null {
  // First try exact match
  for (const pattern of CHORD_PATTERNS) {
    const normalizedPattern = normalizePatternIntervals(pattern.intervals);
    if (normalizedPattern.length !== intervals.length) continue;

    const matches = normalizedPattern.every(interval => intervals.includes(interval));
    if (matches) return pattern;
  }
  return null;
}

// Try to find a subset match (chord with additional notes)
function matchChordPatternSubset(intervals: number[]): ChordPattern | null {
  let bestMatch: ChordPattern | null = null;
  let bestScore = 0;

  for (const pattern of CHORD_PATTERNS) {
    const normalizedPattern = normalizePatternIntervals(pattern.intervals);

    // Skip if pattern has more notes than we have
    if (normalizedPattern.length > intervals.length) continue;

    // Skip simple intervals when we have more notes
    if (normalizedPattern.length <= 2 && intervals.length > 2) continue;

    // Check if all pattern intervals are present in our intervals
    const allPresent = normalizedPattern.every(interval => intervals.includes(interval));

    if (allPresent) {
      // Score based on how many notes of the pattern we matched
      // Prefer more complete matches
      const score = normalizedPattern.length * 10 - (intervals.length - normalizedPattern.length);

      if (score > bestScore) {
        bestScore = score;
        bestMatch = pattern;
      }
    }
  }

  return bestMatch;
}

export function identifyChord(notes: string[]): string | null {
  if (notes.length === 0) return null;
  if (notes.length === 1) return notes[0].replace(/\d+$/, '');

  const midiNotes = notes.map(noteToMidi).sort((a, b) => a - b);
  const uniquePitchClasses = [...new Set(midiNotes.map(m => m % 12))];

  if (uniquePitchClasses.length === 1) {
    return getNoteNameFromMidi(midiNotes[0]);
  }

  // Try each note as potential root - exact match first
  for (const rootMidi of midiNotes) {
    const intervals = getIntervalsFromRoot(midiNotes, rootMidi);
    const pattern = matchChordPattern(intervals);

    if (pattern) {
      const rootName = getNoteNameFromMidi(rootMidi);
      const bassNote = getNoteNameFromMidi(midiNotes[0]);
      if (bassNote !== rootName) {
        return `${rootName}${pattern.name}/${bassNote}`;
      }
      return `${rootName}${pattern.name}`;
    }
  }

  // Try subset matching (for chords with extra notes)
  for (const rootMidi of midiNotes) {
    const intervals = getIntervalsFromRoot(midiNotes, rootMidi);
    const pattern = matchChordPatternSubset(intervals);

    if (pattern) {
      const rootName = getNoteNameFromMidi(rootMidi);
      const bassNote = getNoteNameFromMidi(midiNotes[0]);
      // Add indicator that there are additional notes
      const suffix = intervals.length > normalizePatternIntervals(pattern.intervals).length ? '*' : '';
      if (bassNote !== rootName) {
        return `${rootName}${pattern.name}${suffix}/${bassNote}`;
      }
      return `${rootName}${pattern.name}${suffix}`;
    }
  }

  // No pattern found - try to describe by intervals present
  const bassNote = getNoteNameFromMidi(midiNotes[0]);
  const intervalsFromBass = getIntervalsFromRoot(midiNotes, midiNotes[0]);

  // Check for common patterns
  const has3 = intervalsFromBass.includes(3) || intervalsFromBass.includes(4);
  const has5 = intervalsFromBass.includes(7) || intervalsFromBass.includes(6) || intervalsFromBass.includes(8);
  const has7 = intervalsFromBass.includes(10) || intervalsFromBass.includes(11);

  if (has3 && has5) {
    return `${bassNote}?`; // Unknown chord quality but has basic triad structure
  }

  return `${bassNote} (unrecognized)`;
}
