// Chord sets, their sections and saved chords/scales, and the loop sequencer: a port of the Apple
// app's `AppState` (chord-set parts) and `LoopSequencer`. Everything here is pure; the page holds
// the state and calls these to work out the next one.

import type { MusicalKey } from './notes';

/** An entry in a chord set: a chord, or a scale (when `scale` is set). */
export interface SavedChord {
  id: string;
  name: string;
  /** A chord's notes ('C4', 'E4'…). A scale stores one octave going up, for playback. */
  notes: string[];
  /** Set for a scale. */
  scale?: MusicalKey;
}

/** Part of a set, like a song's verse or chorus. */
export interface ChordSection {
  id: string;
  /** Empty for the unnamed section a set starts with. */
  name: string;
  chords: SavedChord[];
}

/** A named group of saved chords, like a song or practice set, divided into sections. */
export interface ChordSet {
  id: string;
  name: string;
  /** Never empty. */
  sections: ChordSection[];
}

/** The chord-set part of the app's state. */
export interface ChordLibrary {
  /** Never empty. */
  sets: ChordSet[];
  activeSetId: string;
}

/** Most chords and scales a set can hold, across all its sections. */
export const MAX_SAVED_CHORDS = 48;

export const newId = (): string =>
  typeof crypto !== 'undefined' && 'randomUUID' in crypto
    ? crypto.randomUUID()
    : `${Date.now().toString(36)}-${Math.random().toString(36).slice(2)}`;

export const isScale = (chord: SavedChord) => chord.scale !== undefined;

/** The name to show: unnamed sections are numbered by position. */
export const sectionDisplayName = (section: ChordSection, index: number) =>
  section.name || `Section ${index + 1}`;

const defaultSetName = (n: number) => `Set ${n}`;

export function makeSet(name: string, chords: SavedChord[] = []): ChordSet {
  return { id: newId(), name, sections: [{ id: newId(), name: '', chords }] };
}

export function makeLibrary(chords: SavedChord[] = []): ChordLibrary {
  const set = makeSet(defaultSetName(1), chords);
  return { sets: [set], activeSetId: set.id };
}

export function activeSet(library: ChordLibrary): ChordSet {
  return library.sets.find(s => s.id === library.activeSetId) ?? library.sets[0];
}

/** Every entry in the active set, section by section. */
export const allChords = (set: ChordSet) => set.sections.flatMap(s => s.chords);

/** The active set's chords without its scales: what the loop and the arrow keys step through. */
export const chordsOnly = (set: ChordSet) => allChords(set).filter(c => !isScale(c));

/** Where an entry is: its section's index and its index within that section. */
export function positionOf(set: ChordSet, chordId: string): { section: number; index: number } | null {
  for (let s = 0; s < set.sections.length; s++) {
    const index = set.sections[s].chords.findIndex(c => c.id === chordId);
    if (index >= 0) return { section: s, index };
  }
  return null;
}

/** Applies `change` to a copy of the active set. */
function editActiveSet(library: ChordLibrary, change: (set: ChordSet) => ChordSet): ChordLibrary {
  return {
    ...library,
    sets: library.sets.map(s => (s.id === library.activeSetId ? change(s) : s)),
  };
}

const withSections = (set: ChordSet, sections: ChordSection[]): ChordSet => ({ ...set, sections });

// MARK: - Sets

/** "Set N" with N one higher than any existing default-named set. */
export function nextDefaultSetName(library: ChordLibrary): string {
  const numbers = library.sets
    .map(s => (/^Set (\d+)$/.exec(s.name)?.[1]))
    .filter((n): n is string => n !== undefined)
    .map(Number);
  return defaultSetName((numbers.length ? Math.max(...numbers) : 0) + 1);
}

/** Creates an empty set with a default name and switches to it. */
export function createSet(library: ChordLibrary): ChordLibrary {
  const set = makeSet(nextDefaultSetName(library));
  return { sets: [...library.sets, set], activeSetId: set.id };
}

export function renameSet(library: ChordLibrary, id: string, name: string): ChordLibrary {
  const trimmed = name.trim();
  if (!trimmed) return library;
  return { ...library, sets: library.sets.map(s => (s.id === id ? { ...s, name: trimmed } : s)) };
}

