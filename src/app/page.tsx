'use client';

import { useState, useRef, useEffect, useCallback, useSyncExternalStore } from 'react';
import GuitarFretboard from '@/components/GuitarFretboard';
import PianoKeyboard from '@/components/PianoKeyboard';
import SettingsDialog from '@/components/SettingsDialog';
import ChordSetPanel from '@/components/ChordSetPanel';
import WelcomeTutorial from '@/components/WelcomeTutorial';
import KeyMenu from '@/components/KeyMenu';
import ChordBankPanel from '@/components/ChordBankPanel';
import { TUNINGS, MusicalKey, noteToMidi, midiToNote, getDefaultTuning, getKeyShortName, getKeyRootPitchClass, parseStoredKey, sameKey } from '@/lib/notes';
import {
  NoteLabelContent, NOTE_LABEL_CONTENTS, getNextNoteLabelContent, createNoteLabelContext, getNoteLabel,
  getNoteColorRole, getPitchClassColorRole,
} from '@/lib/noteLabels';
import { getRoleColor, getRoleSolidClass } from '@/lib/colors';
import {
  playNote, play, playArpeggio, previewSound, getAudioTime, beatInterval, LOOP_LOOKAHEAD_SECONDS,
  SoundId, DEFAULT_SOUND, isSoundId, DEFAULT_TEMPO, clampTempo,
  subscribeSoundingNotes, getSoundingNotes, getServerSoundingNotes,
} from '@/lib/audio';
import { identifyChord, getChordRoot } from '@/lib/chords';
import {
  ChordLibrary, SavedChord, LoopSequencer, MAX_SAVED_CHORDS, makeLibrary, loadLibrary, activeSet, allChords,
  chordsOnly, isScale, positionOf, appendChord, updateChord, deleteChord as removeChord, chordAfter, newId,
  activeSectionId, sectionDisplayName,
} from '@/lib/chordSets';

interface Fretboard {
  id: string;
  tuning: string[];
  capo: number;
}


/** Which instrument a phone shows (it shows one at a time). */
type InstrumentChoice = 'guitar' | 'guitar2' | 'piano';

const sameNotes = (a: string[], b: string[]) => a.length === b.length && a.every((n, i) => n === b[i]);

