# DODS Global – SourceMod Plugins

![SourceMod](https://img.shields.io/badge/SourceMod-1.11%2B-blue)
![Game](https://img.shields.io/badge/Game-Day%20of%20Defeat%3A%20Source-orange)
![Status](https://img.shields.io/badge/Status-Stable-green)
![License](https://img.shields.io/badge/License-MIT-lightgrey)

A small collection of **SourceMod plugins** developed for the **DODS Global** community, focused on improving competitive integrity in **Day of Defeat: Source**.

![Banner](https://i.ibb.co/SDRxtqCH/Youtube-Banner.jpg)

---

## Plugins

### blockrespawnswitch
Prevents players from forcing a respawn by switching teams/class during an active round.  
Designed to stop round abuse and enforce fair play in competitive matches.

**Technical Details**
The plugin uses `SDKHook_PreThink` to monitor player inputs every server tick (66 tick servers). It:

1. **Tracks button press order**: Detects whether Sprint or Forward was pressed first
2. **Monitors stamina recovery**: Flags when a player's stamina reaches 100%
3. **Applies penalty**: If the exploit pattern is detected, forces stamina to drop on next sprint activation

**Performance**
- **CPU Usage**: < 0.01% on servers with up to 32 players
- **Memory**: ~16 bytes per player
- **Network**: No additional network traffic
- **Optimized**: Uses native Source Engine functions for maximum efficiency



### sprintblock
Blocks or restricts sprint usage to align movement mechanics with competitive or custom rule sets.

---

## Requirements

- Day of Defeat: Source Server
- SourceMod 1.11 or newer  
- Metamod:Source

---

## Installation

1. Use precompiled `.smx` or compile the `.sp`
2. Upload to: `addons/sourcemod/plugins/`
3. Restart the server or load the plugins manually

---

## License

MIT License

---

## Community

Developed for the **DODS Global** community.  
Issues and pull requests are welcome.
