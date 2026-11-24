'use client';

import { useState } from 'react';
import {
  MusicalKey, ScaleType, SCALE_FAMILIES, getKeysOfType, getKeyName, getKeyShortName, getScaleTypeTitle, sameKey,
} from '@/lib/notes';
import { NoteLabelContent, NOTE_LABEL_CONTENTS, getKeySummaryText } from '@/lib/noteLabels';
import { Menu, MenuItem, MenuDivider, MenuHeading } from './Menu';

interface KeyMenuProps {
  selectedKey: MusicalKey | null;
  onSelectKey: (key: MusicalKey | null) => void;
  /** The app's own key menu also picks how notes are labeled; the chord bank's doesn't. */
  labelContent?: NoteLabelContent;
  onLabelContentChange?: (content: NoteLabelContent) => void;
  sharpsOnly: boolean;
  /** Wider windows show the key's full name and its notes (or degrees). */
  isWide: boolean;
  darkMode: boolean;
}

/** The key menu: how notes are labeled, then No key, other scales and modes, and the major and
 *  minor keys. Its button shows the chosen key and, on wider windows, its notes or degrees. */
export default function KeyMenu({ selectedKey, onSelectKey, labelContent, onLabelContentChange, sharpsOnly, isWide, darkMode }: KeyMenuProps) {
  // "More Scales" opens a list of scale types, then a type's twelve roots.
  const [view, setView] = useState<'main' | 'scales' | ScaleType>('main');

  const keyItem = (key: MusicalKey, close: () => void) => (
    <MenuItem
      key={`${key.root}-${key.type}`}
      darkMode={darkMode}
      checked={sameKey(key, selectedKey)}
      onClick={() => { onSelectKey(key); close(); setView('main'); }}
    >
      {getKeyName(key, sharpsOnly)}
    </MenuItem>
  );

  const backItem = (to: 'main' | 'scales', label: string) => (
    <button
      onClick={() => setView(to)}
      className={`w-full text-left px-3 py-1.5 flex items-center gap-1 text-sm font-medium ${darkMode ? 'text-blue-400 hover:bg-zinc-700' : 'text-blue-600 hover:bg-zinc-100'}`}
    >
      ‹ {label}
    </button>
  );

  return (
    <Menu
      darkMode={darkMode}
      width="w-64"
      ariaLabel={`Key: ${selectedKey ? getKeyName(selectedKey, sharpsOnly) : 'No key'}`}
      buttonClassName={`flex items-center gap-2 px-3 py-1.5 rounded-lg text-sm font-medium transition-colors min-w-0 max-w-full ${darkMode ? 'hover:bg-zinc-700' : 'hover:bg-zinc-200'}`}
      label={
        <>
          <span className={`truncate ${darkMode ? 'text-zinc-200' : 'text-zinc-700'}`}>
            {/* Narrow windows use short names ("A min. pent.") so the top bar fits. */}
            {selectedKey ? (isWide ? getKeyName(selectedKey, sharpsOnly) : getKeyShortName(selectedKey, sharpsOnly)) : 'No key'}
          </span>
          {selectedKey && isWide && (
            <span className="text-xs text-zinc-500 whitespace-nowrap">{getKeySummaryText(selectedKey, labelContent ?? 'names', sharpsOnly)}</span>
          )}
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" className="w-4 h-4 text-zinc-500 flex-shrink-0">
            <path fillRule="evenodd" d="M5.23 7.21a.75.75 0 011.06.02L10 11.168l3.71-3.938a.75.75 0 111.08 1.04l-4.25 4.5a.75.75 0 01-1.08 0l-4.25-4.5a.75.75 0 01.02-1.06z" clipRule="evenodd" />
          </svg>
        </>
      }
    >
      {close => {
        if (view === 'scales') {
          return (
            <>
              {backItem('main', 'Keys')}
              {SCALE_FAMILIES.map(family => (
                <div key={family.id}>
                  <MenuHeading darkMode={darkMode}>{family.title}</MenuHeading>
                  {family.types.filter(t => t !== 'major' && t !== 'minor').map(type => (
                    <MenuItem key={type} darkMode={darkMode} detail="›" checked={selectedKey?.type === type} onClick={() => setView(type)}>
                      {getScaleTypeTitle(type)}
                    </MenuItem>
                  ))}
                </div>
              ))}
            </>
          );
        }
        if (view !== 'main') {
          return (
            <>
              {backItem('scales', 'More Scales')}
              <MenuHeading darkMode={darkMode}>{getScaleTypeTitle(view)}</MenuHeading>
              {getKeysOfType(view).map(key => keyItem(key, close))}
            </>
          );
        }
        return (
          <>
            {labelContent && onLabelContentChange && <>
            <MenuHeading darkMode={darkMode}>Label Notes With</MenuHeading>
            <div className="px-3 pb-2">
              <div className={`flex p-0.5 rounded-lg ${darkMode ? 'bg-zinc-900' : 'bg-zinc-100'}`}>
                {NOTE_LABEL_CONTENTS.map(({ id, title }) => (
                  <button
                    key={id}
                    onClick={() => onLabelContentChange(id)}
                    className={`flex-1 py-1 rounded-md text-xs font-medium transition-colors ${
                      labelContent === id
                        ? darkMode ? 'bg-zinc-600 text-white' : 'bg-white text-zinc-900 shadow-sm'
                        : darkMode ? 'text-zinc-400 hover:text-zinc-200' : 'text-zinc-600 hover:text-zinc-900'
                    }`}
                    title="Label notes with their names, scale degrees, or intervals from the chord's root (N)"
                  >
                    {title}
                  </button>
                ))}
              </div>
            </div>
            <MenuDivider darkMode={darkMode} />
            </>}
            <MenuItem darkMode={darkMode} checked={selectedKey === null} onClick={() => { onSelectKey(null); close(); }}>No key</MenuItem>
            <MenuItem darkMode={darkMode} checked={!!selectedKey && selectedKey.type !== 'major' && selectedKey.type !== 'minor'} detail="›" onClick={() => setView('scales')}>
              More Scales
            </MenuItem>
            <MenuDivider darkMode={darkMode} />
            <MenuHeading darkMode={darkMode}>Major</MenuHeading>
            {getKeysOfType('major').map(key => keyItem(key, close))}
            <MenuDivider darkMode={darkMode} />
            <MenuHeading darkMode={darkMode}>Minor</MenuHeading>
            {getKeysOfType('minor').map(key => keyItem(key, close))}
          </>
        );
      }}
    </Menu>
  );
}
