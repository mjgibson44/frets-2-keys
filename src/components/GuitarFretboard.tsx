'use client';

import { getNoteAtFret } from '@/lib/notes';
import { NoteLabelContext, getNoteAppearance, getNoteColorRole, getNoteAccessibilityName } from '@/lib/noteLabels';
import { getRoleSolidClass } from '@/lib/colors';
import { NoteSpotOverlays, NextChordHint } from './NoteSpotOverlays';
import { NoteBadge, NoteLabelText } from './NoteBadge';

interface GuitarFretboardProps {
  tuning: string[];
  capo: number;
  selectedNotes: string[];
  /** Notes playing right now, which flash. */
  soundingNotes: ReadonlySet<string>;
  /** While looping, the next chord's notes fade in lightly before the change. */
  nextChordHint: NextChordHint;
  onNoteSelect: (note: string) => void;
  anyCapoActive?: boolean;
  /** How notes are labeled (names, degrees or intervals) and which show, for the key. */
  labelContext: NoteLabelContext;
  darkMode?: boolean;
}

const SINGLE_MARKERS = [3, 5, 7, 9, 15, 17, 19, 21];
const DOUBLE_MARKERS = [12, 24];
const NUM_FRETS = 24;

/** Fret cell size, in px. */
const CELL_WIDTH = 56;
const CELL_HEIGHT = 40;
/** A selected fret's fill: a rounded square, at least 6px inside the cell's shorter side. The
 *  playback flash and next-chord fill use the same square; hovering shades the whole cell. */
const FILL_SIDE = Math.min(CELL_WIDTH, CELL_HEIGHT) - 12;
const FILL_RADIUS = 10;
/** Space above the top string and below the bottom one, so the outer strings' frets aren't
 *  crowded against the card's edge. The fret lines run on through it. */
const STRINGS_PADDING = 8;

const OPEN_STRING_FRETS = [0];
const FRETTED_FRETS = Array.from({ length: NUM_FRETS }, (_, i) => i + 1);