/** Copies a set (with fresh IDs) to the end of the list and switches to the copy. */
export function duplicateSet(library: ChordLibrary, id: string): ChordLibrary {
  const original = library.sets.find(s => s.id === id);
  if (!original) return library;
  const copy: ChordSet = {
    id: newId(),
    name: `${original.name} copy`,
    sections: original.sections.map(sec => ({
      id: newId(),
      name: sec.name,
      chords: sec.chords.map(c => ({ ...c, id: newId() })),
    })),
  };
  return { sets: [...library.sets, copy], activeSetId: copy.id };
}

/** Deletes a set. If it was active, the next (or previous) set becomes active; deleting the last
 *  remaining set leaves a fresh empty one. */
export function deleteSet(library: ChordLibrary, id: string): ChordLibrary {
  const index = library.sets.findIndex(s => s.id === id);
  if (index < 0) return library;
  let sets = library.sets.filter(s => s.id !== id);
  if (sets.length === 0) sets = [makeSet(defaultSetName(1))];
  const activeSetId = id === library.activeSetId ? sets[Math.min(index, sets.length - 1)].id : library.activeSetId;
  return { sets, activeSetId };
}

// MARK: - Entries

export type SaveResult = 'saved' | 'limitReached';

/** The section new chords go into: the active chord's, otherwise the last one. */
export function activeSectionId(set: ChordSet, activeChordId: string | null): string {
  const position = activeChordId ? positionOf(set, activeChordId) : null;
  return set.sections[position ? position.section : set.sections.length - 1].id;
}

/** Adds an entry to `sectionId` (or the active section). */
export function appendChord(
  library: ChordLibrary, chord: SavedChord, sectionId: string | null, activeChordId: string | null,
): { library: ChordLibrary; result: SaveResult } {
  const set = activeSet(library);
  if (allChords(set).length >= MAX_SAVED_CHORDS) return { library, result: 'limitReached' };
  const target = sectionId ?? activeSectionId(set, activeChordId);
  const next = editActiveSet(library, s => {
    const index = Math.max(0, s.sections.findIndex(sec => sec.id === target));
    const targetIndex = s.sections.some(sec => sec.id === target) ? index : s.sections.length - 1;
    return withSections(s, s.sections.map((sec, i) => (i === targetIndex ? { ...sec, chords: [...sec.chords, chord] } : sec)));
  });
  return { library: next, result: 'saved' };
}

/** Renames and re-voices an entry in place. */
export function updateChord(library: ChordLibrary, id: string, name: string, notes: string[]): ChordLibrary {
  return editActiveSet(library, s => withSections(s, s.sections.map(sec => ({
    ...sec,
    chords: sec.chords.map(c => (c.id === id ? { ...c, name, notes } : c)),
  }))));
}

export function deleteChord(library: ChordLibrary, id: string): ChordLibrary {
  return editActiveSet(library, s => withSections(s, s.sections.map(sec => ({
    ...sec, chords: sec.chords.filter(c => c.id !== id),
  }))));
}

/** Moves the dragged entry into the target entry's position, which may be in another section. */
export function moveChord(library: ChordLibrary, id: string, targetId: string): ChordLibrary {
  if (id === targetId) return library;
  return editActiveSet(library, s => {
    const from = positionOf(s, id);
    const to = positionOf(s, targetId);
    if (!from || !to) return s;
    const sections = s.sections.map(sec => ({ ...sec, chords: [...sec.chords] }));
    const [chord] = sections[from.section].chords.splice(from.index, 1);
    sections[to.section].chords.splice(to.index, 0, chord);
    return withSections(s, sections);
  });
}

/** Moves an entry to the end of a section. */
export function moveChordToSection(library: ChordLibrary, id: string, sectionId: string): ChordLibrary {
  return editActiveSet(library, s => {
    const from = positionOf(s, id);
    const target = s.sections.findIndex(sec => sec.id === sectionId);
    if (!from || target < 0) return s;
    if (from.section === target && from.index === s.sections[target].chords.length - 1) return s;
    const sections = s.sections.map(sec => ({ ...sec, chords: [...sec.chords] }));
    const [chord] = sections[from.section].chords.splice(from.index, 1);
    sections[target].chords.push(chord);
    return withSections(s, sections);
  });
}

