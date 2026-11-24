// Tailwind color classes for notes. Class names are written out in full so Tailwind's scanner
// finds them; don't build them from parts.

/** Per-chord colors for selected notes (kept for saved-chord chips). */
export const NOTE_COLORS = [
  { name: 'blue', bg: 'bg-blue-700', hover: 'hover:bg-blue-800', ring: 'ring-blue-500', text: 'text-white' },
  { name: 'green', bg: 'bg-green-700', hover: 'hover:bg-green-800', ring: 'ring-green-500', text: 'text-white' },
  { name: 'purple', bg: 'bg-purple-700', hover: 'hover:bg-purple-800', ring: 'ring-purple-500', text: 'text-white' },
  { name: 'orange', bg: 'bg-orange-700', hover: 'hover:bg-orange-800', ring: 'ring-orange-500', text: 'text-white' },
  { name: 'pink', bg: 'bg-pink-700', hover: 'hover:bg-pink-800', ring: 'ring-pink-500', text: 'text-white' },
  { name: 'cyan', bg: 'bg-cyan-700', hover: 'hover:bg-cyan-800', ring: 'ring-cyan-500', text: 'text-white' },
  { name: 'yellow', bg: 'bg-yellow-700', hover: 'hover:bg-yellow-800', ring: 'ring-yellow-500', text: 'text-white' },
  { name: 'red', bg: 'bg-red-700', hover: 'hover:bg-red-800', ring: 'ring-red-500', text: 'text-white' },
  { name: 'teal', bg: 'bg-teal-700', hover: 'hover:bg-teal-800', ring: 'ring-teal-500', text: 'text-white' },
  { name: 'indigo', bg: 'bg-indigo-700', hover: 'hover:bg-indigo-800', ring: 'ring-indigo-500', text: 'text-white' },
  { name: 'lime', bg: 'bg-lime-700', hover: 'hover:bg-lime-800', ring: 'ring-lime-500', text: 'text-white' },
  { name: 'amber', bg: 'bg-amber-700', hover: 'hover:bg-amber-800', ring: 'ring-amber-500', text: 'text-white' },
  { name: 'rose', bg: 'bg-rose-700', hover: 'hover:bg-rose-800', ring: 'ring-rose-500', text: 'text-white' },
  { name: 'violet', bg: 'bg-violet-700', hover: 'hover:bg-violet-800', ring: 'ring-violet-500', text: 'text-white' },
  { name: 'fuchsia', bg: 'bg-fuchsia-700', hover: 'hover:bg-fuchsia-800', ring: 'ring-fuchsia-500', text: 'text-white' },
  { name: 'emerald', bg: 'bg-emerald-700', hover: 'hover:bg-emerald-800', ring: 'ring-emerald-500', text: 'text-white' },
] as const;

export type NoteColor = typeof NOTE_COLORS[number];

export interface SelectedNote {
  note: string;
  colorIndex: number;
}

export function getColor(colorIndex: number): NoteColor {
  return NOTE_COLORS[colorIndex % NOTE_COLORS.length];
}

export function getNextAvailableColorIndex(usedIndices: number[]): number {
  const usedSet = new Set(usedIndices.map(i => i % NOTE_COLORS.length));
  for (let i = 0; i < NOTE_COLORS.length; i++) {
    if (!usedSet.has(i)) {
      return i;
    }
  }
  // All colors in use, just return the next sequential one
  return usedIndices.length;
}

/**
 * Classes for one note color, in light and dark mode.
 * - `bg500` / `darkBg500`: solid fill for a selected note (white text on top).
 * - `bg100` / `darkBg100`: faint tint for an unselected note or tile.
 * - `border200` / `darkBorder`: border drawn with the tint.
 * - `hover100` / `darkHover100`: hover over the tint.
 * - `hex`: the solid color, for SVG or inline styles.
 */
export interface NoteColorClasses {
  readonly name: string;
  readonly hex: string;
  readonly bg500: string;
  readonly darkBg500: string;
  readonly bg100: string;
  readonly darkBg100: string;
  readonly border200: string;
  readonly darkBorder: string;
  readonly hover100: string;
  readonly darkHover100: string;
}

/**
 * The 7 scale-degree colors (red, orange, yellow, green, cyan, blue, purple), indexed by degree
 * number − 1, so ♭3 and 3 share a color. Matches Swift's `ScaleDegreePalette`.
 */
