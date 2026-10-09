# Changelog - Bleakfiber's Chat (Forever)

All notable changes to **Bleakfiber's Chat - Forever** are documented below.

## [1.0.0] - 2026-10-09: Phase 1 Foundation & Architecture

### Added
- **Core Chat Management Architecture (`Core.lua`, `Config.lua`, `UI.lua`)**: High-performance modular architecture engineered for Interface 16001.
- **Whispers in New Window by Default (`whisperWindow = true`)**: Automatic dedicated tab routing for incoming and outgoing whisper messages with notification highlight pulses.
- **Universal Player Class Color Names (`classColorNames = true`)**: Real-time class color resolution across all chat channels, whispers, and raid/party communications.
- **Interactive Link Clicking & URL Copying (`CopyFrame.lua`)**: Regex URL detection filter transforming web links into interactive hyperlinks with lightweight `Ctrl + C` copy dialogs.
- **Persistent Chat & Command History**: Circular SavedVariables buffer preserving chat lines across reload and relogs with subtle session divider timestamps.
- **EditBox Modernization & Docking**: Bottom or Top docking options, sticky channel memory, and Dark Slate & Gold backdrop skinning.
- **Dual-Mode Configuration & Master Hub Integration**: Seamless runtime embed into `BleakfibersAddonConfig-Forever` with non-destructive profile capture and dynamic 2-column reflow.
