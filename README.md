# WhipFlow

<p align="center">
  <strong>Snap your workflow into action.</strong>
</p>

<p align="center">
  A lightweight Windows mouse-gesture utility built with AutoHotkey v2.
</p>

---

## Overview

**WhipFlow** lets you trigger a custom prompt with a whip-like mouse gesture.

Hold **Mouse Button 5**, pull the mouse to the **right**, then snap it quickly back to the **left**. WhipFlow detects the motion, plays a whip effect, pastes your configured prompt, and submits it automatically.

It was designed to feel fast, playful, and surprisingly useful for repetitive AI/workflow actions.

---

## Features

- Real-time animated whip overlay
- Flexible rope-style physics
- Fixed whip handle
- Right → left snap gesture detection
- Repeated triggers while Mouse Button 5 stays held
- Editable prompt
- Adjustable gesture sensitivity
- Persistent settings
- Dedicated Sound settings
- 3 built-in whip sound effects
- Per-app volume control
- Sound preview button
- Lightweight always-on-top overlay
- Built with AutoHotkey v2

---

## How It Works

### 1. Activate WhipFlow

Hold:

**Mouse Button 5**

The whip appears and follows your cursor.

### 2. Trigger the Prompt

While still holding Mouse Button 5:

1. Pull the mouse to the **right**
2. Snap it quickly back to the **left**

If the gesture matches your configured thresholds, WhipFlow sends the prompt automatically.

You can repeat the gesture as many times as you want without releasing Mouse Button 5.

### 3. Hide the Whip

Release **Mouse Button 5**.

---

## Settings

To open Settings:

1. Hold **Mouse Button 5**
2. While still holding it, press **Mouse Button 4**

WhipFlow includes three settings tabs.

---

## Movement

Tune how the whip gesture is detected.

Available controls:

- Right Pull Distance
- Right Minimum Speed
- Left Snap Distance
- Left Minimum Speed
- Snap Timeout
- Repeat Cooldown

### Gesture Tuning

If WhipFlow feels too sensitive:

- Increase Right Pull Distance
- Increase Left Snap Distance
- Increase Right Minimum Speed
- Increase Left Minimum Speed

If it feels too difficult to trigger:

- Lower those values slightly
- Increase Snap Timeout

The intended motion is:

> **Pull right → snap left**

---

## Prompt

The Prompt tab contains the exact text WhipFlow sends when the whip gesture is triggered.

The default prompt is:

> FAST MODE: Continue exactly from the last state. Do not repeat completed work, do not add explanations, do not do unnecessary searches, and do not re-review finished sections. Only do: git status → latest commit → remaining tests → fix real errors → commit → push. If tests already pass, commit and push immediately. Final output only: commit SHA and changed-file summary.

You can replace it with any prompt you want.

WhipFlow automatically saves your custom prompt.

---

## Sound

WhipFlow includes three built-in whip effects:

1. **Classic Crack**
2. **Heavy Leather**
3. **Sharp Snap**

Inside **Settings → Sound**, you can:

- Enable or disable sound
- Choose one of the three sound effects
- Adjust volume from 0–100%
- Preview the selected sound with **Test sound**

WhipFlow keeps its sound files inside the `sounds` folder.

---

## Persistent Settings

WhipFlow stores your configuration in:

```text
whip_settings.ini
```

Saved settings include:

- Movement thresholds
- Snap timeout
- Repeat cooldown
- Custom prompt
- Selected sound effect
- Sound on/off state
- Sound volume

Your configuration remains saved after restarting WhipFlow.

---

## Controls

| Control | Action |
|---|---|
| **Hold Mouse Button 5** | Show / activate WhipFlow |
| **Mouse Button 5 + Mouse Button 4** | Open Settings |
| **Pull Right → Snap Left** | Trigger configured prompt |
| **Ctrl + Alt + F** | Send configured prompt manually |
| **Ctrl + Alt + S** | Toggle sound |
| **Ctrl + Alt + Esc** | Exit WhipFlow |

---

## Installation

### Requirements

- Windows
- AutoHotkey v2
- Mouse with Mouse Button 4 / Mouse Button 5 recommended

### Setup

1. Install **AutoHotkey v2**
2. Download or clone this repository
3. Keep the project files together
4. Run:

```text
WhipFlow.ahk
```

WhipFlow will remain active in the Windows system tray.

---

## Project Structure

```text
WhipFlow/
├── WhipFlow.ahk
├── README.md
├── .gitignore
├── sounds/
│   ├── classic_crack.wav
│   ├── heavy_leather.wav
│   └── sharp_snap.wav
└── whip_settings.ini
```

`whip_settings.ini` is created automatically after settings are saved.

For GitHub, it is recommended to ignore personal settings:

```gitignore
whip_settings.ini
```

---

## Notes

Different mice, DPI values, Windows scaling settings, and display refresh rates can affect how the gesture feels.

That is why movement thresholds are fully configurable.

WhipFlow is designed as a lightweight productivity experiment and mouse-gesture utility. It does not require browser extensions or external services.

---

## Built With

- AutoHotkey v2
- Windows GDI+
- Windows Media playback APIs

---

## Why WhipFlow?

Because sometimes clicking a button is boring.

**WhipFlow turns a mouse gesture into an action trigger — with style.**

---

## WhipFlow

**Snap your workflow into action.**
