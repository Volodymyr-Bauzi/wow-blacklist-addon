# Blacklist by Vovo

A World of Warcraft TBC Anniversary (2.5.4) addon that lets you maintain a persistent blacklist of players with custom warning reasons. When a blacklisted player joins your group, you get an alert banner and an automatic chat message.

## Features

- **Reason library** — create named warning reasons with a custom message template  
- **Blacklist** — assign a reason to any player; account-wide (all your alts share it)  
- **Auto-alert** — banner popup + chat message whenever a blacklisted player joins your group  
- **`{{username}}` placeholder** — message templates auto-fill the player's name  
- **Chat context menu** — right-click any player name to add/remove from blacklist instantly  
- **Settings tab** — global output channel, window scale, alert duration, sound toggle  
- **Minimap button** — LDB/LibDBIcon compatible with manual fallback  

## Slash Commands

| Command | Action |
|---------|--------|
| `/bv` | Open / close the window |
| `/bv minimap` | Toggle minimap button |
| `/bv help` | Print all commands |

## Installation

### Manual
1. Download the latest release zip
2. Extract to `World of Warcraft\_anniversary_\Interface\AddOns\`
3. The folder must be named **`blacklist by Vovo`** (with spaces)
4. Reload WoW (`/reload`) or log in

### CurseForge / Wago
Install via the CurseForge or Wago app — search for **Blacklist by Vovo**.

## Compatibility

- **Game version**: TBC Anniversary (Interface 20504 / patch 2.5.4)
- **Dependencies**: None (LibDataBroker + LibDBIcon are optional for the minimap button)

## Usage

1. Open the addon (`/bv`)
2. **Reasons tab** — click `+ Add Reason`, give it a name and optional message (use `{{username}}` for the player name)
3. **Blacklisted Players tab** — click `+ Add Player`, enter the name, choose a reason
4. **Settings tab** — pick the output channel, adjust scale/duration, toggle sound

When a blacklisted player joins your party or raid, you'll see an alert banner and the message is sent to the configured channel automatically.

## License

MIT