export default function GuitarFretboard({ tuning, capo, selectedNotes, soundingNotes, nextChordHint, onNoteSelect, anyCapoActive, labelContext, darkMode = false }: GuitarFretboardProps) {
  // Highest-pitched string on top, like looking down at the neck.
  const strings = [...tuning].reverse();
  const stringLineColor = darkMode ? 'bg-zinc-600' : 'bg-[#E1E1E1]';

  /** The line between two frets: the nut or capo is a thick amber bar. */
  const fretDivider = (fret: number, color: string) => (
    <span
      aria-hidden
      className={`absolute right-0 top-0 bottom-0 pointer-events-none ${fret === capo ? 'w-1 bg-amber-500' : `w-px ${color}`}`}
    />
  );

  const fretCell = (openNote: string, fret: number, stringNumber: number) => {
    const note = getNoteAtFret(openNote, fret);
    const isBelowCapo = fret < capo;
    const selected = selectedNotes.includes(note) && !isBelowCapo;
    const appearance = getNoteAppearance(note, selected, labelContext);
    const solid = getRoleSolidClass(getNoteColorRole(note, labelContext.key), darkMode);
    const stringLine = <div className={`flex-1 h-0.5 ${stringLineColor}`} />;

    let content: React.ReactNode;
    if (isBelowCapo) {
      content = null;
    } else if (selected) {
      // A rounded square in the note's color, with the string running up to its edges.
      content = (
        <>
          {stringLine}
          <div
            className={`flex items-center justify-center text-white font-medium ${solid}`}
            style={{ width: FILL_SIDE, height: FILL_SIDE, borderRadius: FILL_RADIUS }}
          >
            <NoteLabelText label={appearance.label} />
          </div>
          {stringLine}
        </>
      );
    } else if (!appearance.showsLabel) {
      content = stringLine;
    } else {
      content = (
        <>
          {stringLine}
          <NoteBadge appearance={appearance} darkMode={darkMode} plainTextClass={darkMode ? 'text-zinc-300' : 'text-zinc-700'} />
          {stringLine}
        </>
      );
    }

    return (
      <button
        key={fret}
        onClick={() => !isBelowCapo && onNoteSelect(note)}
        disabled={isBelowCapo}
        title={note}
        aria-label={`${getNoteAccessibilityName(note, labelContext)}, string ${stringNumber}, fret ${fret}`}
        aria-pressed={selected}
        className={`relative flex-shrink-0 flex items-center text-xs transition-colors ${
          isBelowCapo ? 'cursor-not-allowed' : darkMode ? 'hover:bg-zinc-700' : 'hover:bg-zinc-100'
        }`}
        style={{ width: CELL_WIDTH, height: CELL_HEIGHT }}
      >
        {!isBelowCapo && (
          <NoteSpotOverlays
            size={FILL_SIDE}
            radius={FILL_RADIUS}
            isSounding={soundingNotes.has(note)}
            preview={!selected && nextChordHint.notes.includes(note) ? { color: solid, hint: nextChordHint } : null}
            darkMode={darkMode}
          />
        )}
        <div className="relative flex-1 flex items-center self-stretch">{content}</div>
        {fretDivider(fret, darkMode ? 'bg-zinc-700' : 'bg-[#F2F2F2]')}
      </button>
    );
  };

  const footerRow = (frets: number[], content: (fret: number) => React.ReactNode, key: string) => (
    <div key={key} className="flex">
      {frets.map(fret => (
        <div key={fret} className="relative flex-shrink-0 h-6 flex items-center justify-center" style={{ width: CELL_WIDTH }}>
          {content(fret)}
          {fretDivider(fret, darkMode ? 'bg-zinc-600' : 'bg-[#F2F2F2]')}
        </div>
      ))}
    </div>
  );

  const marker = <div className={`w-1.5 h-1.5 rounded-full ${darkMode ? 'bg-zinc-500' : 'bg-zinc-400'}`} />;

  /** The strings across the given frets, with the fret numbers, markers and capo row below. */
  const neck = (frets: number[]) => (
    <div className="flex flex-col" style={{ width: frets.length * CELL_WIDTH }}>
      <div className="relative" style={{ paddingTop: STRINGS_PADDING, paddingBottom: STRINGS_PADDING }}>
        {/* Fret lines through the padding above and below the strings. */}
        <div aria-hidden className="absolute inset-0 flex pointer-events-none">
          {frets.map(fret => (
            <div key={fret} className="relative h-full flex-shrink-0" style={{ width: CELL_WIDTH }}>
              {fretDivider(fret, darkMode ? 'bg-zinc-700' : 'bg-[#F2F2F2]')}
            </div>
          ))}
        </div>
        {strings.map((openNote, stringIndex) => (
          <div key={stringIndex} className="relative flex">
            {frets.map(fret => fretCell(openNote, fret, stringIndex + 1))}
          </div>
        ))}
      </div>

      <div className={`relative ${darkMode ? 'bg-zinc-700' : 'bg-white'}`}>
        {/* The hairline between the strings and the fret numbers, behind the fret lines so the nut
            and capo bars run unbroken through it. */}
        {!darkMode && <div aria-hidden className="absolute left-0 right-0 top-0 h-px bg-[#EDE9E9]" />}
        {footerRow(frets, fret => (
          <span className={`text-xs ${darkMode ? 'text-zinc-400' : 'text-zinc-500'}`}>{fret === 0 ? '' : fret}</span>
        ), 'numbers')}
        {footerRow(frets, fret => (
          DOUBLE_MARKERS.includes(fret)
            ? <div className="flex gap-1">{marker}{marker}</div>
            : SINGLE_MARKERS.includes(fret) ? marker : null
        ), 'markers')}
        {capo > 0
          ? footerRow(frets, fret => (
            <span className="text-xs text-amber-600 font-medium">{fret >= capo ? fret - capo : ''}</span>
          ), 'capo')
          // Keeps both fretboards the same height when only the other has a capo.
          : anyCapoActive && footerRow(frets, () => <span className="text-xs">&nbsp;</span>, 'capo-spacer')}
      </div>
    </div>
  );

  return (
    <div className={`rounded-2xl overflow-hidden border ${
      darkMode ? 'bg-[#1F1F22] border-zinc-700' : 'bg-white border-[#EDE9E9]'
    }`}>
      {/* The open strings and nut stay put while the frets scroll beside them. */}
      <div className="flex">
        {neck(OPEN_STRING_FRETS)}
        <div className="flex-1 min-w-0 overflow-x-auto scrollbar-hide">
          {neck(FRETTED_FRETS)}
        </div>
      </div>
    </div>
  );
}
