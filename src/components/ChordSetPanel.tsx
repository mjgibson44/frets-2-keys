'use client';

import { useEffect, useState } from 'react';
import {
  ChordLibrary, ChordSection, SavedChord, activeSet, allChords, isScale, sectionDisplayName,
  createSet, renameSet, duplicateSet, deleteSet, addSection, renameSection, deleteSection,
  moveSection, shiftSection, moveChord, moveChordToSection, shiftChord, canShiftChord,
} from '@/lib/chordSets';
import { Menu, MenuItem, MenuDivider, MenuHeading, ContextMenu } from './Menu';
import { TextPromptDialog, ConfirmDialog } from './Dialogs';

interface ChordSetPanelProps {
  library: ChordLibrary;
  onLibraryChange: (library: ChordLibrary) => void;
  /** Whether a chip shows as the current one (the active chord, or the scale that's the key). */
  isChipActive: (chord: SavedChord) => boolean;
  /** Tailwind classes coloring a chip by its root, like that note on the instruments. */
  chipClassName: (chord: SavedChord, isActive: boolean) => string;
  /** A chip's text: the chord's name, or a scale's short name. */
  chipTitle: (chord: SavedChord) => string;
  onSelectChord: (chord: SavedChord) => void;
  onDeleteChord: (id: string) => void;
  /** Opens the chord bank, adding to `sectionId` (or the active section). */
  onOpenBank: (sectionId: string | null) => void;
  isBankOpen: boolean;
  loopingSectionId: string | null;
  onToggleSectionLoop: (sectionId: string) => void;
  darkMode: boolean;
}

const CHORD_DRAG = 'f2k-chord:';
const SECTION_DRAG = 'f2k-section:';
const COLLAPSED_KEY = 'collapsedSections';

