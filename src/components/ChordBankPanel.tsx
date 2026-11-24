'use client';

import { ReactNode, useEffect, useState } from 'react';
import { MusicalKey, ScaleType, isScaleType, makeKey, isHeptatonic, getKeyName, getKeyPitchClasses, getPitchClassDisplayName } from '@/lib/notes';
import {
  CHORD_QUALITIES, ChordQuality, getChordQuality, getChordBankNotes, getChordBankName, getChordTileSuffix,
  getDiatonicChords, DiatonicChord, SCALE_BANK_FAMILIES, getScaleBankEntry,
} from '@/lib/chordBank';
import { getNoteColorRole, getPitchClassColorRole } from '@/lib/noteLabels';
import { NoteColorRole, getRoleColor, getRoleSolidClass, SCALE_DEGREE_COLORS } from '@/lib/colors';
import KeyMenu from './KeyMenu';

interface ChordBankPanelProps {
  /** The app's key, which the bank's own key starts from. Changing the bank's key doesn't change the app's. */
  appKey: MusicalKey | null;
  sharpsOnly: boolean;
  /** "Add to Set", or "Add to Chorus" when the set has sections. */
  addTitle: string;
  /** The set holds the most chords and scales it can. */
  isFull: boolean;
  /** Plays notes without changing anything: a chord, or a scale going up. */
  onPreview: (notes: string[], mode: 'chord' | 'arpeggio') => void;
  /** Shows a chord on the instruments without saving it. */
  onSelectChord: (notes: string[]) => void;
  onAddChord: (notes: string[]) => void;
  /** Makes a scale the key, so the instruments highlight it. */
  onShowScale: (scale: MusicalKey, notes: string[]) => void;
  onAddScale: (scale: MusicalKey, notes: string[], name: string) => void;
  onClose: () => void;
  darkMode: boolean;
}

type Mode = 'chords' | 'scales';

/** Reads a remembered choice from localStorage. */
function stored<T>(key: string, parse: (value: string) => T | undefined, fallback: T): T {
  if (typeof window === 'undefined') return fallback;
  try {
    const value = localStorage.getItem(key);
    return (value !== null ? parse(value) : undefined) ?? fallback;
  } catch {
    return fallback;
  }
}