/** Whether `shiftChord` can move the entry that way: within its section, or into the next one. */
export function canShiftChord(set: ChordSet, id: string, offset: -1 | 1): boolean {
  const position = positionOf(set, id);
  if (!position) return false;
  if (offset < 0) return position.index > 0 || position.section > 0;
  return position.index < set.sections[position.section].chords.length - 1 || position.section < set.sections.length - 1;
}

/** Moves an entry one place left (-1) or right (+1); at a section's end it crosses into the next. */
export function shiftChord(library: ChordLibrary, id: string, offset: -1 | 1): ChordLibrary {
  if (!canShiftChord(activeSet(library), id, offset)) return library;
  return editActiveSet(library, s => {
    const from = positionOf(s, id)!;
    const sections = s.sections.map(sec => ({ ...sec, chords: [...sec.chords] }));
    const chords = sections[from.section].chords;
    const to = from.index + offset;
    if (to >= 0 && to < chords.length) {
      [chords[from.index], chords[to]] = [chords[to], chords[from.index]];
    } else {
      const [chord] = chords.splice(from.index, 1);
      if (offset < 0) sections[from.section - 1].chords.push(chord);
      else sections[from.section + 1].chords.unshift(chord);
    }
    return withSections(s, sections);
  });
}

/** The chord after `chordId` (skipping scales, wrapping around), within `sectionId` when given. */
export function chordAfter(set: ChordSet, chordId: string | null, sectionId: string | null = null): SavedChord | null {
  const section = sectionId ? set.sections.find(s => s.id === sectionId) : null;
  const chords = section ? section.chords.filter(c => !isScale(c)) : chordsOnly(set);
  if (chords.length < 2 || !chordId) return null;
  const index = chords.findIndex(c => c.id === chordId);
  return index < 0 ? null : chords[(index + 1) % chords.length];
}

// MARK: - Sections

/** Adds a section to the end of the active set and returns its ID. Unnamed sections get numbered
 *  names first, so they keep their names when sections are rearranged. */
export function addSection(library: ChordLibrary, name?: string): { library: ChordLibrary; id: string } {
  const id = newId();
  const next = editActiveSet(library, s => {
    const named = s.sections.map((sec, i) => (sec.name ? sec : { ...sec, name: sectionDisplayName(sec, i) }));
    const trimmed = name?.trim() ?? '';
    return withSections(s, [...named, { id, name: trimmed || `Section ${named.length + 1}`, chords: [] }]);
  });
  return { library: next, id };
}

export function renameSection(library: ChordLibrary, id: string, name: string): ChordLibrary {
  const trimmed = name.trim();
  if (!trimmed) return library;
  return editActiveSet(library, s => withSections(s, s.sections.map(sec => (sec.id === id ? { ...sec, name: trimmed } : sec))));
}

/** Deletes a section and its chords. The last section can't be deleted. */
export function deleteSection(library: ChordLibrary, id: string): ChordLibrary {
  if (activeSet(library).sections.length <= 1) return library;
  return editActiveSet(library, s => withSections(s, s.sections.filter(sec => sec.id !== id)));
}

/** Moves the dragged section into the target section's position. */
export function moveSection(library: ChordLibrary, id: string, targetId: string): ChordLibrary {
  if (id === targetId) return library;
  return editActiveSet(library, s => {
    const from = s.sections.findIndex(sec => sec.id === id);
    const to = s.sections.findIndex(sec => sec.id === targetId);
    if (from < 0 || to < 0) return s;
    const sections = [...s.sections];
    const [section] = sections.splice(from, 1);
    sections.splice(to, 0, section);
    return withSections(s, sections);
  });
}