/** The set menu, Add Section and Add Chord, and the set's sections of saved chords and scales. */
export default function ChordSetPanel(props: ChordSetPanelProps) {
  const { library, onLibraryChange, darkMode, onOpenBank, isBankOpen } = props;
  const set = activeSet(library);
  const [renamingSet, setRenamingSet] = useState(false);
  const [deletingSet, setDeletingSet] = useState(false);
  const [renamingSectionId, setRenamingSectionId] = useState<string | null>(null);
  const [deletingSectionId, setDeletingSectionId] = useState<string | null>(null);
  // Which sections are collapsed on this device.
  const [collapsed, setCollapsed] = useState<string[]>([]);

  useEffect(() => {
    try { setCollapsed(JSON.parse(localStorage.getItem(COLLAPSED_KEY) ?? '[]')); } catch { /* ignore */ }
  }, []);
  const toggleCollapsed = (id: string) => {
    const next = collapsed.includes(id) ? collapsed.filter(c => c !== id) : [...collapsed, id];
    setCollapsed(next);
    try { localStorage.setItem(COLLAPSED_KEY, JSON.stringify(next)); } catch { /* ignore */ }
  };

  const handleAddSection = () => {
    const { library: next, id } = addSection(library);
    onLibraryChange(next);
    // Name it straight away.
    setRenamingSectionId(id);
  };

  const requestDeleteSection = (section: ChordSection) => {
    if (section.chords.length === 0) onLibraryChange(deleteSection(library, section.id));
    else setDeletingSectionId(section.id);
  };

  const isEmpty = set.sections.length === 1 && set.sections[0].chords.length === 0;
  const itemCount = (count: number) => (count === 1 ? '1 item' : `${count} items`);
  const sectionBeingRenamed = set.sections.findIndex(s => s.id === renamingSectionId);

  const chipButtonClass = (active = false) => `h-[27px] flex items-center justify-center gap-1.5 rounded-md border text-sm transition-colors ${
    active
      ? darkMode ? 'bg-zinc-600 border-zinc-600' : 'bg-zinc-200 border-[#EDE9E9]'
      : darkMode ? 'bg-zinc-700 border-transparent hover:bg-zinc-600' : 'bg-white border-[#EDE9E9] hover:bg-zinc-200'
  } ${darkMode ? 'text-zinc-200' : 'text-zinc-700'}`;

  return (
    <div>
      <div className="flex items-center gap-2 min-h-8">
        {/* The set menu: switch sets, and new / rename / duplicate / delete. */}
        <div className="-ml-2">
          <Menu
            darkMode={darkMode}
            direction="up"
            ariaLabel={`Chord set: ${set.name}`}
            buttonClassName={`flex items-center gap-1.5 px-2 py-1 rounded-md transition-colors ${darkMode ? 'hover:bg-zinc-700' : 'hover:bg-zinc-200'}`}
            label={
              <>
                <span className={`text-sm font-semibold ${darkMode ? 'text-zinc-200' : 'text-zinc-700'}`}>{set.name}</span>
                <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" className="w-4 h-4 text-zinc-500">
                  <path fillRule="evenodd" d="M5.23 7.21a.75.75 0 011.06.02L10 11.168l3.71-3.938a.75.75 0 111.08 1.04l-4.25 4.5a.75.75 0 01-1.08 0l-4.25-4.5a.75.75 0 01.02-1.06z" clipRule="evenodd" />
                </svg>
              </>
            }
          >
            {close => (
              <>
                <MenuHeading darkMode={darkMode}>Chord Sets</MenuHeading>
                {library.sets.map(s => (
                  <MenuItem
                    key={s.id}
                    darkMode={darkMode}
                    checked={s.id === library.activeSetId}
                    detail={itemCount(allChords(s).length)}
                    onClick={() => { onLibraryChange({ ...library, activeSetId: s.id }); close(); }}
                  >
                    {s.name}
                  </MenuItem>
                ))}
                <MenuDivider darkMode={darkMode} />
                <MenuItem darkMode={darkMode} onClick={() => { onLibraryChange(createSet(library)); close(); }}>New Set</MenuItem>
                <MenuItem darkMode={darkMode} onClick={() => { setRenamingSet(true); close(); }}>Rename…</MenuItem>
                <MenuItem darkMode={darkMode} onClick={() => { onLibraryChange(duplicateSet(library, set.id)); close(); }}>Duplicate</MenuItem>
                <MenuItem darkMode={darkMode} destructive onClick={() => { setDeletingSet(true); close(); }}>Delete…</MenuItem>
                <MenuDivider darkMode={darkMode} />
                <MenuItem darkMode={darkMode} onClick={() => { handleAddSection(); close(); }}>Add Section</MenuItem>
              </>
            )}
          </Menu>
        </div>
        {isEmpty ? (
          // An empty set says so on the same row as its menu and buttons.
          <span
            className={`flex-1 text-center text-sm truncate ${darkMode ? 'text-zinc-500' : 'text-zinc-400'}`}
            {...sectionDropHandlers(set.sections[0].id)}
          >
            No saved chords
          </span>
        ) : (
          <div className="flex-1" />
        )}
        <button onClick={handleAddSection} className={`${chipButtonClass()} w-[30px]`} title="Add a section, like a verse or chorus" aria-label="Add Section">
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" className="w-4 h-4">
            <path d="M3 4.75A1.75 1.75 0 014.75 3h6.5A1.75 1.75 0 0113 4.75v.5a.75.75 0 01-1.5 0v-.5a.25.25 0 00-.25-.25h-6.5a.25.25 0 00-.25.25v6.5c0 .138.112.25.25.25h.5a.75.75 0 010 1.5h-.5A1.75 1.75 0 013 11.25v-6.5z" />
            <path d="M8.75 7A1.75 1.75 0 007 8.75v6.5c0 .966.784 1.75 1.75 1.75h6.5A1.75 1.75 0 0017 15.25v-6.5A1.75 1.75 0 0015.25 7h-6.5zM12 9.25a.75.75 0 01.75.75v1.25H14a.75.75 0 010 1.5h-1.25V14a.75.75 0 01-1.5 0v-1.25H10a.75.75 0 010-1.5h1.25V10a.75.75 0 01.75-.75z" />
          </svg>
        </button>
        <button onClick={() => onOpenBank(null)} className={`${chipButtonClass(isBankOpen)} px-3`} title="Choose a chord or scale from the chord bank">
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" className="w-4 h-4">
            <path d="M10.75 4.75a.75.75 0 00-1.5 0v4.5h-4.5a.75.75 0 000 1.5h4.5v4.5a.75.75 0 001.5 0v-4.5h4.5a.75.75 0 000-1.5h-4.5v-4.5z" />
          </svg>
          Add Chord
        </button>
      </div>

      {!isEmpty && (
        <div className="mt-3">
          {set.sections.length === 1 ? (
            <div {...sectionDropHandlers(set.sections[0].id)}>
              <SectionChips section={set.sections[0]} {...props} />
            </div>
          ) : (
            <div className="flex flex-col gap-2.5">
              {set.sections.map((section, index) => (
                <SectionBlock
                  key={section.id}
                  section={section}
                  index={index}
                  count={set.sections.length}
                  isCollapsed={collapsed.includes(section.id)}
                  onToggleCollapsed={() => toggleCollapsed(section.id)}
                  onRename={() => setRenamingSectionId(section.id)}
                  onDelete={() => requestDeleteSection(section)}
                  {...props}
                />
              ))}
            </div>
          )}
        </div>
      )}

      {renamingSet && (
        <TextPromptDialog
          title="Rename Set"
          initialValue={set.name}
          darkMode={darkMode}
          onCancel={() => setRenamingSet(false)}
          onConfirm={name => { onLibraryChange(renameSet(library, set.id, name)); setRenamingSet(false); }}
        />
      )}
      {deletingSet && (
        <ConfirmDialog
          title={`Delete “${set.name}”?`}
          message="Its saved chords will be removed. This can't be undone."
          darkMode={darkMode}
          onCancel={() => setDeletingSet(false)}
          onConfirm={() => { onLibraryChange(deleteSet(library, set.id)); setDeletingSet(false); }}
        />
      )}
      {renamingSectionId && sectionBeingRenamed >= 0 && (() => {
        const name = sectionDisplayName(set.sections[sectionBeingRenamed], sectionBeingRenamed);
        return (
          <TextPromptDialog
            title="Rename Section"
            message="For example Verse, Chorus or Bridge."
            // Numbered default names ("Section 2") are left out so typing replaces them.
            initialValue={/^Section \d+$/.test(name) ? '' : name}
            placeholder={name}
            darkMode={darkMode}
            onCancel={() => setRenamingSectionId(null)}
            onConfirm={value => { onLibraryChange(renameSection(library, renamingSectionId, value)); setRenamingSectionId(null); }}
          />
        );
      })()}
      {deletingSectionId && (() => {
        const index = set.sections.findIndex(s => s.id === deletingSectionId);
        const name = index >= 0 ? sectionDisplayName(set.sections[index], index) : 'Section';
        return (
          <ConfirmDialog
            title={`Delete “${name}”?`}
            message="Its chords and scales will be removed. This can't be undone."
            darkMode={darkMode}
            onCancel={() => setDeletingSectionId(null)}
            onConfirm={() => { onLibraryChange(deleteSection(library, deletingSectionId)); setDeletingSectionId(null); }}
          />
        );
      })()}
    </div>
  );

  /** Dropping a chord here moves it to the end of the section; a section takes this one's place. */
  function sectionDropHandlers(sectionId: string) {
    return {
      onDragOver: (e: React.DragEvent) => e.preventDefault(),
      onDrop: (e: React.DragEvent) => {
        e.preventDefault();
        const payload = e.dataTransfer.getData('text/plain');
        if (payload.startsWith(CHORD_DRAG)) onLibraryChange(moveChordToSection(library, payload.slice(CHORD_DRAG.length), sectionId));
        else if (payload.startsWith(SECTION_DRAG)) onLibraryChange(moveSection(library, payload.slice(SECTION_DRAG.length), sectionId));
      },
    };
  }
}

