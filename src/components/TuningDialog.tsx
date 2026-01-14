'use client';

import { useState, useEffect } from 'react';
import { noteToMidi, midiToNote, TUNINGS } from '@/lib/notes';

interface TuningDialogProps {
  isOpen: boolean;
  tuning: string[];
  onClose: () => void;
  onSave: (tuning: string[]) => void;
}

export default function TuningDialog({ isOpen, tuning, onClose, onSave }: TuningDialogProps) {
  const [editedTuning, setEditedTuning] = useState<string[]>(tuning);

  useEffect(() => {
    setEditedTuning(tuning);
  }, [tuning, isOpen]);

  if (!isOpen) return null;

  const handleNoteChange = (stringIndex: number, value: string) => {
    const newTuning = [...editedTuning];
    newTuning[stringIndex] = value.toUpperCase();
    setEditedTuning(newTuning);
  };

  const handlePitchChange = (stringIndex: number, delta: number) => {
    const currentNote = editedTuning[stringIndex];
    try {
      const midi = noteToMidi(currentNote);
      const newMidi = midi + delta;
      if (newMidi >= 0 && newMidi <= 127) {
        const newTuning = [...editedTuning];
        newTuning[stringIndex] = midiToNote(newMidi);
        setEditedTuning(newTuning);
      }
    } catch {
      // Invalid note, ignore
    }
  };

  const handlePresetSelect = (presetKey: string) => {
    const preset = TUNINGS[presetKey];
    if (preset) {
      setEditedTuning([...preset.notes]);
    }
  };

  const handleSave = () => {
    onSave(editedTuning);
    onClose();
  };

  // String labels from high to low (display order)
  const stringLabels = ['1 (High E)', '2 (B)', '3 (G)', '4 (D)', '5 (A)', '6 (Low E)'];

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center">
      {/* Backdrop */}
      <div
        className="absolute inset-0 bg-black/50"
        onClick={onClose}
      />

      {/* Dialog */}
      <div className="relative bg-white rounded-lg shadow-xl p-6 w-full max-w-md mx-4">
        <h2 className="text-xl font-bold mb-4">Edit Tuning</h2>

        {/* Preset selector */}
        <div className="mb-4">
          <label className="block text-sm font-medium text-zinc-600 mb-2">
            Presets
          </label>
          <div className="flex flex-wrap gap-2">
            {Object.entries(TUNINGS).map(([key, preset]) => (
              <button
                key={key}
                onClick={() => handlePresetSelect(key)}
                className="px-3 py-1 text-sm bg-zinc-100 hover:bg-zinc-200 rounded transition-colors"
              >
                {preset.name.split(' ')[0]}
              </button>
            ))}
          </div>
        </div>

        {/* String editors */}
        <div className="space-y-3 mb-6">
          {editedTuning.slice().reverse().map((note, displayIndex) => {
            const stringIndex = editedTuning.length - 1 - displayIndex;
            return (
              <div key={stringIndex} className="flex items-center gap-3">
                <span className="w-24 text-sm text-zinc-500">
                  {stringLabels[displayIndex] || `String ${displayIndex + 1}`}
                </span>
                <button
                  onClick={() => handlePitchChange(stringIndex, -1)}
                  className="w-8 h-8 flex items-center justify-center bg-zinc-200 hover:bg-zinc-300 rounded transition-colors"
                >
                  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" className="w-4 h-4">
                    <path fillRule="evenodd" d="M4 10a.75.75 0 01.75-.75h10.5a.75.75 0 010 1.5H4.75A.75.75 0 014 10z" clipRule="evenodd" />
                  </svg>
                </button>
                <input
                  type="text"
                  value={note}
                  onChange={(e) => handleNoteChange(stringIndex, e.target.value)}
                  className="w-16 px-2 py-1 text-center font-mono border border-zinc-300 rounded focus:outline-none focus:ring-2 focus:ring-blue-500"
                />
                <button
                  onClick={() => handlePitchChange(stringIndex, 1)}
                  className="w-8 h-8 flex items-center justify-center bg-zinc-200 hover:bg-zinc-300 rounded transition-colors"
                >
                  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" className="w-4 h-4">
                    <path d="M10.75 4.75a.75.75 0 00-1.5 0v4.5h-4.5a.75.75 0 000 1.5h4.5v4.5a.75.75 0 001.5 0v-4.5h4.5a.75.75 0 000-1.5h-4.5v-4.5z" />
                  </svg>
                </button>
              </div>
            );
          })}
        </div>

        {/* Actions */}
        <div className="flex justify-end gap-3">
          <button
            onClick={onClose}
            className="px-4 py-2 text-sm text-zinc-600 hover:text-zinc-800 transition-colors"
          >
            Cancel
          </button>
          <button
            onClick={handleSave}
            className="px-4 py-2 text-sm bg-blue-600 hover:bg-blue-500 text-white rounded transition-colors"
          >
            Save
          </button>
        </div>
      </div>
    </div>
  );
}