/** Moves a section up (-1) or down (+1). */
export function shiftSection(library: ChordLibrary, id: string, offset: -1 | 1): ChordLibrary {
  return editActiveSet(library, s => {
    const from = s.sections.findIndex(sec => sec.id === id);
    const to = from + offset;
    if (from < 0 || to < 0 || to >= s.sections.length) return s;
    const sections = [...s.sections];
    [sections[from], sections[to]] = [sections[to], sections[from]];
    return withSections(s, sections);
  });
}

// MARK: - Persistence

/** Reads the stored library, upgrading the old single list of saved chords into "Set 1". */
export function loadLibrary(stored: unknown, legacySavedChords: unknown): ChordLibrary {
  const lib = stored as Partial<ChordLibrary> | undefined;
  if (lib && Array.isArray(lib.sets) && lib.sets.length > 0) {
    const sets = lib.sets.map(s => ({
      ...s,
      sections: Array.isArray(s.sections) && s.sections.length > 0 ? s.sections : [{ id: newId(), name: '', chords: [] }],
    }));
    const activeSetId = sets.some(s => s.id === lib.activeSetId) ? lib.activeSetId! : sets[0].id;
    return { sets, activeSetId };
  }
  // Before sets, saved chords were `{ id, name, notes: { note, colorIndex }[] }`.
  const legacy = Array.isArray(legacySavedChords) ? legacySavedChords : [];
  const chords: SavedChord[] = legacy.map((c: { id?: string; name?: string; notes?: ({ note: string } | string)[] }) => ({
    id: c.id ?? newId(),
    name: c.name ?? '',
    notes: (c.notes ?? []).map(n => (typeof n === 'string' ? n : n.note)),
  }));
  return makeLibrary(chords);
}

// MARK: - Loop

export type PlayMode = 'chord' | 'arpeggio';

/** How many times the loop plays each chord before moving on. */
export const REPEATS_PER_CHORD = 4;

/** Decides what the loop plays on each beat. With two or more saved chords it walks through them,
 *  section by section, playing each four times starting from the active chord, skipping scales. It
 *  can stay within one section. Otherwise it repeats the current selection (or the set's only chord,
 *  if nothing is selected). */
export class LoopSequencer {
  readonly sectionId: string | null;
  private chordIndex = 0;
  private playCount = 0;
  /** Beats (counting the one just played) until the next chord, or null when it won't change. */
  beatsUntilChange: number | null = null;

  constructor(set: ChordSet, activeChordId: string | null, sectionId: string | null = null) {
    this.sectionId = sectionId;
    const chords = this.chords(set);
    const active = chords.findIndex(c => c.id === activeChordId);
    if (chords.length > 1 && active >= 0) this.chordIndex = active;
  }

  private chords(set: ChordSet): SavedChord[] {
    if (!this.sectionId) return chordsOnly(set);
    return set.sections.find(s => s.id === this.sectionId)?.chords.filter(c => !isScale(c)) ?? [];
  }

  /** The next beat: the notes to play and the chord to make active (undefined leaves the active
   *  chord alone), or null to stop. */
  nextBeat(set: ChordSet, selectedNotes: string[]): { notes: string[]; activeChordId?: string } | null {
    const chords = this.chords(set);
    if (chords.length > 1) {
      if (this.chordIndex >= chords.length) this.chordIndex = 0;
      const chord = chords[this.chordIndex];
      this.playCount += 1;
      this.beatsUntilChange = REPEATS_PER_CHORD - this.playCount + 1;
      if (this.playCount >= REPEATS_PER_CHORD) {
        this.playCount = 0;
        this.chordIndex = (this.chordIndex + 1) % chords.length;
      }
      return { notes: chord.notes, activeChordId: chord.id };
    }
    this.beatsUntilChange = null;
    if (chords.length === 1 && (this.sectionId !== null || selectedNotes.length === 0)) {
      return { notes: chords[0].notes, activeChordId: chords[0].id };
    }
    return selectedNotes.length ? { notes: selectedNotes } : null;
  }

  /** Seconds until the next beat: one beat for a chord, or all of an arpeggio's notes (two a beat). */
  static beatInterval(noteCount: number, mode: PlayMode, tempo: number): number {
    const beat = 60 / tempo;
    return mode === 'chord' ? beat : (noteCount * beat) / 2;
  }
}
