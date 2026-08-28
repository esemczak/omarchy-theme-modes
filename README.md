# omarchy-theme-modes

Separate **light** and **dark** Omarchy themes with per-mode backgrounds, manual switching, and optional automatic mode by schedule or battery.

![Panel — General tab](docs/screenshots/panel-general.svg)

Pick different themes for day and night, choose a background for each, and switch with one click — or let Omarchy follow the clock or power source.

![Light theme picker](docs/screenshots/panel-light-themes.svg)

> **Note:** Configure themes and backgrounds in this plugin's panel. Omarchy's native theme/background switchers do not update these presets (by design — no polling, no global hooks).

## Features

- **Dual presets** — independent light and dark theme + background pairs
- **Tabbed panel** — General · Light themes · Dark themes
- **Theme carousel** — infinite scroll, size highlights selection, debounced apply
- **Background picker** — thumbnails for each theme's bundled backgrounds
- **Panel preview** — active theme background fades in from the top-right
- **Manual mode** — pick light or dark yourself
- **Automatic mode** — schedule (light/dark times) or battery (dark on battery, light on power)
- **Bar shortcuts**
  - **Left-click** — open panel
  - **Right-click** — toggle light ↔ dark (applies saved theme + background)
  - **Middle-click** — follow automatic rules

## Requirements

- [Omarchy](https://omarchy.org) with shell plugin support
- `jq`, `bash`, standard Omarchy theme tools (`omarchy theme`, `omarchy theme bg`)

## Install

### From git (recommended)

```bash
omarchy plugin add https://github.com/esemczak/omarchy-theme-modes.git --enable --yes
omarchy restart shell
```

Replace the URL with your repository after publishing.

### Manual copy

```bash
git clone https://github.com/esemczak/omarchy-theme-modes.git \
  ~/.config/omarchy/plugins/esemczak.theme-modes

omarchy plugin validate ~/.config/omarchy/plugins/esemczak.theme-modes
omarchy plugin enable esemczak.theme-modes --section right
omarchy restart shell
```

### Validate before publishing

```bash
omarchy plugin validate ./omarchy-theme-modes
```

## Usage

1. Click the bar icon (sun/moon) to open the panel.
2. **General** — set current mode, manual vs automatic, schedule or battery rules.
3. **Light themes** / **Dark themes** — scroll the carousel to pick a theme; click a background thumbnail below.
4. **Right-click** the bar icon anytime to flip between your saved light and dark setups.

Settings persist in:

```
~/.local/state/omarchy/settings/theme-modes.json
```

## IPC

Target: `esemczak.theme-modes`

```bash
omarchy-shell esemczak.theme-modes toggle          # toggle mode manually
omarchy-shell esemczak.theme-modes followAutomatic # switch to automatic
omarchy-shell esemczak.theme-modes status          # JSON status
```

## Project layout

```
omarchy-theme-modes/
├── manifest.json      # Plugin metadata (id: esemczak.theme-modes)
├── Panel.qml          # Bar widget + panel UI
├── Service.qml        # State, theme apply, auto timers
├── Model.js           # State parse/serialize, auto logic
├── catalog.sh         # Theme list + preview paths
├── backgrounds.sh     # Background list for a theme slug
├── docs/screenshots/  # Replace SVG previews with PNG captures
├── LICENSE
└── CHANGELOG.md
```

## Screenshots

SVG previews ship for GitHub rendering. For real captures, see [docs/screenshots/README.md](docs/screenshots/README.md).

| Preview | Description |
|---------|-------------|
| [panel-general.svg](docs/screenshots/panel-general.svg) | General tab |
| [panel-light-themes.svg](docs/screenshots/panel-light-themes.svg) | Light theme + backgrounds |
| [bar-icon.svg](docs/screenshots/bar-icon.svg) | Bar widget tooltip |

## Development

The plugin hot-reloads when files under `~/.config/omarchy/plugins/` are saved. Otherwise:

```bash
omarchy restart shell
```

Test validation after changes:

```bash
omarchy plugin validate ~/.config/omarchy/plugins/esemczak.theme-modes
```

## License

MIT — see [LICENSE](LICENSE).

## Author

esemczak
