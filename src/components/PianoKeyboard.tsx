'use client';

import { generatePianoRange, isBlackKey, noteToMidi, midiToNote } from '@/lib/notes';
import { NoteLabelContext, getNoteAppearance, getNoteColorRole, getNoteAccessibilityName } from '@/lib/noteLabels';
import { getRoleSolidClass } from '@/lib/colors';
import { NoteBadge, NoteLabelText } from './NoteBadge';
import { NoteSpotOverlays, NextChordHint } from './NoteSpotOverlays';

interface PianoKeyboardProps {
  tuning: string[];
  selectedNotes: string[];
  /** Notes playing right now, which flash. */
  soundingNotes: ReadonlySet<string>;
  /** While looping, the next chord's notes fade in lightly before the change. */
  nextChordHint: NextChordHint;
  onNoteSelect: (note: string) => void;
  /** How notes are labeled (names, degrees or intervals) and which show, for the key. */
  labelContext: NoteLabelContext;
  darkMode?: boolean;
  /** How tall the card may grow, to match the guitars when there's room. It never shrinks below
   *  its usual size. */
  targetHeight?: number | null;
  /** Wide layouts (600px and up) get taller keys. */
  wide?: boolean;
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

export default function PianoKeyboard({ tuning, selectedNotes, soundingNotes, nextChordHint, onNoteSelect, labelContext, darkMode = false, targetHeight, wide = true }: PianoKeyboardProps) {
  // Start from the nearest C below the lowest guitar note for a clean keyboard start
  const lowestGuitarMidi = Math.min(...tuning.map(noteToMidi));
  const startNote = midiToNote(Math.floor(lowestGuitarMidi / 12) * 12);

  const allNotes = generatePianoRange(startNote, END_NOTE);
  const whiteNotes = allNotes.filter(note => !isBlackKey(note));

  const standardWhiteHeight = wide ? 144 : 112;
  // The card's 1px border sits above and below the keys.
  const whiteHeight = targetHeight ? Math.max(targetHeight - 2, standardWhiteHeight) : standardWhiteHeight;
  const blackHeight = whiteHeight === standardWhiteHeight ? (wide ? 80 : 56) : Math.round(whiteHeight * 0.56);

  /** The rounded square near the bottom of a key, like a fret's: filled with the note's color
   *  when selected, otherwise holding the note's badge. The playback flash and next-chord fill
   *  light up the same square. */
  const keySpot = (note: string, size: number, radius: number, plainTextClass: string) => {
    const selected = selectedNotes.includes(note);
    const appearance = getNoteAppearance(note, selected, labelContext);
    const solid = getRoleSolidClass(getNoteColorRole(note, labelContext.key), darkMode);
    const overlays = (
      <NoteSpotOverlays
        size={size}
        radius={radius}
        isSounding={soundingNotes.has(note)}
        preview={!selected && nextChordHint.notes.includes(note) ? { color: solid, hint: nextChordHint } : null}
        darkMode={darkMode}
      />
    );
    if (selected) {
      return (
        <div
          className={`relative flex items-center justify-center text-white font-medium ${solid}`}
          style={{ width: size, height: size, borderRadius: radius }}
        >
          {overlays}
          <span className="relative"><NoteLabelText label={appearance.label} /></span>
        </div>
      );
    }
    return (
      <div className="relative flex items-center justify-center" style={{ width: size, height: size }}>
        {overlays}
        <NoteBadge appearance={appearance} darkMode={darkMode} plainTextClass={plainTextClass} />
      </div>
    );
  };

  const keyProps = (note: string) => ({
    title: note,
    'aria-label': getNoteAccessibilityName(note, labelContext),
    'aria-pressed': selectedNotes.includes(note),
  });

  return (
    <div className={`rounded-2xl overflow-hidden border ${
      darkMode ? 'bg-[#1F1F22] border-zinc-700' : 'bg-white border-[#EDE9E9]'
    }`}>
      <div className="overflow-x-auto scrollbar-hide">
        <div className="relative inline-block align-top">
          {/* White keys */}
          <div className="flex">
            {whiteNotes.map(note => (
              <button
                key={note}
                onClick={() => onNoteSelect(note)}
                {...keyProps(note)}
                className={`relative flex-shrink-0 flex flex-col items-center justify-end pb-1 text-xs transition-colors ${
                  darkMode ? 'bg-zinc-800 hover:bg-zinc-700' : 'bg-white hover:bg-zinc-100'
                }`}
                style={{ width: WHITE_KEY_WIDTH, height: whiteHeight }}
              >
                {keySpot(note, WHITE_KEY_WIDTH - 8, 10, darkMode ? 'text-zinc-300' : 'text-zinc-600')}
                {/* One line between neighboring keys. The keyboard's top and bottom edges are left
                    to the card's border, so they aren't doubled up. */}
                <span aria-hidden className={`absolute right-0 top-0 bottom-0 w-px ${darkMode ? 'bg-zinc-600' : 'bg-[#EDE9E9]'}`} />
              </button>
            ))}
          </div>

          {/* Black keys */}
          {whiteNotes.map((whiteNote, index) => {
            const blackKeyName = BLACK_KEY_AFTER[whiteNote.replace(/\d+$/, '')];
            if (!blackKeyName) return null;
            const blackNote = `${blackKeyName}${whiteNote.match(/(\d+)$/)?.[1] ?? ''}`;
            if (!allNotes.includes(blackNote)) return null;

            // Right edge of the white key, less half the black key's width.
            const left = (index + 1) * WHITE_KEY_WIDTH - BLACK_KEY_WIDTH / 2;
            return (
              <button
                key={blackNote}
                onClick={() => onNoteSelect(blackNote)}
                {...keyProps(blackNote)}
                // The same 1px line as between the white keys, down the sides and along the bottom.
                className={`absolute top-0 z-10 rounded-b border border-t-0 flex flex-col items-center justify-end pb-[3px] text-xs transition-colors ${
                  darkMode
                    ? 'bg-[#323236] hover:bg-zinc-700 border-zinc-600'
                    : 'bg-[#F2EFEE] hover:bg-[#E7E3E1] border-[#EDE9E9]'
                }`}
                style={{ left, width: BLACK_KEY_WIDTH, height: blackHeight }}
              >
                {keySpot(blackNote, BLACK_KEY_WIDTH - 6, 8, darkMode ? 'text-zinc-400' : 'text-zinc-600')}
              </button>
            );
          })}
        </div>
      </div>
    </div>
  );
}
