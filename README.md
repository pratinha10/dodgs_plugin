# DODS Global – SourceMod Plugins

![SourceMod](https://img.shields.io/badge/SourceMod-1.11%2B-blue)
![Game](https://img.shields.io/badge/Game-Day%20of%20Defeat%3A%20Source-orange)
![Status](https://img.shields.io/badge/Status-Stable-green)
![License](https://img.shields.io/badge/License-MIT-lightgrey)

A small collection of **SourceMod plugins** developed for the **DODS Global** community, focused on improving competitive integrity in **Day of Defeat: Source**.

![Banner](https://i.ibb.co/SDRxtqCH/Youtube-Banner.jpg)

---

## Plugins

### 💽 blockrespawnswitch
Prevents players from forcing a respawn by switching teams/class during an active round.  
Designed to stop round abuse and enforce fair play in competitive matches.

- ✅ Blocks immediate respawn when changing class in spawn areas
- ✅ Works for both Allied and Axis teams
- ✅ Respects server class limits (mp_limit_* cvars)
- ✅ Shows "You will respawn as [class]" message to players

### 💽 sprintblock
Blocks or restricts sprint usage to align movement mechanics with competitive or custom rule sets.

The plugin uses `SDKHook_PreThink` to monitor player inputs every server tick (66 tick servers). It:

1. **Tracks button press order**: Detects whether Sprint or Forward was pressed first
2. **Monitors stamina recovery**: Flags when a player's stamina reaches 100%
3. **Applies penalty**: If the exploit pattern is detected, forces stamina to drop on next sprint activation

### 💽 dodsg_firstpersoncam (Forces First Person POV while dead)
This plugin enhances the spectator experience by automatically forcing first-person camera when observing teammates after death. Players can still switch between teammates normally, but the view is locked to first-person perspective.

- ✅ Automatic first-person view when observing teammates
- ✅ 5 second delay after death before forcing the camera mode
- ✅ Players can freely switch between teammates
- ✅ Prevents switching to third-person or free-look modes
- ✅ Lightweight and optimized performance

**Recommended Server Configuration**
Add `dod_freezecam 0` to your `server.cfg` to disable the default killcam.

### 💽 dodsg_ftb (Fade to Black)
A modern SourceMod plugin for Day of Defeat: Source that implements a realistic "Fade to Black" effect when players die.

- ✅ Instant black screen fade on death
- ✅ Configurable fade speed and duration
- ✅ Customizable RGB colors
- ✅ Auto-enables on installation
- ✅ Optimized performance (unhooks when disabled)

**Available Commands**
```
dodsg_ftb_enabled 1      // Enable/disable plugin (default: 1)
dodsg_ftb_speed 0.5      // Fade transition speed in seconds (default: 0.5) (0.1 = very fast, 2.0 = slow)
dodsg_ftb_delay 5.0      // Duration to stay black in seconds (default: 5.0)
dodsg_ftb_red 0          // Red color value 0-255 (default: 0)
dodsg_ftb_green 0        // Green color value 0-255 (default: 0)
dodsg_ftb_blue 0         // Blue color value 0-255 (default: 0)
dodsg_ftb_alpha 255      // Transparency 0-255 (default: 255)
```
**Credits**
- [Original plugin](https://forums.alliedmods.net/showthread.php?t=73173) `sm_dod_ftb` by <eVa>Dog

### 💽 dodsg_cvarenforcer (CVAR Checker/Enforcer)
SourceMod plugin for Day of Defeat: Source that monitors and enforces client console variable rules.

- ✅ Automatic CVar monitoring at configurable intervals
- ✅ Warning system with multiple chances before punishment
- ✅ Public violation alerts visible to all players
- ✅ Auto-enables on installation
- ✅ Immediate verification when players join
- ✅ Configurable kick or ban punishments

**Server ConVars/Commands**
```
sm_dodsg_timer "10.0"  // Check interval in seconds (default: 10.0)
sm_dodsg_warn "5"      // Warnings before punishment (default: 5)
sm_dodsg_check <name|#userid>  // Manually check player CVars
```
**CVar Rules**
Check examples and edit you way @`addons/sourcemod/configs/dodsg_cvar_checker.cfg`:
```
"cvar"
{
    "r_shadows"
    {
        "value"      "0"
        "mode"       "0"
        "punishment" "1"
        "bantime"    "0"
    }
}
```
**Validation Modes**
- Mode 0: Must equal exact value
- Mode 1: Must NOT equal value
- Mode 2: Must be within range (requires `min` and `max`)
- Mode 3: Must be less than or equal to value
- Mode 4: Must be greater than or equal to value

**Credits**
- [Original plugin](https://forums.alliedmods.net/showthread.php?p=2529748) `Client-Convar-Checker` by Kento
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
