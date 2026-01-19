'use client';

export interface SavedChord {
  id: string;
  name: string;
  notes: { note: string; colorIndex: number }[];
}

interface SavedChordsProps {
  chords: SavedChord[];
  activeChordId: string | null;
  onChordSelect: (chord: SavedChord) => void;
  onChordDelete: (id: string) => void;
  darkMode?: boolean;
}

export default function SavedChords({
  chords,
  activeChordId,
  onChordSelect,
  onChordDelete,
  darkMode = false,
}: SavedChordsProps) {
  if (chords.length === 0) {
    return (
      <div className={`rounded-lg p-4 text-center text-sm ${
        darkMode
          ? 'bg-zinc-800 border border-zinc-700 text-zinc-500'
          : 'bg-white border border-[#EDE9E9] text-zinc-400'
      }`}>
        No saved chords
      </div>
    );
  }

  return (
    <div className={`rounded-lg p-4 ${
      darkMode
        ? 'bg-zinc-800 border border-zinc-700'
        : 'bg-white border border-[#EDE9E9]'
    }`}>
      <div className="flex gap-2 flex-wrap">
        {chords.map((chord) => {
          const isActive = chord.id === activeChordId;
          return (
            <div
              key={chord.id}
              className={`
                flex items-center gap-2 px-3 py-2 rounded cursor-pointer transition-colors
                ${isActive
                  ? darkMode
                    ? 'bg-zinc-600 ring-1 ring-inset ring-zinc-500'
                    : 'bg-zinc-200 ring-1 ring-inset ring-zinc-400'
                  : darkMode
                    ? 'bg-zinc-700 hover:bg-zinc-600'
                    : 'bg-zinc-100 hover:bg-zinc-200'
                }
              `}
              onClick={() => onChordSelect(chord)}
            >
              <span className={`text-sm font-medium whitespace-nowrap ${darkMode ? 'text-zinc-200' : 'text-zinc-700'}`}>{chord.name}</span>
              <button
                onClick={(e) => {
                  e.stopPropagation();
                  onChordDelete(chord.id);
                }}
                className={`w-5 h-5 flex items-center justify-center rounded transition-colors ${
                  darkMode
                    ? 'hover:bg-zinc-500 text-zinc-400 hover:text-zinc-200'
                    : 'hover:bg-zinc-300 text-zinc-400 hover:text-zinc-600'
                }`}
                title="Delete chord"
              >
                <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" className="w-3 h-3">
                  <path d="M6.28 5.22a.75.75 0 00-1.06 1.06L8.94 10l-3.72 3.72a.75.75 0 101.06 1.06L10 11.06l3.72 3.72a.75.75 0 101.06-1.06L11.06 10l3.72-3.72a.75.75 0 00-1.06-1.06L10 8.94 6.28 5.22z" />
                </svg>
              </button>
            </div>
          );
        })}
      </div>
    </div>
  );
}
