# WhipFlow

**Snap your workflow into action.**

WhipFlow is a lightweight AutoHotkey v2 mouse-gesture utility for Windows.

## Settings

Hold **Mouse Button 5** and press **Mouse Button 4**.

WhipFlow now has three settings tabs:

### Movement
Tune the right-pull / left-snap gesture.

### Prompt
Edit the exact prompt sent when the whip triggers.

### Sound
Choose between three built-in whip effects:

1. **Classic Crack**
2. **Heavy Leather**
3. **Sharp Snap**

You can also:
- Enable / disable sound
- Adjust WhipFlow volume from **0–100%**
- Test the selected sound directly from Settings

Sound volume is handled separately from the Windows master volume when Windows Media Player COM is available.

## Files

```text
WhipFlow/
├── WhipFlow.ahk
├── sounds/
│   ├── classic_crack.wav
│   ├── heavy_leather.wav
│   └── sharp_snap.wav
└── whip_settings.ini   # created automatically
```

Keep the `sounds` folder beside `WhipFlow.ahk`.

## Controls

| Control | Action |
|---|---|
| Hold Mouse Button 5 | Show / activate WhipFlow |
| Mouse 5 + Mouse 4 | Open Settings |
| Pull right → snap left | Send configured prompt |
| Ctrl + Alt + F | Send prompt manually |
| Ctrl + Alt + S | Toggle sound |
| Ctrl + Alt + Esc | Exit WhipFlow |
