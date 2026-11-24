'use client';

import { NoteAppearance, splitNoteLabel } from '@/lib/noteLabels';
import { SCALE_DEGREE_COLORS } from '@/lib/colors';

/** A note's label with its accidental small and raised: after the letter in names ('B♭'), before
 *  the number in degrees and intervals ('♭3'). */
export function NoteLabelText({ label }: { label: string }) {
  const { main, accidental, accidentalFirst, smallDigits } = splitNoteLabel(label);
  const small = accidental && <span className="text-[8px] leading-none">{accidental}</span>;
  return (
    <span className={`flex items-start leading-none ${smallDigits ? 'text-[11px]' : ''}`}>
      {accidentalFirst && small}
      {main}
      {!accidentalFirst && small}
    </span>
  );
}

/** An unselected note's 20px badge: tinted in its scale degree's color when it's in the key,
 *  plain text otherwise, and faded when it's outside the key. */
export function NoteBadge({ appearance, darkMode, plainTextClass }: {
  appearance: NoteAppearance;
  darkMode: boolean;
  plainTextClass: string;
}) {
  if (!appearance.showsLabel) return null;
  const style = appearance.style;
  const colorClass = style.kind === 'inKey'
    ? (() => {
      const c = SCALE_DEGREE_COLORS[style.scaleDegree];
      return darkMode ? `${c.darkBg100} text-zinc-200 border ${c.darkBorder}` : `${c.bg100} text-zinc-700 border ${c.border200}`;
    })()
    : plainTextClass;
  return (
    <div className={`relative w-5 h-5 flex items-center justify-center rounded ${colorClass} ${appearance.isDimmed ? 'opacity-30' : ''}`}>
      <NoteLabelText label={appearance.label} />
    </div>
  );
}
