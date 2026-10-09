# Changelog - Bleakfiber's Chat (Forever)

All notable changes to **Bleakfiber's Chat - Forever** are documented below.

## [1.0.1] - 2026-10-09: Phase 2 URL Detection & Copy Dialog Enhancements

### Added
- **Bulletproof URL Detection Engine**: Token-based parser supporting web protocols (`http://`, `https://`, `ftp://`), `www.` prefixes, Discord invites (`discord.gg/`), and all top-level domains (`.com`, `.org`, `.net`, `.io`, `.gg`, `.tv`, `.app`, etc.).
- **Smart Punctuation & Parentheses Trimming**: Automatically trims trailing sentence punctuation (`.`, `,`, `!`, `?`, `;`, `:`) and enclosing brackets/quotes, while intelligently preserving balanced parentheses for complex query strings and Wikipedia links.
- **Hyperlink Preservation Pipeline**: Temporarily shields existing game item, spell, quest, and player links (`|H...|h...|h`) before URL parsing, eliminating corrupted nested markup and double replacements.
- **Interactive Shift-Click URL Insertion**: Shift-clicking any URL link in chat automatically inserts the raw URL directly into your active chat edit box (mirroring standard item link behavior).
- **Interactive URL Copy Dialog**: Clean Dark Slate & Gold modal popup with auto-focus, text pre-selection, single-click re-selection (`OnMouseUp`), and instant `Ctrl + C` copy workflow.
- **Full Chat Log Copy Dialog**: Scrollable multi-line dialog with dynamic content height recalculation, mousewheel scrolling, window resizing grip, and "Select All" button.
- **Plain-Text Formatting Cleaner**: Automatically strips chat color codes (`|c...|r`) and textures while formatting hyperlinks into clean text for external pasting.
- **Temporary Window & Whisper Tab Synchronization**: Auto-hooks `FCF_OpenTemporaryWindow` and `FCF_OpenNewWindow` so newly created whisper tabs immediately receive copy buttons, smooth scrolling, typography, and link handlers.
- **UI Customization Options**: Added URL Accent Color picker in General options and Copy Button toggle in Layout & Style settings.

## [1.0.0] - 2026-10-09: Phase 1 Foundation & Architecture

### Added
- **Core Chat Management Architecture (`Core.lua`, `Config.lua`, `UI.lua`)**: High-performance modular architecture engineered for Interface 16001.
- **Whispers in New Window by Default (`whisperWindow = true`)**: Automatic dedicated tab routing for incoming and outgoing whisper messages with notification highlight pulses.
- **Universal Player Class Color Names (`classColorNames = true`)**: Real-time class color resolution across all chat channels, whispers, and raid/party communications.
- **Persistent Chat & Command History**: Circular SavedVariables buffer preserving chat lines across reload and relogs with subtle session divider timestamps.
- **EditBox Modernization & Docking**: Bottom or Top docking options, sticky channel memory, and Dark Slate & Gold backdrop skinning.
- **Dual-Mode Configuration & Master Hub Integration**: Seamless runtime embed into `BleakfibersAddonConfig-Forever` with non-destructive profile capture and dynamic 2-column reflow.
