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
