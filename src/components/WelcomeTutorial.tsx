'use client';

interface WelcomeTutorialProps {
  isOpen: boolean;
  onClose: () => void;
  darkMode?: boolean;
}

export default function WelcomeTutorial({
  isOpen,
  onClose,
  darkMode = false,
}: WelcomeTutorialProps) {
  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center">
      {/* Backdrop */}
      <div
        className="absolute inset-0 bg-black/50"
        onClick={onClose}
      />

      {/* Dialog */}
      <div className={`relative rounded-[16px] shadow-xl w-full max-w-2xl mx-8 min-[480px]:mx-4 max-h-[90vh] flex flex-col ${
        darkMode ? 'bg-zinc-800 text-zinc-100' : 'bg-white text-zinc-900'
      }`}>
        {/* Sticky header */}
        <div className={`sticky top-0 z-10 flex items-center justify-between p-6 pb-4 rounded-t-[16px] ${
          darkMode ? 'bg-zinc-800' : 'bg-white'
        }`}>
          <div>
            <h2 className="text-xl font-bold">Welcome to Frets 2 Keys</h2>
            <p className={`text-sm ${darkMode ? 'text-zinc-400' : 'text-zinc-500'}`}>
              Created by Matt Gibson in 2026
            </p>
          </div>
          <button
            onClick={onClose}
            className={`p-1.5 rounded transition-colors ${
              darkMode
                ? 'hover:bg-zinc-700 text-zinc-400 hover:text-zinc-200'
                : 'hover:bg-zinc-100 text-zinc-400 hover:text-zinc-600'
            }`}
          >
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" className="w-5 h-5">
              <path d="M6.28 5.22a.75.75 0 00-1.06 1.06L8.94 10l-3.72 3.72a.75.75 0 101.06 1.06L10 11.06l3.72 3.72a.75.75 0 101.06-1.06L11.06 10l3.72-3.72a.75.75 0 00-1.06-1.06L10 8.94 6.28 5.22z" />
            </svg>
          </button>
        </div>

        {/* Scrollable content */}
        <div className="overflow-y-auto px-6 pb-6 pt-2 space-y-6">
          {/* Introduction */}
          <p className={`text-sm leading-relaxed ${darkMode ? 'text-zinc-300' : 'text-zinc-600'}`}>
            This app allows you to visually translate chords from piano to a stringed instrument, like guitar by interacting with either instrument. You can hear notes/chords, save them, transpose them, and also view different major/minor keys to help learn chords/notes within those keys.
          </p>

          {/* Setting up the interface */}
          <div>
            <h3 className={`text-base font-semibold mb-2 ${darkMode ? 'text-zinc-200' : 'text-zinc-800'}`}>
              Setting up the interface
            </h3>
            <p className={`text-sm leading-relaxed ${darkMode ? 'text-zinc-300' : 'text-zinc-600'}`}>
              You can choose to have anywhere from 0, to 2 stringed instruments. Each stringed instruments tuning, number of strings, and applying a capo, can be configured in the settings menu in the top right.
            </p>
          </div>

          {/* Keys */}
          <div>
            <h3 className={`text-base font-semibold mb-2 ${darkMode ? 'text-zinc-200' : 'text-zinc-800'}`}>
              Keys
            </h3>
            <p className={`text-sm leading-relaxed ${darkMode ? 'text-zinc-300' : 'text-zinc-600'}`}>
              You can choose to select a major/minor key from the menu in the top left to have notes highlighted for that selected key. You can also choose how those notes will be displayed by going to the settings. You can hide notes outside of the key. You can also select "No key" and it will show all the notes without any highlighting.
            </p>
          </div>

          {/* Core Actions */}
          <div>
            <h3 className={`text-base font-semibold mb-2 ${darkMode ? 'text-zinc-200' : 'text-zinc-800'}`}>
              Core Actions
            </h3>
            <p className={`text-sm mb-3 ${darkMode ? 'text-zinc-300' : 'text-zinc-600'}`}>
              Once you have selected one or more notes there are several actions you can do:
            </p>
            <ul className="space-y-3">
              {/* Clear selection */}
              <li className="flex items-center gap-3">
                <div className={`w-8 h-8 flex items-center justify-center rounded-lg flex-shrink-0 ${
                  darkMode ? 'bg-zinc-700' : 'bg-zinc-100'
                }`}>
                  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" className={`w-5 h-5 ${darkMode ? 'text-zinc-400' : 'text-zinc-500'}`}>
                    <path d="M6.28 5.22a.75.75 0 00-1.06 1.06L8.94 10l-3.72 3.72a.75.75 0 101.06 1.06L10 11.06l3.72 3.72a.75.75 0 101.06-1.06L11.06 10l3.72-3.72a.75.75 0 00-1.06-1.06L10 8.94 6.28 5.22z" />
                  </svg>
                </div>
                <span className={`text-sm ${darkMode ? 'text-zinc-300' : 'text-zinc-600'}`}>
                  Clear your selection of notes.
                </span>
              </li>

              {/* Save as new chord */}
              <li className="flex items-center gap-3">
                <div className={`w-8 h-8 flex items-center justify-center rounded-lg flex-shrink-0 ${
                  darkMode ? 'bg-zinc-700' : 'bg-zinc-100'
                }`}>
                  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" className={`w-5 h-5 ${darkMode ? 'text-zinc-400' : 'text-zinc-500'}`}>
                    <path d="M10.75 4.75a.75.75 0 00-1.5 0v4.5h-4.5a.75.75 0 000 1.5h4.5v4.5a.75.75 0 001.5 0v-4.5h4.5a.75.75 0 000-1.5h-4.5v-4.5z" />
                  </svg>
                </div>
                <span className={`text-sm ${darkMode ? 'text-zinc-300' : 'text-zinc-600'}`}>
                  Save as a new chord.
                </span>
              </li>

              {/* Update saved chord */}
              <li className="flex items-center gap-3">
                <div className={`w-8 h-8 flex items-center justify-center rounded-lg flex-shrink-0 ${
                  darkMode ? 'bg-zinc-700' : 'bg-zinc-100'
                }`}>
                  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" className={`w-5 h-5 ${darkMode ? 'text-zinc-400' : 'text-zinc-500'}`}>
                    <path fillRule="evenodd" d="M16.704 4.153a.75.75 0 01.143 1.052l-8 10.5a.75.75 0 01-1.127.075l-4.5-4.5a.75.75 0 011.06-1.06l3.894 3.893 7.48-9.817a.75.75 0 011.05-.143z" clipRule="evenodd" />
                  </svg>
                </div>
                <span className={`text-sm ${darkMode ? 'text-zinc-300' : 'text-zinc-600'}`}>
                  Update a previously saved chord.
                </span>
              </li>

              {/* Transpose */}
              <li className="flex items-center gap-3">
                <div className={`w-8 h-8 flex items-center justify-center rounded-lg flex-shrink-0 ${
                  darkMode ? 'bg-zinc-700' : 'bg-zinc-100'
                }`}>
                  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" className={`w-5 h-5 ${darkMode ? 'text-zinc-400' : 'text-zinc-500'}`}>
                    <path fillRule="evenodd" d="M10 17a.75.75 0 01-.75-.75V5.612L5.29 9.77a.75.75 0 01-1.08-1.04l5.25-5.5a.75.75 0 011.08 0l5.25 5.5a.75.75 0 11-1.08 1.04l-3.96-4.158V16.25A.75.75 0 0110 17z" clipRule="evenodd" />
                  </svg>
                </div>
                <span className={`text-sm ${darkMode ? 'text-zinc-300' : 'text-zinc-600'}`}>
                  Transpose notes up/down.
                </span>
              </li>

              {/* Play */}
              <li className="flex items-center gap-3">
                <div className={`w-8 h-8 flex items-center justify-center rounded-lg flex-shrink-0 ${
                  darkMode ? 'bg-zinc-700' : 'bg-zinc-100'
                }`}>
                  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" className={`w-5 h-5 ${darkMode ? 'text-zinc-400' : 'text-zinc-500'}`}>
                    <path fillRule="evenodd" d="M4.5 5.653c0-1.426 1.529-2.33 2.779-1.643l11.54 6.348c1.295.712 1.295 2.573 0 3.285L7.28 19.991c-1.25.687-2.779-.217-2.779-1.643V5.653z" clipRule="evenodd" />
                  </svg>
                </div>
                <span className={`text-sm ${darkMode ? 'text-zinc-300' : 'text-zinc-600'}`}>
                  Play the chord once.
                </span>
              </li>

              {/* Loop */}
              <li className="flex items-center gap-3">
                <div className={`w-8 h-8 flex items-center justify-center rounded-lg flex-shrink-0 ${
                  darkMode ? 'bg-zinc-700' : 'bg-zinc-100'
                }`}>
                  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" className={`w-5 h-5 ${darkMode ? 'text-zinc-400' : 'text-zinc-500'}`}>
                    <path fillRule="evenodd" d="M12 5.25c1.213 0 2.415.046 3.605.135a3.256 3.256 0 013.01 3.01c.044.583.077 1.17.1 1.759L17.03 8.47a.75.75 0 10-1.06 1.06l3 3a.75.75 0 001.06 0l3-3a.75.75 0 00-1.06-1.06l-1.752 1.751c-.023-.65-.06-1.296-.108-1.939a4.756 4.756 0 00-4.392-4.392 49.422 49.422 0 00-7.436 0A4.756 4.756 0 003.89 8.282c-.017.224-.033.447-.046.672a.75.75 0 101.497.092c.013-.217.028-.432.044-.647a3.256 3.256 0 013.01-3.01c1.19-.09 2.392-.136 3.605-.136zm-6.97 6.22a.75.75 0 00-1.06 0l-3 3a.75.75 0 101.06 1.06l1.752-1.751c.023.65.06 1.296.108 1.939a4.756 4.756 0 004.392 4.392 49.413 49.413 0 007.436 0 4.756 4.756 0 004.392-4.392c.017-.223.032-.447.046-.672a.75.75 0 00-1.497-.092c-.013.217-.028.434-.044.647a3.256 3.256 0 01-3.01 3.01 47.953 47.953 0 01-7.21 0 3.256 3.256 0 01-3.01-3.01 47.759 47.759 0 01-.1-1.759L6.97 12.53a.75.75 0 001.06-1.06l-3-3z" clipRule="evenodd" />
                  </svg>
                </div>
                <span className={`text-sm ${darkMode ? 'text-zinc-300' : 'text-zinc-600'}`}>
                  Play chords continuously in a loop.
                </span>
              </li>
            </ul>
          </div>
        </div>
      </div>
    </div>
  );
}