export default function Home() {
  const [selectedNotes, setSelectedNotes] = useState<string[]>([]);
  const [activeChordId, setActiveChordId] = useState<string | null>(null);
  const [fretboards, setFretboards] = useState<Fretboard[]>([
    { id: '1', tuning: TUNINGS.standard.notes, capo: 0 }
  ]);
  const [library, setLibrary] = useState<ChordLibrary>(() => makeLibrary());
  const [playMode, setPlayMode] = useState<'chord' | 'arpeggio'>('chord');
  const [settingsOpen, setSettingsOpen] = useState(false);
  const [showPiano, setShowPiano] = useState(true);
  const [selectedKey, setSelectedKey] = useState<MusicalKey | null>({ root: 'C', type: 'major' });
  const [keyLabelMode, setKeyLabelMode] = useState<'onlyInKey' | 'showAll'>('showAll');
  const [darkMode, setDarkMode] = useState(false);
  const [noteLabelMode, setNoteLabelMode] = useState<'sharpsAndFlats' | 'sharpsOnly'>('sharpsAndFlats');
  const [noteLabelContent, setNoteLabelContent] = useState<NoteLabelContent>('names');
  const [tempo, setTempo] = useState(DEFAULT_TEMPO);
  const [sound, setSound] = useState<SoundId>(DEFAULT_SOUND);
  const [showNextChord, setShowNextChord] = useState(true);
  const [loopMode, setLoopMode] = useState(false);
  const [loopingSectionId, setLoopingSectionId] = useState<string | null>(null);
  const [isPreviewingNext, setIsPreviewingNext] = useState(false);
  const [previewFadeMs, setPreviewFadeMs] = useState(0);
  const [chordLimitWarning, setChordLimitWarning] = useState(false);
  const [tutorialOpen, setTutorialOpen] = useState(false);
  const [bankOpen, setBankOpen] = useState(false);
  const [bankTargetSectionId, setBankTargetSectionId] = useState<string | null>(null);
  const [phoneInstrument, setPhoneInstrument] = useState<InstrumentChoice>('guitar');
  const warningTimeoutRef = useRef<NodeJS.Timeout | null>(null);
  const hasLoadedState = useRef(false);

  const STORAGE_KEY = 'frets2keys_appState';
  const set = activeSet(library);
  const savedChords = allChords(set);
  const chordName = identifyChord(selectedNotes);
  /** How notes are labeled and colored right now (intervals measure from the chord's root). */
  const labelContext = createNoteLabelContext({
    key: selectedKey, keyLabelMode, noteLabelMode, content: noteLabelContent, chordNotes: selectedNotes,
  });
  const soundingNotes = useSyncExternalStore(subscribeSoundingNotes, getSoundingNotes, getServerSoundingNotes);

  // Check if the current selection differs from the active saved chord
  const activeChord = savedChords.find(c => c.id === activeChordId);
  const hasChangesFromSaved = activeChord ? !sameNotes(activeChord.notes, selectedNotes) : false;
  const hasSelection = selectedNotes.length > 0;
  const canLoop = hasSelection || chordsOnly(set).length > 0;

  // Load state from localStorage on mount. (It can't be read during the server render, so it's
  // applied once the page is in the browser.)
  useEffect(() => {
    /* eslint-disable react-hooks/set-state-in-effect */
    try {
      const saved = localStorage.getItem(STORAGE_KEY);
      if (saved) {
        const state = JSON.parse(saved);
        if (state.fretboards) setFretboards(state.fretboards);
        // Before chord sets, saved chords were one list; it becomes "Set 1".
        setLibrary(loadLibrary(state.library, state.savedChords));
        if (state.playMode) setPlayMode(state.playMode);
        if (state.showPiano !== undefined) setShowPiano(state.showPiano);
        // Always stored (as null for "No key"); an unreadable key falls back to none.
        if (state.selectedKey !== undefined) setSelectedKey(parseStoredKey(state.selectedKey));
        if (state.keyLabelMode) setKeyLabelMode(state.keyLabelMode);
        if (state.noteLabelMode) setNoteLabelMode(state.noteLabelMode);
        if (NOTE_LABEL_CONTENTS.some(c => c.id === state.noteLabelContent)) setNoteLabelContent(state.noteLabelContent);
        if (typeof state.tempo === 'number') setTempo(clampTempo(state.tempo));
        if (isSoundId(state.sound)) setSound(state.sound);
        if (state.showNextChord !== undefined) setShowNextChord(state.showNextChord);
        if (state.darkMode !== undefined) setDarkMode(state.darkMode);
      }
      const instrument = localStorage.getItem('frets2keys_phoneInstrument');
      if (instrument === 'guitar' || instrument === 'guitar2' || instrument === 'piano') setPhoneInstrument(instrument);
    } catch {
      // Ignore localStorage errors
    }
    /* eslint-enable react-hooks/set-state-in-effect */
    hasLoadedState.current = true;
  }, []);

  // Save state to localStorage when it changes
  useEffect(() => {
    if (!hasLoadedState.current) return;
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify({
        fretboards, library, playMode, showPiano, selectedKey, keyLabelMode, noteLabelMode,
        noteLabelContent, tempo, sound, showNextChord, darkMode,
      }));
    } catch {
      // Ignore localStorage errors (e.g., quota exceeded)
    }
  }, [fretboards, library, playMode, showPiano, selectedKey, keyLabelMode, noteLabelMode, noteLabelContent, tempo, sound, showNextChord, darkMode]);

  // MARK: - Sound

  /** Plays notes now as a chord or arpeggio, at the current tempo and sound (they flash as heard). */
  const sound_ = (notes: string[], mode: 'chord' | 'arpeggio' = playMode) => {
    if (notes.length) play(notes, mode, sound, tempo);
  };

  // MARK: - Selection

  const handleNoteSelect = (note: string) => {
    if (selectedNotes.includes(note)) {
      setSelectedNotes(prev => prev.filter(n => n !== note));
    } else {
      playNote(note, sound);
      setSelectedNotes(prev => [...prev, note]);
    }
  };

  const handleClearAll = () => {
    setSelectedNotes([]);
    setActiveChordId(null);
    stopLoopIfEmpty(library, []);
  };

  const handleTranspose = (semitones: number) => {
    if (selectedNotes.length === 0) return;
    // Transposed notes may fall outside the key, so make sure they stay visible.
    if (keyLabelMode === 'onlyInKey') setKeyLabelMode('showAll');
    setSelectedNotes(prev => prev.map(note => {
      const midi = noteToMidi(note) + semitones;
      return midi < 0 || midi > 127 ? note : midiToNote(midi);
    }));
  };

  const handlePlayAll = () => sound_(selectedNotes);

  const cycleNoteLabels = () => setNoteLabelContent(getNextNoteLabelContent);

  // MARK: - Loop

  // The loop reads the latest state through this ref, since it runs across many renders.
  const latest = useRef({ library, selectedNotes, activeChordId, playMode, sound, tempo, showNextChord });
  useEffect(() => {
    latest.current = { library, selectedNotes, activeChordId, playMode, sound, tempo, showNextChord };
  });
  const loopTokenRef = useRef(0);
  const loopTimersRef = useRef<NodeJS.Timeout[]>([]);
  const isPreviewingRef = useRef(false);
  useEffect(() => { isPreviewingRef.current = isPreviewingNext; }, [isPreviewingNext]);

  const stopLoop = useCallback(() => {
    loopTokenRef.current += 1;
    loopTimersRef.current.forEach(clearTimeout);
    loopTimersRef.current = [];
    setLoopMode(false);
    setLoopingSectionId(null);
    setIsPreviewingNext(false);
  }, []);

  /** Starts looping the set (or just `sectionId`'s chords): each beat is booked on the audio clock a
   *  moment ahead, so beats land exactly one interval apart, and the selection switches as the
   *  beat is heard. From the second-to-last beat of a chord, the next chord fades in. */
  const startLoop = (sectionId: string | null) => {
    const token = ++loopTokenRef.current;
    const start = latest.current;
    const sequencer = new LoopSequencer(activeSet(start.library), start.activeChordId, sectionId);
    let nextBeat: number | undefined;
    setLoopMode(true);
    setLoopingSectionId(sectionId);

    const later = (ms: number, fn: () => void) => {
      const timer = setTimeout(() => {
        loopTimersRef.current = loopTimersRef.current.filter(t => t !== timer);
        if (loopTokenRef.current === token) fn();
      }, Math.max(0, ms));
      loopTimersRef.current.push(timer);
    };

    const tick = () => {
      const now_ = latest.current;
      const beatResult = sequencer.nextBeat(activeSet(now_.library), now_.selectedNotes);
      if (!beatResult) { stopLoop(); return; }
      const now = getAudioTime();
      let beat = nextBeat ?? now;
      // Fell behind (or the audio clock restarted): start afresh.
      if (beat < now || beat > now + 10) beat = now;
      const isChange = !sameNotes(beatResult.notes, now_.selectedNotes);
      const playback = play(beatResult.notes, now_.playMode, now_.sound, now_.tempo, { at: beat });
      const interval = beatInterval(beatResult.notes.length, now_.playMode, now_.tempo);
      nextBeat = playback.nextBeatTime;
      const beatsLeft = sequencer.beatsUntilChange;

      // Switch the instruments when the beat is heard, a little early to cover the redraw.
      later(playback.heardInMs - (isChange ? 120 : 30), () => {
        const current = latest.current;
        if (!sameNotes(beatResult.notes, current.selectedNotes) || (beatResult.activeChordId !== undefined && beatResult.activeChordId !== current.activeChordId)) {
          setIsPreviewingNext(false);
          isPreviewingRef.current = false;
          setSelectedNotes(beatResult.notes);
          if (beatResult.activeChordId !== undefined) setActiveChordId(beatResult.activeChordId);
        }
        if (beatsLeft !== null && beatsLeft <= 2 && !isPreviewingRef.current && current.showNextChord) {
          setPreviewFadeMs(interval * 1000);
          setIsPreviewingNext(true);
          isPreviewingRef.current = true;
        }
      });
      later((nextBeat - LOOP_LOOKAHEAD_SECONDS - getAudioTime()) * 1000, tick);
    };
    tick();
  };

  /** Starts or stops the loop. With `sectionId`, loops just that section (or switches to it). */
  const toggleLoop = (sectionId: string | null = null) => {
    if (loopMode) {
      const switching = sectionId !== null && sectionId !== loopingSectionId;
      stopLoop();
      if (switching) startLoop(sectionId);
    } else if (sectionId !== null || canLoop) {
      startLoop(sectionId);
    }
  };
  const handleLoopToggle = () => toggleLoop(null);

  /** Stops a whole-set loop once there's nothing left for it to play. */
  const stopLoopIfEmpty = (nextLibrary: ChordLibrary, nextSelection: string[]) => {
    if (loopMode && loopingSectionId === null && nextSelection.length === 0 && chordsOnly(activeSet(nextLibrary)).length === 0) stopLoop();
  };
  useEffect(() => () => { loopTimersRef.current.forEach(clearTimeout); }, []);

  /** The chord the loop moves to next, for the next-chord preview. */
  const nextChord = loopMode ? chordAfter(set, activeChordId, loopingSectionId) : null;

  // MARK: - Chord sets

  /** Applies a change to the chord sets, keeping the active chord and loop consistent with it. */
  const handleLibraryChange = (next: ChordLibrary) => {
    if (next.activeSetId !== library.activeSetId) {
      setActiveChordId(null);
      if (loopMode) stopLoop();
    } else if (activeChordId && !positionOf(activeSet(next), activeChordId)) {
      setActiveChordId(null);
    }
    if (loopingSectionId && !activeSet(next).sections.some(s => s.id === loopingSectionId)) stopLoop();
    stopLoopIfEmpty(next, selectedNotes);
    setLibrary(next);
  };

  const showLimitWarning = () => {
    if (warningTimeoutRef.current) clearTimeout(warningTimeoutRef.current);
    setChordLimitWarning(true);
    warningTimeoutRef.current = setTimeout(() => setChordLimitWarning(false), 3000);
  };

  /** Saves `notes` as a new chord in `sectionId` (or the active section) and makes it active. */
  const saveChord = (notes: string[], sectionId: string | null = null) => {
    const name = identifyChord(notes);
    if (!notes.length || !name) return;
    const chord: SavedChord = { id: newId(), name, notes };
    const { library: next, result } = appendChord(library, chord, sectionId, activeChordId);
    if (result === 'limitReached') { showLimitWarning(); return; }
    setLibrary(next);
    setSelectedNotes(notes);
    setActiveChordId(chord.id);
  };

  const handleSaveChordAsNew = () => saveChord(selectedNotes);

  const handleUpdateChord = () => {
    if (!activeChordId || !chordName || !hasChangesFromSaved) return;
    setLibrary(updateChord(library, activeChordId, chordName, selectedNotes));
  };

  /** Saves a scale and shows it on the instruments. */
  const addScale = (scale: MusicalKey, notes: string[], name: string, sectionId: string | null) => {
    const { library: next, result } = appendChord(library, { id: newId(), name, notes, scale }, sectionId, activeChordId);
    if (result === 'limitReached') { showLimitWarning(); return; }
    setLibrary(next);
    setSelectedKey(scale);
    playArpeggio(notes, sound, tempo);
  };

  /** Selects a saved chord, or shows (and plays) a saved scale as the key. */
  const handleChordSelect = (chord: SavedChord) => {
    if (chord.scale) {
      setSelectedKey(chord.scale);
      playArpeggio(chord.notes, sound, tempo);
      return;
    }
    setSelectedNotes(chord.notes);
    setActiveChordId(chord.id);
  };

  const handleChordDelete = (id: string) => {
    handleLibraryChange(removeChord(library, id));
    if (activeChordId === id) setActiveChordId(null);
  };

  const stepChord = (offset: 1 | -1) => {
    const chords = chordsOnly(set);
    if (!chords.length) return;
    const current = chords.findIndex(c => c.id === activeChordId);
    const index = offset > 0
      ? (current >= chords.length - 1 ? 0 : current + 1)
      : (current <= 0 ? chords.length - 1 : current - 1);
    handleChordSelect(chords[index]);
  };

  const openChordBank = (sectionId: string | null) => {
    if (bankOpen && sectionId === bankTargetSectionId) { setBankOpen(false); return; }
    setBankTargetSectionId(sectionId);
    setBankOpen(true);
  };

  const handleSoundChange = (next: SoundId) => {
    setSound(next);
    // Play a short arpeggio so you hear it (unless a loop is playing).
    if (!loopMode) previewSound(next, tempo);
  };

  // Keyboard shortcuts
  const shortcutsRef = useRef<(e: KeyboardEvent) => void>(() => {});
  const handleShortcut = (e: KeyboardEvent) => {
    // Don't trigger shortcuts when typing in inputs, or with modifier keys held.
    if (e.target instanceof HTMLInputElement || e.target instanceof HTMLTextAreaElement || e.target instanceof HTMLSelectElement) return;
    if (e.metaKey || e.ctrlKey || e.altKey) return;
    switch (e.key) {
      case 'Delete':
      case 'Backspace': e.preventDefault(); handleClearAll(); break;
      case 's':
      case 'S': e.preventDefault(); handleUpdateChord(); break;
      case 'a':
      case 'A': e.preventDefault(); handleSaveChordAsNew(); break;
      case 'n':
      case 'N': e.preventDefault(); cycleNoteLabels(); break;
      case '+':
      case '=': e.preventDefault(); handleTranspose(1); break;
      case '-':
      case '_': e.preventDefault(); handleTranspose(-1); break;
      case 'Enter': e.preventDefault(); handlePlayAll(); break;
      case ' ': e.preventDefault(); handleLoopToggle(); break;
      case 'ArrowLeft': e.preventDefault(); stepChord(-1); break;
      case 'ArrowRight': e.preventDefault(); stepChord(1); break;
    }
  };
  useEffect(() => { shortcutsRef.current = handleShortcut; });
  useEffect(() => {
    const onKeyDown = (e: KeyboardEvent) => shortcutsRef.current(e);
    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  }, []);

  const handleTuningChange = (fretboardId: string, tuning: string[]) => {
    setFretboards(prev => prev.map(fb => (fb.id === fretboardId ? { ...fb, tuning } : fb)));
  };

  const handleCapoChange = (fretboardId: string, capo: number) => {
    setFretboards(prev => prev.map(fb => (fb.id === fretboardId ? { ...fb, capo } : fb)));
  };

  const handleStringCountChange = (fretboardId: string, count: number) => {
    setFretboards(prev => prev.map(fb => (fb.id === fretboardId ? { ...fb, tuning: getDefaultTuning(count) } : fb)));
  };

  const handleResetTuning = (fretboardId: string) => {
    setFretboards(prev => prev.map(fb => (fb.id === fretboardId ? { ...fb, tuning: getDefaultTuning(fb.tuning.length), capo: 0 } : fb)));
  };

  const handleFretboardCountChange = (count: number) => {
    if (count < fretboards.length) {
      setFretboards(prev => prev.slice(0, count));
      return;
    }
    const next = [...fretboards];
    while (next.length < count) next.push({ id: newId(), tuning: TUNINGS.standard.notes, capo: 0 });
    setFretboards(next);
  };

  // Get all tunings for piano keyboard range calculation
  const allTunings = fretboards.flatMap(fb => fb.tuning);
  const anyCapoActive = fretboards.some(fb => fb.capo > 0);


  // Layout: the window's width picks the breakpoints, and the instruments' area is measured so
  // the piano can grow to match a guitar card when there's room.
  const [windowWidth, setWindowWidth] = useState(1024);
  const instrumentsAreaRef = useRef<HTMLElement>(null);
  const fretboardsRef = useRef<HTMLDivElement>(null);
  const firstGuitarRef = useRef<HTMLDivElement>(null);
  const [instrumentsAreaHeight, setInstrumentsAreaHeight] = useState(0);
  const [fretboardsHeight, setFretboardsHeight] = useState(0);
  const [guitarCardHeight, setGuitarCardHeight] = useState(0);

  useEffect(() => {
    const updateWidth = () => setWindowWidth(window.innerWidth);
    updateWidth();
    window.addEventListener('resize', updateWidth);
    return () => window.removeEventListener('resize', updateWidth);
  }, []);

  useEffect(() => {
    const observer = new ResizeObserver(() => {
      setInstrumentsAreaHeight(instrumentsAreaRef.current?.clientHeight ?? 0);
      setFretboardsHeight(fretboardsRef.current?.offsetHeight ?? 0);
      setGuitarCardHeight(firstGuitarRef.current?.offsetHeight ?? 0);
    });
    [instrumentsAreaRef, fretboardsRef, firstGuitarRef].forEach(ref => ref.current && observer.observe(ref.current));
    return () => observer.disconnect();
  }, [fretboards.length, showPiano]);

  const isWide = windowWidth >= 600;
  /** Guitars side by side, and the chord panel's two sections side by side. */
  const isDesktop = windowWidth >= 900;
  const INSTRUMENT_SPACING = 16;
  const INSTRUMENTS_VERTICAL_PADDING = 16;

  /** As tall as a guitar card, or whatever's left below the guitars if that's less. */
  const pianoTargetHeight = fretboards.length > 0 && guitarCardHeight > 0
    ? Math.min(guitarCardHeight, instrumentsAreaHeight - 2 * INSTRUMENTS_VERTICAL_PADDING - INSTRUMENT_SPACING - fretboardsHeight)
    : null;

  // Phones get 16px at the sides, like the iPhone app.
  const sidePadding = 'px-4 min-[600px]:px-8';
  const dividerColor = darkMode ? 'bg-zinc-700' : 'bg-[#E7E2E0]';

  const iconButtonClass = (enabled: boolean, extra = '') => `${isWide ? 'w-8 h-8' : 'w-10 h-10'} flex items-center justify-center rounded-lg transition-colors ${extra} ${
    enabled
      ? darkMode ? 'hover:bg-zinc-700 text-zinc-400 hover:text-zinc-200' : 'hover:bg-zinc-200 text-zinc-500 hover:text-zinc-700'
      : darkMode ? 'text-zinc-600 cursor-not-allowed' : 'text-zinc-300 cursor-not-allowed'
  }`;

  const icon = (path: React.ReactNode, viewBox = '0 0 20 20') => (
    <svg xmlns="http://www.w3.org/2000/svg" viewBox={viewBox} fill="currentColor" className="w-5 h-5">{path}</svg>
  );
  const ICONS = {
    clear: icon(<path d="M6.28 5.22a.75.75 0 00-1.06 1.06L8.94 10l-3.72 3.72a.75.75 0 101.06 1.06L10 11.06l3.72 3.72a.75.75 0 101.06-1.06L11.06 10l3.72-3.72a.75.75 0 00-1.06-1.06L10 8.94 6.28 5.22z" />),
    update: icon(<path fillRule="evenodd" d="M16.704 4.153a.75.75 0 01.143 1.052l-8 10.5a.75.75 0 01-1.127.075l-4.5-4.5a.75.75 0 011.06-1.06l3.894 3.893 7.48-9.817a.75.75 0 011.05-.143z" clipRule="evenodd" />),
    saveNew: icon(<path d="M10.75 4.75a.75.75 0 00-1.5 0v4.5h-4.5a.75.75 0 000 1.5h4.5v4.5a.75.75 0 001.5 0v-4.5h4.5a.75.75 0 000-1.5h-4.5v-4.5z" />),
    up: icon(<path fillRule="evenodd" d="M10 17a.75.75 0 01-.75-.75V5.612L5.29 9.77a.75.75 0 01-1.08-1.04l5.25-5.5a.75.75 0 011.08 0l5.25 5.5a.75.75 0 11-1.08 1.04l-3.96-4.158V16.25A.75.75 0 0110 17z" clipRule="evenodd" />),
    down: icon(<path fillRule="evenodd" d="M10 17a.75.75 0 01-.75-.75V5.612L5.29 9.77a.75.75 0 01-1.08-1.04l5.25-5.5a.75.75 0 011.08 0l5.25 5.5a.75.75 0 11-1.08 1.04l-3.96-4.158V16.25A.75.75 0 0110 17z" clipRule="evenodd" transform="rotate(180 10 10)" />),
    play: icon(<path fillRule="evenodd" d="M4.5 5.653c0-1.426 1.529-2.33 2.779-1.643l11.54 6.348c1.295.712 1.295 2.573 0 3.285L7.28 19.991c-1.25.687-2.779-.217-2.779-1.643V5.653z" clipRule="evenodd" />, '0 0 24 24'),
    loop: icon(<path fillRule="evenodd" d="M12 5.25c1.213 0 2.415.046 3.605.135a3.256 3.256 0 013.01 3.01c.044.583.077 1.17.1 1.759L17.03 8.47a.75.75 0 10-1.06 1.06l3 3a.75.75 0 001.06 0l3-3a.75.75 0 00-1.06-1.06l-1.752 1.751c-.023-.65-.06-1.296-.108-1.939a4.756 4.756 0 00-4.392-4.392 49.422 49.422 0 00-7.436 0A4.756 4.756 0 003.89 8.282c-.017.224-.033.447-.046.672a.75.75 0 101.497.092c.013-.217.028-.432.044-.647a3.256 3.256 0 013.01-3.01c1.19-.09 2.392-.136 3.605-.136zm-6.97 6.22a.75.75 0 00-1.06 0l-3 3a.75.75 0 101.06 1.06l1.752-1.751c.023.65.06 1.296.108 1.939a4.756 4.756 0 004.392 4.392 49.413 49.413 0 007.436 0 4.756 4.756 0 004.392-4.392c.017-.223.032-.447.046-.672a.75.75 0 00-1.497-.092c-.013.217-.028.434-.044.647a3.256 3.256 0 01-3.01 3.01 47.953 47.953 0 01-7.21 0 3.256 3.256 0 01-3.01-3.01 47.759 47.759 0 01-.1-1.759L6.97 12.53a.75.75 0 001.06-1.06l-3-3z" clipRule="evenodd" />, '0 0 24 24'),
    sun: icon(<path d="M10 2a.75.75 0 01.75.75v1.5a.75.75 0 01-1.5 0v-1.5A.75.75 0 0110 2zM10 15a.75.75 0 01.75.75v1.5a.75.75 0 01-1.5 0v-1.5A.75.75 0 0110 15zM10 7a3 3 0 100 6 3 3 0 000-6zM15.657 5.404a.75.75 0 10-1.06-1.06l-1.061 1.06a.75.75 0 001.06 1.06l1.06-1.06zM6.464 14.596a.75.75 0 10-1.06-1.06l-1.06 1.06a.75.75 0 001.06 1.06l1.06-1.06zM18 10a.75.75 0 01-.75.75h-1.5a.75.75 0 010-1.5h1.5A.75.75 0 0118 10zM5 10a.75.75 0 01-.75.75h-1.5a.75.75 0 010-1.5h1.5A.75.75 0 015 10zM14.596 15.657a.75.75 0 001.06-1.06l-1.06-1.061a.75.75 0 10-1.06 1.06l1.06 1.06zM5.404 6.464a.75.75 0 001.06-1.06l-1.06-1.06a.75.75 0 10-1.06 1.06l1.06 1.06z" />),
    moon: icon(<path fillRule="evenodd" d="M7.455 2.004a.75.75 0 01.26.77 7 7 0 009.958 7.967.75.75 0 011.067.853A8.5 8.5 0 116.647 1.921a.75.75 0 01.808.083z" clipRule="evenodd" />),
    settings: icon(<path fillRule="evenodd" d="M11.078 2.25c-.917 0-1.699.663-1.85 1.567L9.05 4.889c-.02.12-.115.26-.297.348a7.493 7.493 0 00-.986.57c-.166.115-.334.126-.45.083L6.3 5.508a1.875 1.875 0 00-2.282.819l-.922 1.597a1.875 1.875 0 00.432 2.385l.84.692c.095.078.17.229.154.43a7.598 7.598 0 000 1.139c.015.2-.059.352-.153.43l-.841.692a1.875 1.875 0 00-.432 2.385l.922 1.597a1.875 1.875 0 002.282.818l1.019-.382c.115-.043.283-.031.45.082.312.214.641.405.985.57.182.088.277.228.297.35l.178 1.071c.151.904.933 1.567 1.85 1.567h1.844c.916 0 1.699-.663 1.85-1.567l.178-1.072c.02-.12.114-.26.297-.349.344-.165.673-.356.985-.57.167-.114.335-.125.45-.082l1.02.382a1.875 1.875 0 002.28-.819l.923-1.597a1.875 1.875 0 00-.432-2.385l-.84-.692c-.095-.078-.17-.229-.154-.43a7.614 7.614 0 000-1.139c-.016-.2.059-.352.153-.43l.84-.692c.708-.582.891-1.59.433-2.385l-.922-1.597a1.875 1.875 0 00-2.282-.818l-1.02.382c-.114.043-.282.031-.449-.083a7.49 7.49 0 00-.985-.57c-.183-.087-.277-.227-.297-.348l-.179-1.072a1.875 1.875 0 00-1.85-1.567h-1.843zM12 15.75a3.75 3.75 0 100-7.5 3.75 3.75 0 000 7.5z" clipRule="evenodd" />, '0 0 24 24'),
  };

  const canUpdate = !!activeChordId && hasSelection && !!chordName && hasChangesFromSaved;
  const canSaveNew = hasSelection && !!chordName;

  /** The selected chord's controls: clear, update, save as new, transpose up and down. */
  const chordControls = (spread: boolean) => (
    <div className={`flex items-center ${spread ? 'justify-between' : ''}`}>
      <button onClick={handleClearAll} disabled={!hasSelection} className={iconButtonClass(hasSelection)} title="Clear all notes (Delete)">{ICONS.clear}</button>
      <button onClick={handleUpdateChord} disabled={!canUpdate} className={iconButtonClass(canUpdate)} title="Update existing chord (S)">{ICONS.update}</button>
      <button onClick={handleSaveChordAsNew} disabled={!canSaveNew} className={iconButtonClass(canSaveNew)} title="Save as new chord (A)">{ICONS.saveNew}</button>
      <button onClick={() => handleTranspose(1)} disabled={!hasSelection} className={iconButtonClass(hasSelection)} title="Transpose up 1 semitone (+)">{ICONS.up}</button>
      <button onClick={() => handleTranspose(-1)} disabled={!hasSelection} className={iconButtonClass(hasSelection)} title="Transpose down 1 semitone (-)">{ICONS.down}</button>
    </div>
  );

  /** The chord's name and its notes, scrolling sideways when long; a hint when nothing's selected. */
  const chordSummary = (
    <div className="min-w-0 flex-1 overflow-x-auto scrollbar-hide">
      <div className="flex items-center gap-2 min-h-6 w-max">
        {hasSelection ? (
          <>
            {chordName && (
              <span className={`text-sm font-semibold whitespace-nowrap ${darkMode ? 'text-zinc-200' : 'text-zinc-700'}`}>{chordName}</span>
            )}
            <div className="flex items-center gap-1">
              {selectedNotes.map(note => (
                <span key={note} className={`px-2 py-0.5 rounded text-xs font-medium text-white ${getRoleSolidClass(getNoteColorRole(note, selectedKey), darkMode)}`}>
                  {/* Sharp names regardless of key; degrees and intervals match the instruments. */}
                  {noteLabelContent === 'names' ? note.replace(/\d+$/, '') : getNoteLabel(note, labelContext)}
                </span>
              ))}
            </div>
          </>
        ) : (
          <span className={`text-[13px] whitespace-nowrap ${darkMode ? 'text-zinc-500' : 'text-zinc-400'}`}>Tap notes to build a chord</span>
        )}
      </div>
    </div>
  );

  /** A chip's color: its root's color in the key, like that note on the instruments. Solid when
   *  it's the current one, tinted otherwise; scales get a matching border. */
  const chipClassName = (chord: SavedChord, isActive: boolean) => {
    const root = chord.scale ? getKeyRootPitchClass(chord.scale) : getChordRoot(chord.name, chord.notes);
    if (root === null) {
      return isActive
        ? `${darkMode ? 'bg-zinc-600' : 'bg-zinc-200'} border border-transparent ${darkMode ? 'text-white' : 'text-zinc-800'}`
        : `border ${darkMode ? 'bg-zinc-700 border-transparent hover:bg-zinc-600 text-zinc-200' : 'bg-white border-[#EDE9E9] hover:bg-zinc-100 text-zinc-700'}`;
    }
    const role = getPitchClassColorRole(root, selectedKey);
    if (isActive) return `${getRoleSolidClass(role, darkMode)} border border-transparent text-white`;
    const color = getRoleColor(role);
    const border = isScale(chord) ? `border ${darkMode ? color.darkBorder : color.border200}` : 'border border-transparent';
    return `${darkMode ? `${color.darkBg100} ${color.darkHover100} text-zinc-200` : `${color.bg100} ${color.hover100} text-zinc-700`} ${border}`;
  };

  const chordSetPanel = (
    <ChordSetPanel
      library={library}
      onLibraryChange={handleLibraryChange}
      isChipActive={chord => (chord.scale ? sameKey(chord.scale, selectedKey) : chord.id === activeChordId)}
      chipClassName={chipClassName}
      chipTitle={chord => (chord.scale ? getKeyShortName(chord.scale, noteLabelMode === 'sharpsOnly') : chord.name)}
      onSelectChord={handleChordSelect}
      onDeleteChord={handleChordDelete}
      onOpenBank={openChordBank}
      isBankOpen={bankOpen}
      loopingSectionId={loopingSectionId}
      onToggleSectionLoop={id => toggleLoop(id)}
      darkMode={darkMode}
    />
  );

  /** Phones show one instrument at a time. */
  const isPhone = !isWide;

  /** What both instruments need to draw the selection, labels, playback flash and next chord. */
  const instrumentProps = {
    selectedNotes,
    onNoteSelect: handleNoteSelect,
    labelContext,
    darkMode,
    soundingNotes,
    nextChordHint: {
      notes: nextChord && showNextChord ? nextChord.notes : [],
      isShowing: isPreviewingNext,
      fadeMs: previewFadeMs,
    },
  };

  /** Instruments that are turned on, and on a phone the one that's showing. */
  const instrumentOptions: InstrumentChoice[] = [
    ...(['guitar', 'guitar2'] as const).slice(0, fretboards.length),
    ...(showPiano ? ['piano' as const] : []),
  ];
  const phoneShowing = instrumentOptions.includes(phoneInstrument) ? phoneInstrument : instrumentOptions[0];
  const choosePhoneInstrument = (choice: InstrumentChoice) => {
    setPhoneInstrument(choice);
    try { localStorage.setItem('frets2keys_phoneInstrument', choice); } catch { /* ignore */ }
  };
  const visibleFretboards = isPhone
    ? fretboards.filter((_, i) => phoneShowing === (i === 0 ? 'guitar' : 'guitar2'))
    : fretboards;
  const instrumentTitle = (choice: InstrumentChoice) =>
    choice === 'piano' ? 'Piano' : choice === 'guitar2' ? 'Guitar 2' : fretboards.length > 1 ? 'Guitar 1' : 'Guitar';

  /** The section the chord bank adds to, named on its button when the set has sections. */
  const bankAddTitle = (() => {
    if (set.sections.length < 2) return 'Add to Set';
    const id = bankTargetSectionId ?? activeSectionId(set, activeChordId);
    const index = Math.max(0, set.sections.findIndex(s => s.id === id));
    return `Add to ${sectionDisplayName(set.sections[index], index)}`;
  })();
  /** On a phone the bank covers everything, so it closes after an action to show the result. */
  const afterBankAction = () => { if (isPhone) setBankOpen(false); };

  const chordBank = bankOpen && (
    <ChordBankPanel
      appKey={selectedKey}
      sharpsOnly={noteLabelMode === 'sharpsOnly'}
      addTitle={bankAddTitle}
      isFull={savedChords.length >= MAX_SAVED_CHORDS}
      onPreview={(notes, mode) => play(notes, mode, sound, tempo)}
      onSelectChord={notes => {
        setSelectedNotes(notes);
        setActiveChordId(null);
        sound_(notes);
        afterBankAction();
      }}
      onAddChord={notes => { saveChord(notes, bankTargetSectionId); afterBankAction(); }}
      onShowScale={(scale, notes) => {
        setSelectedKey(scale);
        playArpeggio(notes, sound, tempo);
        afterBankAction();
      }}
      onAddScale={(scale, notes, name) => { addScale(scale, notes, name, bankTargetSectionId); afterBankAction(); }}
      onClose={() => { setBankOpen(false); setBankTargetSectionId(null); }}
      darkMode={darkMode}
    />
  );

  return (
    <div className={`h-dvh flex overflow-hidden ${darkMode ? 'bg-zinc-900 text-zinc-100' : 'bg-[#F5F3F2] text-zinc-900'}`}>
    <div className="flex-1 min-w-0 flex flex-col">
      {/* Top bar: the key on the left, playback and settings on the right. */}
      <header className={`flex-shrink-0 flex items-center gap-2 min-[600px]:gap-3 pt-4 pb-2 ${sidePadding}`}>
        {/* On narrow screens the key's name can truncate rather than push the bar off screen. */}
        <div className="min-w-0 flex-shrink">
        <KeyMenu
          selectedKey={selectedKey}
          onSelectKey={setSelectedKey}
          labelContent={noteLabelContent}
          onLabelContentChange={setNoteLabelContent}
          sharpsOnly={noteLabelMode === 'sharpsOnly'}
          isWide={isWide}
          darkMode={darkMode}
        />
        </div>
        {isPhone && instrumentOptions.length > 1 ? (
          // A phone shows one instrument at a time; tabs pick which.
          <div className="flex-1 flex justify-center">
            <div className={`flex p-0.5 rounded-lg ${darkMode ? 'bg-zinc-800' : 'bg-zinc-200/70'}`} role="tablist" aria-label="Instrument">
              {instrumentOptions.map(choice => (
                <button
                  key={choice}
                  role="tab"
                  aria-selected={choice === phoneShowing}
                  onClick={() => choosePhoneInstrument(choice)}
                  className={`px-2.5 py-1 rounded-md text-[13px] font-medium whitespace-nowrap transition-colors ${
                    choice === phoneShowing
                      ? darkMode ? 'bg-zinc-600 text-white' : 'bg-white text-zinc-900 shadow-sm'
                      : darkMode ? 'text-zinc-300' : 'text-zinc-600'
                  }`}
                >
                  {instrumentTitle(choice)}
                </button>
              ))}
            </div>
          </div>
        ) : (
          <div className="flex-1" />
        )}
        <div className="flex items-center">
          <button onClick={handlePlayAll} disabled={!hasSelection} className={iconButtonClass(hasSelection)} title="Play all selected notes (Enter)">{ICONS.play}</button>
          <button
            onClick={handleLoopToggle}
            disabled={!canLoop && !loopMode}
            className={loopMode
              ? `${isWide ? 'w-8 h-8' : 'w-10 h-10'} flex items-center justify-center rounded-lg transition-colors bg-green-500 text-white hover:bg-green-600`
              : iconButtonClass(canLoop)}
            title={loopMode ? 'Stop loop (Space)' : 'Loop playback (Space)'}
          >
            {ICONS.loop}
          </button>
          <button onClick={() => setSettingsOpen(true)} className={iconButtonClass(true)} title="Settings">{ICONS.settings}</button>
        </div>
      </header>

      {/* The instrument cards, centered in the space between the bars; they scroll when they
          need more room than there is. */}
      <main ref={instrumentsAreaRef} className="flex-1 min-h-0 overflow-y-auto">
        <div className={`min-h-full flex flex-col justify-center ${sidePadding}`} style={{ gap: INSTRUMENT_SPACING, paddingTop: INSTRUMENTS_VERTICAL_PADDING, paddingBottom: INSTRUMENTS_VERTICAL_PADDING }}>
          {visibleFretboards.length > 0 && (
            <div ref={fretboardsRef} className={`flex ${isDesktop ? 'flex-row' : 'flex-col'}`} style={{ gap: INSTRUMENT_SPACING }}>
              {visibleFretboards.map((fretboard, index) => (
                <div key={fretboard.id} ref={index === 0 ? firstGuitarRef : undefined} className="flex-1 min-w-0">
                  <GuitarFretboard
                    {...instrumentProps}
                    tuning={fretboard.tuning}
                    capo={fretboard.capo}
                    anyCapoActive={anyCapoActive}
                  />
                </div>
              ))}
            </div>
          )}

          {showPiano && (!isPhone || phoneShowing === 'piano') && (
            <PianoKeyboard
              {...instrumentProps}
              tuning={allTunings.length > 0 ? allTunings : TUNINGS.standard.notes}
              targetHeight={isPhone ? null : pianoTargetHeight}
              wide={isWide}
            />
          )}
        </div>
      </main>

      {/* The chord panel, divided off by a hairline: the selected chord and the saved chords. */}
      <div className="flex-shrink-0 pb-[env(safe-area-inset-bottom)]">
        <div className={`h-px ${dividerColor}`} />
        {chordLimitWarning && (
          <div className={`${sidePadding} pt-2`}>
            <div className={`rounded-2xl p-3 flex items-center gap-2 ${
              darkMode
                ? 'bg-amber-900/50 border border-amber-700 text-amber-200'
                : 'bg-amber-50 border border-amber-200 text-amber-800'
            }`}>
              <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" className="w-5 h-5 flex-shrink-0">
                <path fillRule="evenodd" d="M8.485 2.495c.673-1.167 2.357-1.167 3.03 0l6.28 10.875c.673 1.167-.17 2.625-1.516 2.625H3.72c-1.347 0-2.189-1.458-1.515-2.625L8.485 2.495zM10 5a.75.75 0 01.75.75v3.5a.75.75 0 01-1.5 0v-3.5A.75.75 0 0110 5zm0 9a1 1 0 100-2 1 1 0 000 2z" clipRule="evenodd" />
              </svg>
              <span className="text-sm">Maximum of {MAX_SAVED_CHORDS} chords reached. Delete some chords to save new ones.</span>
              <button
                onClick={() => setChordLimitWarning(false)}
                className={`ml-auto p-1 rounded transition-colors ${darkMode ? 'hover:bg-amber-800' : 'hover:bg-amber-100'}`}
              >
                <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" className="w-4 h-4">
                  <path d="M6.28 5.22a.75.75 0 00-1.06 1.06L8.94 10l-3.72 3.72a.75.75 0 101.06 1.06L10 11.06l3.72 3.72a.75.75 0 101.06-1.06L11.06 10l3.72-3.72a.75.75 0 00-1.06-1.06L10 8.94 6.28 5.22z" />
                </svg>
              </button>
            </div>
          </div>
        )}

        {isDesktop ? (
          // Wide windows: the selected chord in the left third, the saved chords beside it.
          <div className="flex items-stretch">
            <div className={`w-1/3 flex-shrink-0 py-4 flex flex-col gap-1 ${sidePadding}`}>
              <div className="flex">{chordSummary}</div>
              {/* Grouped at the start, the first icon lined up with the text above. */}
              <div className="-ml-2">{chordControls(false)}</div>
            </div>
            <div className={`w-px flex-shrink-0 ${dividerColor}`} />
            <div className={`flex-1 min-w-0 py-4 ${sidePadding}`}>{chordSetPanel}</div>
          </div>
        ) : (
          <>
            {isWide ? (
              <div className={`flex items-center gap-2 py-2.5 ${sidePadding}`}>
                {chordSummary}
                {chordControls(false)}
              </div>
            ) : (
              // Phones: the chord on one line, its controls spread across the next.
              <div className={`flex flex-col gap-1 py-2 ${sidePadding}`}>
                <div className="flex">{chordSummary}</div>
                {chordControls(true)}
              </div>
            )}
            <div className={`h-px ${dividerColor}`} />
            {/* On a phone the set grows with its chords up to a cap, then scrolls. */}
            <div className={`py-4 ${sidePadding} ${isPhone ? 'max-h-[40dvh] overflow-y-auto' : ''}`}>{chordSetPanel}</div>
          </>
        )}
      </div>

    </div>

      {/* The chord bank: beside everything on wider windows, covering it on a phone. */}
      {chordBank && (isPhone ? (
        <div className="fixed inset-0 z-40">{chordBank}</div>
      ) : (
        <aside className={`w-[380px] flex-shrink-0 border-l ${darkMode ? 'border-zinc-700' : 'border-[#E7E2E0]'}`}>{chordBank}</aside>
      ))}

      <SettingsDialog
        isOpen={settingsOpen}
        fretboards={fretboards}
        fretboardCount={fretboards.length}
        showPiano={showPiano}
        playMode={playMode}
        keyLabelMode={keyLabelMode}
        noteLabelMode={noteLabelMode}
        hasKeySelected={selectedKey !== null}
        darkMode={darkMode}
        onClose={() => setSettingsOpen(false)}
        onFretboardCountChange={handleFretboardCountChange}
        onShowPianoChange={setShowPiano}
        onPlayModeChange={setPlayMode}
        onKeyLabelModeChange={setKeyLabelMode}
        onNoteLabelModeChange={setNoteLabelMode}
        onTuningChange={handleTuningChange}
        onCapoChange={handleCapoChange}
        onStringCountChange={handleStringCountChange}
        onResetTuning={handleResetTuning}
        onOpenTutorial={() => setTutorialOpen(true)}
        onDarkModeChange={setDarkMode}
        sound={sound}
        onSoundChange={handleSoundChange}
        tempo={tempo}
        onTempoChange={value => setTempo(clampTempo(value))}
        showNextChord={showNextChord}
        onShowNextChordChange={setShowNextChord}
      />

      <WelcomeTutorial
        isOpen={tutorialOpen}
        onClose={() => setTutorialOpen(false)}
        darkMode={darkMode}
      />
    </div>
  );
}
