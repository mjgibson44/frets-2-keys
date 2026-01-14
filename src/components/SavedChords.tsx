'use client';

import { getColor } from '@/lib/colors';

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
  onPrevChord: () => void;
  onNextChord: () => void;
}

export default function SavedChords({
  chords,
  activeChordId,
  onChordSelect,
  onChordDelete,
  onPrevChord,
  onNextChord,
}: SavedChordsProps) {
  if (chords.length === 0) {
    return (
      <div className="border border-zinc-300 rounded bg-white p-4 text-center text-zinc-400">
        No saved chords yet. Select notes and click "Save Chord" to add one.
      </div>
    );
  }

  const activeIndex = chords.findIndex(c => c.id === activeChordId);

  return (
    <div className="border border-zinc-300 rounded bg-white p-4">
      <div className="flex items-center gap-4">
        {/* Navigation buttons */}
        <div className="flex items-center gap-2">
          <button
            onClick={onPrevChord}
            disabled={chords.length <= 1}
            className="w-8 h-8 flex items-center justify-center rounded bg-zinc-200 hover:bg-zinc-300 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
            title="Previous chord"
          >
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" className="w-4 h-4">
              <path fillRule="evenodd" d="M12.79 5.23a.75.75 0 01-.02 1.06L8.832 10l3.938 3.71a.75.75 0 11-1.04 1.08l-4.5-4.25a.75.75 0 010-1.08l4.5-4.25a.75.75 0 011.06.02z" clipRule="evenodd" />
            </svg>
          </button>
          <span className="text-sm text-zinc-500 min-w-[3rem] text-center">
            {activeIndex >= 0 ? `${activeIndex + 1}/${chords.length}` : `${chords.length}`}
          </span>
          <button
            onClick={onNextChord}
            disabled={chords.length <= 1}
            className="w-8 h-8 flex items-center justify-center rounded bg-zinc-200 hover:bg-zinc-300 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
            title="Next chord"
          >
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" className="w-4 h-4">
              <path fillRule="evenodd" d="M7.21 14.77a.75.75 0 01.02-1.06L11.168 10 7.23 6.29a.75.75 0 111.04-1.08l4.5 4.25a.75.75 0 010 1.08l-4.5 4.25a.75.75 0 01-1.06-.02z" clipRule="evenodd" />
            </svg>
          </button>
        </div>

        {/* Saved chords list */}
        <div className="flex-1 flex gap-2 overflow-x-auto">
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
                <span className="font-medium text-zinc-700 whitespace-nowrap">{chord.name}</span>
                <div className="flex gap-1">
                  {chord.notes.slice(0, 4).map(({ note, colorIndex }) => {
                    const color = getColor(colorIndex);
                    return (
                      <span
                        key={note}
                        className={`w-2 h-2 rounded-full ${color.bg}`}
                        title={note}
                      />
                    );
                  })}
                  {chord.notes.length > 4 && (
                    <span className="text-xs text-zinc-400">+{chord.notes.length - 4}</span>
                  )}
                </div>
                <button
                  onClick={(e) => {
                    e.stopPropagation();
                    onChordDelete(chord.id);
                  }}
                  className="ml-1 w-5 h-5 flex items-center justify-center rounded hover:bg-zinc-300 text-zinc-400 hover:text-zinc-600 transition-colors"
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
    </div>
  );
}
