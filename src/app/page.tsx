'use client';

import { useState } from 'react';
import GuitarFretboard from '@/components/GuitarFretboard';
import PianoKeyboard from '@/components/PianoKeyboard';
import TuningDialog from '@/components/TuningDialog';
import SavedChords, { SavedChord } from '@/components/SavedChords';
import { TUNINGS } from '@/lib/notes';
import { playNote, playChord, playArpeggio } from '@/lib/audio';
import { SelectedNote, getColor } from '@/lib/colors';
import { identifyChord } from '@/lib/chords';

interface Fretboard {
  id: string;
  tuning: string[];
}

export default function Home() {
  const [selectedNotes, setSelectedNotes] = useState<SelectedNote[]>([]);
  const [nextColorIndex, setNextColorIndex] = useState(0);
  const [fretboards, setFretboards] = useState<Fretboard[]>([
    { id: '1', tuning: TUNINGS.standard.notes }
  ]);
  const [editingFretboardId, setEditingFretboardId] = useState<string | null>(null);
  const [playMode, setPlayMode] = useState<'chord' | 'arpeggio'>('chord');
  const [savedChords, setSavedChords] = useState<SavedChord[]>([]);
  const [activeChordId, setActiveChordId] = useState<string | null>(null);

  const chordName = identifyChord(selectedNotes.map(sn => sn.note));

  const handleNoteSelect = (note: string) => {
    // Clear active chord when manually selecting notes
    setActiveChordId(null);

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

  const handlePlayAll = () => {
    const notes = selectedNotes.map(sn => sn.note);
    if (playMode === 'chord') {
      playChord(notes);
    } else {
      playArpeggio(notes);
    }
  };

  const handleSaveChord = () => {
    if (selectedNotes.length === 0 || !chordName) return;

    const newChord: SavedChord = {
      id: Date.now().toString(),
      name: chordName,
      notes: [...selectedNotes],
    };

    setSavedChords(prev => [...prev, newChord]);
    setActiveChordId(newChord.id);
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

  const handlePrevChord = () => {
    if (savedChords.length <= 1) return;
    const currentIndex = savedChords.findIndex(c => c.id === activeChordId);
    const prevIndex = currentIndex <= 0 ? savedChords.length - 1 : currentIndex - 1;
    handleChordSelect(savedChords[prevIndex]);
  };

  const handleNextChord = () => {
    if (savedChords.length <= 1) return;
    const currentIndex = savedChords.findIndex(c => c.id === activeChordId);
    const nextIndex = currentIndex >= savedChords.length - 1 ? 0 : currentIndex + 1;
    handleChordSelect(savedChords[nextIndex]);
  };

  const handleTuningSave = (newTuning: string[]) => {
    if (!editingFretboardId) return;
    setFretboards(prev => prev.map(fb =>
      fb.id === editingFretboardId ? { ...fb, tuning: newTuning } : fb
    ));
  };

  const handleAddFretboard = () => {
    const newFretboard: Fretboard = {
      id: Date.now().toString(),
      tuning: TUNINGS.standard.notes,
    };
    setFretboards(prev => [...prev, newFretboard]);
  };

  const handleDeleteFretboard = (id: string) => {
    if (fretboards.length <= 1) return;
    setFretboards(prev => prev.filter(fb => fb.id !== id));
  };

  // Get all tunings for piano keyboard range calculation
  const allTunings = fretboards.flatMap(fb => fb.tuning);
  const editingFretboard = fretboards.find(fb => fb.id === editingFretboardId);

  return (
    <div className="min-h-screen bg-zinc-100 text-zinc-900 p-8">
      <div className="max-w-7xl mx-auto space-y-8">
        <header className="space-y-2">
          <h1 className="text-3xl font-bold">Frets 2 Keys</h1>
          <p className="text-zinc-500">
            Click notes to select multiple. Each note gets a unique color.
          </p>
        </header>

        <SavedChords
          chords={savedChords}
          activeChordId={activeChordId}
          onChordSelect={handleChordSelect}
          onChordDelete={handleChordDelete}
          onPrevChord={handlePrevChord}
          onNextChord={handleNextChord}
        />

        {/* Controls bar */}
        <div className="flex items-center gap-3 flex-wrap">
          <button
            onClick={handlePlayAll}
            disabled={selectedNotes.length === 0}
            className={`w-8 h-8 flex items-center justify-center rounded-full transition-colors ${
              selectedNotes.length > 0
                ? 'bg-green-600 hover:bg-green-500 text-white'
                : 'bg-zinc-200 text-zinc-400 cursor-not-allowed'
            }`}
            title="Play all selected notes"
          >
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" className="w-4 h-4">
              <path d="M8 5v14l11-7z" />
            </svg>
          </button>
          <button
            onClick={() => setPlayMode(prev => prev === 'chord' ? 'arpeggio' : 'chord')}
            disabled={selectedNotes.length === 0}
            className={`px-3 py-1.5 rounded-full text-xs font-medium transition-colors ${
              selectedNotes.length === 0
                ? 'bg-zinc-200 text-zinc-400 cursor-not-allowed'
                : playMode === 'chord'
                  ? 'bg-zinc-300 text-zinc-700'
                  : 'bg-purple-200 text-purple-800'
            }`}
            title={`Switch to ${playMode === 'chord' ? 'arpeggio' : 'chord'} mode`}
          >
            {playMode === 'chord' ? 'Chord' : 'Arpeggio'}
          </button>
          <div className="w-px h-6 bg-zinc-300" />
          {selectedNotes.length > 0 ? (
            <>
              {chordName && (
                <div className="flex items-center gap-1">
                  <span className="text-sm font-semibold text-amber-600">
                    {chordName}
                  </span>
                  <button
                    onClick={handleClearAll}
                    className="w-5 h-5 flex items-center justify-center rounded-full hover:bg-zinc-300 text-zinc-400 hover:text-zinc-600 transition-colors"
                    title="Clear all notes"
                  >
                    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" className="w-3.5 h-3.5">
                      <path d="M6.28 5.22a.75.75 0 00-1.06 1.06L8.94 10l-3.72 3.72a.75.75 0 101.06 1.06L10 11.06l3.72 3.72a.75.75 0 101.06-1.06L11.06 10l3.72-3.72a.75.75 0 00-1.06-1.06L10 8.94 6.28 5.22z" />
                    </svg>
                  </button>
                </div>
              )}
              <div className="w-px h-6 bg-zinc-300" />
              <div className="flex gap-2">
                {selectedNotes.map(({ note, colorIndex }) => {
                  const color = getColor(colorIndex);
                  return (
                    <span
                      key={note}
                      className={`px-2 py-0.5 rounded-full text-xs font-mono font-bold ${color.bg} ${color.text}`}
                    >
                      {note}
                    </span>
                  );
                })}
              </div>
            </>
          ) : (
            <span className="text-sm text-zinc-400">No notes selected</span>
          )}
          <div className="w-px h-6 bg-zinc-300" />
          <button
            onClick={handleSaveChord}
            disabled={selectedNotes.length === 0 || !chordName}
            className={`px-3 py-1.5 rounded-full text-xs font-medium transition-colors ${
              selectedNotes.length > 0 && chordName
                ? 'bg-amber-500 hover:bg-amber-400 text-white'
                : 'bg-zinc-200 text-zinc-400 cursor-not-allowed'
            }`}
            title="Save this chord"
          >
            Save
          </button>
          <div className="w-px h-6 bg-zinc-300" />
          <button
            onClick={handleAddFretboard}
            className="w-8 h-8 flex items-center justify-center bg-zinc-200 hover:bg-zinc-300 text-zinc-600 rounded-full transition-colors"
            title="Add another fretboard"
          >
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" className="w-4 h-4">
              <path d="M10.75 4.75a.75.75 0 00-1.5 0v4.5h-4.5a.75.75 0 000 1.5h4.5v4.5a.75.75 0 001.5 0v-4.5h4.5a.75.75 0 000-1.5h-4.5v-4.5z" />
            </svg>
          </button>
        </div>

        <div className="flex gap-4">
          {fretboards.map((fretboard) => (
            <div key={fretboard.id} className="flex-1 min-w-0">
              <GuitarFretboard
                tuning={fretboard.tuning}
                selectedNotes={selectedNotes}
                onNoteSelect={handleNoteSelect}
                onEditTuning={() => setEditingFretboardId(fretboard.id)}
                onDelete={fretboards.length > 1 ? () => handleDeleteFretboard(fretboard.id) : undefined}
              />
            </div>
          ))}
        </div>

        <PianoKeyboard
          tuning={allTunings}
          selectedNotes={selectedNotes}
          onNoteSelect={handleNoteSelect}
        />
      </div>

      <TuningDialog
        isOpen={editingFretboardId !== null}
        tuning={editingFretboard?.tuning ?? TUNINGS.standard.notes}
        onClose={() => setEditingFretboardId(null)}
        onSave={handleTuningSave}
      />
    </div>
  );
}
