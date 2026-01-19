'use client';

import { noteToMidi, midiToNote, TUNINGS } from '@/lib/notes';

interface Fretboard {
  id: string;
  tuning: string[];
  capo: number;
}

interface SettingsDialogProps {
  isOpen: boolean;
  fretboards: Fretboard[];
  fretboardCount: number;
  showPiano: boolean;
  playMode: 'chord' | 'arpeggio';
  keyLabelMode: 'onlyInKey' | 'showAll';
  hasKeySelected: boolean;
  darkMode?: boolean;
  onClose: () => void;
  onFretboardCountChange: (count: number) => void;
  onShowPianoChange: (show: boolean) => void;
  onPlayModeChange: (mode: 'chord' | 'arpeggio') => void;
  onKeyLabelModeChange: (mode: 'onlyInKey' | 'showAll') => void;
  onTuningChange: (fretboardId: string, tuning: string[]) => void;
  onCapoChange: (fretboardId: string, capo: number) => void;
}

export default function SettingsDialog({
  isOpen,
  fretboards,
  fretboardCount,
  showPiano,
  playMode,
  keyLabelMode,
  hasKeySelected,
  darkMode = false,
  onClose,
  onFretboardCountChange,
  onShowPianoChange,
  onPlayModeChange,
  onKeyLabelModeChange,
  onTuningChange,
  onCapoChange,
}: SettingsDialogProps) {
  if (!isOpen) return null;

  const handlePitchChange = (fretboardId: string, tuning: string[], stringIndex: number, delta: number) => {
    const currentNote = tuning[stringIndex];
    try {
      const midi = noteToMidi(currentNote);
      const newMidi = midi + delta;
      if (newMidi >= 0 && newMidi <= 127) {
        const newTuning = [...tuning];
        newTuning[stringIndex] = midiToNote(newMidi);
        onTuningChange(fretboardId, newTuning);
      }
    } catch {
      // Invalid note, ignore
    }
  };

  const handleNoteChange = (fretboardId: string, tuning: string[], stringIndex: number, value: string) => {
    const newTuning = [...tuning];
    newTuning[stringIndex] = value.toUpperCase();
    onTuningChange(fretboardId, newTuning);
  };

  const handleCapoInputChange = (fretboardId: string, value: string) => {
    const num = parseInt(value, 10);
    if (value === '' || (num >= 0 && num <= 12)) {
      onCapoChange(fretboardId, value === '' ? 0 : num);
    }
  };

  const stringLabels = ['1 (High E)', '2 (B)', '3 (G)', '4 (D)', '5 (A)', '6 (Low E)'];

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center">
      {/* Backdrop */}
      <div
        className="absolute inset-0 bg-black/50"
        onClick={onClose}
      />

      {/* Dialog */}
      <div className={`relative rounded-[16px] shadow-xl p-6 w-full max-w-2xl mx-4 max-h-[90vh] overflow-y-auto ${
        darkMode ? 'bg-zinc-800 text-zinc-100' : 'bg-white text-zinc-900'
      }`}>
        <div className="flex items-center justify-between mb-6">
          <h2 className="text-xl font-bold">Settings</h2>
          <button
            onClick={onClose}
            className={`p-1.5 rounded transition-colors ${
              darkMode
                ? 'hover:bg-zinc-700 text-zinc-400 hover:text-zinc-200'
                : 'hover:bg-zinc-100 text-zinc-400 hover:text-zinc-600'
            }`}
          >
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" className="w-5 h-5">
              <path d="M6.28 5.22a.75.75 0 00-1.06 1.06L8.94 10l-3.72 3.72a.75.75 0 101.06 1.06L10 11.06l3.72 3.72a.75.75 0 101.06-1.06L11.06 10l3.72-3.72a.75.75 0 00-1.06-1.06L10 8.94 6.28 5.22z" />
            </svg>
          </button>
        </div>

        {/* Play mode toggle */}
        <div className="mb-6">
          <label className={`block text-sm font-medium mb-3 ${darkMode ? 'text-zinc-300' : 'text-zinc-600'}`}>
            Playback Mode
          </label>
          <div className="grid grid-cols-2 gap-2">
            <button
              onClick={() => onPlayModeChange('chord')}
              className={`py-2 px-4 rounded-lg text-sm font-medium transition-colors ${
                playMode === 'chord'
                  ? darkMode
                    ? 'bg-zinc-600 text-white'
                    : 'bg-zinc-800 text-white'
                  : darkMode
                    ? 'bg-zinc-700 text-zinc-300 hover:bg-zinc-600'
                    : 'bg-zinc-100 text-zinc-600 hover:bg-zinc-200'
              }`}
            >
              Chord
            </button>
            <button
              onClick={() => onPlayModeChange('arpeggio')}
              className={`py-2 px-4 rounded-lg text-sm font-medium transition-colors ${
                playMode === 'arpeggio'
                  ? darkMode
                    ? 'bg-zinc-600 text-white'
                    : 'bg-zinc-800 text-white'
                  : darkMode
                    ? 'bg-zinc-700 text-zinc-300 hover:bg-zinc-600'
                    : 'bg-zinc-100 text-zinc-600 hover:bg-zinc-200'
              }`}
            >
              Arpeggio
            </button>
          </div>
        </div>

        {/* Key Labels */}
        <div className={`mb-6 ${!hasKeySelected ? 'opacity-40 pointer-events-none' : ''}`}>
          <label className={`block text-sm font-medium mb-3 ${darkMode ? 'text-zinc-300' : 'text-zinc-600'}`}>
            Key Labels
          </label>
          <div className="grid grid-cols-2 gap-2">
            <button
              onClick={() => onKeyLabelModeChange('onlyInKey')}
              className={`py-2 px-4 rounded-lg text-sm font-medium transition-colors ${
                keyLabelMode === 'onlyInKey'
                  ? darkMode
                    ? 'bg-zinc-600 text-white'
                    : 'bg-zinc-800 text-white'
                  : darkMode
                    ? 'bg-zinc-700 text-zinc-300 hover:bg-zinc-600'
                    : 'bg-zinc-100 text-zinc-600 hover:bg-zinc-200'
              }`}
            >
              Only show notes in key
            </button>
            <button
              onClick={() => onKeyLabelModeChange('showAll')}
              className={`py-2 px-4 rounded-lg text-sm font-medium transition-colors ${
                keyLabelMode === 'showAll'
                  ? darkMode
                    ? 'bg-zinc-600 text-white'
                    : 'bg-zinc-800 text-white'
                  : darkMode
                    ? 'bg-zinc-700 text-zinc-300 hover:bg-zinc-600'
                    : 'bg-zinc-100 text-zinc-600 hover:bg-zinc-200'
              }`}
            >
              Show all notes
            </button>
          </div>
        </div>

        {/* Instruments */}
        <div className="mb-6">
          <label className={`block text-sm font-medium mb-3 ${darkMode ? 'text-zinc-300' : 'text-zinc-600'}`}>
            Instruments
          </label>
          <div className="flex gap-2">
            <button
              onClick={() => onFretboardCountChange(fretboardCount >= 1 ? 0 : 1)}
              className={`flex-1 flex items-center justify-between py-2 px-3 rounded-lg text-sm font-medium transition-colors ${
                darkMode ? 'bg-zinc-700 hover:bg-zinc-600' : 'bg-zinc-100 hover:bg-zinc-200'
              }`}
            >
              <span className={darkMode ? 'text-zinc-200' : 'text-zinc-700'}>Guitar 1</span>
              <div className={`w-10 h-6 rounded-full p-1 transition-colors ${fretboardCount >= 1 ? (darkMode ? 'bg-zinc-500' : 'bg-zinc-800') : (darkMode ? 'bg-zinc-600' : 'bg-zinc-300')}`}>
                <div className={`w-4 h-4 rounded-full bg-white transition-transform ${fretboardCount >= 1 ? 'translate-x-4' : 'translate-x-0'}`} />
              </div>
            </button>
            <button
              onClick={() => onFretboardCountChange(fretboardCount === 2 ? 1 : 2)}
              className={`flex-1 flex items-center justify-between py-2 px-3 rounded-lg text-sm font-medium transition-colors ${
                darkMode ? 'bg-zinc-700 hover:bg-zinc-600' : 'bg-zinc-100 hover:bg-zinc-200'
              }`}
            >
              <span className={darkMode ? 'text-zinc-200' : 'text-zinc-700'}>Guitar 2</span>
              <div className={`w-10 h-6 rounded-full p-1 transition-colors ${fretboardCount === 2 ? (darkMode ? 'bg-zinc-500' : 'bg-zinc-800') : (darkMode ? 'bg-zinc-600' : 'bg-zinc-300')}`}>
                <div className={`w-4 h-4 rounded-full bg-white transition-transform ${fretboardCount === 2 ? 'translate-x-4' : 'translate-x-0'}`} />
              </div>
            </button>
            <button
              onClick={() => onShowPianoChange(!showPiano)}
              className={`flex-1 flex items-center justify-between py-2 px-3 rounded-lg text-sm font-medium transition-colors ${
                darkMode ? 'bg-zinc-700 hover:bg-zinc-600' : 'bg-zinc-100 hover:bg-zinc-200'
              }`}
            >
              <span className={darkMode ? 'text-zinc-200' : 'text-zinc-700'}>Piano</span>
              <div className={`w-10 h-6 rounded-full p-1 transition-colors ${showPiano ? (darkMode ? 'bg-zinc-500' : 'bg-zinc-800') : (darkMode ? 'bg-zinc-600' : 'bg-zinc-300')}`}>
                <div className={`w-4 h-4 rounded-full bg-white transition-transform ${showPiano ? 'translate-x-4' : 'translate-x-0'}`} />
              </div>
            </button>
          </div>
        </div>

        {/* Tuning controls for each fretboard */}
        <div className="grid grid-cols-1 min-[600px]:grid-cols-2 gap-6">
        {[0, 1].map((index) => {
          const fretboard = fretboards[index];
          const isEnabled = index === 0 ? fretboardCount >= 1 : fretboardCount === 2;
          const tuning = fretboard?.tuning ?? TUNINGS.standard.notes;
          const capo = fretboard?.capo ?? 0;

          return (
            <div key={index} className={isEnabled ? '' : 'opacity-40 pointer-events-none'}>
              <label className={`block text-sm font-medium mb-3 ${darkMode ? 'text-zinc-300' : 'text-zinc-600'}`}>
                Guitar {index + 1} Tuning
              </label>

              {/* String editors */}
              <div className="space-y-2 mb-4">
                {tuning.slice().reverse().map((note, displayIndex) => {
                  const stringIndex = tuning.length - 1 - displayIndex;
                  return (
                    <div key={stringIndex} className="flex items-center gap-2">
                      <span className={`w-20 text-xs ${darkMode ? 'text-zinc-400' : 'text-zinc-500'}`}>
                        {stringLabels[displayIndex] || `String ${displayIndex + 1}`}
                      </span>
                      <button
                        onClick={() => fretboard && handlePitchChange(fretboard.id, fretboard.tuning, stringIndex, -1)}
                        disabled={!isEnabled}
                        className={`w-7 h-7 flex items-center justify-center disabled:cursor-not-allowed rounded transition-colors ${
                          darkMode ? 'bg-zinc-600 hover:bg-zinc-500' : 'bg-zinc-200 hover:bg-zinc-300'
                        }`}
                      >
                        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" className="w-3 h-3">
                          <path fillRule="evenodd" d="M4 10a.75.75 0 01.75-.75h10.5a.75.75 0 010 1.5H4.75A.75.75 0 014 10z" clipRule="evenodd" />
                        </svg>
                      </button>
                      <input
                        type="text"
                        value={note}
                        onChange={(e) => fretboard && handleNoteChange(fretboard.id, fretboard.tuning, stringIndex, e.target.value)}
                        disabled={!isEnabled}
                        className={`w-14 px-2 py-1 text-center text-sm rounded focus:outline-none focus:ring-2 focus:ring-blue-500 disabled:cursor-not-allowed ${
                          darkMode ? 'bg-zinc-700 border border-zinc-600 text-zinc-100' : 'bg-white border border-[#EDE9E9] text-zinc-900'
                        }`}
                      />
                      <button
                        onClick={() => fretboard && handlePitchChange(fretboard.id, fretboard.tuning, stringIndex, 1)}
                        disabled={!isEnabled}
                        className={`w-7 h-7 flex items-center justify-center disabled:cursor-not-allowed rounded transition-colors ${
                          darkMode ? 'bg-zinc-600 hover:bg-zinc-500' : 'bg-zinc-200 hover:bg-zinc-300'
                        }`}
                      >
                        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" className="w-3 h-3">
                          <path d="M10.75 4.75a.75.75 0 00-1.5 0v4.5h-4.5a.75.75 0 000 1.5h4.5v4.5a.75.75 0 001.5 0v-4.5h4.5a.75.75 0 000-1.5h-4.5v-4.5z" />
                        </svg>
                      </button>
                    </div>
                  );
                })}
              </div>

              {/* Capo selector */}
              <div className="flex items-center gap-2">
                <span className={`w-20 text-xs ${darkMode ? 'text-zinc-400' : 'text-zinc-500'}`}>Capo</span>
                <button
                  onClick={() => fretboard && onCapoChange(fretboard.id, Math.max(0, fretboard.capo - 1))}
                  disabled={!isEnabled || capo === 0}
                  className={`w-7 h-7 flex items-center justify-center disabled:opacity-50 disabled:cursor-not-allowed rounded transition-colors ${
                    darkMode ? 'bg-zinc-600 hover:bg-zinc-500' : 'bg-zinc-200 hover:bg-zinc-300'
                  }`}
                >
                  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" className="w-3 h-3">
                    <path fillRule="evenodd" d="M4 10a.75.75 0 01.75-.75h10.5a.75.75 0 010 1.5H4.75A.75.75 0 014 10z" clipRule="evenodd" />
                  </svg>
                </button>
                <input
                  type="text"
                  value={capo}
                  onChange={(e) => fretboard && handleCapoInputChange(fretboard.id, e.target.value)}
                  disabled={!isEnabled}
                  className={`w-14 px-2 py-1 text-center text-sm rounded focus:outline-none focus:ring-2 focus:ring-blue-500 disabled:cursor-not-allowed ${
                    darkMode ? 'bg-zinc-700 border border-zinc-600 text-zinc-100' : 'bg-white border border-[#EDE9E9] text-zinc-900'
                  }`}
                />
                <button
                  onClick={() => fretboard && onCapoChange(fretboard.id, Math.min(12, fretboard.capo + 1))}
                  disabled={!isEnabled || capo === 12}
                  className={`w-7 h-7 flex items-center justify-center disabled:opacity-50 disabled:cursor-not-allowed rounded transition-colors ${
                    darkMode ? 'bg-zinc-600 hover:bg-zinc-500' : 'bg-zinc-200 hover:bg-zinc-300'
                  }`}
                >
                  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" className="w-3 h-3">
                    <path d="M10.75 4.75a.75.75 0 00-1.5 0v4.5h-4.5a.75.75 0 000 1.5h4.5v4.5a.75.75 0 001.5 0v-4.5h4.5a.75.75 0 000-1.5h-4.5v-4.5z" />
                  </svg>
                </button>
                {capo > 0 && isEnabled && (
                  <button
                    onClick={() => fretboard && onCapoChange(fretboard.id, 0)}
                    className={`w-7 h-7 flex items-center justify-center rounded transition-colors ${
                      darkMode ? 'bg-zinc-600 hover:bg-zinc-500 text-zinc-400 hover:text-zinc-200' : 'bg-zinc-200 hover:bg-zinc-300 text-zinc-500 hover:text-zinc-700'
                    }`}
                    title="Clear capo"
                  >
                    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" className="w-3 h-3">
                      <path d="M6.28 5.22a.75.75 0 00-1.06 1.06L8.94 10l-3.72 3.72a.75.75 0 101.06 1.06L10 11.06l3.72 3.72a.75.75 0 101.06-1.06L11.06 10l3.72-3.72a.75.75 0 00-1.06-1.06L10 8.94 6.28 5.22z" />
                    </svg>
                  </button>
                )}
              </div>
            </div>
          );
        })}
        </div>
      </div>
    </div>
  );
}
