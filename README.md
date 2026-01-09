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

- ✅ Blocks immediate respawn when changing class in spawn areas
- ✅ Works for both Allied and Axis teams
- ✅ Respects server class limits (mp_limit_* cvars)
- ✅ Shows "You will respawn as [class]" message to players


### sprintblock
Blocks or restricts sprint usage to align movement mechanics with competitive or custom rule sets.

The plugin uses `SDKHook_PreThink` to monitor player inputs every server tick (66 tick servers). It:

1. **Tracks button press order**: Detects whether Sprint or Forward was pressed first
2. **Monitors stamina recovery**: Flags when a player's stamina reaches 100%
3. **Applies penalty**: If the exploit pattern is detected, forces stamina to drop on next sprint activation

**Performance**
- **CPU Usage**: < 0.01% on servers with up to 32 players
- **Memory**: ~16 bytes per player
- **Network**: No additional network traffic
- **Optimized**: Uses native Source Engine functions for maximum efficiency

### dodsg_ftb
A modern SourceMod plugin for Day of Defeat: Source that implements a realistic "Fade to Black" effect when players die.

✅ Instant black screen fade on death
✅ Configurable fade speed and duration
✅ Customizable RGB colors
✅ Auto-enables on installation
✅ Optimized performance (unhooks when disabled)

**Available Commands**
```
dodsg_ftb_enabled 1      // Enable/disable plugin (default: 1)
dodsg_ftb_speed 0.5      // Fade transition speed in seconds (default: 0.5) (0.1 = very fast, 2.0 = slow)
dodsg_ftb_delay 3.0      // Duration to stay black in seconds (default: 3.0)
dodsg_ftb_red 0          // Red color value 0-255 (default: 0)
dodsg_ftb_green 0        // Green color value 0-255 (default: 0)
dodsg_ftb_blue 0         // Blue color value 0-255 (default: 0)
dodsg_ftb_alpha 255      // Transparency 0-255 (default: 255)
```

---

## Requirements

- Day of Defeat: Source Dedicated Server
- [SourceMod](https://www.sourcemod.net/) 1.11 or newer
- [Metamod:Source](https://www.sourcemm.net/)

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

Developed for the [**DODS Global**](https://dodsglobal.com/league) community.
Feel free to join them on [discord](https://discord.com/invite/B8z3vrYxHP).

Issues and pull requests are welcome.
