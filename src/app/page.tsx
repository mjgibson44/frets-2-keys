'use client';

import { useState, useRef, useEffect, useCallback } from 'react';
import GuitarFretboard from '@/components/GuitarFretboard';
import PianoKeyboard from '@/components/PianoKeyboard';
import SettingsDialog from '@/components/SettingsDialog';
import SavedChords, { SavedChord } from '@/components/SavedChords';
import WelcomeTutorial from '@/components/WelcomeTutorial';
import { TUNINGS, MusicalKey, ALL_KEYS, getKeyName, getNotesInKeyDisplay, noteToMidi, midiToNote, getScaleDegree, getScaleDegreeColor, getOutOfKeyColor, getChromaticNoteColor, getDefaultTuning } from '@/lib/notes';
import { playNote, playChord, playArpeggio } from '@/lib/audio';
import { SelectedNote, getNextAvailableColorIndex } from '@/lib/colors';
import { identifyChord } from '@/lib/chords';

interface Fretboard {
  id: string;
  tuning: string[];
  capo: number;
}

export default function Home() {
  const [selectedNotes, setSelectedNotes] = useState<SelectedNote[]>([]);
  const [fretboards, setFretboards] = useState<Fretboard[]>([
    { id: '1', tuning: TUNINGS.standard.notes, capo: 0 }
  ]);
  const [playMode, setPlayMode] = useState<'chord' | 'arpeggio'>('chord');
  const [savedChords, setSavedChords] = useState<SavedChord[]>([]);
  const [activeChordId, setActiveChordId] = useState<string | null>(null);
  const [settingsOpen, setSettingsOpen] = useState(false);
  const [showPiano, setShowPiano] = useState(true);
  const [selectedKey, setSelectedKey] = useState<MusicalKey | null>({ root: 'C', type: 'major' });
  const [keyDropdownOpen, setKeyDropdownOpen] = useState(false);
  const [keyLabelMode, setKeyLabelMode] = useState<'onlyInKey' | 'showAll'>('showAll');
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);
  const [darkMode, setDarkMode] = useState(false);
  const [noteLabelMode, setNoteLabelMode] = useState<'sharpsAndFlats' | 'sharpsOnly'>('sharpsAndFlats');
  const [loopMode, setLoopMode] = useState(false);
  const [chordLimitWarning, setChordLimitWarning] = useState(false);
  const [tutorialOpen, setTutorialOpen] = useState(false);
  const loopTimeoutRef = useRef<NodeJS.Timeout | null>(null);
  const loopChordIndexRef = useRef(0);
  const loopPlayCountRef = useRef(0);
  const warningTimeoutRef = useRef<NodeJS.Timeout | null>(null);
  const hasLoadedState = useRef(false);

  const MAX_SAVED_CHORDS = 20;
  const STORAGE_KEY = 'frets2keys_appState';
  const chordName = identifyChord(selectedNotes.map(sn => sn.note));

  // Check if the current selection differs from the active saved chord
  const activeChord = savedChords.find(c => c.id === activeChordId);
  const hasChangesFromSaved = activeChord ? (
    selectedNotes.length !== activeChord.notes.length ||
    selectedNotes.some((sn, i) => sn.note !== activeChord.notes[i]?.note)
  ) : false;

  // Load state from localStorage on mount
  useEffect(() => {
    try {
      const saved = localStorage.getItem(STORAGE_KEY);
      if (saved) {
        const state = JSON.parse(saved);
        if (state.fretboards) setFretboards(state.fretboards);
        if (state.savedChords) setSavedChords(state.savedChords);
        if (state.playMode) setPlayMode(state.playMode);
        if (state.showPiano !== undefined) setShowPiano(state.showPiano);
        if (state.selectedKey !== undefined) setSelectedKey(state.selectedKey);
        if (state.keyLabelMode) setKeyLabelMode(state.keyLabelMode);
        if (state.noteLabelMode) setNoteLabelMode(state.noteLabelMode);
        if (state.darkMode !== undefined) setDarkMode(state.darkMode);
      }
    } catch (e) {
      // Ignore localStorage errors
    }
    hasLoadedState.current = true;
  }, []);

  // Save state to localStorage when it changes
  useEffect(() => {
    if (!hasLoadedState.current) return;

    try {
      const state = {
        fretboards,
        savedChords,
        playMode,
        showPiano,
        selectedKey,
        keyLabelMode,
        noteLabelMode,
        darkMode,
      };
      localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
    } catch (e) {
      // Ignore localStorage errors (e.g., quota exceeded)
    }
  }, [fretboards, savedChords, playMode, showPiano, selectedKey, keyLabelMode, noteLabelMode, darkMode]);

  const handleNoteSelect = (note: string) => {
    const existingIndex = selectedNotes.findIndex(sn => sn.note === note);

    if (existingIndex !== -1) {
      setSelectedNotes(prev => prev.filter((_, i) => i !== existingIndex));
    } else {
      playNote(note);
      const usedIndices = selectedNotes.map(sn => sn.colorIndex);
      const newColorIndex = getNextAvailableColorIndex(usedIndices);
      setSelectedNotes(prev => [...prev, { note, colorIndex: newColorIndex }]);
    }
  };

  const handleClearAll = () => {
    setSelectedNotes([]);
    setActiveChordId(null);
  };

  const handleTranspose = (semitones: number) => {
    if (selectedNotes.length === 0) return;

    // If in 'onlyInKey' mode, switch to 'showAll'
    if (keyLabelMode === 'onlyInKey') {
      setKeyLabelMode('showAll');
    }

    setSelectedNotes(prev => prev.map(sn => {
      const midi = noteToMidi(sn.note);
      const newMidi = midi + semitones;
      // Keep within valid MIDI range
      if (newMidi < 0 || newMidi > 127) return sn;
      return { ...sn, note: midiToNote(newMidi) };
    }));
  };

  const handlePlayAll = () => {
    const notes = selectedNotes.map(sn => sn.note);
    if (playMode === 'chord') {
      playChord(notes);
    } else {
      playArpeggio(notes);
    }
  };

  // Calculate playback duration based on mode and number of notes
  // Uses fixed rhythmic intervals for consistent timing
  const getPlaybackDuration = useCallback((noteCount: number) => {
    if (playMode === 'chord') {
      // Trigger every 800ms for faster rhythm
      return 800;
    } else {
      // Arpeggio: notes are 400ms apart, so next arpeggio starts at noteCount * 400ms
      // This keeps the gap between last note and next first note equal to gaps within arpeggio
      return noteCount * 400;
    }
  }, [playMode]);

  // Play the current chord/arpeggio and schedule the next iteration
  const playLoopIteration = useCallback(() => {
    if (!loopMode) return;

    let notesToPlay: string[];

    if (savedChords.length > 1) {
      // Multiple saved chords: play each 4 times before switching
      const currentChord = savedChords[loopChordIndexRef.current];
      if (currentChord) {
        notesToPlay = currentChord.notes.map(sn => sn.note);
        setSelectedNotes(currentChord.notes);
        setActiveChordId(currentChord.id);

        // Increment play count
        loopPlayCountRef.current += 1;

        // After 4 plays, move to next chord
        if (loopPlayCountRef.current >= 4) {
          loopPlayCountRef.current = 0;
          loopChordIndexRef.current = (loopChordIndexRef.current + 1) % savedChords.length;
        }
      } else {
        return;
      }
    } else {
      // Single chord or no saved chords: play current selection
      notesToPlay = selectedNotes.map(sn => sn.note);
    }

    if (notesToPlay.length === 0) {
      setLoopMode(false);
      return;
    }

    // Play the notes
    if (playMode === 'chord') {
      playChord(notesToPlay);
    } else {
      playArpeggio(notesToPlay);
    }

    // Schedule next iteration
    const duration = getPlaybackDuration(notesToPlay.length);
    loopTimeoutRef.current = setTimeout(() => {
      playLoopIteration();
    }, duration);
  }, [loopMode, savedChords, selectedNotes, playMode, getPlaybackDuration]);

  // Start/stop loop when loopMode changes
  useEffect(() => {
    if (loopMode) {
      // Reset chord index to start from current active chord or beginning
      if (savedChords.length > 1 && activeChordId) {
        const currentIndex = savedChords.findIndex(c => c.id === activeChordId);
        loopChordIndexRef.current = currentIndex >= 0 ? currentIndex : 0;
      } else {
        loopChordIndexRef.current = 0;
      }
      loopPlayCountRef.current = 0; // Reset play count
      playLoopIteration();
    } else {
      // Stop loop
      if (loopTimeoutRef.current) {
        clearTimeout(loopTimeoutRef.current);
        loopTimeoutRef.current = null;
      }
    }

    return () => {
      if (loopTimeoutRef.current) {
        clearTimeout(loopTimeoutRef.current);
        loopTimeoutRef.current = null;
      }
    };
  }, [loopMode]); // Only depend on loopMode to avoid re-triggering

  const handleLoopToggle = () => {
    if (selectedNotes.length === 0 && savedChords.length === 0) return;
    setLoopMode(prev => !prev);
  };

  // Stop loop if no notes are selected
  useEffect(() => {
    if (loopMode && selectedNotes.length === 0 && savedChords.length === 0) {
      setLoopMode(false);
    }
  }, [selectedNotes.length, savedChords.length, loopMode]);

  // Show tutorial on first visit
  useEffect(() => {
    const hasSeenTutorial = localStorage.getItem('frets2keys_hasSeenTutorial');
    if (!hasSeenTutorial) {
      setTutorialOpen(true);
      localStorage.setItem('frets2keys_hasSeenTutorial', 'true');
    }
  }, []);

  const handleSaveChordAsNew = () => {
    if (selectedNotes.length === 0 || !chordName) return;

    // Check chord limit
    if (savedChords.length >= MAX_SAVED_CHORDS) {
      // Clear any existing timeout
      if (warningTimeoutRef.current) {
        clearTimeout(warningTimeoutRef.current);
      }
      setChordLimitWarning(true);
      // Auto-hide warning after 3 seconds
      warningTimeoutRef.current = setTimeout(() => {
        setChordLimitWarning(false);
      }, 3000);
      return;
    }

    const newChord: SavedChord = {
      id: Date.now().toString(),
      name: chordName,
      notes: [...selectedNotes],
    };

    setSavedChords(prev => [...prev, newChord]);
    setActiveChordId(newChord.id);
  };

  const handleUpdateChord = () => {
    if (selectedNotes.length === 0 || !chordName || !activeChordId) return;

    setSavedChords(prev => prev.map(chord =>
      chord.id === activeChordId
        ? { ...chord, name: chordName, notes: [...selectedNotes] }
        : chord
    ));
  };

  const handleChordSelect = (chord: SavedChord) => {
    setSelectedNotes(chord.notes);
    setActiveChordId(chord.id);
  };

  const handleChordDelete = (id: string) => {
    setSavedChords(prev => prev.filter(c => c.id !== id));
    if (activeChordId === id) {
      setActiveChordId(null);
    }
  };

  const handleChordReorder = (reorderedChords: SavedChord[]) => {
    setSavedChords(reorderedChords);
  };

  // Keyboard shortcuts
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      // Don't trigger shortcuts when typing in inputs
      if (e.target instanceof HTMLInputElement || e.target instanceof HTMLTextAreaElement || e.target instanceof HTMLSelectElement) {
        return;
      }

      switch (e.key) {
        case 'Delete':
        case 'Backspace':
          e.preventDefault();
          handleClearAll();
          break;
        case 's':
        case 'S':
          e.preventDefault();
          if (activeChordId && selectedNotes.length > 0 && chordName && hasChangesFromSaved) {
            handleUpdateChord();
          }
          break;
        case 'a':
        case 'A':
          e.preventDefault();
          if (selectedNotes.length > 0 && chordName) {
            handleSaveChordAsNew();
          }
          break;
        case '+':
        case '=':
          e.preventDefault();
          handleTranspose(1);
          break;
        case '-':
        case '_':
          e.preventDefault();
          handleTranspose(-1);
          break;
        case 'Enter':
          e.preventDefault();
          if (selectedNotes.length > 0) {
            handlePlayAll();
          }
          break;
        case ' ':
          e.preventDefault();
          handleLoopToggle();
          break;
        case 'ArrowLeft':
          e.preventDefault();
          if (savedChords.length > 0) {
            const currentIndex = activeChordId ? savedChords.findIndex(c => c.id === activeChordId) : -1;
            const prevIndex = currentIndex <= 0 ? savedChords.length - 1 : currentIndex - 1;
            const prevChord = savedChords[prevIndex];
            setSelectedNotes(prevChord.notes);
            setActiveChordId(prevChord.id);
          }
          break;
        case 'ArrowRight':
          e.preventDefault();
          if (savedChords.length > 0) {
            const currentIndex = activeChordId ? savedChords.findIndex(c => c.id === activeChordId) : -1;
            const nextIndex = currentIndex >= savedChords.length - 1 ? 0 : currentIndex + 1;
            const nextChord = savedChords[nextIndex];
            setSelectedNotes(nextChord.notes);
            setActiveChordId(nextChord.id);
          }
          break;
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [selectedNotes, savedChords, activeChordId, chordName, hasChangesFromSaved]);

  const handleTuningChange = (fretboardId: string, tuning: string[]) => {
    setFretboards(prev => prev.map(fb =>
      fb.id === fretboardId ? { ...fb, tuning } : fb
    ));
  };

  const handleCapoChange = (fretboardId: string, capo: number) => {
    setFretboards(prev => prev.map(fb =>
      fb.id === fretboardId ? { ...fb, capo } : fb
    ));
  };

  const handleStringCountChange = (fretboardId: string, count: number) => {
    setFretboards(prev => prev.map(fb => {
      if (fb.id !== fretboardId) return fb;
      const newTuning = getDefaultTuning(count);
      return { ...fb, tuning: newTuning };
    }));
  };

  const handleResetTuning = (fretboardId: string) => {
    setFretboards(prev => prev.map(fb => {
      if (fb.id !== fretboardId) return fb;
      const defaultTuning = getDefaultTuning(fb.tuning.length);
      return { ...fb, tuning: defaultTuning, capo: 0 };
    }));
  };

  const handleAddFretboard = () => {
    const newFretboard: Fretboard = {
      id: Date.now().toString(),
      tuning: TUNINGS.standard.notes,
      capo: 0,
    };
    setFretboards(prev => [...prev, newFretboard]);
  };

  const handleDeleteFretboard = (id: string) => {
    if (fretboards.length <= 1) return;
    setFretboards(prev => prev.filter(fb => fb.id !== id));
  };

  const handleFretboardCountChange = (count: number) => {
    if (count === 0) {
      setFretboards([]);
    } else if (count > fretboards.length) {
      // Add fretboards
      const newFretboards = [...fretboards];
      while (newFretboards.length < count) {
        newFretboards.push({
          id: Date.now().toString() + newFretboards.length,
          tuning: TUNINGS.standard.notes,
          capo: 0,
        });
      }
      setFretboards(newFretboards);
    } else if (count < fretboards.length) {
      // Remove fretboards from the end
      setFretboards(prev => prev.slice(0, count));
    }
  };

  // Get all tunings for piano keyboard range calculation
  const allTunings = fretboards.flatMap(fb => fb.tuning);
  const anyCapoActive = fretboards.some(fb => fb.capo > 0);

  return (
    <div className={`min-h-screen p-6 min-[600px]:p-8 ${darkMode ? 'bg-zinc-900 text-zinc-100' : 'bg-[#F8F4F4] text-zinc-900'}`}>
      <div className="max-w-7xl mx-auto space-y-[16px]">
        {/* Controls bar */}
        <header className="space-y-2">
          {/* Icons row - first row below 800px */}
          <div className="flex min-[880px]:hidden items-center justify-end">
            <div className="flex items-center">
              <button
                onClick={handleClearAll}
                disabled={selectedNotes.length === 0}
                className={`w-10 h-10 min-[600px]:w-8 min-[600px]:h-8 flex items-center justify-center rounded-lg transition-colors ${
                  selectedNotes.length > 0
                    ? darkMode
                      ? 'hover:bg-zinc-700 text-zinc-400 hover:text-zinc-200'
                      : 'hover:bg-zinc-200 text-zinc-400 hover:text-zinc-600'
                    : darkMode
                      ? 'text-zinc-600 cursor-not-allowed'
                      : 'text-zinc-300 cursor-not-allowed'
                }`}
                title="Clear all notes (Delete)"
              >
                <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" className="w-5 h-5">
                  <path d="M6.28 5.22a.75.75 0 00-1.06 1.06L8.94 10l-3.72 3.72a.75.75 0 101.06 1.06L10 11.06l3.72 3.72a.75.75 0 101.06-1.06L11.06 10l3.72-3.72a.75.75 0 00-1.06-1.06L10 8.94 6.28 5.22z" />
                </svg>
              </button>
              <button
                onClick={handleUpdateChord}
                disabled={!activeChordId || selectedNotes.length === 0 || !chordName || !hasChangesFromSaved}
                className={`w-10 h-10 min-[600px]:w-8 min-[600px]:h-8 flex items-center justify-center rounded-lg transition-colors ${
                  activeChordId && selectedNotes.length > 0 && chordName && hasChangesFromSaved
                    ? darkMode
                      ? 'hover:bg-zinc-700 text-zinc-400 hover:text-zinc-200'
                      : 'hover:bg-zinc-200 text-zinc-400 hover:text-zinc-600'
                    : darkMode
                      ? 'text-zinc-600 cursor-not-allowed'
                      : 'text-zinc-300 cursor-not-allowed'
                }`}
                title="Update existing chord (S)"
              >
                <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" className="w-5 h-5">
                  <path fillRule="evenodd" d="M16.704 4.153a.75.75 0 01.143 1.052l-8 10.5a.75.75 0 01-1.127.075l-4.5-4.5a.75.75 0 011.06-1.06l3.894 3.893 7.48-9.817a.75.75 0 011.05-.143z" clipRule="evenodd" />
                </svg>
              </button>
              <button
                onClick={handleSaveChordAsNew}
                disabled={selectedNotes.length === 0 || !chordName}
                className={`w-10 h-10 min-[600px]:w-8 min-[600px]:h-8 flex items-center justify-center rounded-lg transition-colors ${
                  selectedNotes.length > 0 && chordName
                    ? darkMode
                      ? 'hover:bg-zinc-700 text-zinc-400 hover:text-zinc-200'
                      : 'hover:bg-zinc-200 text-zinc-400 hover:text-zinc-600'
                    : darkMode
                      ? 'text-zinc-600 cursor-not-allowed'
                      : 'text-zinc-300 cursor-not-allowed'
                }`}
                title="Save as new chord (A)"
              >
                <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" className="w-5 h-5">
                  <path d="M10.75 4.75a.75.75 0 00-1.5 0v4.5h-4.5a.75.75 0 000 1.5h4.5v4.5a.75.75 0 001.5 0v-4.5h4.5a.75.75 0 000-1.5h-4.5v-4.5z" />
                </svg>
              </button>
              <button
                onClick={() => handleTranspose(1)}
                disabled={selectedNotes.length === 0}
                className={`w-10 h-10 min-[600px]:w-8 min-[600px]:h-8 flex items-center justify-center rounded-lg transition-colors ${
                  selectedNotes.length > 0
                    ? darkMode
                      ? 'hover:bg-zinc-700 text-zinc-400 hover:text-zinc-200'
                      : 'hover:bg-zinc-200 text-zinc-400 hover:text-zinc-600'
                    : darkMode
                      ? 'text-zinc-600 cursor-not-allowed'
                      : 'text-zinc-300 cursor-not-allowed'
                }`}
                title="Transpose up 1 semitone (+)"
              >
                <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" className="w-5 h-5">
                  <path fillRule="evenodd" d="M10 17a.75.75 0 01-.75-.75V5.612L5.29 9.77a.75.75 0 01-1.08-1.04l5.25-5.5a.75.75 0 011.08 0l5.25 5.5a.75.75 0 11-1.08 1.04l-3.96-4.158V16.25A.75.75 0 0110 17z" clipRule="evenodd" />
                </svg>
              </button>
              <button
                onClick={() => handleTranspose(-1)}
                disabled={selectedNotes.length === 0}
                className={`w-10 h-10 min-[600px]:w-8 min-[600px]:h-8 flex items-center justify-center rounded-lg transition-colors ${
                  selectedNotes.length > 0
                    ? darkMode
                      ? 'hover:bg-zinc-700 text-zinc-400 hover:text-zinc-200'
                      : 'hover:bg-zinc-200 text-zinc-400 hover:text-zinc-600'
                    : darkMode
                      ? 'text-zinc-600 cursor-not-allowed'
                      : 'text-zinc-300 cursor-not-allowed'
                }`}
                title="Transpose down 1 semitone (-)"
              >
                <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" className="w-5 h-5">
                  <path fillRule="evenodd" d="M10 17a.75.75 0 01-.75-.75V5.612L5.29 9.77a.75.75 0 01-1.08-1.04l5.25-5.5a.75.75 0 011.08 0l5.25 5.5a.75.75 0 11-1.08 1.04l-3.96-4.158V16.25A.75.75 0 0110 17z" clipRule="evenodd" transform="rotate(180 10 10)" />
                </svg>
              </button>
              <button
                onClick={handlePlayAll}
                disabled={selectedNotes.length === 0}
                className={`w-10 h-10 min-[600px]:w-8 min-[600px]:h-8 flex items-center justify-center rounded-lg transition-colors ${
                  selectedNotes.length > 0
                    ? darkMode
                      ? 'hover:bg-zinc-700 text-zinc-400 hover:text-zinc-200'
                      : 'hover:bg-zinc-200 text-zinc-400 hover:text-zinc-600'
                    : darkMode
                      ? 'text-zinc-600 cursor-not-allowed'
                      : 'text-zinc-300 cursor-not-allowed'
                }`}
                title="Play all selected notes (Enter)"
              >
                <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" className="w-5 h-5">
                  <path fillRule="evenodd" d="M4.5 5.653c0-1.426 1.529-2.33 2.779-1.643l11.54 6.348c1.295.712 1.295 2.573 0 3.285L7.28 19.991c-1.25.687-2.779-.217-2.779-1.643V5.653z" clipRule="evenodd" />
                </svg>
              </button>
              <button
                onClick={handleLoopToggle}
                disabled={selectedNotes.length === 0 && savedChords.length === 0}
                className={`w-10 h-10 min-[600px]:w-8 min-[600px]:h-8 flex items-center justify-center rounded-lg transition-colors ${
                  loopMode
                    ? 'bg-green-500 text-white hover:bg-green-600'
                    : (selectedNotes.length > 0 || savedChords.length > 0)
                      ? darkMode
                        ? 'hover:bg-zinc-700 text-zinc-400 hover:text-zinc-200'
                        : 'hover:bg-zinc-200 text-zinc-400 hover:text-zinc-600'
                      : darkMode
                        ? 'text-zinc-600 cursor-not-allowed'
                        : 'text-zinc-300 cursor-not-allowed'
                }`}
                title={loopMode ? 'Stop loop (Space)' : 'Loop playback (Space)'}
              >
                <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" className="w-5 h-5">
                  <path fillRule="evenodd" d="M12 5.25c1.213 0 2.415.046 3.605.135a3.256 3.256 0 013.01 3.01c.044.583.077 1.17.1 1.759L17.03 8.47a.75.75 0 10-1.06 1.06l3 3a.75.75 0 001.06 0l3-3a.75.75 0 00-1.06-1.06l-1.752 1.751c-.023-.65-.06-1.296-.108-1.939a4.756 4.756 0 00-4.392-4.392 49.422 49.422 0 00-7.436 0A4.756 4.756 0 003.89 8.282c-.017.224-.033.447-.046.672a.75.75 0 101.497.092c.013-.217.028-.432.044-.647a3.256 3.256 0 013.01-3.01c1.19-.09 2.392-.136 3.605-.136zm-6.97 6.22a.75.75 0 00-1.06 0l-3 3a.75.75 0 101.06 1.06l1.752-1.751c.023.65.06 1.296.108 1.939a4.756 4.756 0 004.392 4.392 49.413 49.413 0 007.436 0 4.756 4.756 0 004.392-4.392c.017-.223.032-.447.046-.672a.75.75 0 00-1.497-.092c-.013.217-.028.434-.044.647a3.256 3.256 0 01-3.01 3.01 47.953 47.953 0 01-7.21 0 3.256 3.256 0 01-3.01-3.01 47.759 47.759 0 01-.1-1.759L6.97 12.53a.75.75 0 001.06-1.06l-3-3z" clipRule="evenodd" />
                </svg>
              </button>
              <button
                onClick={() => setDarkMode(!darkMode)}
                className={`w-10 h-10 min-[600px]:w-8 min-[600px]:h-8 flex items-center justify-center rounded-lg transition-colors ${
                  darkMode
                    ? 'hover:bg-zinc-700 text-zinc-400 hover:text-zinc-200'
                    : 'hover:bg-zinc-200 text-zinc-400 hover:text-zinc-600'
                }`}
                title={darkMode ? 'Switch to light mode' : 'Switch to dark mode'}
              >
                {darkMode ? (
                  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" className="w-5 h-5">
                    <path d="M10 2a.75.75 0 01.75.75v1.5a.75.75 0 01-1.5 0v-1.5A.75.75 0 0110 2zM10 15a.75.75 0 01.75.75v1.5a.75.75 0 01-1.5 0v-1.5A.75.75 0 0110 15zM10 7a3 3 0 100 6 3 3 0 000-6zM15.657 5.404a.75.75 0 10-1.06-1.06l-1.061 1.06a.75.75 0 001.06 1.06l1.06-1.06zM6.464 14.596a.75.75 0 10-1.06-1.06l-1.06 1.06a.75.75 0 001.06 1.06l1.06-1.06zM18 10a.75.75 0 01-.75.75h-1.5a.75.75 0 010-1.5h1.5A.75.75 0 0118 10zM5 10a.75.75 0 01-.75.75h-1.5a.75.75 0 010-1.5h1.5A.75.75 0 015 10zM14.596 15.657a.75.75 0 001.06-1.06l-1.06-1.061a.75.75 0 10-1.06 1.06l1.06 1.06zM5.404 6.464a.75.75 0 001.06-1.06l-1.06-1.06a.75.75 0 10-1.06 1.06l1.06 1.06z" />
                  </svg>
                ) : (
                  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" className="w-5 h-5">
                    <path fillRule="evenodd" d="M7.455 2.004a.75.75 0 01.26.77 7 7 0 009.958 7.967.75.75 0 011.067.853A8.5 8.5 0 116.647 1.921a.75.75 0 01.808.083z" clipRule="evenodd" />
                  </svg>
                )}
              </button>
              <button
                onClick={() => setSettingsOpen(true)}
                className={`w-10 h-10 min-[600px]:w-8 min-[600px]:h-8 flex items-center justify-center rounded-lg transition-colors ${
                  darkMode
                    ? 'hover:bg-zinc-700 text-zinc-400 hover:text-zinc-200'
                    : 'hover:bg-zinc-200 text-zinc-400 hover:text-zinc-600'
                }`}
                title="Settings"
              >
                <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" className="w-5 h-5">
                  <path fillRule="evenodd" d="M11.078 2.25c-.917 0-1.699.663-1.85 1.567L9.05 4.889c-.02.12-.115.26-.297.348a7.493 7.493 0 00-.986.57c-.166.115-.334.126-.45.083L6.3 5.508a1.875 1.875 0 00-2.282.819l-.922 1.597a1.875 1.875 0 00.432 2.385l.84.692c.095.078.17.229.154.43a7.598 7.598 0 000 1.139c.015.2-.059.352-.153.43l-.841.692a1.875 1.875 0 00-.432 2.385l.922 1.597a1.875 1.875 0 002.282.818l1.019-.382c.115-.043.283-.031.45.082.312.214.641.405.985.57.182.088.277.228.297.35l.178 1.071c.151.904.933 1.567 1.85 1.567h1.844c.916 0 1.699-.663 1.85-1.567l.178-1.072c.02-.12.114-.26.297-.349.344-.165.673-.356.985-.57.167-.114.335-.125.45-.082l1.02.382a1.875 1.875 0 002.28-.819l.923-1.597a1.875 1.875 0 00-.432-2.385l-.84-.692c-.095-.078-.17-.229-.154-.43a7.614 7.614 0 000-1.139c-.016-.2.059-.352.153-.43l.84-.692c.708-.582.891-1.59.433-2.385l-.922-1.597a1.875 1.875 0 00-2.282-.818l-1.02.382c-.114.043-.282.031-.449-.083a7.49 7.49 0 00-.985-.57c-.183-.087-.277-.227-.297-.348l-.179-1.072a1.875 1.875 0 00-1.85-1.567h-1.843zM12 15.75a3.75 3.75 0 100-7.5 3.75 3.75 0 000 7.5z" clipRule="evenodd" />
                </svg>
              </button>
            </div>
          </div>
          {/* Main row - key selector + chord/note selection + icons (icons only at 800px+) */}
          <div className="flex items-center gap-3">
          {/* Key selector */}
          <div className="relative">
            <button
              onClick={() => setKeyDropdownOpen(!keyDropdownOpen)}
              className={`flex items-center gap-2 px-3 py-1.5 rounded-lg text-sm font-medium transition-colors ${
                darkMode ? 'hover:bg-zinc-700' : 'hover:bg-zinc-200'
              }`}
            >
              <span className={darkMode ? 'text-zinc-200' : 'text-zinc-700'}>
                {selectedKey ? getKeyName(selectedKey, noteLabelMode === 'sharpsOnly') : 'No key'}
              </span>
              {selectedKey && (
                <span className="text-xs text-zinc-500 hidden min-[600px]:inline">
                  {getNotesInKeyDisplay(selectedKey, noteLabelMode === 'sharpsOnly').join(' ')}
                </span>
              )}
              <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" className="w-4 h-4 text-zinc-500">
                <path fillRule="evenodd" d="M5.23 7.21a.75.75 0 011.06.02L10 11.168l3.71-3.938a.75.75 0 111.08 1.04l-4.25 4.5a.75.75 0 01-1.08 0l-4.25-4.5a.75.75 0 01.02-1.06z" clipRule="evenodd" />
              </svg>
            </button>
            {keyDropdownOpen && (
              <>
                <div
                  className="fixed inset-0 z-10"
                  onClick={() => setKeyDropdownOpen(false)}
                />
                <div className={`absolute left-0 top-full mt-1 z-20 rounded-lg shadow-lg max-h-80 overflow-y-auto w-48 ${
                  darkMode ? 'bg-zinc-800 border border-zinc-700' : 'bg-white border border-[#EDE9E9]'
                }`}>
                  <button
                    onClick={() => {
                      setSelectedKey(null);
                      setKeyDropdownOpen(false);
                    }}
                    className={`w-full text-left px-3 py-2 text-sm ${
                      darkMode
                        ? `hover:bg-zinc-700 ${selectedKey === null ? 'bg-zinc-700 font-medium' : ''}`
                        : `hover:bg-zinc-100 ${selectedKey === null ? 'bg-zinc-100 font-medium' : ''}`
                    }`}
                  >
                    No key
                  </button>
                  <div className={`border-t ${darkMode ? 'border-zinc-700' : 'border-[#EDE9E9]'}`} />
                  <div className="px-3 py-1 text-xs text-zinc-400 font-medium">Major</div>
                  {ALL_KEYS.filter(k => k.type === 'major').map(key => (
                    <button
                      key={key.root + key.type}
                      onClick={() => {
                        setSelectedKey(key);
                        setKeyDropdownOpen(false);
                      }}
                      className={`w-full text-left px-3 py-2 text-sm ${
                        darkMode
                          ? `hover:bg-zinc-700 ${selectedKey && selectedKey.root === key.root && selectedKey.type === key.type ? 'bg-zinc-700 font-medium' : ''}`
                          : `hover:bg-zinc-100 ${selectedKey && selectedKey.root === key.root && selectedKey.type === key.type ? 'bg-zinc-100 font-medium' : ''}`
                      }`}
                    >
                      {getKeyName(key, noteLabelMode === 'sharpsOnly')}
                    </button>
                  ))}
                  <div className={`border-t ${darkMode ? 'border-zinc-700' : 'border-[#EDE9E9]'}`} />
                  <div className="px-3 py-1 text-xs text-zinc-400 font-medium">Minor</div>
                  {ALL_KEYS.filter(k => k.type === 'minor').map(key => (
                    <button
                      key={key.root + key.type}
                      onClick={() => {
                        setSelectedKey(key);
                        setKeyDropdownOpen(false);
                      }}
                      className={`w-full text-left px-3 py-2 text-sm ${
                        darkMode
                          ? `hover:bg-zinc-700 ${selectedKey && selectedKey.root === key.root && selectedKey.type === key.type ? 'bg-zinc-700 font-medium' : ''}`
                          : `hover:bg-zinc-100 ${selectedKey && selectedKey.root === key.root && selectedKey.type === key.type ? 'bg-zinc-100 font-medium' : ''}`
                      }`}
                    >
                      {getKeyName(key, noteLabelMode === 'sharpsOnly')}
                    </button>
                  ))}
                </div>
              </>
            )}
          </div>
          <div className="flex-1" />
          {/* Chord/note selection */}
          {selectedNotes.length > 0 ? (
            <div className="flex items-center gap-2 min-[880px]:pr-2">
              {chordName && (
                <span className={`text-sm font-medium ${darkMode ? 'text-zinc-200' : 'text-zinc-700'}`}>
                  {chordName}
                </span>
              )}
              <div className="flex items-center gap-1">
                {/* Mobile (<600px): show first 4 notes */}
                {selectedNotes.slice(0, 4).map(({ note }) => {
                  const scaleDegree = getScaleDegree(note, selectedKey);
                  const scaleDegreeColor = getScaleDegreeColor(scaleDegree);
                  const outOfKeyColor = getOutOfKeyColor(note, selectedKey);
                  const chromaticColor = getChromaticNoteColor(note);
                  let chipStyle = '';
                  if (scaleDegreeColor) {
                    chipStyle = `${scaleDegreeColor.bg500} text-white`;
                  } else if (outOfKeyColor) {
                    chipStyle = `${outOfKeyColor.bg500} text-white`;
                  } else {
                    chipStyle = `${chromaticColor.bg500} text-white`;
                  }
                  return (
                    <span
                      key={note}
                      className={`min-[600px]:hidden px-2 py-0.5 rounded text-xs font-medium ${chipStyle}`}
                    >
                      {note.replace(/\d+$/, '')}
                    </span>
                  );
                })}
                {selectedNotes.length > 4 && (
                  <span className={`min-[600px]:hidden px-2 py-0.5 rounded text-xs font-medium ${darkMode ? 'bg-zinc-700 text-zinc-300' : 'bg-zinc-200 text-zinc-600'}`}>
                    +{selectedNotes.length - 4}
                  </span>
                )}
                {/* Desktop (600px+): show first 6 notes */}
                {selectedNotes.slice(0, 6).map(({ note }) => {
                  const scaleDegree = getScaleDegree(note, selectedKey);
                  const scaleDegreeColor = getScaleDegreeColor(scaleDegree);
                  const outOfKeyColor = getOutOfKeyColor(note, selectedKey);
                  const chromaticColor = getChromaticNoteColor(note);
                  let chipStyle = '';
                  if (scaleDegreeColor) {
                    chipStyle = `${scaleDegreeColor.bg500} text-white`;
                  } else if (outOfKeyColor) {
                    chipStyle = `${outOfKeyColor.bg500} text-white`;
                  } else {
                    chipStyle = `${chromaticColor.bg500} text-white`;
                  }
                  return (
                    <span
                      key={note}
                      className={`hidden min-[600px]:inline px-2 py-0.5 rounded text-xs font-medium ${chipStyle}`}
                    >
                      {note.replace(/\d+$/, '')}
                    </span>
                  );
                })}
                {selectedNotes.length > 6 && (
                  <span className={`hidden min-[600px]:inline px-2 py-0.5 rounded text-xs font-medium ${darkMode ? 'bg-zinc-700 text-zinc-300' : 'bg-zinc-200 text-zinc-600'}`}>
                    +{selectedNotes.length - 6}
                  </span>
                )}
              </div>
            </div>
          ) : null}
          {/* Desktop icon buttons - only at 800px+ */}
          <div className="hidden min-[880px]:flex items-center">
            <button
              onClick={handleClearAll}
              disabled={selectedNotes.length === 0}
              className={`w-8 h-8 flex items-center justify-center rounded-lg transition-colors ${
                selectedNotes.length > 0
                  ? darkMode
                    ? 'hover:bg-zinc-700 text-zinc-400 hover:text-zinc-200'
                    : 'hover:bg-zinc-200 text-zinc-400 hover:text-zinc-600'
                  : darkMode
                    ? 'text-zinc-600 cursor-not-allowed'
                    : 'text-zinc-300 cursor-not-allowed'
              }`}
              title="Clear all notes (Delete)"
            >
              <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" className="w-5 h-5">
                <path d="M6.28 5.22a.75.75 0 00-1.06 1.06L8.94 10l-3.72 3.72a.75.75 0 101.06 1.06L10 11.06l3.72 3.72a.75.75 0 101.06-1.06L11.06 10l3.72-3.72a.75.75 0 00-1.06-1.06L10 8.94 6.28 5.22z" />
              </svg>
            </button>
            <button
              onClick={handleUpdateChord}
              disabled={!activeChordId || selectedNotes.length === 0 || !chordName || !hasChangesFromSaved}
              className={`w-8 h-8 flex items-center justify-center rounded-lg transition-colors ${
                activeChordId && selectedNotes.length > 0 && chordName && hasChangesFromSaved
                  ? darkMode
                    ? 'hover:bg-zinc-700 text-zinc-400 hover:text-zinc-200'
                    : 'hover:bg-zinc-200 text-zinc-400 hover:text-zinc-600'
                  : darkMode
                    ? 'text-zinc-600 cursor-not-allowed'
                    : 'text-zinc-300 cursor-not-allowed'
              }`}
              title="Update existing chord (S)"
            >
              <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" className="w-5 h-5">
                <path fillRule="evenodd" d="M16.704 4.153a.75.75 0 01.143 1.052l-8 10.5a.75.75 0 01-1.127.075l-4.5-4.5a.75.75 0 011.06-1.06l3.894 3.893 7.48-9.817a.75.75 0 011.05-.143z" clipRule="evenodd" />
              </svg>
            </button>
            <button
              onClick={handleSaveChordAsNew}
              disabled={selectedNotes.length === 0 || !chordName}
              className={`w-8 h-8 flex items-center justify-center rounded-lg transition-colors ${
                selectedNotes.length > 0 && chordName
                  ? darkMode
                    ? 'hover:bg-zinc-700 text-zinc-400 hover:text-zinc-200'
                    : 'hover:bg-zinc-200 text-zinc-400 hover:text-zinc-600'
                  : darkMode
                    ? 'text-zinc-600 cursor-not-allowed'
                    : 'text-zinc-300 cursor-not-allowed'
              }`}
              title="Save as new chord (A)"
            >
              <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" className="w-5 h-5">
                <path d="M10.75 4.75a.75.75 0 00-1.5 0v4.5h-4.5a.75.75 0 000 1.5h4.5v4.5a.75.75 0 001.5 0v-4.5h4.5a.75.75 0 000-1.5h-4.5v-4.5z" />
              </svg>
            </button>
            <button
              onClick={() => handleTranspose(1)}
              disabled={selectedNotes.length === 0}
              className={`w-8 h-8 flex items-center justify-center rounded-lg transition-colors ${
                selectedNotes.length > 0
                  ? darkMode
                    ? 'hover:bg-zinc-700 text-zinc-400 hover:text-zinc-200'
                    : 'hover:bg-zinc-200 text-zinc-400 hover:text-zinc-600'
                  : darkMode
                    ? 'text-zinc-600 cursor-not-allowed'
                    : 'text-zinc-300 cursor-not-allowed'
              }`}
              title="Transpose up 1 semitone (+)"
            >
              <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" className="w-5 h-5">
                <path fillRule="evenodd" d="M10 17a.75.75 0 01-.75-.75V5.612L5.29 9.77a.75.75 0 01-1.08-1.04l5.25-5.5a.75.75 0 011.08 0l5.25 5.5a.75.75 0 11-1.08 1.04l-3.96-4.158V16.25A.75.75 0 0110 17z" clipRule="evenodd" />
              </svg>
            </button>
            <button
              onClick={() => handleTranspose(-1)}
              disabled={selectedNotes.length === 0}
              className={`w-8 h-8 flex items-center justify-center rounded-lg transition-colors ${
                selectedNotes.length > 0
                  ? darkMode
                    ? 'hover:bg-zinc-700 text-zinc-400 hover:text-zinc-200'
                    : 'hover:bg-zinc-200 text-zinc-400 hover:text-zinc-600'
                  : darkMode
                    ? 'text-zinc-600 cursor-not-allowed'
                    : 'text-zinc-300 cursor-not-allowed'
              }`}
              title="Transpose down 1 semitone (-)"
            >
              <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" className="w-5 h-5">
                <path fillRule="evenodd" d="M10 17a.75.75 0 01-.75-.75V5.612L5.29 9.77a.75.75 0 01-1.08-1.04l5.25-5.5a.75.75 0 011.08 0l5.25 5.5a.75.75 0 11-1.08 1.04l-3.96-4.158V16.25A.75.75 0 0110 17z" clipRule="evenodd" transform="rotate(180 10 10)" />
              </svg>
            </button>
            <button
              onClick={handlePlayAll}
              disabled={selectedNotes.length === 0}
              className={`w-8 h-8 flex items-center justify-center rounded-lg transition-colors ${
                selectedNotes.length > 0
                  ? darkMode
                    ? 'hover:bg-zinc-700 text-zinc-400 hover:text-zinc-200'
                    : 'hover:bg-zinc-200 text-zinc-400 hover:text-zinc-600'
                  : darkMode
                    ? 'text-zinc-600 cursor-not-allowed'
                    : 'text-zinc-300 cursor-not-allowed'
              }`}
              title="Play all selected notes (Enter)"
            >
              <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" className="w-5 h-5">
                <path fillRule="evenodd" d="M4.5 5.653c0-1.426 1.529-2.33 2.779-1.643l11.54 6.348c1.295.712 1.295 2.573 0 3.285L7.28 19.991c-1.25.687-2.779-.217-2.779-1.643V5.653z" clipRule="evenodd" />
              </svg>
            </button>
            <button
              onClick={handleLoopToggle}
              disabled={selectedNotes.length === 0 && savedChords.length === 0}
              className={`w-8 h-8 flex items-center justify-center rounded-lg transition-colors ${
                loopMode
                  ? 'bg-green-500 text-white hover:bg-green-600'
                  : (selectedNotes.length > 0 || savedChords.length > 0)
                    ? darkMode
                      ? 'hover:bg-zinc-700 text-zinc-400 hover:text-zinc-200'
                      : 'hover:bg-zinc-200 text-zinc-400 hover:text-zinc-600'
                    : darkMode
                      ? 'text-zinc-600 cursor-not-allowed'
                      : 'text-zinc-300 cursor-not-allowed'
              }`}
              title={loopMode ? 'Stop loop (Space)' : 'Loop playback (Space)'}
            >
              <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" className="w-5 h-5">
                <path fillRule="evenodd" d="M12 5.25c1.213 0 2.415.046 3.605.135a3.256 3.256 0 013.01 3.01c.044.583.077 1.17.1 1.759L17.03 8.47a.75.75 0 10-1.06 1.06l3 3a.75.75 0 001.06 0l3-3a.75.75 0 00-1.06-1.06l-1.752 1.751c-.023-.65-.06-1.296-.108-1.939a4.756 4.756 0 00-4.392-4.392 49.422 49.422 0 00-7.436 0A4.756 4.756 0 003.89 8.282c-.017.224-.033.447-.046.672a.75.75 0 101.497.092c.013-.217.028-.432.044-.647a3.256 3.256 0 013.01-3.01c1.19-.09 2.392-.136 3.605-.136zm-6.97 6.22a.75.75 0 00-1.06 0l-3 3a.75.75 0 101.06 1.06l1.752-1.751c.023.65.06 1.296.108 1.939a4.756 4.756 0 004.392 4.392 49.413 49.413 0 007.436 0 4.756 4.756 0 004.392-4.392c.017-.223.032-.447.046-.672a.75.75 0 00-1.497-.092c-.013.217-.028.434-.044.647a3.256 3.256 0 01-3.01 3.01 47.953 47.953 0 01-7.21 0 3.256 3.256 0 01-3.01-3.01 47.759 47.759 0 01-.1-1.759L6.97 12.53a.75.75 0 001.06-1.06l-3-3z" clipRule="evenodd" />
              </svg>
            </button>
            <button
              onClick={() => setDarkMode(!darkMode)}
              className={`w-8 h-8 flex items-center justify-center rounded-lg transition-colors ${
                darkMode
                  ? 'hover:bg-zinc-700 text-zinc-400 hover:text-zinc-200'
                  : 'hover:bg-zinc-200 text-zinc-400 hover:text-zinc-600'
              }`}
              title={darkMode ? 'Switch to light mode' : 'Switch to dark mode'}
            >
              {darkMode ? (
                <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" className="w-5 h-5">
                  <path d="M10 2a.75.75 0 01.75.75v1.5a.75.75 0 01-1.5 0v-1.5A.75.75 0 0110 2zM10 15a.75.75 0 01.75.75v1.5a.75.75 0 01-1.5 0v-1.5A.75.75 0 0110 15zM10 7a3 3 0 100 6 3 3 0 000-6zM15.657 5.404a.75.75 0 10-1.06-1.06l-1.061 1.06a.75.75 0 001.06 1.06l1.06-1.06zM6.464 14.596a.75.75 0 10-1.06-1.06l-1.06 1.06a.75.75 0 001.06 1.06l1.06-1.06zM18 10a.75.75 0 01-.75.75h-1.5a.75.75 0 010-1.5h1.5A.75.75 0 0118 10zM5 10a.75.75 0 01-.75.75h-1.5a.75.75 0 010-1.5h1.5A.75.75 0 015 10zM14.596 15.657a.75.75 0 001.06-1.06l-1.06-1.061a.75.75 0 10-1.06 1.06l1.06 1.06zM5.404 6.464a.75.75 0 001.06-1.06l-1.06-1.06a.75.75 0 10-1.06 1.06l1.06 1.06z" />
                </svg>
              ) : (
                <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" className="w-5 h-5">
                  <path fillRule="evenodd" d="M7.455 2.004a.75.75 0 01.26.77 7 7 0 009.958 7.967.75.75 0 011.067.853A8.5 8.5 0 116.647 1.921a.75.75 0 01.808.083z" clipRule="evenodd" />
                </svg>
              )}
            </button>
            <button
              onClick={() => setSettingsOpen(true)}
              className={`w-8 h-8 flex items-center justify-center rounded-lg transition-colors ${
                darkMode
                  ? 'hover:bg-zinc-700 text-zinc-400 hover:text-zinc-200'
                  : 'hover:bg-zinc-200 text-zinc-400 hover:text-zinc-600'
              }`}
              title="Settings"
            >
              <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" className="w-5 h-5">
                <path fillRule="evenodd" d="M11.078 2.25c-.917 0-1.699.663-1.85 1.567L9.05 4.889c-.02.12-.115.26-.297.348a7.493 7.493 0 00-.986.57c-.166.115-.334.126-.45.083L6.3 5.508a1.875 1.875 0 00-2.282.819l-.922 1.597a1.875 1.875 0 00.432 2.385l.84.692c.095.078.17.229.154.43a7.598 7.598 0 000 1.139c.015.2-.059.352-.153.43l-.841.692a1.875 1.875 0 00-.432 2.385l.922 1.597a1.875 1.875 0 002.282.818l1.019-.382c.115-.043.283-.031.45.082.312.214.641.405.985.57.182.088.277.228.297.35l.178 1.071c.151.904.933 1.567 1.85 1.567h1.844c.916 0 1.699-.663 1.85-1.567l.178-1.072c.02-.12.114-.26.297-.349.344-.165.673-.356.985-.57.167-.114.335-.125.45-.082l1.02.382a1.875 1.875 0 002.28-.819l.923-1.597a1.875 1.875 0 00-.432-2.385l-.84-.692c-.095-.078-.17-.229-.154-.43a7.614 7.614 0 000-1.139c-.016-.2.059-.352.153-.43l.84-.692c.708-.582.891-1.59.433-2.385l-.922-1.597a1.875 1.875 0 00-2.282-.818l-1.02.382c-.114.043-.282.031-.449-.083a7.49 7.49 0 00-.985-.57c-.183-.087-.277-.227-.297-.348l-.179-1.072a1.875 1.875 0 00-1.85-1.567h-1.843zM12 15.75a3.75 3.75 0 100-7.5 3.75 3.75 0 000 7.5z" clipRule="evenodd" />
              </svg>
            </button>
          </div>

          {/* Mobile menu - hidden since icons are now on first row */}
          <div className="relative hidden">
            <button
              onClick={() => setMobileMenuOpen(!mobileMenuOpen)}
              className={`w-8 h-8 flex items-center justify-center rounded-lg transition-colors ${
                darkMode
                  ? 'hover:bg-zinc-700 text-zinc-400 hover:text-zinc-200'
                  : 'hover:bg-zinc-200 text-zinc-400 hover:text-zinc-600'
              }`}
              title="Menu"
            >
              <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" className="w-5 h-5">
                <path d="M3 10a1.5 1.5 0 113 0 1.5 1.5 0 01-3 0zM8.5 10a1.5 1.5 0 113 0 1.5 1.5 0 01-3 0zM15.5 8.5a1.5 1.5 0 100 3 1.5 1.5 0 000-3z" />
              </svg>
            </button>
            {mobileMenuOpen && (
              <>
                <div
                  className="fixed inset-0 z-10"
                  onClick={() => setMobileMenuOpen(false)}
                />
                <div className={`absolute right-0 top-full mt-1 z-20 rounded-lg shadow-lg w-48 py-1 ${
                  darkMode ? 'bg-zinc-800 border border-zinc-700' : 'bg-white border border-[#EDE9E9]'
                }`}>
                  <button
                    onClick={() => {
                      handleClearAll();
                      setMobileMenuOpen(false);
                    }}
                    disabled={selectedNotes.length === 0}
                    className={`w-full text-left px-3 py-2 text-sm flex items-center gap-2 ${
                      selectedNotes.length > 0
                        ? darkMode
                          ? 'hover:bg-zinc-700 text-zinc-200'
                          : 'hover:bg-zinc-100 text-zinc-700'
                        : darkMode
                          ? 'text-zinc-600 cursor-not-allowed'
                          : 'text-zinc-300 cursor-not-allowed'
                    }`}
                  >
                    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" className="w-4 h-4">
                      <path d="M6.28 5.22a.75.75 0 00-1.06 1.06L8.94 10l-3.72 3.72a.75.75 0 101.06 1.06L10 11.06l3.72 3.72a.75.75 0 101.06-1.06L11.06 10l3.72-3.72a.75.75 0 00-1.06-1.06L10 8.94 6.28 5.22z" />
                    </svg>
                    Clear selection
                  </button>
                  <button
                    onClick={() => {
                      handleUpdateChord();
                      setMobileMenuOpen(false);
                    }}
                    disabled={!activeChordId || selectedNotes.length === 0 || !chordName || !hasChangesFromSaved}
                    className={`w-full text-left px-3 py-2 text-sm flex items-center gap-2 ${
                      activeChordId && selectedNotes.length > 0 && chordName && hasChangesFromSaved
                        ? darkMode
                          ? 'hover:bg-zinc-700 text-zinc-200'
                          : 'hover:bg-zinc-100 text-zinc-700'
                        : darkMode
                          ? 'text-zinc-600 cursor-not-allowed'
                          : 'text-zinc-300 cursor-not-allowed'
                    }`}
                  >
                    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" className="w-4 h-4">
                      <path fillRule="evenodd" d="M16.704 4.153a.75.75 0 01.143 1.052l-8 10.5a.75.75 0 01-1.127.075l-4.5-4.5a.75.75 0 011.06-1.06l3.894 3.893 7.48-9.817a.75.75 0 011.05-.143z" clipRule="evenodd" />
                    </svg>
                    Save chord
                  </button>
                  <button
                    onClick={() => {
                      handleSaveChordAsNew();
                      setMobileMenuOpen(false);
                    }}
                    disabled={selectedNotes.length === 0 || !chordName}
                    className={`w-full text-left px-3 py-2 text-sm flex items-center gap-2 ${
                      selectedNotes.length > 0 && chordName
                        ? darkMode
                          ? 'hover:bg-zinc-700 text-zinc-200'
                          : 'hover:bg-zinc-100 text-zinc-700'
                        : darkMode
                          ? 'text-zinc-600 cursor-not-allowed'
                          : 'text-zinc-300 cursor-not-allowed'
                    }`}
                  >
                    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" className="w-4 h-4">
                      <path d="M10.75 4.75a.75.75 0 00-1.5 0v4.5h-4.5a.75.75 0 000 1.5h4.5v4.5a.75.75 0 001.5 0v-4.5h4.5a.75.75 0 000-1.5h-4.5v-4.5z" />
                    </svg>
                    Save as new chord
                  </button>
                  <button
                    onClick={() => {
                      handleTranspose(1);
                      setMobileMenuOpen(false);
                    }}
                    disabled={selectedNotes.length === 0}
                    className={`w-full text-left px-3 py-2 text-sm flex items-center gap-2 ${
                      selectedNotes.length > 0
                        ? darkMode
                          ? 'hover:bg-zinc-700 text-zinc-200'
                          : 'hover:bg-zinc-100 text-zinc-700'
                        : darkMode
                          ? 'text-zinc-600 cursor-not-allowed'
                          : 'text-zinc-300 cursor-not-allowed'
                    }`}
                  >
                    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" className="w-4 h-4">
                      <path fillRule="evenodd" d="M10 17a.75.75 0 01-.75-.75V5.612L5.29 9.77a.75.75 0 01-1.08-1.04l5.25-5.5a.75.75 0 011.08 0l5.25 5.5a.75.75 0 11-1.08 1.04l-3.96-4.158V16.25A.75.75 0 0110 17z" clipRule="evenodd" />
                    </svg>
                    Transpose up
                  </button>
                  <button
                    onClick={() => {
                      handleTranspose(-1);
                      setMobileMenuOpen(false);
                    }}
                    disabled={selectedNotes.length === 0}
                    className={`w-full text-left px-3 py-2 text-sm flex items-center gap-2 ${
                      selectedNotes.length > 0
                        ? darkMode
                          ? 'hover:bg-zinc-700 text-zinc-200'
                          : 'hover:bg-zinc-100 text-zinc-700'
                        : darkMode
                          ? 'text-zinc-600 cursor-not-allowed'
                          : 'text-zinc-300 cursor-not-allowed'
                    }`}
                  >
                    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" className="w-4 h-4">
                      <path fillRule="evenodd" d="M10 17a.75.75 0 01-.75-.75V5.612L5.29 9.77a.75.75 0 01-1.08-1.04l5.25-5.5a.75.75 0 011.08 0l5.25 5.5a.75.75 0 11-1.08 1.04l-3.96-4.158V16.25A.75.75 0 0110 17z" clipRule="evenodd" transform="rotate(180 10 10)" />
                    </svg>
                    Transpose down
                  </button>
                  <button
                    onClick={() => {
                      handlePlayAll();
                      setMobileMenuOpen(false);
                    }}
                    disabled={selectedNotes.length === 0}
                    className={`w-full text-left px-3 py-2 text-sm flex items-center gap-2 ${
                      selectedNotes.length > 0
                        ? darkMode
                          ? 'hover:bg-zinc-700 text-zinc-200'
                          : 'hover:bg-zinc-100 text-zinc-700'
                        : darkMode
                          ? 'text-zinc-600 cursor-not-allowed'
                          : 'text-zinc-300 cursor-not-allowed'
                    }`}
                  >
                    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" className="w-4 h-4">
                      <path fillRule="evenodd" d="M4.5 5.653c0-1.426 1.529-2.33 2.779-1.643l11.54 6.348c1.295.712 1.295 2.573 0 3.285L7.28 19.991c-1.25.687-2.779-.217-2.779-1.643V5.653z" clipRule="evenodd" />
                    </svg>
                    Play chord
                  </button>
                  <div className={`border-t my-1 ${darkMode ? 'border-zinc-700' : 'border-[#EDE9E9]'}`} />
                  <button
                    onClick={() => {
                      setDarkMode(!darkMode);
                      setMobileMenuOpen(false);
                    }}
                    className={`w-full text-left px-3 py-2 text-sm flex items-center gap-2 ${
                      darkMode
                        ? 'hover:bg-zinc-700 text-zinc-200'
                        : 'hover:bg-zinc-100 text-zinc-700'
                    }`}
                  >
                    {darkMode ? (
                      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" className="w-4 h-4">
                        <path d="M10 2a.75.75 0 01.75.75v1.5a.75.75 0 01-1.5 0v-1.5A.75.75 0 0110 2zM10 15a.75.75 0 01.75.75v1.5a.75.75 0 01-1.5 0v-1.5A.75.75 0 0110 15zM10 7a3 3 0 100 6 3 3 0 000-6zM15.657 5.404a.75.75 0 10-1.06-1.06l-1.061 1.06a.75.75 0 001.06 1.06l1.06-1.06zM6.464 14.596a.75.75 0 10-1.06-1.06l-1.06 1.06a.75.75 0 001.06 1.06l1.06-1.06zM18 10a.75.75 0 01-.75.75h-1.5a.75.75 0 010-1.5h1.5A.75.75 0 0118 10zM5 10a.75.75 0 01-.75.75h-1.5a.75.75 0 010-1.5h1.5A.75.75 0 015 10zM14.596 15.657a.75.75 0 001.06-1.06l-1.06-1.061a.75.75 0 10-1.06 1.06l1.06 1.06zM5.404 6.464a.75.75 0 001.06-1.06l-1.06-1.06a.75.75 0 10-1.06 1.06l1.06 1.06z" />
                      </svg>
                    ) : (
                      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" className="w-4 h-4">
                        <path fillRule="evenodd" d="M7.455 2.004a.75.75 0 01.26.77 7 7 0 009.958 7.967.75.75 0 011.067.853A8.5 8.5 0 116.647 1.921a.75.75 0 01.808.083z" clipRule="evenodd" />
                      </svg>
                    )}
                    {darkMode ? 'Light mode' : 'Dark mode'}
                  </button>
                  <button
                    onClick={() => {
                      setSettingsOpen(true);
                      setMobileMenuOpen(false);
                    }}
                    className={`w-full text-left px-3 py-2 text-sm flex items-center gap-2 ${
                      darkMode
                        ? 'hover:bg-zinc-700 text-zinc-200'
                        : 'hover:bg-zinc-100 text-zinc-700'
                    }`}
                  >
                    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" className="w-4 h-4">
                      <path fillRule="evenodd" d="M11.078 2.25c-.917 0-1.699.663-1.85 1.567L9.05 4.889c-.02.12-.115.26-.297.348a7.493 7.493 0 00-.986.57c-.166.115-.334.126-.45.083L6.3 5.508a1.875 1.875 0 00-2.282.819l-.922 1.597a1.875 1.875 0 00.432 2.385l.84.692c.095.078.17.229.154.43a7.598 7.598 0 000 1.139c.015.2-.059.352-.153.43l-.841.692a1.875 1.875 0 00-.432 2.385l.922 1.597a1.875 1.875 0 002.282.818l1.019-.382c.115-.043.283-.031.45.082.312.214.641.405.985.57.182.088.277.228.297.35l.178 1.071c.151.904.933 1.567 1.85 1.567h1.844c.916 0 1.699-.663 1.85-1.567l.178-1.072c.02-.12.114-.26.297-.349.344-.165.673-.356.985-.57.167-.114.335-.125.45-.082l1.02.382a1.875 1.875 0 002.28-.819l.923-1.597a1.875 1.875 0 00-.432-2.385l-.84-.692c-.095-.078-.17-.229-.154-.43a7.614 7.614 0 000-1.139c-.016-.2.059-.352.153-.43l.84-.692c.708-.582.891-1.59.433-2.385l-.922-1.597a1.875 1.875 0 00-2.282-.818l-1.02.382c-.114.043-.282.031-.449-.083a7.49 7.49 0 00-.985-.57c-.183-.087-.277-.227-.297-.348l-.179-1.072a1.875 1.875 0 00-1.85-1.567h-1.843zM12 15.75a3.75 3.75 0 100-7.5 3.75 3.75 0 000 7.5z" clipRule="evenodd" />
                    </svg>
                    Settings
                  </button>
                </div>
              </>
            )}
          </div>
          </div>
        </header>

        <SavedChords
          chords={savedChords}
          activeChordId={activeChordId}
          onChordSelect={handleChordSelect}
          onChordDelete={handleChordDelete}
          onReorder={handleChordReorder}
          darkMode={darkMode}
        />

        {/* Chord limit warning */}
        {chordLimitWarning && (
          <div className={`rounded-lg p-3 flex items-center gap-2 ${
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
              className={`ml-auto p-1 rounded transition-colors ${
                darkMode ? 'hover:bg-amber-800' : 'hover:bg-amber-100'
              }`}
            >
              <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" className="w-4 h-4">
                <path d="M6.28 5.22a.75.75 0 00-1.06 1.06L8.94 10l-3.72 3.72a.75.75 0 101.06 1.06L10 11.06l3.72 3.72a.75.75 0 101.06-1.06L11.06 10l3.72-3.72a.75.75 0 00-1.06-1.06L10 8.94 6.28 5.22z" />
              </svg>
            </button>
          </div>
        )}

        {fretboards.length > 0 && (
          <div className="flex gap-[16px]">
            {fretboards.map((fretboard) => (
              <div key={fretboard.id} className="flex-1 min-w-0">
                <GuitarFretboard
                  tuning={fretboard.tuning}
                  capo={fretboard.capo}
                  selectedNotes={selectedNotes}
                  onNoteSelect={handleNoteSelect}
                  anyCapoActive={anyCapoActive}
                  selectedKey={selectedKey}
                  keyLabelMode={keyLabelMode}
                  noteLabelMode={noteLabelMode}
                  darkMode={darkMode}
                />
              </div>
            ))}
          </div>
        )}

        {showPiano && (
          <PianoKeyboard
            tuning={allTunings.length > 0 ? allTunings : TUNINGS.standard.notes}
            selectedNotes={selectedNotes}
            onNoteSelect={handleNoteSelect}
            selectedKey={selectedKey}
            keyLabelMode={keyLabelMode}
            noteLabelMode={noteLabelMode}
            darkMode={darkMode}
          />
        )}
      </div>

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
      />

      <WelcomeTutorial
        isOpen={tutorialOpen}
        onClose={() => setTutorialOpen(false)}
        darkMode={darkMode}
      />
    </div>
  );
}
