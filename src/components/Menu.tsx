'use client';

import { ReactNode, useEffect, useState } from 'react';

/** Panel styling shared by dropdown and context menus. */
export const menuPanelClass = (darkMode: boolean) =>
  `rounded-xl shadow-lg py-1 text-sm ${darkMode ? 'bg-zinc-800 border border-zinc-700 text-zinc-200' : 'bg-white border border-[#EDE9E9] text-zinc-800'}`;

interface MenuProps {
  /** The button's contents. */
  label: ReactNode;
  /** The menu's items; call `close` after acting. */
  children: (close: () => void) => ReactNode;
  darkMode: boolean;
  align?: 'left' | 'right';
  /** Opens upward, for menus near the bottom of the window. */
  direction?: 'down' | 'up';
  buttonClassName?: string;
  title?: string;
  width?: string;
  ariaLabel?: string;
}

/** A button that opens a dropdown of items; clicking outside or pressing Escape closes it. */
export function Menu({ label, children, darkMode, align = 'left', direction = 'down', buttonClassName = '', title, width = 'w-56', ariaLabel }: MenuProps) {
  const [open, setOpen] = useState(false);
  const close = () => setOpen(false);

  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => { if (e.key === 'Escape') setOpen(false); };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [open]);

  return (
    <div className="relative min-w-0">
      <button onClick={() => setOpen(o => !o)} className={buttonClassName} title={title} aria-label={ariaLabel} aria-haspopup="menu" aria-expanded={open}>
        {label}
      </button>
      {open && (
        <>
          <div className="fixed inset-0 z-30" onClick={close} />
          <div
            role="menu"
            className={`absolute z-40 max-h-[70vh] overflow-y-auto ${width} ${align === 'left' ? 'left-0' : 'right-0'} ${
              direction === 'down' ? 'top-full mt-1' : 'bottom-full mb-1'
            } ${menuPanelClass(darkMode)}`}
          >
            {children(close)}
          </div>
        </>
      )}
    </div>
  );
}

/** A context menu shown at the pointer. */
export function ContextMenu({ x, y, darkMode, onClose, children }: { x: number; y: number; darkMode: boolean; onClose: () => void; children: ReactNode }) {
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => { if (e.key === 'Escape') onClose(); };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [onClose]);
  // Kept on screen near the edges.
  const left = typeof window === 'undefined' ? x : Math.min(x, window.innerWidth - 230);
  const top = typeof window === 'undefined' ? y : Math.min(y, window.innerHeight - 260);
  return (
    <>
      <div className="fixed inset-0 z-40" onClick={onClose} onContextMenu={e => { e.preventDefault(); onClose(); }} />
      <div role="menu" className={`fixed z-50 w-56 ${menuPanelClass(darkMode)}`} style={{ left, top }}>
        {children}
      </div>
    </>
  );
}

interface MenuItemProps {
  onClick: () => void;
  darkMode: boolean;
  children: ReactNode;
  disabled?: boolean;
  /** Shows a checkmark (for the current choice). */
  checked?: boolean;
  destructive?: boolean;
  /** A second, quieter line or trailing detail. */
  detail?: ReactNode;
}

export function MenuItem({ onClick, darkMode, children, disabled, checked, destructive, detail }: MenuItemProps) {
  return (
    <button
      role="menuitem"
      disabled={disabled}
      onClick={onClick}
      className={`w-full text-left px-3 py-1.5 flex items-center gap-2 ${
        disabled
          ? darkMode ? 'text-zinc-600 cursor-not-allowed' : 'text-zinc-300 cursor-not-allowed'
          : `${darkMode ? 'hover:bg-zinc-700' : 'hover:bg-zinc-100'} ${destructive ? 'text-red-500' : ''}`
      }`}
    >
      {checked !== undefined && <span className="w-4 text-center">{checked ? '✓' : ''}</span>}
      <span className="flex-1 min-w-0 truncate">{children}</span>
      {detail && <span className={`text-xs ${darkMode ? 'text-zinc-500' : 'text-zinc-400'}`}>{detail}</span>}
    </button>
  );
}

export function MenuDivider({ darkMode }: { darkMode: boolean }) {
  return <div className={`my-1 border-t ${darkMode ? 'border-zinc-700' : 'border-[#EDE9E9]'}`} />;
}

export function MenuHeading({ darkMode, children }: { darkMode: boolean; children: ReactNode }) {
  return <div className={`px-3 pt-2 pb-1 text-xs font-medium ${darkMode ? 'text-zinc-500' : 'text-zinc-400'}`}>{children}</div>;
}
