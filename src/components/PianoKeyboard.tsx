'use client';

import { generatePianoRange, isBlackKey, noteToMidi, midiToNote } from '@/lib/notes';
import { SelectedNote, getColor } from '@/lib/colors';

interface PianoKeyboardProps {
  tuning: string[];
  selectedNotes: SelectedNote[];
  onNoteSelect: (note: string) => void;
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

export default function PianoKeyboard({ tuning, selectedNotes, onNoteSelect }: PianoKeyboardProps) {
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
    <div className="border border-zinc-300 rounded-[12px] bg-white p-4">
      <div className="overflow-x-auto scrollbar-hide">
        <div className="relative inline-block">
        {/* White keys */}
        <div className="flex">
          {whiteNotes.map((note, index) => {
            const selected = getSelectedNote(note);
            const color = selected ? getColor(selected.colorIndex) : null;
            return (
              <button
                key={note}
                onClick={() => onNoteSelect(note)}
                className={`
                  h-36 rounded-b border border-zinc-300
                  flex flex-col items-center justify-end pb-2
                  text-xs font-mono transition-colors
                  ${color
                    ? `${color.bg} ${color.text} ring-1 ring-inset ${color.ring} font-medium`
                    : 'bg-white text-zinc-600 hover:bg-zinc-100'
                  }
                `}
                style={{ width: `${WHITE_KEY_WIDTH}px` }}
              >
{note.replace(/\d+$/, '')}
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
                text-[10px] font-mono transition-colors z-10
                ${color
                  ? `${color.bg} ${color.text} ring-1 ring-inset ${color.ring} font-medium`
                  : 'bg-zinc-200 text-zinc-600 hover:bg-zinc-300'
                }
              `}
            >
{blackNote.replace(/\d+$/, '')}
            </button>
          );
        })}
        </div>
      </div>
    </div>
  );
}
