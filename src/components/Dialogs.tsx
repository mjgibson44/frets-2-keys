'use client';

import { ReactNode, useEffect, useRef, useState } from 'react';

function DialogFrame({ darkMode, onCancel, children }: { darkMode: boolean; onCancel: () => void; children: ReactNode }) {
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => { if (e.key === 'Escape') onCancel(); };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [onCancel]);
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-6">
      <div className="absolute inset-0 bg-black/40" onClick={onCancel} />
      <div role="dialog" className={`relative w-full max-w-sm rounded-2xl p-5 shadow-xl ${
        darkMode ? 'bg-zinc-800 border border-zinc-700 text-zinc-100' : 'bg-white border border-[#EDE9E9] text-zinc-900'
      }`}>
        {children}
      </div>
    </div>
  );
}

const buttonClass = (darkMode: boolean, kind: 'primary' | 'secondary' | 'destructive') =>
  `px-3 py-1.5 rounded-lg text-sm font-medium transition-colors ${
    kind === 'primary' ? 'bg-blue-500 text-white hover:bg-blue-600'
      : kind === 'destructive' ? 'bg-red-500 text-white hover:bg-red-600'
        : darkMode ? 'hover:bg-zinc-700 text-zinc-300' : 'hover:bg-zinc-100 text-zinc-600'
  }`;

/** Asks for a name, e.g. to rename a set or section. */
export function TextPromptDialog({ title, message, initialValue = '', placeholder, confirmLabel = 'Rename', darkMode, onConfirm, onCancel }: {
  title: string;
  message?: string;
  initialValue?: string;
  placeholder?: string;
  confirmLabel?: string;
  darkMode: boolean;
  onConfirm: (value: string) => void;
  onCancel: () => void;
}) {
  const [value, setValue] = useState(initialValue);
  const inputRef = useRef<HTMLInputElement>(null);
  useEffect(() => { inputRef.current?.select(); }, []);
  return (
    <DialogFrame darkMode={darkMode} onCancel={onCancel}>
      <form onSubmit={e => { e.preventDefault(); onConfirm(value); }}>
        <h2 className="text-base font-semibold">{title}</h2>
        {message && <p className={`mt-1 text-sm ${darkMode ? 'text-zinc-400' : 'text-zinc-500'}`}>{message}</p>}
        <input
          ref={inputRef}
          value={value}
          placeholder={placeholder}
          onChange={e => setValue(e.target.value)}
          className={`mt-4 w-full rounded-lg px-3 py-2 text-sm outline-none border ${
            darkMode ? 'bg-zinc-900 border-zinc-700 focus:border-zinc-500' : 'bg-white border-[#EDE9E9] focus:border-zinc-400'
          }`}
        />
        <div className="mt-5 flex justify-end gap-2">
          <button type="button" onClick={onCancel} className={buttonClass(darkMode, 'secondary')}>Cancel</button>
          <button type="submit" className={buttonClass(darkMode, 'primary')}>{confirmLabel}</button>
        </div>
      </form>
    </DialogFrame>
  );
}

/** Asks before something that can't be undone. */
export function ConfirmDialog({ title, message, confirmLabel = 'Delete', darkMode, onConfirm, onCancel }: {
  title: string;
  message: string;
  confirmLabel?: string;
  darkMode: boolean;
  onConfirm: () => void;
  onCancel: () => void;
}) {
  return (
    <DialogFrame darkMode={darkMode} onCancel={onCancel}>
      <h2 className="text-base font-semibold">{title}</h2>
      <p className={`mt-1 text-sm ${darkMode ? 'text-zinc-400' : 'text-zinc-500'}`}>{message}</p>
      <div className="mt-5 flex justify-end gap-2">
        <button onClick={onCancel} className={buttonClass(darkMode, 'secondary')}>Cancel</button>
        <button onClick={onConfirm} className={buttonClass(darkMode, 'destructive')} autoFocus>{confirmLabel}</button>
      </div>
    </DialogFrame>
  );
}
