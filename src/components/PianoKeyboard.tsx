'use client';

import { generatePianoRange, isBlackKey, noteToMidi, midiToNote, MusicalKey, isNoteInKey, getNoteDisplayName, getScaleDegree, getScaleDegreeColor, getOutOfKeyColor, getChromaticNoteColor, parseNoteDisplay } from '@/lib/notes';
import { SelectedNote } from '@/lib/colors';

interface PianoKeyboardProps {
  tuning: string[];
  selectedNotes: SelectedNote[];
  onNoteSelect: (note: string) => void;
  selectedKey: MusicalKey | null;
  keyLabelMode: 'onlyInKey' | 'showAll';
  noteLabelMode: 'sharpsAndFlats' | 'sharpsOnly';
  darkMode?: boolean;
}

const END_NOTE = 'E6';
const WHITE_KEY_WIDTH = 40;
const BLACK_KEY_WIDTH = 32;

// Black keys that follow each white key (null means no black key after)
const BLACK_KEY_AFTER: Record<string, string | null> = {
  'C': 'C#',
  'D': 'D#',
  'E': null,
  'F': 'F#',
  'G': 'G#',
  'A': 'A#',
  'B': null,
};

export default function PianoKeyboard({ tuning, selectedNotes, onNoteSelect, selectedKey, keyLabelMode, noteLabelMode, darkMode = false }: PianoKeyboardProps) {
  // Find the lowest note in the tuning
  const lowestGuitarMidi = Math.min(...tuning.map(noteToMidi));

  // Start from the nearest C below the lowest guitar note for a clean keyboard start
  const startMidi = Math.floor(lowestGuitarMidi / 12) * 12; // Round down to nearest C
  const startNote = midiToNote(startMidi);

  const allNotes = generatePianoRange(startNote, END_NOTE);
  const whiteNotes = allNotes.filter(note => !isBlackKey(note));

  const getSelectedNote = (note: string): SelectedNote | undefined => {
    return selectedNotes.find(sn => sn.note === note);
  };

  const getNoteName = (note: string): string => {
    const match = note.match(/^([A-G]#?)/);
    return match ? match[1] : '';
  };

  const getOctave = (note: string): number => {
    const match = note.match(/(\d+)$/);
    return match ? parseInt(match[1], 10) : 0;
  };

  return (
    <div className={`rounded-lg p-4 min-[600px]:p-[24px] ${
      darkMode
        ? 'bg-zinc-800 border border-zinc-700'
        : 'bg-white border border-[#EDE9E9]'
    }`}>
      <div className="overflow-x-auto scrollbar-hide">
        <div className="relative inline-block">
        {/* White keys */}
        <div className="flex">
          {whiteNotes.map((note, index) => {
            const selected = getSelectedNote(note);
            const inKey = isNoteInKey(note, selectedKey);
            const scaleDegree = getScaleDegree(note, selectedKey);
            const scaleDegreeColor = getScaleDegreeColor(scaleDegree);
            const outOfKeyColor = getOutOfKeyColor(note, selectedKey);
            const chromaticColor = getChromaticNoteColor(note);
            const isSelected = !!selected;

            // Determine the indicator square styling
            let indicatorStyle = '';
            if (isSelected && scaleDegreeColor) {
              // Selected and in key: use scale degree color at 500 level with white text
              indicatorStyle = `${scaleDegreeColor.bg500} text-white font-medium`;
            } else if (isSelected && outOfKeyColor) {
              // Selected but not in key: use out-of-key color at 500 level with white text
              indicatorStyle = `${outOfKeyColor.bg500} text-white font-medium`;
            } else if (isSelected) {
              // Selected with no key: use chromatic color at 500 level with white text
              indicatorStyle = `${chromaticColor.bg500} text-white font-medium`;
            } else if (scaleDegreeColor && selectedKey) {
              // Not selected but in key: use scale degree color at 100 level with border
              indicatorStyle = darkMode
                ? `${scaleDegreeColor.darkBg100} text-zinc-200 border ${scaleDegreeColor.darkBorder}`
                : `${scaleDegreeColor.bg100} text-zinc-700 border ${scaleDegreeColor.border200}`;
            } else {
              // Not selected and not in key: transparent/no color
              indicatorStyle = darkMode
                ? 'text-zinc-300'
                : 'text-zinc-600';
            }

            const showIndicator = isSelected || (scaleDegreeColor && selectedKey);

            return (
              <button
                key={note}
                onClick={() => onNoteSelect(note)}
                className={`
                  h-28 min-[600px]:h-36 rounded-b
                  flex flex-col items-center justify-end pb-2
                  text-xs transition-colors
                  ${darkMode
                    ? 'bg-zinc-800 hover:bg-zinc-700 border border-zinc-600'
                    : 'bg-white hover:bg-zinc-100 border border-[#EDE9E9]'
                  }
                `}
                style={{ width: `${WHITE_KEY_WIDTH}px` }}
              >
                {keyLabelMode === 'onlyInKey' && !inKey && !isSelected ? null : (
                  <div className="w-7 h-7 flex items-center justify-center">
                    <div
                      className={`
                        ${isSelected ? 'w-7 h-7' : 'w-5 h-5'} flex items-center justify-center rounded
                        ${showIndicator ? indicatorStyle : (darkMode ? 'text-zinc-300' : 'text-zinc-600')}
                        ${keyLabelMode === 'showAll' && !inKey && !isSelected ? 'opacity-30' : ''}
                      `}
                    >
                      {(() => {
                        const displayName = noteLabelMode === 'sharpsOnly' ? note.replace(/\d+$/, '') : getNoteDisplayName(note, selectedKey);
                        const { letter, accidental } = parseNoteDisplay(displayName);
                        return (
                          <span className="flex items-start leading-none">
                            {letter}
                            {accidental && <span className="text-[8px] leading-none">{accidental}</span>}
                          </span>
                        );
                      })()}
                    </div>
                  </div>
                )}
              </button>
            );
          })}
        </div>

        {/* Black keys */}
        {whiteNotes.map((whiteNote, index) => {
          const noteName = getNoteName(whiteNote);
          const octave = getOctave(whiteNote);
          const blackKeyName = BLACK_KEY_AFTER[noteName];

          if (!blackKeyName) return null;

          const blackNote = `${blackKeyName}${octave}`;

          // Check if this black note exists in our range
          if (!allNotes.includes(blackNote)) return null;

          const selected = getSelectedNote(blackNote);
          const inKey = isNoteInKey(blackNote, selectedKey);
          const scaleDegree = getScaleDegree(blackNote, selectedKey);
          const scaleDegreeColor = getScaleDegreeColor(scaleDegree);
          const outOfKeyColor = getOutOfKeyColor(blackNote, selectedKey);
          const chromaticColor = getChromaticNoteColor(blackNote);
          const isSelected = !!selected;

          // Determine the indicator square styling
          let indicatorStyle = '';
          if (isSelected && scaleDegreeColor) {
            // Selected and in key: use scale degree color at 500 level with white text
            indicatorStyle = `${scaleDegreeColor.bg500} text-white font-medium`;
          } else if (isSelected && outOfKeyColor) {
            // Selected but not in key: use out-of-key color at 500 level with white text
            indicatorStyle = `${outOfKeyColor.bg500} text-white font-medium`;
          } else if (isSelected) {
            // Selected with no key: use chromatic color at 500 level with white text
            indicatorStyle = `${chromaticColor.bg500} text-white font-medium`;
          } else if (scaleDegreeColor && selectedKey) {
            // Not selected but in key: use scale degree color at 100 level with border
            indicatorStyle = darkMode
              ? `${scaleDegreeColor.darkBg100} text-zinc-200 border ${scaleDegreeColor.darkBorder}`
              : `${scaleDegreeColor.bg100} text-zinc-700 border ${scaleDegreeColor.border200}`;
          } else {
            // Not selected and not in key: transparent/no color
            indicatorStyle = darkMode
              ? 'text-zinc-400'
              : 'text-zinc-600';
          }

          const showIndicator = isSelected || (scaleDegreeColor && selectedKey);

          // Position: right edge of current white key minus half of black key width
          const leftPosition = (index + 1) * WHITE_KEY_WIDTH - BLACK_KEY_WIDTH / 2;

          return (
            <button
              key={blackNote}
              onClick={() => onNoteSelect(blackNote)}
              style={{ left: `${leftPosition}px`, width: `${BLACK_KEY_WIDTH}px` }}
              className={`
                absolute top-0 h-14 min-[600px]:h-20 rounded-b
                flex flex-col items-center justify-end pb-1
                text-xs transition-colors z-10
                ${darkMode
                  ? 'bg-zinc-700 hover:bg-zinc-600'
                  : 'bg-zinc-200 hover:bg-zinc-300'
                }
              `}
            >
              {keyLabelMode === 'onlyInKey' && !inKey && !isSelected ? null : (
                <div className="w-6 h-6 flex items-center justify-center">
                  <div
                    className={`
                      ${isSelected ? 'w-6 h-6' : 'w-4 h-4'} flex items-center justify-center rounded
                      ${showIndicator ? indicatorStyle : (darkMode ? 'text-zinc-400' : 'text-zinc-600')}
                      ${keyLabelMode === 'showAll' && !inKey && !isSelected ? 'opacity-30' : ''}
                    `}
                  >
                    {(() => {
                      const displayName = noteLabelMode === 'sharpsOnly' ? blackNote.replace(/\d+$/, '') : getNoteDisplayName(blackNote, selectedKey);
                      const { letter, accidental } = parseNoteDisplay(displayName);
                      return (
                        <span className="flex items-start leading-none">
                          {letter}
                          {accidental && <span className="text-[8px] leading-none">{accidental}</span>}
                        </span>
                      );
                    })()}
                  </div>
                </div>
              )}
            </button>
          );
        })}
        </div>
      </div>
    </div>
  );
}
