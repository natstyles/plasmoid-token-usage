# Token Usage

A Plasma 6 widget that monitors the usage of your AI subscriptions (Claude, ChatGPT, and Gemini). It displays your session and weekly usage percentages, a countdown until your quotas reset, historical usage charts, and a detailed breakdown of Claude's weekly usage.

![Panel View](screenshots/panel.png)

![Popup View](screenshots/popup.png)

![Appearance Settings](screenshots/appearance.png)

## Features
- **Compact Panel View**: Choose between double rings, a single ring, or just a logo and percentage.
- **Detailed Popup**: View colored cards for each provider with full details.
- **Alerts & Notifications**: Get notified when you reach warning/critical thresholds or when your quotas are reloaded.
- **Usage History**: Chart your token usage over the last 6, 24, 72, or 168 hours.

## Requirements
- **Plasma 6**
- `python3`
- `python-gobject` (required for the color picker)
- `pw-play` (PipeWire) or `paplay` (PulseAudio) for notification sounds.
- `ss` (iproute2) for reading Gemini status.
- By default, it uses the Ocean sound theme (`/usr/share/sounds/ocean/`). If you don't have it, you can select custom sounds in the widget settings.

## Providers
This widget reads the sessions you already have active in other CLI tools on your system. **It relies on unofficial APIs, which may break if the providers change them.**

| Provider | Data Source | Notes |
|---|---|---|
| **Claude** | `~/.claude/.credentials.json` | Renews the OAuth token automatically when expired, **but only if Claude Code is closed**; otherwise it waits for Claude Code to do it. The renewed token is **written back to `~/.claude/.credentials.json`** (same file, permissions `600`), because the refresh token rotates and Claude Code must keep the valid one. |
| **Gemini** | Antigravity local language server | Requires Antigravity to be running. If closed, it displays the last known data. |
| **ChatGPT** | Codex CLI | *Experimental*. Reads `~/.codex/auth.json` and `~/.codex/sessions`. |

## Privacy
- **Everything stays on your machine**, except for the direct API calls to each provider to fetch your usage.
- History and the last known values are saved locally in `~/.local/share/aiusage/`.
- The only file outside its own folders that the widget writes to is `~/.claude/.credentials.json`, when it renews the Claude token (see above).
- No analytics, telemetry, or data is sent to any third party.

## Installation
**Option A: From the [KDE Store](https://www.opendesktop.org/p/2377168/) (Recommended)**
Right-click on your desktop or panel -> "Add Widgets..." -> "Get New Widgets..." -> Search for "Token Usage".

On first launch the widget registers its notifications and its icon in `~/.local/share/`. Until it has run once, "Add Widgets" may show a generic icon.

**Option B: Manual Installation**
Clone this repository and run the installation script:
```bash
git clone https://github.com/natstyles/plasmoid-token-usage.git
cd plasmoid-token-usage
./install.sh
```

## Translations
The widget's base language is English, and it is fully translated into Spanish. To add a new language, use the scripts in the `translate/` directory.

## Trademarks
Claude, ChatGPT, and Gemini are trademarks of Anthropic, OpenAI, and Google respectively. This project is not affiliated with them. The default icons are original drawings; you can replace them with any image in the widget's settings.

## License
[GPL-3.0-or-later](LICENSE)
