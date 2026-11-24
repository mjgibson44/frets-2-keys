'use client';

/** The coming chord, shown on the instruments over the last beats before a change while looping:
 *  its notes fill in a light version of their color, fading in over `fadeMs`. */
export interface NextChordHint {
  notes: string[];
  isShowing: boolean;
  fadeMs: number;
}

/** The light next-chord fill and the playback flash, drawn in the rounded square a selected note
 *  fills, centered in its cell or key and behind its label. */
export function NoteSpotOverlays({ size, radius, isSounding, preview, darkMode }: {
  size: number;
  radius: number;
  isSounding: boolean;
  /** The note's solid color class, when it's in the next chord. */
  preview: { color: string; hint: NextChordHint } | null;
  darkMode: boolean;
}) {
  const square = (extra: string, style: React.CSSProperties = {}) => ({
    className: `absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2 pointer-events-none ${extra}`,
    style: { width: size, height: size, borderRadius: radius, ...style },
  });
  return (
    <>
      {preview && (
        <span
          aria-hidden
          {...square(preview.color, {
            opacity: preview.hint.isShowing ? 0.35 : 0,
            // Fades in over the beat; hidden straight away.
            transition: preview.hint.isShowing ? `opacity ${preview.hint.fadeMs}ms ease-in-out` : 'none',
          })}
        />
      )}
      {/* Instant both ways, so one note's flash doesn't linger into the next. A selected note
          shades inside its fill; others shade the square behind the badge. */}
      <span
        aria-hidden
        {...square(darkMode ? 'bg-white' : 'bg-black', { opacity: isSounding ? (darkMode ? 0.38 : 0.32) : 0 })}
      />
    </>
  );
}