export const SCALE_DEGREE_COLORS: readonly NoteColorClasses[] = [
  { name: 'red', hex: '#EF4444', bg100: 'bg-red-100', bg500: 'bg-red-500', border200: 'border-red-400', hover100: 'hover:bg-red-200', darkBg100: 'bg-red-900/40', darkBg500: 'bg-red-500', darkBorder: 'border-red-700', darkHover100: 'hover:bg-red-800/50' },
  { name: 'orange', hex: '#EA580C', bg100: 'bg-orange-100', bg500: 'bg-orange-600', border200: 'border-orange-400', hover100: 'hover:bg-orange-200', darkBg100: 'bg-orange-900/40', darkBg500: 'bg-orange-600', darkBorder: 'border-orange-700', darkHover100: 'hover:bg-orange-800/50' },
  { name: 'yellow', hex: '#CA8A04', bg100: 'bg-yellow-100', bg500: 'bg-yellow-600', border200: 'border-yellow-400', hover100: 'hover:bg-yellow-200', darkBg100: 'bg-yellow-900/40', darkBg500: 'bg-yellow-600', darkBorder: 'border-yellow-700', darkHover100: 'hover:bg-yellow-800/50' },
  { name: 'green', hex: '#16A34A', bg100: 'bg-green-100', bg500: 'bg-green-600', border200: 'border-green-400', hover100: 'hover:bg-green-200', darkBg100: 'bg-green-900/40', darkBg500: 'bg-green-600', darkBorder: 'border-green-700', darkHover100: 'hover:bg-green-800/50' },
  { name: 'cyan', hex: '#0891B2', bg100: 'bg-cyan-100', bg500: 'bg-cyan-600', border200: 'border-cyan-400', hover100: 'hover:bg-cyan-200', darkBg100: 'bg-cyan-900/40', darkBg500: 'bg-cyan-600', darkBorder: 'border-cyan-700', darkHover100: 'hover:bg-cyan-800/50' },
  { name: 'blue', hex: '#3B82F6', bg100: 'bg-blue-100', bg500: 'bg-blue-500', border200: 'border-blue-400', hover100: 'hover:bg-blue-200', darkBg100: 'bg-blue-900/40', darkBg500: 'bg-blue-500', darkBorder: 'border-blue-700', darkHover100: 'hover:bg-blue-800/50' },
  { name: 'purple', hex: '#A855F7', bg100: 'bg-purple-100', bg500: 'bg-purple-500', border200: 'border-purple-400', hover100: 'hover:bg-purple-200', darkBg100: 'bg-purple-900/40', darkBg500: 'bg-purple-500', darkBorder: 'border-purple-700', darkHover100: 'hover:bg-purple-800/50' },
];

// Non-degree colors get a light wash of the solid color (12% light / 22% dark) and a border of it
// (55% light / 70% dark), as in Swift's `NotePalette.tint` and `NoteTileStyle`.

/**
 * Colors for selected notes outside the key, indexed by position among the key's out-of-key
 * semitones: pink, lime, teal, indigo, rose, then fuchsia and stone for scales with fewer than 7
 * notes. Matches Swift's `NotePalette.outOfKey`.
 */