/** Pick a root and chord type (or scale), hear it, then add it to the active set or just show it. */
export default function ChordBankPanel({
  appKey, sharpsOnly, addTitle, isFull, onPreview, onSelectChord, onAddChord, onShowScale, onAddScale, onClose, darkMode,
}: ChordBankPanelProps) {
  const [mode, setMode] = useState<Mode>(() => stored('chordBankMode', v => (v === 'scales' ? 'scales' : v === 'chords' ? 'chords' : undefined), 'chords'));
  const [root, setRoot] = useState(() => stored('chordBankRoot', v => { const n = Number(v); return n >= 0 && n < 12 ? n : undefined; }, 0));
  const [qualityId, setQualityId] = useState(() => stored('chordBankQuality', v => v, CHORD_QUALITIES[0].id));
  const [scaleType, setScaleType] = useState<ScaleType>(() => stored('scaleBankType', v => (isScaleType(v) ? v : undefined), 'major'));
  const [key, setKey] = useState<MusicalKey | null>(appKey);

  useEffect(() => {
    try {
      localStorage.setItem('chordBankMode', mode);
      localStorage.setItem('chordBankRoot', String(root));
      localStorage.setItem('chordBankQuality', qualityId);
      localStorage.setItem('scaleBankType', scaleType);
    } catch { /* ignore */ }
  }, [mode, root, qualityId, scaleType]);

  const quality = getChordQuality(qualityId);
  const notes = getChordBankNotes(root, quality);
  const scale = makeKey(root, scaleType);
  const scaleEntry = getScaleBankEntry(scale, sharpsOnly);
  const keyPitchClasses = key ? getKeyPitchClasses(key) : null;

  /** Root names spelled for the bank's key (flats in flat keys) unless "Sharps only" is on. */
  const rootName = (pc: number) => getPitchClassDisplayName(pc, key, sharpsOnly);
  /** The instruments' color for a root under the bank's key. */
  const rootRole = (pc: number) => getPitchClassColorRole(pc, key);

  const muted = darkMode ? 'text-zinc-400' : 'text-zinc-500';

  /** A choice tile. With a note `role`, it's tinted like that note and filled when selected (like a
   *  selected note); otherwise it's neutral and fills with `selectedClass` when selected. */
  const tile = (title: ReactNode, isSelected: boolean, onClick: () => void, options: { role?: NoteColorRole; selectedClass?: string; dimmed?: boolean; tall?: boolean; label?: string } = {}) => {
    const { role, selectedClass, dimmed, tall, label } = options;
    let colors: string;
    if (isSelected) {
      colors = `${role ? getRoleSolidClass(role, darkMode) : selectedClass ?? 'bg-blue-500'} text-white border border-transparent font-semibold`;
    } else if (role) {
      const c = getRoleColor(role);
      colors = darkMode ? `${c.darkBg100} ${c.darkHover100} ${c.darkBorder} border text-zinc-200` : `${c.bg100} ${c.hover100} ${c.border200} border text-zinc-700`;
    } else {
      colors = darkMode ? 'bg-zinc-700 hover:bg-zinc-600 text-zinc-200 border border-transparent' : 'bg-zinc-100 hover:bg-zinc-200 text-zinc-700 border border-transparent';
    }
    return (
      <button
        onClick={onClick}
        aria-pressed={isSelected}
        aria-label={label}
        className={`w-full rounded-md px-1 text-sm truncate transition-colors ${tall ? 'min-h-[38px] py-1' : 'min-h-[34px]'} ${colors} ${dimmed ? 'opacity-45' : ''}`}
      >
        {title}
      </button>
    );
  };

  const section = (title: string, content: ReactNode) => (
    <div>
      <div className={`mb-2 text-sm font-medium ${muted}`}>{title}</div>
      {content}
    </div>
  );

  const chooseChord = (pc: number, q: ChordQuality) => {
    setRoot(pc);
    setQualityId(q.id);
    onPreview(getChordBankNotes(pc, q), 'chord');
  };

  /** One tile per scale degree: the Roman numeral over the chord name. */
  const diatonicRow = (chords: DiatonicChord[]) => (
    <div className="grid grid-cols-7 gap-1">
      {chords.map(chord => <div key={chord.numeral}>{tile(
        <span className="flex flex-col leading-tight">
          <span className="text-[11px] font-semibold">{chord.numeral}</span>
          <span className="text-[11px] truncate">{rootName(chord.root) + getChordTileSuffix(chord.quality)}</span>
        </span>,
        root === chord.root && qualityId === chord.quality.id,
        () => chooseChord(chord.root, chord.quality),
        { role: rootRole(chord.root), tall: true, label: `${chord.numeral}: ${rootName(chord.root)} ${chord.quality.label}` },
      )}</div>)}
    </div>
  );

  const chordChoices = (
    <>
      <div className="flex items-center gap-2">
        <span className={`text-sm font-medium ${muted}`}>Key</span>
        <div className="-ml-1"><KeyMenu selectedKey={key} onSelectKey={setKey} sharpsOnly={sharpsOnly} isWide darkMode={darkMode} /></div>
      </div>
      {key && isHeptatonic(key) && section(`Chords in ${getKeyName(key, sharpsOnly)}`, (
        <div className="flex flex-col gap-1.5">
          {diatonicRow(getDiatonicChords(key))}
          {diatonicRow(getDiatonicChords(key, true))}
        </div>
      ))}
      {section('Root', (
        <div className="grid grid-cols-6 gap-1.5">
          {Array.from({ length: 12 }, (_, pc) => (
            <div key={pc}>
              {tile(rootName(pc), root === pc, () => chooseChord(pc, quality), {
                role: rootRole(pc),
                // Roots outside the chosen key are dimmed.
                dimmed: keyPitchClasses !== null && !keyPitchClasses.includes(pc),
              })}
            </div>
          ))}
        </div>
      ))}
      {section('Type', (
        <div className="grid grid-cols-[repeat(auto-fill,minmax(76px,1fr))] gap-1.5">
          {CHORD_QUALITIES.map(q => (
            <div key={q.id}>
              {tile(q.label, qualityId === q.id, () => chooseChord(root, q), { selectedClass: getRoleSolidClass(rootRole(root), darkMode) })}
            </div>
          ))}
        </div>
      ))}
    </>
  );

  const scaleChoices = (
    <>
      {section('Root', (
        <div className="grid grid-cols-6 gap-1.5">
          {Array.from({ length: 12 }, (_, pc) => (
            <div key={pc}>
              {tile(rootName(pc), root === pc, () => {
                setRoot(pc);
                onPreview(getScaleBankEntry(makeKey(pc, scaleType)).ascendingNotes, 'arpeggio');
              }, { role: { kind: 'chromatic', index: pc } })}
            </div>
          ))}
        </div>
      ))}
      {SCALE_BANK_FAMILIES.map(family => (
        <div key={family.id}>
          {section(family.title, (
            <div className="grid grid-cols-[repeat(auto-fill,minmax(110px,1fr))] gap-1.5">
              {family.types.map(({ type, title }) => (
                <div key={type}>
                  {tile(title, scaleType === type, () => {
                    setScaleType(type);
                    onPreview(getScaleBankEntry(makeKey(root, type)).ascendingNotes, 'arpeggio');
                  }, { selectedClass: getRoleSolidClass({ kind: 'chromatic', index: root }, darkMode) })}
                </div>
              ))}
            </div>
          ))}
        </div>
      ))}
    </>
  );

  const speakerButton = (onClick: () => void, label: string) => (
    <button onClick={onClick} title={label} aria-label={label} className={`p-1 rounded-md ${darkMode ? 'text-blue-400 hover:bg-zinc-700' : 'text-blue-500 hover:bg-zinc-100'}`}>
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" className="w-5 h-5">
        <path d="M10.5 3.75a.75.75 0 00-1.264-.546L5.203 7H2.667a.75.75 0 00-.7.48A6.985 6.985 0 001.5 10c0 .887.165 1.737.468 2.52.111.29.39.48.7.48h2.535l4.033 3.796a.75.75 0 001.264-.546V3.75zM16.45 5.05a.75.75 0 00-1.06 1.061 5.5 5.5 0 010 7.778.75.75 0 001.06 1.06 7 7 0 000-9.899z" />
        <path d="M14.329 7.172a.75.75 0 00-1.061 1.06 2.5 2.5 0 010 3.536.75.75 0 001.06 1.06 4 4 0 000-5.656z" />
      </svg>
    </button>
  );

  const footerButtons = (secondaryTitle: string, secondaryHelp: string, onSecondary: () => void, onPrimary: () => void, primaryHelp: string) => (
    <>
      <div className="flex gap-2">
        <button onClick={onSecondary} title={secondaryHelp} className={`flex-1 py-2 rounded-lg text-sm font-medium transition-colors ${darkMode ? 'bg-zinc-700 hover:bg-zinc-600 text-blue-400' : 'bg-zinc-100 hover:bg-zinc-200 text-blue-600'}`}>
          {secondaryTitle}
        </button>
        <button onClick={onPrimary} disabled={isFull} title={primaryHelp} className={`flex-1 py-2 rounded-lg text-sm font-medium truncate px-2 transition-colors ${isFull ? 'bg-blue-500/40 text-white cursor-not-allowed' : 'bg-blue-500 hover:bg-blue-600 text-white'}`}>
          {addTitle}
        </button>
      </div>
      {isFull && <p className={`text-xs ${muted}`}>This set has the most chords and scales it can hold. Delete one to add more.</p>}
    </>
  );

  return (
    <div className={`h-full flex flex-col ${darkMode ? 'bg-zinc-800 text-zinc-100' : 'bg-white text-zinc-900'}`}>
      <div className="flex-1 min-h-0 overflow-y-auto p-5 flex flex-col gap-4">
        <div className="flex items-center">
          <h2 className="text-base font-semibold flex-1">Chord Bank</h2>
          <button onClick={onClose} title="Close the chord bank" aria-label="Close" className={`w-7 h-7 flex items-center justify-center rounded-full ${darkMode ? 'bg-zinc-700 text-zinc-300' : 'bg-zinc-100 text-zinc-500'}`}>
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" className="w-4 h-4">
              <path d="M6.28 5.22a.75.75 0 00-1.06 1.06L8.94 10l-3.72 3.72a.75.75 0 101.06 1.06L10 11.06l3.72 3.72a.75.75 0 101.06-1.06L11.06 10l3.72-3.72a.75.75 0 00-1.06-1.06L10 8.94 6.28 5.22z" />
            </svg>
          </button>
        </div>
        <div className={`flex p-0.5 rounded-lg ${darkMode ? 'bg-zinc-900' : 'bg-zinc-100'}`} role="tablist">
          {(['chords', 'scales'] as const).map(m => (
            <button
              key={m}
              role="tab"
              aria-selected={mode === m}
              onClick={() => setMode(m)}
              className={`flex-1 py-1 rounded-md text-sm font-medium transition-colors ${
                mode === m ? darkMode ? 'bg-zinc-600 text-white' : 'bg-white text-zinc-900 shadow-sm' : darkMode ? 'text-zinc-400' : 'text-zinc-600'
              }`}
            >
              {m === 'chords' ? 'Chords' : 'Scales'}
            </button>
          ))}
        </div>
        {mode === 'chords' ? chordChoices : scaleChoices}
      </div>

      {/* The chosen chord or scale and its actions stay pinned to the bottom while the choices scroll. */}
      <div className={`flex-shrink-0 px-5 py-3.5 flex flex-col gap-3 border-t ${darkMode ? 'border-zinc-700 bg-zinc-800' : 'border-[#EDE9E9] bg-zinc-50'}`}>
        {mode === 'chords' ? (
          <>
            <div className="flex items-center gap-2 min-w-0">
              <span className="text-[15px] font-semibold whitespace-nowrap">{getChordBankName(root, quality)}</span>
              <div className="flex gap-1 overflow-x-auto scrollbar-hide">
                {notes.map(note => (
                  <span key={note} className={`px-1.5 py-0.5 rounded text-xs font-medium text-white ${getRoleSolidClass(getNoteColorRole(note, key), darkMode)}`}>
                    {note.replace(/\d+$/, '')}
                  </span>
                ))}
              </div>
              <div className="flex-1" />
              {speakerButton(() => onPreview(notes, 'chord'), 'Hear this chord')}
            </div>
            {footerButtons('Select', 'Show this chord on the instruments without saving it', () => onSelectChord(notes), () => onAddChord(notes), 'Save this chord in the set')}
          </>
        ) : (
          <>
            <div className="flex items-center gap-2">
              <span className="text-[15px] font-semibold truncate">{scaleEntry.name}</span>
              <div className="flex-1" />
              {speakerButton(() => onPreview(scaleEntry.ascendingNotes, 'arpeggio'), 'Hear this scale')}
            </div>
            <div className="flex gap-1 overflow-x-auto scrollbar-hide">
              {scaleEntry.notes.map(n => (
                <span key={n.degreeLabel} className={`min-w-[28px] px-1 py-0.5 rounded flex flex-col items-center text-white ${SCALE_DEGREE_COLORS[n.colorIndex][darkMode ? 'darkBg500' : 'bg500']}`}>
                  <span className="text-xs font-medium leading-tight">{n.name}</span>
                  <span className="text-[10px] opacity-85 leading-tight">{n.degreeLabel}</span>
                </span>
              ))}
            </div>
            {footerButtons(
              'Show', 'Highlight this scale on the instruments without saving it',
              () => onShowScale(scale, scaleEntry.ascendingNotes),
              () => onAddScale(scale, scaleEntry.ascendingNotes, getScaleBankEntry(scale).name),
              'Save this scale in the set',
            )}
          </>
        )}
      </div>
    </div>
  );
}