/** One section: a header (name, loop, add, menu) over its chords. */
function SectionBlock(props: ChordSetPanelProps & {
  section: ChordSection; index: number; count: number;
  isCollapsed: boolean; onToggleCollapsed: () => void; onRename: () => void; onDelete: () => void;
}) {
  const { section, index, count, isCollapsed, onToggleCollapsed, onRename, onDelete, library, onLibraryChange, darkMode, loopingSectionId, onToggleSectionLoop, onOpenBank } = props;
  const [isDropTarget, setIsDropTarget] = useState(false);
  const name = sectionDisplayName(section, index);
  const isLooping = loopingSectionId === section.id;
  const chordCount = section.chords.filter(c => !isScale(c)).length;
  const canLoop = chordCount > 0 || isLooping;

  const smallButton = (enabled: boolean, active = false) => `w-[26px] h-6 flex items-center justify-center rounded-md transition-colors ${
    active ? 'bg-green-500 text-white hover:bg-green-600'
      : enabled ? darkMode ? 'text-zinc-400 hover:bg-zinc-700' : 'text-zinc-500 hover:bg-zinc-200'
        : darkMode ? 'text-zinc-600 cursor-not-allowed' : 'text-zinc-300 cursor-not-allowed'
  }`;

  return (
    <div
      className={`-m-1.5 p-1.5 rounded-lg border-[1.5px] ${isDropTarget ? 'border-blue-500/60 bg-blue-500/[0.08]' : 'border-transparent'}`}
      onDragOver={e => { e.preventDefault(); setIsDropTarget(true); }}
      onDragLeave={e => { if (!e.currentTarget.contains(e.relatedTarget as Node)) setIsDropTarget(false); }}
      onDrop={e => {
        e.preventDefault();
        setIsDropTarget(false);
        const payload = e.dataTransfer.getData('text/plain');
        if (payload.startsWith(CHORD_DRAG)) onLibraryChange(moveChordToSection(library, payload.slice(CHORD_DRAG.length), section.id));
        else if (payload.startsWith(SECTION_DRAG)) onLibraryChange(moveSection(library, payload.slice(SECTION_DRAG.length), section.id));
      }}
    >
      <div className="flex items-center gap-1">
        {/* Drag a section by its header to reorder. */}
        <button
          draggable
          onDragStart={e => { e.dataTransfer.setData('text/plain', SECTION_DRAG + section.id); e.dataTransfer.effectAllowed = 'move'; }}
          onClick={onToggleCollapsed}
          className="flex items-center gap-1.5 py-[3px] min-w-0"
          aria-label={`${name}, ${section.chords.length} items`}
          aria-expanded={!isCollapsed}
        >
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" className={`w-3 h-3 text-zinc-500 transition-transform ${isCollapsed ? '' : 'rotate-90'}`}>
            <path fillRule="evenodd" d="M7.21 14.77a.75.75 0 01.02-1.06L11.168 10 7.23 6.29a.75.75 0 111.04-1.08l4.5 4.25a.75.75 0 010 1.08l-4.5 4.25a.75.75 0 01-1.06-.02z" clipRule="evenodd" />
          </svg>
          <span className={`text-[13px] font-semibold truncate ${darkMode ? 'text-zinc-200' : 'text-zinc-700'}`}>{name}</span>
          {(isCollapsed || section.chords.length === 0) && (
            <span className={`text-[11px] font-medium ${darkMode ? 'text-zinc-500' : 'text-zinc-400'}`}>{section.chords.length}</span>
          )}
        </button>
        <div className="flex-1" />
        <button
          onClick={() => onToggleSectionLoop(section.id)}
          disabled={!canLoop}
          className={smallButton(canLoop, isLooping)}
          title={isLooping ? `Stop looping ${name}` : `Loop ${name}`}
        >
          {isLooping ? (
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" className="w-3 h-3"><rect x="5" y="5" width="10" height="10" rx="1.5" /></svg>
          ) : (
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" className="w-3.5 h-3.5">
              <path fillRule="evenodd" d="M12 5.25c1.213 0 2.415.046 3.605.135a3.256 3.256 0 013.01 3.01c.044.583.077 1.17.1 1.759L17.03 8.47a.75.75 0 10-1.06 1.06l3 3a.75.75 0 001.06 0l3-3a.75.75 0 00-1.06-1.06l-1.752 1.751c-.023-.65-.06-1.296-.108-1.939a4.756 4.756 0 00-4.392-4.392 49.422 49.422 0 00-7.436 0A4.756 4.756 0 003.89 8.282c-.017.224-.033.447-.046.672a.75.75 0 101.497.092c.013-.217.028-.432.044-.647a3.256 3.256 0 013.01-3.01c1.19-.09 2.392-.136 3.605-.136zm-6.97 6.22a.75.75 0 00-1.06 0l-3 3a.75.75 0 101.06 1.06l1.752-1.751c.023.65.06 1.296.108 1.939a4.756 4.756 0 004.392 4.392 49.413 49.413 0 007.436 0 4.756 4.756 0 004.392-4.392c.017-.223.032-.447.046-.672a.75.75 0 00-1.497-.092c-.013.217-.028.434-.044.647a3.256 3.256 0 01-3.01 3.01 47.953 47.953 0 01-7.21 0 3.256 3.256 0 01-3.01-3.01 47.759 47.759 0 01-.1-1.759L6.97 12.53a.75.75 0 001.06-1.06l-3-3z" clipRule="evenodd" />
            </svg>
          )}
        </button>
        <button onClick={() => onOpenBank(section.id)} className={smallButton(true)} title={`Add a chord or scale to ${name}`}>
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" className="w-3.5 h-3.5">
            <path d="M10.75 4.75a.75.75 0 00-1.5 0v4.5h-4.5a.75.75 0 000 1.5h4.5v4.5a.75.75 0 001.5 0v-4.5h4.5a.75.75 0 000-1.5h-4.5v-4.5z" />
          </svg>
        </button>
        <Menu
          darkMode={darkMode}
          align="right"
          direction="up"
          width="w-52"
          title="Section options"
          ariaLabel={`${name} options`}
          buttonClassName={smallButton(true)}
          label={<span className="text-base leading-none tracking-wider">···</span>}
        >
          {close => (
            <>
              <MenuItem darkMode={darkMode} onClick={() => { onRename(); close(); }}>Rename…</MenuItem>
              <MenuItem darkMode={darkMode} onClick={() => { onOpenBank(section.id); close(); }}>Add Chord or Scale</MenuItem>
              <MenuItem darkMode={darkMode} disabled={!canLoop} onClick={() => { onToggleSectionLoop(section.id); close(); }}>
                {isLooping ? 'Stop Loop' : 'Loop Section'}
              </MenuItem>
              <MenuDivider darkMode={darkMode} />
              <MenuItem darkMode={darkMode} disabled={index === 0} onClick={() => { onLibraryChange(shiftSection(library, section.id, -1)); close(); }}>Move Up</MenuItem>
              <MenuItem darkMode={darkMode} disabled={index === count - 1} onClick={() => { onLibraryChange(shiftSection(library, section.id, 1)); close(); }}>Move Down</MenuItem>
              <MenuDivider darkMode={darkMode} />
              <MenuItem darkMode={darkMode} destructive onClick={() => { onDelete(); close(); }}>Delete Section…</MenuItem>
            </>
          )}
        </Menu>
      </div>
      {!isCollapsed && (
        <div className="mt-1.5">
          <SectionChips {...props} />
        </div>
      )}
    </div>
  );
}

