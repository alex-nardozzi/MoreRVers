# MoreRVers - Multiplayer Expansion Mod for RV There Yet?

![Version](https://img.shields.io/badge/version-1.1.0-blue)
![Game](https://img.shields.io/badge/game-RV%20There%20Yet%3F-orange)
![Modloader](https://img.shields.io/badge/modloader-UE4SS-purple)

A runtime mod that increases the multiplayer player cap beyond the default 4-player limit for RV There Yet.

**Only the host needs to install the mod.**

## Overview

This mod patches the game's multiplayer cap at runtime, allowing you to host sessions with more than the default 4 players. The modification uses UE4SS for runtime patching without requiring binary editing or permanent game file changes.

## Features

- **Simple Configuration** - Single-value INI file configuration
- **Host-Only Requirement** - Clients do not require mod installation
- **Non-Destructive** - No permanent game file modifications
- **Flexible Limits** - Configurable player count from 1-24
- **Runtime Patching** - Applied immediately upon session creation

## Installation

Two installation packages are available with each release. **The With-UE4SS package is recommended for most users.**

### Option 1: With-UE4SS (Recommended - Easy Install)

**File:** `MoreRVers-vX.Y.Z-WithUE4SS.zip`

This package includes UE4SS experimental and MoreRVers pre-configured. Just extract and play!

1. Download `MoreRVers-vX.Y.Z-WithUE4SS.zip` from the latest release
2. Navigate to your game directory:
   ```
   <Steam>\steamapps\common\Ride\Ride\Binaries\Win64\
   ```
3. Extract **all files** from the zip directly into the `Win64` folder
4. (Optional) Configure player limit by editing `ue4ss\Mods\MoreRVers\config.ini`:
   ```ini
   MaxPlayers = 8
   ```
5. Launch the game and host a session

**That's it!** The mod is pre-enabled!

### Option 2: Mod-Only (Advanced Users)

**File:** `MoreRVers-vX.Y.Z-ModOnly.zip`

Use this if you already have UE4SS experimental installed and configured.

**Requirements:**
- [UE4SS experimental branch](https://github.com/UE4SS-RE/RE-UE4SS/releases) (3.0.1+)
- RV There Yet? (Steam version)

**Installation:**

1. Download `MoreRVers-vX.Y.Z-ModOnly.zip` from the latest release
2. Extract the `MoreRVers` folder to:
   ```
   <Steam>\steamapps\common\Ride\Ride\Binaries\Win64\ue4ss\Mods\
   ```
3. The mod ships with an `enabled.txt`, so UE4SS loads it automatically. (Alternatively add `MoreRVers : 1` to `ue4ss\Mods\mods.txt`, before `Keybinds : 1`.)
4. Configure the player limit in `ue4ss\Mods\MoreRVers\config.ini`:
   ```ini
   MaxPlayers = 8
   ```
5. Launch the game and host a session

## File Tree
When properly installed, your game directory should look similar to this:
```
{Steam}\steamapps\common\Ride\
├── Ride\
│   └── Binaries\
│       └── Win64\
│           ├── Ride-Win64-Shipping.exe         
│           ├── dwmapi.dll                       
│           │
│           └── ue4ss\                          
│               ├── UE4SS.dll                  
│               ├── UE4SS-settings.ini         
│               │
│               └── Mods\
│                   ├── mods.txt                 
│                   │
│                   └── MoreRVers\               
│                       ├── mod.json             
│                       ├── config.ini           
│                       │
│                       └── scripts\
```

## Configuration

Edit `UE4SS/Mods/MoreRVers/config.ini`:

```ini
MaxPlayers = 8
```

**Configuration Parameters:**
- Default: 8 (vanilla game limit is 4)
- Range: 1-24
- Recommended: 8 for optimal stability

The game must be restarted for configuration changes to take effect.

## Verification

Successful installation can be verified by checking the UE4SS console (or `ue4ss\UE4SS.log`) for:

```
[MoreRVers] [INFO] MaxPlayers 4 -> 8 (startup) GameSession /Script/Engine.Default__GameSession
[MoreRVers] [INFO] Session cap is now 8 players
[MoreRVers] [INFO] v1.1.0 loaded. Target MaxPlayers = 8 (F10 = status)
```

Press **F10** in game (or type `morervers` in the UE4SS console) to print the current cap values.
`Default__GameSession.MaxPlayers` is the value the game enforces.

## How it works

Since game version 1.4 the game's own session class (`RGGameSession`) takes the player cap from the
engine's `GameSession` class default object (`/Script/Engine.Default__GameSession`): it uses it to
reject joins ("Session is full."), to size the lobby, and it copies it onto the live session every time
a session starts. Earlier versions of this mod only changed the live session, which the game now
overwrites, so the cap stayed at 4. The mod now patches that default object at startup and re-applies
the cap on every session spawn, game-mode init and map load. If a level sets
`RGWorldSettings.MaxPlayersOverride` below the target, that is raised too.

## Troubleshooting

### Mod fails to load

- Check UE4SS console for error messages
- Verify UE4SS 3.0.1 or higher is installed
- Confirm file structure matches the documented structure
- Ensure mod is enabled in `mods.txt`

### Player limit remains at 4

- Press F10 in game and check that `Default__GameSession.MaxPlayers` shows your configured value
- Test with `MaxPlayers = 1` to verify mod functionality
- Review `UE4SS-settings.ini` to ensure Lua scripting is enabled

### Game crashes or instability

- Reduce the configured player count
- Verify UE4SS version compatibility
- Report issues with complete console logs

## Contributing

Bug reports and feature suggestions can be submitted via GitHub Issues. Pull requests are welcome.

## License

MIT License. See LICENSE file for details.

## Credits

- **UE4SS Team** - Unreal Engine modding framework
- **RV There Yet? Community** - Testing and feedback
