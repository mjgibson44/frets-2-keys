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
}

export default function SavedChords({
  chords,
  activeChordId,
  onChordSelect,
  onChordDelete,
}: SavedChordsProps) {
  if (chords.length === 0) {
    return (
      <div className="border border-[#EDE9E9] rounded-[16px] bg-white p-4 text-center text-sm text-zinc-400">
        No saved chords yet. Select notes and click "Save Chord" to add one.
      </div>
    );
  }

  return (
    <div className="border border-[#EDE9E9] rounded-[16px] bg-white p-4">
      <div className="flex gap-2 flex-wrap">
        {chords.map((chord) => {
          const isActive = chord.id === activeChordId;
          return (
            <div
              key={chord.id}
              className={`
                flex items-center gap-2 px-3 py-2 rounded cursor-pointer transition-colors
                ${isActive
                  ? 'bg-zinc-200 ring-1 ring-inset ring-zinc-400'
                  : 'bg-zinc-100 hover:bg-zinc-200'
                }
              `}
              onClick={() => onChordSelect(chord)}
            >
              <span className="text-sm font-medium text-zinc-700 whitespace-nowrap">{chord.name}</span>
              <button
                onClick={(e) => {
                  e.stopPropagation();
                  onChordDelete(chord.id);
                }}
                className="w-5 h-5 flex items-center justify-center rounded hover:bg-zinc-300 text-zinc-400 hover:text-zinc-600 transition-colors"
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