export const CHROMATIC_OUT_OF_KEY_COLORS: readonly NoteColorClasses[] = [
  { name: 'pink', hex: '#EC4899', bg500: 'bg-pink-500', darkBg500: 'bg-pink-500', bg100: 'bg-pink-500/12', darkBg100: 'bg-pink-500/22', border200: 'border-pink-500/55', darkBorder: 'border-pink-500/70', hover100: 'hover:bg-pink-500/20', darkHover100: 'hover:bg-pink-500/30' },
  { name: 'lime', hex: '#65A30D', bg500: 'bg-lime-600', darkBg500: 'bg-lime-600', bg100: 'bg-lime-600/12', darkBg100: 'bg-lime-600/22', border200: 'border-lime-600/55', darkBorder: 'border-lime-600/70', hover100: 'hover:bg-lime-600/20', darkHover100: 'hover:bg-lime-600/30' },
  { name: 'teal', hex: '#0D9488', bg500: 'bg-teal-600', darkBg500: 'bg-teal-600', bg100: 'bg-teal-600/12', darkBg100: 'bg-teal-600/22', border200: 'border-teal-600/55', darkBorder: 'border-teal-600/70', hover100: 'hover:bg-teal-600/20', darkHover100: 'hover:bg-teal-600/30' },
  { name: 'indigo', hex: '#6366F1', bg500: 'bg-indigo-500', darkBg500: 'bg-indigo-500', bg100: 'bg-indigo-500/12', darkBg100: 'bg-indigo-500/22', border200: 'border-indigo-500/55', darkBorder: 'border-indigo-500/70', hover100: 'hover:bg-indigo-500/20', darkHover100: 'hover:bg-indigo-500/30' },
  { name: 'rose', hex: '#F43F5E', bg500: 'bg-rose-500', darkBg500: 'bg-rose-500', bg100: 'bg-rose-500/12', darkBg100: 'bg-rose-500/22', border200: 'border-rose-500/55', darkBorder: 'border-rose-500/70', hover100: 'hover:bg-rose-500/20', darkHover100: 'hover:bg-rose-500/30' },
  { name: 'fuchsia', hex: '#C026D3', bg500: 'bg-fuchsia-600', darkBg500: 'bg-fuchsia-600', bg100: 'bg-fuchsia-600/12', darkBg100: 'bg-fuchsia-600/22', border200: 'border-fuchsia-600/55', darkBorder: 'border-fuchsia-600/70', hover100: 'hover:bg-fuchsia-600/20', darkHover100: 'hover:bg-fuchsia-600/30' },
  { name: 'stone', hex: '#78716C', bg500: 'bg-stone-500', darkBg500: 'bg-stone-500', bg100: 'bg-stone-500/12', darkBg100: 'bg-stone-500/22', border200: 'border-stone-500/55', darkBorder: 'border-stone-500/70', hover100: 'hover:bg-stone-500/20', darkHover100: 'hover:bg-stone-500/30' },
];

/** One color per pitch class (C = 0 … B = 11), used when no key is selected. Swift's `NotePalette.chromatic`. */
export const CHROMATIC_NOTE_COLORS: readonly NoteColorClasses[] = [
  { name: 'red', hex: '#EF4444', bg500: 'bg-red-500', darkBg500: 'bg-red-500', bg100: 'bg-red-500/12', darkBg100: 'bg-red-500/22', border200: 'border-red-500/55', darkBorder: 'border-red-500/70', hover100: 'hover:bg-red-500/20', darkHover100: 'hover:bg-red-500/30' }, // C
  { name: 'pink', hex: '#EC4899', bg500: 'bg-pink-500', darkBg500: 'bg-pink-500', bg100: 'bg-pink-500/12', darkBg100: 'bg-pink-500/22', border200: 'border-pink-500/55', darkBorder: 'border-pink-500/70', hover100: 'hover:bg-pink-500/20', darkHover100: 'hover:bg-pink-500/30' }, // C#
  { name: 'orange', hex: '#EA580C', bg500: 'bg-orange-600', darkBg500: 'bg-orange-600', bg100: 'bg-orange-600/12', darkBg100: 'bg-orange-600/22', border200: 'border-orange-600/55', darkBorder: 'border-orange-600/70', hover100: 'hover:bg-orange-600/20', darkHover100: 'hover:bg-orange-600/30' }, // D
  { name: 'lime', hex: '#65A30D', bg500: 'bg-lime-600', darkBg500: 'bg-lime-600', bg100: 'bg-lime-600/12', darkBg100: 'bg-lime-600/22', border200: 'border-lime-600/55', darkBorder: 'border-lime-600/70', hover100: 'hover:bg-lime-600/20', darkHover100: 'hover:bg-lime-600/30' }, // D#
  { name: 'yellow', hex: '#CA8A04', bg500: 'bg-yellow-600', darkBg500: 'bg-yellow-600', bg100: 'bg-yellow-600/12', darkBg100: 'bg-yellow-600/22', border200: 'border-yellow-600/55', darkBorder: 'border-yellow-600/70', hover100: 'hover:bg-yellow-600/20', darkHover100: 'hover:bg-yellow-600/30' }, // E
  { name: 'green', hex: '#16A34A', bg500: 'bg-green-600', darkBg500: 'bg-green-600', bg100: 'bg-green-600/12', darkBg100: 'bg-green-600/22', border200: 'border-green-600/55', darkBorder: 'border-green-600/70', hover100: 'hover:bg-green-600/20', darkHover100: 'hover:bg-green-600/30' }, // F
  { name: 'teal', hex: '#0D9488', bg500: 'bg-teal-600', darkBg500: 'bg-teal-600', bg100: 'bg-teal-600/12', darkBg100: 'bg-teal-600/22', border200: 'border-teal-600/55', darkBorder: 'border-teal-600/70', hover100: 'hover:bg-teal-600/20', darkHover100: 'hover:bg-teal-600/30' }, // F#
  { name: 'cyan', hex: '#0891B2', bg500: 'bg-cyan-600', darkBg500: 'bg-cyan-600', bg100: 'bg-cyan-600/12', darkBg100: 'bg-cyan-600/22', border200: 'border-cyan-600/55', darkBorder: 'border-cyan-600/70', hover100: 'hover:bg-cyan-600/20', darkHover100: 'hover:bg-cyan-600/30' }, // G
  { name: 'indigo', hex: '#6366F1', bg500: 'bg-indigo-500', darkBg500: 'bg-indigo-500', bg100: 'bg-indigo-500/12', darkBg100: 'bg-indigo-500/22', border200: 'border-indigo-500/55', darkBorder: 'border-indigo-500/70', hover100: 'hover:bg-indigo-500/20', darkHover100: 'hover:bg-indigo-500/30' }, // G#
  { name: 'blue', hex: '#3B82F6', bg500: 'bg-blue-500', darkBg500: 'bg-blue-500', bg100: 'bg-blue-500/12', darkBg100: 'bg-blue-500/22', border200: 'border-blue-500/55', darkBorder: 'border-blue-500/70', hover100: 'hover:bg-blue-500/20', darkHover100: 'hover:bg-blue-500/30' }, // A
  { name: 'rose', hex: '#F43F5E', bg500: 'bg-rose-500', darkBg500: 'bg-rose-500', bg100: 'bg-rose-500/12', darkBg100: 'bg-rose-500/22', border200: 'border-rose-500/55', darkBorder: 'border-rose-500/70', hover100: 'hover:bg-rose-500/20', darkHover100: 'hover:bg-rose-500/30' }, // A#
  { name: 'purple', hex: '#A855F7', bg500: 'bg-purple-500', darkBg500: 'bg-purple-500', bg100: 'bg-purple-500/12', darkBg100: 'bg-purple-500/22', border200: 'border-purple-500/55', darkBorder: 'border-purple-500/70', hover100: 'hover:bg-purple-500/20', darkHover100: 'hover:bg-purple-500/30' }, // B
];

