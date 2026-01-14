export const NOTE_COLORS = [
  { name: 'blue', bg: 'bg-blue-300', hover: 'hover:bg-blue-400', ring: 'ring-blue-500', text: 'text-blue-900' },
  { name: 'green', bg: 'bg-green-300', hover: 'hover:bg-green-400', ring: 'ring-green-500', text: 'text-green-900' },
  { name: 'purple', bg: 'bg-purple-300', hover: 'hover:bg-purple-400', ring: 'ring-purple-500', text: 'text-purple-900' },
  { name: 'orange', bg: 'bg-orange-300', hover: 'hover:bg-orange-400', ring: 'ring-orange-500', text: 'text-orange-900' },
  { name: 'pink', bg: 'bg-pink-300', hover: 'hover:bg-pink-400', ring: 'ring-pink-500', text: 'text-pink-900' },
  { name: 'cyan', bg: 'bg-cyan-300', hover: 'hover:bg-cyan-400', ring: 'ring-cyan-500', text: 'text-cyan-900' },
  { name: 'yellow', bg: 'bg-yellow-300', hover: 'hover:bg-yellow-400', ring: 'ring-yellow-500', text: 'text-yellow-900' },
  { name: 'red', bg: 'bg-red-300', hover: 'hover:bg-red-400', ring: 'ring-red-500', text: 'text-red-900' },
] as const;

export type NoteColor = typeof NOTE_COLORS[number];

export interface SelectedNote {
  note: string;
  colorIndex: number;
}

export function getColor(colorIndex: number): NoteColor {
  return NOTE_COLORS[colorIndex % NOTE_COLORS.length];
}
