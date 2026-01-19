'use client';

import { getNoteAtFret, MusicalKey, isNoteInKey } from '@/lib/notes';
import { SelectedNote, getColor } from '@/lib/colors';

interface GuitarFretboardProps {
  tuning: string[];
  capo: number;
  selectedNotes: SelectedNote[];
  onNoteSelect: (note: string) => void;
  anyCapoActive?: boolean;
  selectedKey: MusicalKey | null;
  keyLabelMode: 'onlyInKey' | 'showAll';
  darkMode?: boolean;
}

const SINGLE_MARKERS = [3, 5, 7, 9, 15, 17, 19, 21];
const DOUBLE_MARKERS = [12, 24];
const NUM_FRETS = 24;

export default function GuitarFretboard({ tuning, capo, selectedNotes, onNoteSelect, anyCapoActive, selectedKey, keyLabelMode, darkMode = false }: GuitarFretboardProps) {
  const strings = [...tuning].reverse();

  const getSelectedNote = (note: string): SelectedNote | undefined => {
    return selectedNotes.find(sn => sn.note === note);
  };

  return (
    <div className={`rounded-lg pt-4 px-4 pb-[10px] min-[600px]:pt-[24px] min-[600px]:px-[24px] min-[600px]:pb-[18px] ${
      darkMode
        ? 'bg-zinc-800 border border-zinc-700'
        : 'bg-white border border-[#EDE9E9]'
    }`}>
      <div className="overflow-x-auto scrollbar-hide">
        <div className="inline-block rounded-[12px] overflow-hidden">
          {/* Fretboard */}
          <div>
            {/* Strings */}
            {strings.map((openNote, stringIndex) => (
              <div key={stringIndex} className="flex">
                {/* Frets */}
                {Array.from({ length: NUM_FRETS + 1 }, (_, fret) => {
                  const note = getNoteAtFret(openNote, fret);
                  const selected = getSelectedNote(note);
                  const isBelowCapo = fret < capo;
                  const isCapoFret = fret === capo;
                  const color = selected && !isBelowCapo ? getColor(selected.colorIndex) : null;
                  const inKey = isNoteInKey(note, selectedKey);

                  return (
                    <button
                      key={fret}
                      onClick={() => !isBelowCapo && onNoteSelect(note)}
                      disabled={isBelowCapo}
                      className={`
                        w-14 h-8 min-[600px]:h-10 flex-shrink-0 flex items-center
                        text-xs transition-colors
                        ${isCapoFret
                          ? 'border-r-4 border-r-amber-500'
                          : darkMode
                            ? 'border-r border-r-zinc-700'
                            : 'border-r border-r-[#F2F2F2]'
                        }
                        ${isBelowCapo
                          ? 'cursor-not-allowed'
                          : ''
                        }
                      `}
                    >
                      {isBelowCapo ? (
                        <div className="flex-1" />
                      ) : keyLabelMode === 'onlyInKey' && !inKey && !color ? (
                        /* Note not in key, not selected, and mode is onlyInKey - just show the string line */
                        <div className={`flex-1 h-0.5 ${darkMode ? 'bg-zinc-600' : 'bg-[#E1E1E1]'}`} />
                      ) : (
                        <>
                          {/* Left string line */}
                          <div className={`flex-1 h-0.5 ${darkMode ? 'bg-zinc-600' : 'bg-[#E1E1E1]'}`} />
                          {/* Note indicator */}
                          <div
                            className={`
                              w-7 h-7 flex items-center justify-center rounded
                              ${color
                                ? `${color.bg} ${color.text} font-medium`
                                : darkMode
                                  ? 'text-zinc-300 hover:bg-zinc-700'
                                  : 'text-zinc-700 hover:bg-zinc-100'
                              }
                              ${keyLabelMode === 'showAll' && !inKey && !color ? 'opacity-30' : ''}
                            `}
                          >
                            {note.replace(/\d+$/, '')}
                          </div>
                          {/* Right string line */}
                          <div className={`flex-1 h-0.5 ${darkMode ? 'bg-zinc-600' : 'bg-[#E1E1E1]'}`} />
                        </>
                      )}
                    </button>
                  );
                })}
              </div>
            ))}
          </div>

          {/* Fret numbers */}
          <div className={`flex ${darkMode ? 'bg-zinc-700' : 'bg-[#F6F6F6]'}`}>
            {Array.from({ length: NUM_FRETS + 1 }, (_, fret) => {
              const isCapoFret = fret === capo;
              return (
                <div
                  key={fret}
                  className={`w-14 flex-shrink-0 flex items-center justify-center py-1
                    ${isCapoFret
                      ? 'border-r-4 border-r-amber-500'
                      : darkMode
                        ? 'border-r border-r-zinc-600'
                        : 'border-r border-r-[#F2F2F2]'
                    }
                  `}
                >
                  <span className={`text-xs ${darkMode ? 'text-zinc-400' : 'text-zinc-500'}`}>
                    {fret === 0 ? '' : fret}
                  </span>
                </div>
              );
            })}
          </div>

          {/* Dot markers */}
          <div className={`flex ${darkMode ? 'bg-zinc-700' : 'bg-[#F6F6F6]'}`}>
            {Array.from({ length: NUM_FRETS + 1 }, (_, fret) => {
              const isCapoFret = fret === capo;
              return (
                <div
                  key={fret}
                  className={`w-14 flex-shrink-0 flex items-center justify-center py-1
                    ${isCapoFret
                      ? 'border-r-4 border-r-amber-500'
                      : darkMode
                        ? 'border-r border-r-zinc-600'
                        : 'border-r border-r-[#F2F2F2]'
                    }
                  `}
                >
                  {SINGLE_MARKERS.includes(fret) && (
                    <div className={`w-1.5 h-1.5 rounded-full ${darkMode ? 'bg-zinc-500' : 'bg-zinc-400'}`} />
                  )}
                  {DOUBLE_MARKERS.includes(fret) && (
                    <div className="flex gap-1">
                      <div className={`w-1.5 h-1.5 rounded-full ${darkMode ? 'bg-zinc-500' : 'bg-zinc-400'}`} />
                      <div className={`w-1.5 h-1.5 rounded-full ${darkMode ? 'bg-zinc-500' : 'bg-zinc-400'}`} />
                    </div>
                  )}
                </div>
              );
            })}
          </div>

          {/* Capo-relative fret numbers (second row when capo active, spacer when another fretboard has capo) */}
          {(capo > 0 || anyCapoActive) && (
            <div className={`flex ${darkMode ? 'bg-zinc-700' : 'bg-[#F6F6F6]'}`}>
              {capo > 0 ? (
                Array.from({ length: NUM_FRETS + 1 }, (_, fret) => {
                  const capoRelative = fret - capo;
                  const isCapoFret = fret === capo;
                  return (
                    <div
                      key={fret}
                      className={`w-14 flex-shrink-0 flex items-center justify-center py-1
                        ${isCapoFret
                          ? 'border-r-4 border-r-amber-500'
                          : darkMode
                            ? 'border-r border-r-zinc-600'
                            : 'border-r border-r-[#F2F2F2]'
                        }
                      `}
                    >
                      <span className="text-xs text-amber-600 font-medium">
                        {fret >= capo ? capoRelative : ''}
                      </span>
                    </div>
                  );
                })
              ) : (
                Array.from({ length: NUM_FRETS + 1 }, (_, fret) => {
                  const isCapoFret = fret === capo;
                  return (
                    <div
                      key={fret}
                      className={`w-14 flex-shrink-0 flex items-center justify-center py-1
                        ${isCapoFret
                          ? 'border-r-4 border-r-amber-500'
                          : darkMode
                            ? 'border-r border-r-zinc-600'
                            : 'border-r border-r-[#F2F2F2]'
                        }
                      `}
                    >
                      <span className="text-xs">&nbsp;</span>
                    </div>
                  );
                })
              )}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
