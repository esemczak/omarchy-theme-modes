# Changelog

All notable changes to this project will be documented in this file.

## [1.0.0] - 2026-08-28

### Added

- Bar widget with tabbed panel: General, Light themes, Dark themes
- Separate light and dark theme presets with per-mode background selection
- Infinite theme carousel with size-based selection and floating nav orbs
- Panel background preview from the active theme/background
- Manual light/dark switching and automatic mode (schedule or battery)
- Battery rule info card (dark on battery, light on power)
- Right-click bar icon to toggle modes; middle-click to follow automatic
- IPC target `esemczak.theme-modes` for shell integration
- Root `preview.png` for marketplace listings
- Real desktop screenshots in `docs/screenshots/`
- Publishing documentation: install, remove, dependencies, security notes

### Notes

- Theme and background are configured through this plugin's panel, not Omarchy's native switchers
- Plugin state is stored in `~/.local/state/omarchy/settings/theme-modes.json`
- No global hooks, polling, or system-wide configuration required
