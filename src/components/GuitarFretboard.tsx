'use client';

import { getNoteAtFret } from '@/lib/notes';
import { SelectedNote, getColor } from '@/lib/colors';

interface GuitarFretboardProps {
  tuning: string[];
  capo: number;
  selectedNotes: SelectedNote[];
  onNoteSelect: (note: string) => void;
  onEditTuning: () => void;
  onDelete?: () => void;
}

const SINGLE_MARKERS = [3, 5, 7, 9, 15, 17, 19, 21];
const DOUBLE_MARKERS = [12, 24];
const NUM_FRETS = 24;

export default function GuitarFretboard({ tuning, capo, selectedNotes, onNoteSelect, onEditTuning, onDelete }: GuitarFretboardProps) {
  const strings = [...tuning].reverse();

  const getSelectedNote = (note: string): SelectedNote | undefined => {
    return selectedNotes.find(sn => sn.note === note);
  };

  // Format tuning display (e.g., "E A D G B E")
  const tuningDisplay = tuning.map(note => note.replace(/\d+$/, '')).join(' ');

  return (
    <div className="border border-zinc-300 rounded bg-white p-4">
      {/* Tuning header */}
      <div className="flex items-center gap-2 mb-3">
        <span className="text-sm text-zinc-500">Tuning:</span>
        <span className="font-mono text-sm text-zinc-700">{tuningDisplay}</span>
        {capo > 0 && (
          <span className="px-2 py-0.5 text-xs font-medium bg-amber-100 text-amber-700 rounded">
            Capo {capo}
          </span>
        )}
        <button
          onClick={onEditTuning}
          className="p-1.5 rounded hover:bg-zinc-100 text-zinc-400 hover:text-zinc-600 transition-colors"
          title="Edit tuning"
        >
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" className="w-4 h-4">
            <path d="M2.695 14.763l-1.262 3.154a.5.5 0 00.65.65l3.155-1.262a4 4 0 001.343-.885L17.5 5.5a2.121 2.121 0 00-3-3L3.58 13.42a4 4 0 00-.885 1.343z" />
          </svg>
        </button>
        {onDelete && (
          <button
            onClick={onDelete}
            className="p-1.5 rounded hover:bg-zinc-100 text-zinc-400 hover:text-red-500 transition-colors ml-auto"
            title="Delete fretboard"
          >
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" className="w-4 h-4">
              <path fillRule="evenodd" d="M8.75 1A2.75 2.75 0 006 3.75v.443c-.795.077-1.584.176-2.365.298a.75.75 0 10.23 1.482l.149-.022.841 10.518A2.75 2.75 0 007.596 19h4.807a2.75 2.75 0 002.742-2.53l.841-10.519.149.023a.75.75 0 00.23-1.482A41.03 41.03 0 0014 4.193V3.75A2.75 2.75 0 0011.25 1h-2.5zM10 4c.84 0 1.673.025 2.5.075V3.75c0-.69-.56-1.25-1.25-1.25h-2.5c-.69 0-1.25.56-1.25 1.25v.325C8.327 4.025 9.16 4 10 4zM8.58 7.72a.75.75 0 00-1.5.06l.3 7.5a.75.75 0 101.5-.06l-.3-7.5zm4.34.06a.75.75 0 10-1.5-.06l-.3 7.5a.75.75 0 101.5.06l.3-7.5z" clipRule="evenodd" />
            </svg>
          </button>
        )}
      </div>

      <div className="overflow-x-auto scrollbar-hide">
        <div className="inline-block min-w-full">
          {/* Fretboard */}
          <div className="border border-zinc-300 rounded">
            {/* Strings */}
            {strings.map((openNote, stringIndex) => (
              <div key={stringIndex} className="flex border-b border-zinc-300 last:border-b-0">
                {/* Frets */}
                {Array.from({ length: NUM_FRETS + 1 }, (_, fret) => {
                  const note = getNoteAtFret(openNote, fret);
                  const selected = getSelectedNote(note);
                  const isOpen = fret === 0;
                  const isBelowCapo = fret < capo;
                  const isCapoFret = fret === capo;
                  const color = selected && !isBelowCapo ? getColor(selected.colorIndex) : null;

                  return (
                    <button
                      key={fret}
                      onClick={() => !isBelowCapo && onNoteSelect(note)}
                      disabled={isBelowCapo}
                      className={`
                        w-14 h-10 flex-shrink-0 flex items-center justify-center
                        text-xs font-mono transition-colors
                        ${isOpen
                          ? 'border-r-4 border-r-zinc-400'
                          : isCapoFret
                            ? 'border-r-4 border-r-amber-500'
                            : 'border-r border-r-zinc-300'
                        }
                        ${isBelowCapo
                          ? 'bg-zinc-200 text-zinc-400 cursor-not-allowed'
                          : color
                            ? `${color.bg} ${color.text} ring-1 ring-inset ${color.ring} font-medium`
                            : 'bg-transparent text-zinc-700 hover:bg-zinc-100'
                        }
                      `}
                    >
                      {isBelowCapo ? '' : note.replace(/\d+$/, '')}
                    </button>
                  );
                })}
              </div>
            ))}
          </div>

          {/* Capo-relative fret numbers (first row when capo active, spacer when not) */}
          <div className="flex mt-2">
            {capo > 0 ? (
              Array.from({ length: NUM_FRETS + 1 }, (_, fret) => {
                const capoRelative = fret - capo;
                return (
                  <div
                    key={fret}
                    className="w-14 flex-shrink-0 flex items-center justify-center"
                  >
                    <span className="text-xs text-amber-600 font-mono font-medium">
                      {fret >= capo ? capoRelative : ''}
                    </span>
                  </div>
                );
              })
            ) : (
              <div className="w-14 flex-shrink-0 flex items-center justify-center">
                <span className="text-xs font-mono">&nbsp;</span>
              </div>
            )}
          </div>

          {/* Fret numbers with dot markers */}
          <div className="flex mt-1">
            {Array.from({ length: NUM_FRETS + 1 }, (_, fret) => (
              <div
                key={fret}
                className="w-14 flex-shrink-0 flex items-center justify-center gap-1"
              >
                <span className="text-xs text-zinc-500 font-mono">
                  {fret === 0 ? '' : fret}
                </span>
                {SINGLE_MARKERS.includes(fret) && (
                  <div className="w-1.5 h-1.5 rounded-full bg-zinc-400" />
                )}
                {DOUBLE_MARKERS.includes(fret) && (
                  <div className="flex flex-col gap-0.5">
                    <div className="w-1.5 h-1.5 rounded-full bg-zinc-400" />
                    <div className="w-1.5 h-1.5 rounded-full bg-zinc-400" />
                  </div>
                )}
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
