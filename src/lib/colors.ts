export const NOTE_COLORS = [
  { name: 'blue', bg: 'bg-blue-300', hover: 'hover:bg-blue-400', ring: 'ring-blue-500', text: 'text-blue-900' },
  { name: 'green', bg: 'bg-green-300', hover: 'hover:bg-green-400', ring: 'ring-green-500', text: 'text-green-900' },
  { name: 'purple', bg: 'bg-purple-300', hover: 'hover:bg-purple-400', ring: 'ring-purple-500', text: 'text-purple-900' },
  { name: 'orange', bg: 'bg-orange-300', hover: 'hover:bg-orange-400', ring: 'ring-orange-500', text: 'text-orange-900' },
  { name: 'pink', bg: 'bg-pink-300', hover: 'hover:bg-pink-400', ring: 'ring-pink-500', text: 'text-pink-900' },
  { name: 'cyan', bg: 'bg-cyan-300', hover: 'hover:bg-cyan-400', ring: 'ring-cyan-500', text: 'text-cyan-900' },
  { name: 'yellow', bg: 'bg-yellow-300', hover: 'hover:bg-yellow-400', ring: 'ring-yellow-500', text: 'text-yellow-900' },
  { name: 'red', bg: 'bg-red-300', hover: 'hover:bg-red-400', ring: 'ring-red-500', text: 'text-red-900' },
  { name: 'teal', bg: 'bg-teal-300', hover: 'hover:bg-teal-400', ring: 'ring-teal-500', text: 'text-teal-900' },
  { name: 'indigo', bg: 'bg-indigo-300', hover: 'hover:bg-indigo-400', ring: 'ring-indigo-500', text: 'text-indigo-900' },
  { name: 'lime', bg: 'bg-lime-300', hover: 'hover:bg-lime-400', ring: 'ring-lime-500', text: 'text-lime-900' },
  { name: 'amber', bg: 'bg-amber-300', hover: 'hover:bg-amber-400', ring: 'ring-amber-500', text: 'text-amber-900' },
  { name: 'rose', bg: 'bg-rose-300', hover: 'hover:bg-rose-400', ring: 'ring-rose-500', text: 'text-rose-900' },
  { name: 'violet', bg: 'bg-violet-300', hover: 'hover:bg-violet-400', ring: 'ring-violet-500', text: 'text-violet-900' },
  { name: 'fuchsia', bg: 'bg-fuchsia-300', hover: 'hover:bg-fuchsia-400', ring: 'ring-fuchsia-500', text: 'text-fuchsia-900' },
  { name: 'emerald', bg: 'bg-emerald-300', hover: 'hover:bg-emerald-400', ring: 'ring-emerald-500', text: 'text-emerald-900' },
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
