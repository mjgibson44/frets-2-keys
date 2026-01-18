'use client';

import { useState } from 'react';
import GuitarFretboard from '@/components/GuitarFretboard';
import PianoKeyboard from '@/components/PianoKeyboard';
import SettingsDialog from '@/components/SettingsDialog';
import SavedChords, { SavedChord } from '@/components/SavedChords';
import { TUNINGS, MusicalKey, ALL_KEYS, getKeyName, getNotesInKey, noteToMidi, midiToNote } from '@/lib/notes';
import { playNote, playChord, playArpeggio } from '@/lib/audio';
import { SelectedNote, getColor } from '@/lib/colors';
import { identifyChord } from '@/lib/chords';

interface Fretboard {
  id: string;
  tuning: string[];
  capo: number;
}

export default function Home() {
  const [selectedNotes, setSelectedNotes] = useState<SelectedNote[]>([]);
  const [nextColorIndex, setNextColorIndex] = useState(0);
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

  const chordName = identifyChord(selectedNotes.map(sn => sn.note));

  // Check if the current selection differs from the active saved chord
  const activeChord = savedChords.find(c => c.id === activeChordId);
  const hasChangesFromSaved = activeChord ? (
    selectedNotes.length !== activeChord.notes.length ||
    selectedNotes.some((sn, i) => sn.note !== activeChord.notes[i]?.note)
  ) : false;

  const handleNoteSelect = (note: string) => {
    const existingIndex = selectedNotes.findIndex(sn => sn.note === note);

    if (existingIndex !== -1) {
      setSelectedNotes(prev => prev.filter((_, i) => i !== existingIndex));
    } else {
      playNote(note);
      setSelectedNotes(prev => [...prev, { note, colorIndex: nextColorIndex }]);
      setNextColorIndex(prev => prev + 1);
    }
  };

  const handleClearAll = () => {
    setSelectedNotes([]);
    setNextColorIndex(0);
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

  const handleSaveChordAsNew = () => {
    if (selectedNotes.length === 0 || !chordName) return;

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
    // Set next color index to continue from where this chord left off
    const maxColorIndex = Math.max(...chord.notes.map(n => n.colorIndex));
    setNextColorIndex(maxColorIndex + 1);
  };

  const handleChordDelete = (id: string) => {
    setSavedChords(prev => prev.filter(c => c.id !== id));
    if (activeChordId === id) {
      setActiveChordId(null);
    }
  };

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
    <div className="min-h-screen bg-[#F8F4F4] text-zinc-900 p-8">
      <div className="max-w-7xl mx-auto space-y-[16px]">
        {/* Controls bar */}
        <header className="flex items-center gap-3 flex-wrap">
          <button
            onClick={handlePlayAll}
            disabled={selectedNotes.length === 0}
            className={`w-8 h-8 flex items-center justify-center rounded-lg transition-colors ${
              selectedNotes.length > 0
                ? 'hover:bg-zinc-200 text-zinc-400 hover:text-zinc-600'
                : 'text-zinc-300 cursor-not-allowed'
            }`}
            title="Play all selected notes"
          >
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" className="w-4 h-4">
              <path d="M8 5v14l11-7z" />
            </svg>
          </button>
          {selectedNotes.length > 0 ? (
            <div className="flex items-center gap-2">
              {chordName && (
                <span className="text-sm font-semibold text-zinc-600">
                  {chordName}
                </span>
              )}
              {selectedNotes.map(({ note, colorIndex }) => {
                const color = getColor(colorIndex);
                return (
                  <span
                    key={note}
                    className={`px-2 py-0.5 rounded-full text-xs font-bold ${color.bg} ${color.text}`}
                  >
                    {note.replace(/\d+$/, '')}
                  </span>
                );
              })}
              <button
                onClick={() => handleTranspose(-1)}
                className="w-8 h-8 flex items-center justify-center rounded-lg hover:bg-zinc-200 text-zinc-400 hover:text-zinc-600 transition-colors"
                title="Transpose down 1 semitone"
              >
                <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" className="w-4 h-4">
                  <path fillRule="evenodd" d="M4 10a.75.75 0 01.75-.75h10.5a.75.75 0 010 1.5H4.75A.75.75 0 014 10z" clipRule="evenodd" />
                </svg>
              </button>
              <button
                onClick={() => handleTranspose(1)}
                className="w-8 h-8 flex items-center justify-center rounded-lg hover:bg-zinc-200 text-zinc-400 hover:text-zinc-600 transition-colors"
                title="Transpose up 1 semitone"
              >
                <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" className="w-4 h-4">
                  <path d="M10.75 4.75a.75.75 0 00-1.5 0v4.5h-4.5a.75.75 0 000 1.5h4.5v4.5a.75.75 0 001.5 0v-4.5h4.5a.75.75 0 000-1.5h-4.5v-4.5z" />
                </svg>
              </button>
              <button
                onClick={handleClearAll}
                className="w-8 h-8 flex items-center justify-center rounded-lg hover:bg-zinc-200 text-zinc-400 hover:text-zinc-600 transition-colors"
                title="Clear all notes"
              >
                <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" className="w-4 h-4">
                  <path d="M6.28 5.22a.75.75 0 00-1.06 1.06L8.94 10l-3.72 3.72a.75.75 0 101.06 1.06L10 11.06l3.72 3.72a.75.75 0 101.06-1.06L11.06 10l3.72-3.72a.75.75 0 00-1.06-1.06L10 8.94 6.28 5.22z" />
                </svg>
              </button>
            </div>
          ) : (
            <span className="text-sm text-zinc-400">No notes selected</span>
          )}
          {activeChordId ? (
            <>
              <button
                onClick={handleUpdateChord}
                disabled={selectedNotes.length === 0 || !chordName || !hasChangesFromSaved}
                className={`w-8 h-8 flex items-center justify-center rounded-lg transition-colors ${
                  selectedNotes.length > 0 && chordName && hasChangesFromSaved
                    ? 'hover:bg-zinc-200 text-zinc-400 hover:text-zinc-600'
                    : 'text-zinc-300 cursor-not-allowed'
                }`}
                title="Update existing chord"
              >
                <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" className="w-4 h-4">
                  <path fillRule="evenodd" d="M16.704 4.153a.75.75 0 01.143 1.052l-8 10.5a.75.75 0 01-1.127.075l-4.5-4.5a.75.75 0 011.06-1.06l3.894 3.893 7.48-9.817a.75.75 0 011.05-.143z" clipRule="evenodd" />
                </svg>
              </button>
              <button
                onClick={handleSaveChordAsNew}
                disabled={selectedNotes.length === 0 || !chordName}
                className={`w-8 h-8 flex items-center justify-center rounded-lg transition-colors ${
                  selectedNotes.length > 0 && chordName
                    ? 'hover:bg-zinc-200 text-zinc-400 hover:text-zinc-600'
                    : 'text-zinc-300 cursor-not-allowed'
                }`}
                title="Save as new chord"
              >
                <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" className="w-4 h-4">
                  <path d="M10.75 4.75a.75.75 0 00-1.5 0v4.5h-4.5a.75.75 0 000 1.5h4.5v4.5a.75.75 0 001.5 0v-4.5h4.5a.75.75 0 000-1.5h-4.5v-4.5z" />
                </svg>
              </button>
            </>
          ) : (
            <button
              onClick={handleSaveChordAsNew}
              disabled={selectedNotes.length === 0 || !chordName}
              className={`w-8 h-8 flex items-center justify-center rounded-lg transition-colors ${
                selectedNotes.length > 0 && chordName
                  ? 'hover:bg-zinc-200 text-zinc-400 hover:text-zinc-600'
                  : 'text-zinc-300 cursor-not-allowed'
              }`}
              title="Save this chord"
            >
              <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" className="w-4 h-4">
                <path d="M10.75 4.75a.75.75 0 00-1.5 0v4.5h-4.5a.75.75 0 000 1.5h4.5v4.5a.75.75 0 001.5 0v-4.5h4.5a.75.75 0 000-1.5h-4.5v-4.5z" />
              </svg>
            </button>
          )}
          <div className="flex-1" />
          {/* Key selector */}
          <div className="relative">
            <button
              onClick={() => setKeyDropdownOpen(!keyDropdownOpen)}
              className="flex items-center gap-2 px-3 py-1.5 rounded-lg text-sm font-medium bg-zinc-100 hover:bg-zinc-200 transition-colors"
            >
              <span className="text-zinc-700">
                {selectedKey ? getKeyName(selectedKey) : 'No key selected'}
              </span>
              {selectedKey && (
                <span className="text-xs text-zinc-500">
                  {getNotesInKey(selectedKey).join(' ')}
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
                <div className="absolute right-0 top-full mt-1 z-20 bg-white border border-[#EDE9E9] rounded-lg shadow-lg max-h-80 overflow-y-auto w-48">
                  <button
                    onClick={() => {
                      setSelectedKey(null);
                      setKeyDropdownOpen(false);
                    }}
                    className={`w-full text-left px-3 py-2 text-sm hover:bg-zinc-100 ${
                      selectedKey === null ? 'bg-zinc-100 font-medium' : ''
                    }`}
                  >
                    No key
                  </button>
                  <div className="border-t border-[#EDE9E9]" />
                  <div className="px-3 py-1 text-xs text-zinc-400 font-medium">Major</div>
                  {ALL_KEYS.filter(k => k.type === 'major').map(key => (
                    <button
                      key={getKeyName(key)}
                      onClick={() => {
                        setSelectedKey(key);
                        setKeyDropdownOpen(false);
                      }}
                      className={`w-full text-left px-3 py-2 text-sm hover:bg-zinc-100 ${
                        selectedKey && selectedKey.root === key.root && selectedKey.type === key.type
                          ? 'bg-zinc-100 font-medium'
                          : ''
                      }`}
                    >
                      {getKeyName(key)}
                    </button>
                  ))}
                  <div className="border-t border-[#EDE9E9]" />
                  <div className="px-3 py-1 text-xs text-zinc-400 font-medium">Minor</div>
                  {ALL_KEYS.filter(k => k.type === 'minor').map(key => (
                    <button
                      key={getKeyName(key)}
                      onClick={() => {
                        setSelectedKey(key);
                        setKeyDropdownOpen(false);
                      }}
                      className={`w-full text-left px-3 py-2 text-sm hover:bg-zinc-100 ${
                        selectedKey && selectedKey.root === key.root && selectedKey.type === key.type
                          ? 'bg-zinc-100 font-medium'
                          : ''
                      }`}
                    >
                      {getKeyName(key)}
                    </button>
                  ))}
                </div>
              </>
            )}
          </div>
          <button
            onClick={() => setSettingsOpen(true)}
            className="w-8 h-8 flex items-center justify-center rounded-lg hover:bg-zinc-200 text-zinc-500 hover:text-zinc-700 transition-colors"
            title="Settings"
          >
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" className="w-5 h-5">
              <path fillRule="evenodd" d="M11.078 2.25c-.917 0-1.699.663-1.85 1.567L9.05 4.889c-.02.12-.115.26-.297.348a7.493 7.493 0 00-.986.57c-.166.115-.334.126-.45.083L6.3 5.508a1.875 1.875 0 00-2.282.819l-.922 1.597a1.875 1.875 0 00.432 2.385l.84.692c.095.078.17.229.154.43a7.598 7.598 0 000 1.139c.015.2-.059.352-.153.43l-.841.692a1.875 1.875 0 00-.432 2.385l.922 1.597a1.875 1.875 0 002.282.818l1.019-.382c.115-.043.283-.031.45.082.312.214.641.405.985.57.182.088.277.228.297.35l.178 1.071c.151.904.933 1.567 1.85 1.567h1.844c.916 0 1.699-.663 1.85-1.567l.178-1.072c.02-.12.114-.26.297-.349.344-.165.673-.356.985-.57.167-.114.335-.125.45-.082l1.02.382a1.875 1.875 0 002.28-.819l.923-1.597a1.875 1.875 0 00-.432-2.385l-.84-.692c-.095-.078-.17-.229-.154-.43a7.614 7.614 0 000-1.139c-.016-.2.059-.352.153-.43l.84-.692c.708-.582.891-1.59.433-2.385l-.922-1.597a1.875 1.875 0 00-2.282-.818l-1.02.382c-.114.043-.282.031-.449-.083a7.49 7.49 0 00-.985-.57c-.183-.087-.277-.227-.297-.348l-.179-1.072a1.875 1.875 0 00-1.85-1.567h-1.843zM12 15.75a3.75 3.75 0 100-7.5 3.75 3.75 0 000 7.5z" clipRule="evenodd" />
            </svg>
          </button>
        </header>

        <SavedChords
          chords={savedChords}
          activeChordId={activeChordId}
          onChordSelect={handleChordSelect}
          onChordDelete={handleChordDelete}
        />

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
        hasKeySelected={selectedKey !== null}
        onClose={() => setSettingsOpen(false)}
        onFretboardCountChange={handleFretboardCountChange}
        onShowPianoChange={setShowPiano}
        onPlayModeChange={setPlayMode}
        onKeyLabelModeChange={setKeyLabelMode}
        onTuningChange={handleTuningChange}
        onCapoChange={handleCapoChange}
      />
    </div>
  );
}
