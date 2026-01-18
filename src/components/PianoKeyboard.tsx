'use client';

import { generatePianoRange, isBlackKey, noteToMidi, midiToNote, MusicalKey, isNoteInKey } from '@/lib/notes';
import { SelectedNote, getColor } from '@/lib/colors';

interface PianoKeyboardProps {
  tuning: string[];
  selectedNotes: SelectedNote[];
  onNoteSelect: (note: string) => void;
  selectedKey: MusicalKey | null;
}

const END_NOTE = 'E6';
const WHITE_KEY_WIDTH = 40;
const BLACK_KEY_WIDTH = 28;

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

export default function PianoKeyboard({ tuning, selectedNotes, onNoteSelect, selectedKey }: PianoKeyboardProps) {
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
    <div className="border border-[#EDE9E9] rounded-[16px] bg-white p-[24px]">
      <div className="overflow-x-auto scrollbar-hide">
        <div className="relative inline-block">
        {/* White keys */}
        <div className="flex">
          {whiteNotes.map((note, index) => {
            const selected = getSelectedNote(note);
            const color = selected ? getColor(selected.colorIndex) : null;
            const inKey = isNoteInKey(note, selectedKey);
            return (
              <button
                key={note}
                onClick={() => onNoteSelect(note)}
                className={`
                  h-36 rounded-b border border-[#EDE9E9]
                  flex flex-col items-center justify-end pb-2
                  text-xs transition-colors
                  ${color
                    ? `${color.bg} ${color.text} font-medium`
                    : 'bg-white text-zinc-600 hover:bg-zinc-100'
                  }
                `}
                style={{ width: `${WHITE_KEY_WIDTH}px` }}
              >
                <span className={!inKey ? 'opacity-50' : ''}>
                  {note.replace(/\d+$/, '')}
                </span>
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
          const color = selected ? getColor(selected.colorIndex) : null;
          const inKey = isNoteInKey(blackNote, selectedKey);

          // Position: right edge of current white key minus half of black key width
          const leftPosition = (index + 1) * WHITE_KEY_WIDTH - BLACK_KEY_WIDTH / 2;

          return (
            <button
              key={blackNote}
              onClick={() => onNoteSelect(blackNote)}
              style={{ left: `${leftPosition}px`, width: `${BLACK_KEY_WIDTH}px` }}
              className={`
                absolute top-0 h-20 rounded-b
                flex flex-col items-center justify-end pb-1
                text-xs transition-colors z-10
                ${color
                  ? `${color.bg} ${color.text} font-medium`
                  : 'bg-zinc-200 text-zinc-600 hover:bg-zinc-300'
                }
              `}
            >
              <span className={!inKey ? 'opacity-50' : ''}>
                {blackNote.replace(/\d+$/, '')}
              </span>
            </button>
          );
        })}
        </div>
      </div>
    </div>
  );
}