/**
 * Which palette a note's color comes from (Swift's `NoteColorRole`):
 * - `scaleDegree`: in the key; `index` is the degree number − 1 (0–6).
 * - `outOfKey`: selected but outside the key; `index` among the key's out-of-key semitones.
 * - `chromatic`: no key; `index` is the pitch class (0–11).
 */
export type NoteColorRole =
  | { kind: 'scaleDegree'; index: number }
  | { kind: 'outOfKey'; index: number }
  | { kind: 'chromatic'; index: number };

/** The color classes for a role. Out-of-key indexes wrap, as in Swift. */
export function getRoleColor(role: NoteColorRole): NoteColorClasses {
  switch (role.kind) {
    case 'scaleDegree':
      return SCALE_DEGREE_COLORS[((role.index % 7) + 7) % 7];
    case 'outOfKey':
      return CHROMATIC_OUT_OF_KEY_COLORS[role.index % CHROMATIC_OUT_OF_KEY_COLORS.length];
    case 'chromatic':
      return CHROMATIC_NOTE_COLORS[((role.index % 12) + 12) % 12];
  }
}

/** Solid fill class for a role (selected notes, chips). */
export function getRoleSolidClass(role: NoteColorRole, dark = false): string {
  const color = getRoleColor(role);
  return dark ? color.darkBg500 : color.bg500;
}

/** Tint + border classes for an unselected tile or badge in a role's color (`NoteTileStyle`). */
export function getRoleTintClasses(role: NoteColorRole, dark = false): string {
  const color = getRoleColor(role);
  return dark ? `${color.darkBg100} ${color.darkBorder}` : `${color.bg100} ${color.border200}`;
}

/** Whether two roles are the same. */
export function sameColorRole(a: NoteColorRole, b: NoteColorRole): boolean {
  return a.kind === b.kind && a.index === b.index;
}