/** A section's chords and scales as chips: tap to select, drag to reorder or move between
 *  sections, right-click to move. */
function SectionChips(props: ChordSetPanelProps & { section: ChordSection }) {
  const { section, library, onLibraryChange, darkMode, isChipActive, chipClassName, chipTitle, onSelectChord, onDeleteChord } = props;
  const set = activeSet(library);
  const [dropTargetId, setDropTargetId] = useState<string | null>(null);
  const [menu, setMenu] = useState<{ chord: SavedChord; x: number; y: number } | null>(null);

  if (section.chords.length === 0) {
    return (
      <div className={`py-1 pl-[18px] text-[13px] ${darkMode ? 'text-zinc-500' : 'text-zinc-400'}`}>
        Drag chords here, or tap +
      </div>
    );
  }

  return (
    <div className="flex flex-wrap gap-2">
      {section.chords.map(chord => {
        const active = isChipActive(chord);
        const scale = isScale(chord);
        return (
          <div
            key={chord.id}
            draggable
            onDragStart={e => { e.dataTransfer.setData('text/plain', CHORD_DRAG + chord.id); e.dataTransfer.effectAllowed = 'move'; }}
            onDragOver={e => { e.preventDefault(); e.stopPropagation(); setDropTargetId(chord.id); }}
            onDragLeave={() => setDropTargetId(id => (id === chord.id ? null : id))}
            onDrop={e => {
              e.preventDefault();
              e.stopPropagation();
              setDropTargetId(null);
              const payload = e.dataTransfer.getData('text/plain');
              if (payload.startsWith(CHORD_DRAG)) onLibraryChange(moveChord(library, payload.slice(CHORD_DRAG.length), chord.id));
              else if (payload.startsWith(SECTION_DRAG)) onLibraryChange(moveSection(library, payload.slice(SECTION_DRAG.length), section.id));
            }}
            onClick={() => onSelectChord(chord)}
            onContextMenu={e => { e.preventDefault(); setMenu({ chord, x: e.clientX, y: e.clientY }); }}
            title={scale ? `Show ${chipTitle(chord)} on the instruments` : chord.name}
            className={`flex items-center gap-2 pl-3 pr-2 py-1.5 cursor-pointer select-none transition-colors ${
              scale ? 'rounded-[14px]' : 'rounded'
            } ${chipClassName(chord, active)} ${dropTargetId === chord.id ? 'ring-2 ring-blue-500' : ''}`}
          >
            <span className="flex items-center gap-1.5 text-sm font-medium whitespace-nowrap">
              {scale && (
                <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16" fill="currentColor" className="w-3 h-3 opacity-80">
                  <path d="M1 13h4v-3h3V7h3V4h4V2H9v3H6v3H3v3H1z" />
                </svg>
              )}
              {chipTitle(chord)}
            </span>
            <button
              onClick={e => { e.stopPropagation(); onDeleteChord(chord.id); }}
              className={`w-5 h-5 flex items-center justify-center rounded transition-colors ${
                active ? 'text-white/85 hover:bg-white/20' : darkMode ? 'text-zinc-400 hover:bg-zinc-400/20' : 'text-zinc-500 hover:bg-zinc-500/20'
              }`}
              title={scale ? 'Delete scale' : 'Delete chord'}
              aria-label={`Delete ${chipTitle(chord)}`}
            >
              <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" className="w-3 h-3">
                <path d="M6.28 5.22a.75.75 0 00-1.06 1.06L8.94 10l-3.72 3.72a.75.75 0 101.06 1.06L10 11.06l3.72 3.72a.75.75 0 101.06-1.06L11.06 10l3.72-3.72a.75.75 0 00-1.06-1.06L10 8.94 6.28 5.22z" />
              </svg>
            </button>
          </div>
        );
      })}
      {menu && (
        <ContextMenu x={menu.x} y={menu.y} darkMode={darkMode} onClose={() => setMenu(null)}>
          <MenuItem darkMode={darkMode} disabled={!canShiftChord(set, menu.chord.id, -1)} onClick={() => { onLibraryChange(shiftChord(library, menu.chord.id, -1)); setMenu(null); }}>Move Left</MenuItem>
          <MenuItem darkMode={darkMode} disabled={!canShiftChord(set, menu.chord.id, 1)} onClick={() => { onLibraryChange(shiftChord(library, menu.chord.id, 1)); setMenu(null); }}>Move Right</MenuItem>
          {set.sections.length > 1 && (
            <>
              <MenuDivider darkMode={darkMode} />
              {set.sections.map((other, i) => other.id !== section.id && (
                <MenuItem key={other.id} darkMode={darkMode} onClick={() => { onLibraryChange(moveChordToSection(library, menu.chord.id, other.id)); setMenu(null); }}>
                  Move to {sectionDisplayName(other, i)}
                </MenuItem>
              ))}
            </>
          )}
          <MenuDivider darkMode={darkMode} />
          <MenuItem darkMode={darkMode} destructive onClick={() => { onDeleteChord(menu.chord.id); setMenu(null); }}>
            {isScale(menu.chord) ? 'Delete Scale' : 'Delete Chord'}
          </MenuItem>
        </ContextMenu>
      )}
    </div>
  );
}
