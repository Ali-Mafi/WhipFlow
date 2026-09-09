
#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

; ============================================================
; WhipFlow v1.0
; ============================================================
; Mouse Button 5 (XButton2) hold:
;   Show the whip.
;
; While Mouse Button 5 is held, press Mouse Button 4 (XButton1):
;   Open Settings.
;
; Settings tabs:
;   1) Movement
;   2) Prompt
;
; Settings are saved persistently to:
;   whip_settings.ini
; ============================================================

; ------------------------------------------------------------
; Defaults
; ------------------------------------------------------------

global DEFAULT_PROMPT := "FAST MODE: Continue from the current state. Do not repeat completed work, do not add explanations, and do not do unnecessary searches or re-reviews. Focus only on the remaining work and finish it as quickly as possible."

global DEFAULT_RIGHT_DISTANCE := 50
global DEFAULT_RIGHT_SPEED := 10
global DEFAULT_LEFT_DISTANCE := 50
global DEFAULT_LEFT_SPEED := 18
global DEFAULT_SNAP_TIMEOUT := 900
global DEFAULT_COOLDOWN := 1100

global settingsFile := A_ScriptDir "\whip_settings.ini"

; ------------------------------------------------------------
; Runtime settings
; ------------------------------------------------------------

global FAST_PROMPT := DEFAULT_PROMPT
global RIGHT_DISTANCE := DEFAULT_RIGHT_DISTANCE
global RIGHT_SPEED := DEFAULT_RIGHT_SPEED
global LEFT_DISTANCE := DEFAULT_LEFT_DISTANCE
global LEFT_SPEED := DEFAULT_LEFT_SPEED
global SNAP_TIMEOUT := DEFAULT_SNAP_TIMEOUT
global cooldownMs := DEFAULT_COOLDOWN
global soundEnabled := true
global SOUND_EFFECT := 1
global SOUND_VOLUME := 50
global audioPlayer := 0

; ------------------------------------------------------------
; Window / GDI+
; ------------------------------------------------------------

global overlay := 0
global overlayHwnd := 0
global screenW := A_ScreenWidth
global screenH := A_ScreenHeight
global gdipToken := 0
global memDC := 0
global dib := 0
global oldBmp := 0
global graphics := 0

global cablePenOuter := 0
global cablePenInner := 0
global handlePenOuter := 0
global handlePenInner := 0
global stripePen := 0

global visible := false
global settingsOpen := false
global settingsGui := 0

; ------------------------------------------------------------
; Handle
; ------------------------------------------------------------

global handleLen := 62.0
global handleAngleDeg := -36.0

; ------------------------------------------------------------
; Rope physics
; ------------------------------------------------------------

global rope := []
global ropeCount := 32
global segLen := 13.0
global gravity := 0.40
global drag := 0.965
global constraintIterations := 16
global bendStrength := 0.018
global maxAnchorDelta := 95.0
global maxVel := 34.0

global prevMouseX := 0.0
global prevMouseY := 0.0
global prevDX := 0.0
global prevDY := 0.0

; ------------------------------------------------------------
; Gesture state
; ------------------------------------------------------------

global gestureArmed := false
global lastMouseX := 0
global whipPhase := 0
global rightTravel := 0.0
global leftTravel := 0.0
global rightPeakSpeed := 0.0
global leftPeakSpeed := 0.0
global phaseStartedAt := 0

; ------------------------------------------------------------
; Send state
; ------------------------------------------------------------

global lastFire := 0

LoadSettings()
InitOverlayAndGraphics()
OnExit Cleanup

; ============================================================
; Mouse controls
; ============================================================

XButton2::
{
    global settingsOpen
    if settingsOpen
        return

    StartWhipSession()
}

XButton2 Up::
{
    StopWhipSession()
}

; Mouse 4 opens settings ONLY while Mouse 5 is held.
#HotIf GetKeyState("XButton2", "P")
XButton1::
{
    OpenSettings()
}
#HotIf

^!f::FirePrompt()

^!s::
{
    global soundEnabled
    soundEnabled := !soundEnabled
    SaveSettings()
    ShowMiniToast(soundEnabled ? "Sound ON" : "Sound OFF")
}

^!Esc::ExitApp

; ============================================================
; Whip session
; ============================================================

StartWhipSession()
{
    global gestureArmed
    global lastMouseX
    global whipPhase
    global rightTravel
    global leftTravel
    global rightPeakSpeed
    global leftPeakSpeed
    global phaseStartedAt
    global prevMouseX
    global prevMouseY
    global prevDX
    global prevDY

    MouseGetPos &mx, &my

    prevMouseX := mx
    prevMouseY := my
    prevDX := 0
    prevDY := 0

    InitRope(mx, my)

    lastMouseX := mx
    whipPhase := 0
    rightTravel := 0.0
    leftTravel := 0.0
    rightPeakSpeed := 0.0
    leftPeakSpeed := 0.0
    phaseStartedAt := A_TickCount
    gestureArmed := true

    ShowWhip()
    RenderWhip()

    SetTimer AnimateWhip, 16
    SetTimer TrackGesture, 12
}

StopWhipSession()
{
    global gestureArmed

    gestureArmed := false
    SetTimer AnimateWhip, 0
    SetTimer TrackGesture, 0
    HideWhip()
}

; ============================================================
; Geometry
; ============================================================

GetHandleAndKnot(mx, my)
{
    global handleLen
    global handleAngleDeg

    rad := handleAngleDeg * 0.0174532925199433

    baseX := mx - 58
    baseY := my + 20

    knotX := baseX + Cos(rad) * handleLen
    knotY := baseY + Sin(rad) * handleLen

    return {baseX: baseX, baseY: baseY, knotX: knotX, knotY: knotY}
}

; ============================================================
; Rope init
; ============================================================

InitRope(mx, my)
{
    global rope
    global ropeCount

    rope := []

    hk := GetHandleAndKnot(mx, my)
    kx := hk.knotX
    ky := hk.knotY

    Loop ropeCount
    {
        i := A_Index - 1
        t := i / Max(1, ropeCount - 1)

        x := kx + t * 90
        y := ky + t * 265

        rope.Push({
            x: x,
            y: y,
            oldx: x,
            oldy: y
        })
    }

    rope[1].x := kx
    rope[1].y := ky
    rope[1].oldx := kx
    rope[1].oldy := ky
}

; ============================================================
; Rope animation
; ============================================================

AnimateWhip()
{
    global visible
    global settingsOpen

    global rope
    global ropeCount
    global segLen
    global gravity
    global drag
    global constraintIterations
    global bendStrength
    global maxAnchorDelta
    global maxVel

    global prevMouseX
    global prevMouseY
    global prevDX
    global prevDY

    if settingsOpen
        return

    if !visible
        return

    if !GetKeyState("XButton2", "P")
    {
        StopWhipSession()
        return
    }

    MouseGetPos &mx, &my

    dx := mx - prevMouseX
    dy := my - prevMouseY

    prevMouseX := mx
    prevMouseY := my

    dLen := Sqrt(dx*dx + dy*dy)

    if (dLen > maxAnchorDelta)
    {
        s := maxAnchorDelta / dLen
        dx *= s
        dy *= s
    }

    ax := dx - prevDX
    ay := dy - prevDY

    prevDX := dx
    prevDY := dy

    hk := GetHandleAndKnot(mx, my)
    anchorX := hk.knotX
    anchorY := hk.knotY

    rope[1].x := anchorX
    rope[1].y := anchorY
    rope[1].oldx := anchorX - dx * 0.18
    rope[1].oldy := anchorY - dy * 0.18

    Loop ropeCount - 1
    {
        i := A_Index + 1
        p := rope[i]

        vx := (p.x - p.oldx) * drag
        vy := (p.y - p.oldy) * drag

        t := (i - 1) / (ropeCount - 1)

        influence := Max(0.0, 1.0 - t * 1.20)
        vx += dx * 0.070 * influence
        vy += dy * 0.070 * influence

        snapInfluence := (1.0 - t) * 0.85 + t * 0.30
        vx += ax * 0.11 * snapInfluence
        vy += ay * 0.11 * snapInfluence

        tipBoost := t * t
        vx += ax * 0.055 * tipBoost
        vy += ay * 0.035 * tipBoost

        vy += gravity * (0.35 + 0.65 * t)

        sp := Sqrt(vx*vx + vy*vy)

        if (sp > maxVel)
        {
            s := maxVel / sp
            vx *= s
            vy *= s
        }

        p.oldx := p.x
        p.oldy := p.y

        p.x += vx
        p.y += vy
    }

    Loop constraintIterations
    {
        rope[1].x := anchorX
        rope[1].y := anchorY

        ; forward pass
        Loop ropeCount - 1
        {
            i := A_Index
            a := rope[i]
            b := rope[i + 1]

            dx2 := b.x - a.x
            dy2 := b.y - a.y
            dist := Sqrt(dx2*dx2 + dy2*dy2)

            if (dist < 0.0001)
                continue

            err := (dist - segLen) / dist

            if (i = 1)
            {
                b.x -= dx2 * err
                b.y -= dy2 * err
            }
            else
            {
                corrX := dx2 * err * 0.5
                corrY := dy2 * err * 0.5

                a.x += corrX
                a.y += corrY

                b.x -= corrX
                b.y -= corrY
            }
        }

        ; backward pass
        Loop ropeCount - 1
        {
            i := ropeCount - A_Index
            if (i < 1)
                break

            a := rope[i]
            b := rope[i + 1]

            dx3 := b.x - a.x
            dy3 := b.y - a.y
            dist := Sqrt(dx3*dx3 + dy3*dy3)

            if (dist < 0.0001)
                continue

            err := (dist - segLen) / dist

            if (i = 1)
            {
                b.x -= dx3 * err
                b.y -= dy3 * err
            }
            else
            {
                corrX := dx3 * err * 0.5
                corrY := dy3 * err * 0.5

                a.x += corrX
                a.y += corrY

                b.x -= corrX
                b.y -= corrY
            }
        }

        if Mod(A_Index, 2) = 0
        {
            Loop ropeCount - 2
            {
                i := A_Index + 1
                t2 := (i - 1) / (ropeCount - 1)

                if (t2 < 0.08)
                    continue

                a := rope[i - 1]
                b := rope[i]
                c := rope[i + 1]

                midX := (a.x + c.x) * 0.5
                midY := (a.y + c.y) * 0.5

                b.x += (midX - b.x) * bendStrength
                b.y += (midY - b.y) * bendStrength
            }
        }
    }

    RenderWhip()
}

; ============================================================
; Gesture detection — right pull, then sharp left snap
; ============================================================

TrackGesture()
{
    global gestureArmed
    global settingsOpen
    global lastMouseX

    global whipPhase
    global rightTravel
    global leftTravel
    global rightPeakSpeed
    global leftPeakSpeed
    global phaseStartedAt

    global RIGHT_DISTANCE
    global RIGHT_SPEED
    global LEFT_DISTANCE
    global LEFT_SPEED
    global SNAP_TIMEOUT

    if settingsOpen
        return

    if !gestureArmed
        return

    MouseGetPos &mx, &my
    dx := mx - lastMouseX
    lastMouseX := mx

    now := A_TickCount

    ; Phase 0: extend to the RIGHT
    if (whipPhase = 0)
    {
        if (dx > 0)
        {
            rightTravel += dx

            if (dx > rightPeakSpeed)
                rightPeakSpeed := dx
        }
        else if (dx < -5)
        {
            rightTravel := Max(0.0, rightTravel + dx * 0.35)
        }

        if (rightTravel >= RIGHT_DISTANCE && rightPeakSpeed >= RIGHT_SPEED)
        {
            whipPhase := 1
            leftTravel := 0.0
            leftPeakSpeed := 0.0
            phaseStartedAt := now
        }

        return
    }

    ; Phase 1: snap LEFT
    if (whipPhase = 1)
    {
        if (now - phaseStartedAt > SNAP_TIMEOUT)
        {
            ResetWhipGesture(mx)
            return
        }

        if (dx < 0)
        {
            leftTravel += -dx

            if (-dx > leftPeakSpeed)
                leftPeakSpeed := -dx
        }
        else if (dx > 8)
        {
            rightTravel := dx
            rightPeakSpeed := dx
            leftTravel := 0.0
            leftPeakSpeed := 0.0
            whipPhase := 0
            phaseStartedAt := now
            return
        }

        if (leftTravel >= LEFT_DISTANCE && leftPeakSpeed >= LEFT_SPEED)
        {
            FirePrompt()

            ; Multi-whip mode:
            ; keep Mouse 5 held and repeat indefinitely.
            ResetWhipGesture(mx)
        }
    }
}

ResetWhipGesture(currentX)
{
    global lastMouseX

    global whipPhase
    global rightTravel
    global leftTravel
    global rightPeakSpeed
    global leftPeakSpeed
    global phaseStartedAt

    lastMouseX := currentX

    whipPhase := 0
    rightTravel := 0.0
    leftTravel := 0.0
    rightPeakSpeed := 0.0
    leftPeakSpeed := 0.0
    phaseStartedAt := A_TickCount
}

; ============================================================
; Rendering
; ============================================================

RenderWhip()
{
    global graphics

    global cablePenOuter
    global cablePenInner
    global handlePenOuter
    global handlePenInner
    global stripePen

    global rope

    MouseGetPos &mx, &my
    hk := GetHandleAndKnot(mx, my)

    DllCall("gdiplus\GdipGraphicsClear", "ptr", graphics, "uint", 0x00000000)

    DrawRopeFromPoints(rope, cablePenOuter)
    DrawRopeFromPoints(rope, cablePenInner)

    DllCall(
        "gdiplus\GdipDrawLineI",
        "ptr", graphics,
        "ptr", handlePenOuter,
        "int", Round(hk.baseX),
        "int", Round(hk.baseY),
        "int", Round(hk.knotX),
        "int", Round(hk.knotY)
    )

    DllCall(
        "gdiplus\GdipDrawLineI",
        "ptr", graphics,
        "ptr", handlePenInner,
        "int", Round(hk.baseX),
        "int", Round(hk.baseY),
        "int", Round(hk.knotX),
        "int", Round(hk.knotY)
    )

    DrawHandleStripes(hk.baseX, hk.baseY, hk.knotX, hk.knotY)

    PresentFrame()
}

DrawRopeFromPoints(points, pen)
{
    global graphics

    count := points.Length

    if (count < 2)
        return

    buf := Buffer(count * 8, 0)

    Loop count
    {
        pt := points[A_Index]
        off := (A_Index - 1) * 8

        NumPut("Int", Round(pt.x), buf, off)
        NumPut("Int", Round(pt.y), buf, off + 4)
    }

    DllCall(
        "gdiplus\GdipDrawCurveI",
        "ptr", graphics,
        "ptr", pen,
        "ptr", buf.Ptr,
        "int", count
    )
}

DrawHandleStripes(baseX, baseY, knotX, knotY)
{
    global graphics
    global stripePen

    dx := knotX - baseX
    dy := knotY - baseY

    d := Sqrt(dx*dx + dy*dy)

    if (d < 0.001)
        return

    ux := dx / d
    uy := dy / d

    px := -uy
    py := ux

    for ratio in [0.20, 0.35, 0.50, 0.65]
    {
        cx := baseX + ux * (d * ratio)
        cy := baseY + uy * (d * ratio)

        halfLen := 4.5

        x1 := cx - px * halfLen
        y1 := cy - py * halfLen

        x2 := cx + px * halfLen
        y2 := cy + py * halfLen

        DllCall(
            "gdiplus\GdipDrawLineI",
            "ptr", graphics,
            "ptr", stripePen,
            "int", Round(x1),
            "int", Round(y1),
            "int", Round(x2),
            "int", Round(y2)
        )
    }
}

; ============================================================
; Prompt send
; ============================================================

FirePrompt()
{
    global FAST_PROMPT
    global lastFire
    global cooldownMs
    global soundEnabled
    global SOUND_EFFECT
    global SOUND_VOLUME

    now := A_TickCount

    if (now - lastFire < cooldownMs)
        return

    lastFire := now

    oldClip := ClipboardAll()
    A_Clipboard := FAST_PROMPT

    if !ClipWait(0.8)
        return

    Send "^v"
    Sleep 110
    Send "{Enter}"

    if soundEnabled
        PlayWhipSound(SOUND_EFFECT, SOUND_VOLUME)

    Sleep 130
    A_Clipboard := oldClip
}

; ============================================================
; SETTINGS UI
; ============================================================

OpenSettings()
{
    global settingsOpen
    global settingsGui

    global RIGHT_DISTANCE
    global RIGHT_SPEED
    global LEFT_DISTANCE
    global LEFT_SPEED
    global SNAP_TIMEOUT
    global cooldownMs
    global FAST_PROMPT
    global soundEnabled
    global SOUND_EFFECT
    global SOUND_VOLUME

    if settingsOpen
    {
        try WinActivate("ahk_id " settingsGui.Hwnd)
        return
    }

    settingsOpen := true

    SetTimer AnimateWhip, 0
    SetTimer TrackGesture, 0
    HideWhip()

    g := Gui("+AlwaysOnTop", "WhipFlow — Settings")
    settingsGui := g
    g.SetFont("s10", "Segoe UI")

    tabs := g.AddTab3("x16 y14 w548 h390", ["Movement", "Prompt", "Sound"])

    ; ---------------- Movement ----------------
    tabs.UseTab(1)

    g.SetFont("s13 Bold", "Segoe UI")
    g.AddText("x36 y58 w480 h28", "Whip Movement")

    g.SetFont("s9", "Segoe UI")
    g.AddText("x36 y90 w485 h34 c666666", "Tune the right pull and left snap until the gesture feels natural.")

    g.AddText("x36 y138 w190 h22", "Right pull distance (px)")
    rightDistanceEdit := g.AddEdit("x270 y134 w110 h26 Number", RIGHT_DISTANCE)

    g.AddText("x36 y178 w190 h22", "Right minimum speed")
    rightSpeedEdit := g.AddEdit("x270 y174 w110 h26 Number", RIGHT_SPEED)

    g.AddText("x36 y218 w190 h22", "Left snap distance (px)")
    leftDistanceEdit := g.AddEdit("x270 y214 w110 h26 Number", LEFT_DISTANCE)

    g.AddText("x36 y258 w190 h22", "Left minimum speed")
    leftSpeedEdit := g.AddEdit("x270 y254 w110 h26 Number", LEFT_SPEED)

    g.AddText("x36 y298 w190 h22", "Snap timeout (ms)")
    timeoutEdit := g.AddEdit("x270 y294 w110 h26 Number", SNAP_TIMEOUT)

    g.AddText("x36 y338 w190 h22", "Repeat cooldown (ms)")
    cooldownEdit := g.AddEdit("x270 y334 w110 h26 Number", cooldownMs)

    ; ---------------- Prompt ----------------
    tabs.UseTab(2)

    g.SetFont("s13 Bold", "Segoe UI")
    g.AddText("x36 y58 w480 h28", "Whip Prompt")

    g.SetFont("s9", "Segoe UI")
    g.AddText("x36 y90 w480 h34 c666666", "This exact text is pasted and submitted whenever WhipFlow triggers.")

    promptEdit := g.AddEdit("x36 y132 w490 h210 Multi WantTab VScroll", FAST_PROMPT)
    resetPromptBtn := g.AddButton("x36 y354 w130 h30", "Reset prompt")

    ; ---------------- Sound ----------------
    tabs.UseTab(3)

    g.SetFont("s13 Bold", "Segoe UI")
    g.AddText("x36 y58 w480 h28", "Whip Sound")

    g.SetFont("s9", "Segoe UI")
    g.AddText("x36 y90 w485 h34 c666666", "Choose a whip effect and set its playback volume.")

    soundCheckbox := g.AddCheckBox("x36 y140 w150 h24", "Enable sound")
    soundCheckbox.Value := soundEnabled ? 1 : 0

    g.AddText("x36 y188 w160 h22", "Sound effect")
    soundChoice := g.AddDropDownList("x210 y184 w230 Choose" SOUND_EFFECT, [
        "Classic Crack",
        "Heavy Leather",
        "Sharp Snap"
    ])

    g.AddText("x36 y236 w160 h22", "Volume")
    volumeText := g.AddText("x442 y236 w64 h22 Right", SOUND_VOLUME "%")
    volumeSlider := g.AddSlider("x210 y230 w230 h32 Range0-100 ToolTip", SOUND_VOLUME)
    volumeSlider.OnEvent("Change", (*) => volumeText.Text := volumeSlider.Value "%")

    testSoundBtn := g.AddButton("x210 y286 w130 h32", "Test sound")

    g.AddText("x36 y338 w470 h34 c777777", "Tip: use Test sound while adjusting the slider.")

    ; ---------------- Shared buttons ----------------
    tabs.UseTab()

    saveBtn := g.AddButton("x330 y420 w105 h34 Default", "Save")
    cancelBtn := g.AddButton("x447 y420 w105 h34", "Cancel")
    resetAllBtn := g.AddButton("x16 y420 w125 h34", "Reset defaults")

    resetPromptBtn.OnEvent("Click", (*) => promptEdit.Value := DEFAULT_PROMPT)

    testSoundBtn.OnEvent("Click", (*) => TestSelectedSound(
        soundChoice.Value,
        volumeSlider.Value,
        soundCheckbox.Value
    ))

    resetAllBtn.OnEvent("Click", (*) => ResetSettingsControls(
        rightDistanceEdit,
        rightSpeedEdit,
        leftDistanceEdit,
        leftSpeedEdit,
        timeoutEdit,
        cooldownEdit,
        promptEdit,
        soundCheckbox,
        soundChoice,
        volumeSlider,
        volumeText
    ))

    saveBtn.OnEvent("Click", (*) => SaveSettingsFromGui(
        g,
        rightDistanceEdit,
        rightSpeedEdit,
        leftDistanceEdit,
        leftSpeedEdit,
        timeoutEdit,
        cooldownEdit,
        promptEdit,
        soundCheckbox,
        soundChoice,
        volumeSlider
    ))

    cancelBtn.OnEvent("Click", (*) => CloseSettings(g))
    g.OnEvent("Close", (*) => CloseSettings(g))
    g.OnEvent("Escape", (*) => CloseSettings(g))

    g.Show("w580 h470")
}

ResetSettingsControls(
    rightDistanceEdit,
    rightSpeedEdit,
    leftDistanceEdit,
    leftSpeedEdit,
    timeoutEdit,
    cooldownEdit,
    promptEdit,
    soundCheckbox,
    soundChoice,
    volumeSlider,
    volumeText
)
{
    global DEFAULT_RIGHT_DISTANCE
    global DEFAULT_RIGHT_SPEED
    global DEFAULT_LEFT_DISTANCE
    global DEFAULT_LEFT_SPEED
    global DEFAULT_SNAP_TIMEOUT
    global DEFAULT_COOLDOWN
    global DEFAULT_PROMPT

    rightDistanceEdit.Value := DEFAULT_RIGHT_DISTANCE
    rightSpeedEdit.Value := DEFAULT_RIGHT_SPEED
    leftDistanceEdit.Value := DEFAULT_LEFT_DISTANCE
    leftSpeedEdit.Value := DEFAULT_LEFT_SPEED
    timeoutEdit.Value := DEFAULT_SNAP_TIMEOUT
    cooldownEdit.Value := DEFAULT_COOLDOWN
    promptEdit.Value := DEFAULT_PROMPT

    soundCheckbox.Value := 1
    soundChoice.Choose(1)
    volumeSlider.Value := 80
    volumeText.Text := "80%"
}

SaveSettingsFromGui(
    g,
    rightDistanceEdit,
    rightSpeedEdit,
    leftDistanceEdit,
    leftSpeedEdit,
    timeoutEdit,
    cooldownEdit,
    promptEdit,
    soundCheckbox,
    soundChoice,
    volumeSlider
)
{
    global RIGHT_DISTANCE
    global RIGHT_SPEED
    global LEFT_DISTANCE
    global LEFT_SPEED
    global SNAP_TIMEOUT
    global cooldownMs
    global FAST_PROMPT
    global soundEnabled
    global SOUND_EFFECT
    global SOUND_VOLUME

    RIGHT_DISTANCE := ClampInt(rightDistanceEdit.Value, 20, 1000, 95)
    RIGHT_SPEED := ClampInt(rightSpeedEdit.Value, 1, 200, 10)
    LEFT_DISTANCE := ClampInt(leftDistanceEdit.Value, 20, 1000, 72)
    LEFT_SPEED := ClampInt(leftSpeedEdit.Value, 1, 200, 18)
    SNAP_TIMEOUT := ClampInt(timeoutEdit.Value, 100, 5000, 900)
    cooldownMs := ClampInt(cooldownEdit.Value, 0, 10000, 1100)

    FAST_PROMPT := Trim(promptEdit.Value)
    if (FAST_PROMPT = "")
        FAST_PROMPT := DEFAULT_PROMPT

    soundEnabled := soundCheckbox.Value ? true : false
    SOUND_EFFECT := Max(1, Min(3, soundChoice.Value))
    SOUND_VOLUME := Max(0, Min(100, volumeSlider.Value))

    SaveSettings()
    ShowMiniToast("Settings saved")
    CloseSettings(g)
}

ClampInt(value, minVal, maxVal, fallback)
{
    try n := Integer(value)
    catch
        return fallback

    return Max(minVal, Min(maxVal, n))
}

CloseSettings(g)
{
    global settingsOpen
    global settingsGui

    try g.Destroy()

    settingsOpen := false
    settingsGui := 0

    if GetKeyState("XButton2", "P")
        StartWhipSession()
}

TestSelectedSound(effect, volume, enabled)
{
    if !enabled
    {
        ShowMiniToast("Sound is disabled")
        return
    }

    PlayWhipSound(effect, volume)
}

GetSoundPath(effect)
{
    effect := Max(1, Min(3, effect))

    if (effect = 1)
        return A_ScriptDir "\sounds\classic_crack.wav"

    if (effect = 2)
        return A_ScriptDir "\sounds\heavy_leather.wav"

    return A_ScriptDir "\sounds\sharp_snap.wav"
}

PlayWhipSound(effect := 0, volume := -1)
{
    global SOUND_EFFECT
    global SOUND_VOLUME
    global audioPlayer

    if (effect = 0)
        effect := SOUND_EFFECT

    if (volume < 0)
        volume := SOUND_VOLUME

    soundPath := GetSoundPath(effect)

    if !FileExist(soundPath)
    {
        SoundBeep 950, 120
        ShowMiniToast("Sound file missing")
        return false
    }

    ; Windows Media Player COM gives WhipFlow its own playback volume
    ; without changing the Windows master volume.
    try
    {
        if !audioPlayer
            audioPlayer := ComObject("WMPlayer.OCX")

        audioPlayer.settings.volume := Max(0, Min(100, volume))
        audioPlayer.settings.setMode("loop", false)
        audioPlayer.URL := soundPath
        audioPlayer.controls.stop()
        audioPlayer.controls.play()
        return true
    }
    catch
    {
        ; Fallback for systems without WMP COM.
        flags := 0x0001 | 0x00020000 | 0x0002
        ok := DllCall(
            "winmm\PlaySoundW",
            "wstr", soundPath,
            "ptr", 0,
            "uint", flags,
            "int"
        )

        if !ok
            SoundBeep 950, 120

        return !!ok
    }
}

; ============================================================
; Persistent settings
; ============================================================

LoadSettings()
{
    global settingsFile

    global FAST_PROMPT
    global RIGHT_DISTANCE
    global RIGHT_SPEED
    global LEFT_DISTANCE
    global LEFT_SPEED
    global SNAP_TIMEOUT
    global cooldownMs
    global soundEnabled
    global SOUND_EFFECT
    global SOUND_VOLUME

    global DEFAULT_PROMPT
    global DEFAULT_RIGHT_DISTANCE
    global DEFAULT_RIGHT_SPEED
    global DEFAULT_LEFT_DISTANCE
    global DEFAULT_LEFT_SPEED
    global DEFAULT_SNAP_TIMEOUT
    global DEFAULT_COOLDOWN

    RIGHT_DISTANCE := Integer(IniRead(settingsFile, "Movement", "RightDistance", DEFAULT_RIGHT_DISTANCE))
    RIGHT_SPEED := Integer(IniRead(settingsFile, "Movement", "RightSpeed", DEFAULT_RIGHT_SPEED))
    LEFT_DISTANCE := Integer(IniRead(settingsFile, "Movement", "LeftDistance", DEFAULT_LEFT_DISTANCE))
    LEFT_SPEED := Integer(IniRead(settingsFile, "Movement", "LeftSpeed", DEFAULT_LEFT_SPEED))
    SNAP_TIMEOUT := Integer(IniRead(settingsFile, "Movement", "SnapTimeout", DEFAULT_SNAP_TIMEOUT))
    cooldownMs := Integer(IniRead(settingsFile, "Movement", "Cooldown", DEFAULT_COOLDOWN))

    soundEnabled := (IniRead(settingsFile, "Sound", "Enabled", "1") = "1")
    SOUND_EFFECT := Integer(IniRead(settingsFile, "Sound", "Effect", "1"))
    SOUND_VOLUME := Integer(IniRead(settingsFile, "Sound", "Volume", "80"))

    SOUND_EFFECT := Max(1, Min(3, SOUND_EFFECT))
    SOUND_VOLUME := Max(0, Min(100, SOUND_VOLUME))

    promptValue := IniRead(settingsFile, "Prompt", "Text", DEFAULT_PROMPT)
    FAST_PROMPT := promptValue = "" ? DEFAULT_PROMPT : promptValue
}

SaveSettings()
{
    global settingsFile

    global FAST_PROMPT
    global RIGHT_DISTANCE
    global RIGHT_SPEED
    global LEFT_DISTANCE
    global LEFT_SPEED
    global SNAP_TIMEOUT
    global cooldownMs
    global soundEnabled
    global SOUND_EFFECT
    global SOUND_VOLUME

    IniWrite(RIGHT_DISTANCE, settingsFile, "Movement", "RightDistance")
    IniWrite(RIGHT_SPEED, settingsFile, "Movement", "RightSpeed")
    IniWrite(LEFT_DISTANCE, settingsFile, "Movement", "LeftDistance")
    IniWrite(LEFT_SPEED, settingsFile, "Movement", "LeftSpeed")
    IniWrite(SNAP_TIMEOUT, settingsFile, "Movement", "SnapTimeout")
    IniWrite(cooldownMs, settingsFile, "Movement", "Cooldown")

    IniWrite(soundEnabled ? "1" : "0", settingsFile, "Sound", "Enabled")
    IniWrite(SOUND_EFFECT, settingsFile, "Sound", "Effect")
    IniWrite(SOUND_VOLUME, settingsFile, "Sound", "Volume")

    IniWrite(FAST_PROMPT, settingsFile, "Prompt", "Text")
}

; ============================================================
; Small toast
; ============================================================

ShowMiniToast(message)
{
    toast := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20")
    toast.BackColor := "202020"
    toast.SetFont("s10 Bold", "Segoe UI")
    toast.AddText("x12 y8 w190 h26 Center cFFFFFF BackgroundTrans", message)

    MouseGetPos &x, &y

    toast.Show("NA x" (x + 20) " y" (y + 20) " w214 h42")
    SetTimer () => toast.Destroy(), -900
}

; ============================================================
; Window / GDI+
; ============================================================

InitOverlayAndGraphics()
{
    global overlay
    global overlayHwnd
    global screenW
    global screenH

    global gdipToken
    global memDC
    global dib
    global oldBmp
    global graphics

    global cablePenOuter
    global cablePenInner
    global handlePenOuter
    global handlePenInner
    global stripePen

    overlay := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20 +E0x80000")
    overlay.Show("NA x0 y0 w" screenW " h" screenH)
    overlayHwnd := overlay.Hwnd

    startupSize := (A_PtrSize = 8) ? 24 : 16
    si := Buffer(startupSize, 0)
    NumPut("UInt", 1, si, 0)

    DllCall(
        "gdiplus\GdiplusStartup",
        "ptr*", &gdipToken,
        "ptr", si.Ptr,
        "ptr", 0
    )

    memDC := DllCall(
        "gdi32\CreateCompatibleDC",
        "ptr", 0,
        "ptr"
    )

    bmi := Buffer(40, 0)

    NumPut("UInt", 40, bmi, 0)
    NumPut("Int", screenW, bmi, 4)
    NumPut("Int", -screenH, bmi, 8)
    NumPut("UShort", 1, bmi, 12)
    NumPut("UShort", 32, bmi, 14)
    NumPut("UInt", 0, bmi, 16)

    bits := 0

    dib := DllCall(
        "gdi32\CreateDIBSection",
        "ptr", memDC,
        "ptr", bmi.Ptr,
        "uint", 0,
        "ptr*", &bits,
        "ptr", 0,
        "uint", 0,
        "ptr"
    )

    oldBmp := DllCall(
        "gdi32\SelectObject",
        "ptr", memDC,
        "ptr", dib,
        "ptr"
    )

    DllCall(
        "gdiplus\GdipCreateFromHDC",
        "ptr", memDC,
        "ptr*", &graphics
    )

    DllCall(
        "gdiplus\GdipSetSmoothingMode",
        "ptr", graphics,
        "int", 4
    )

    DllCall(
        "gdiplus\GdipCreatePen1",
        "uint", 0xFF000000,
        "float", 10.0,
        "int", 2,
        "ptr*", &cablePenOuter
    )

    DllCall(
        "gdiplus\GdipCreatePen1",
        "uint", 0xFF2A2A2A,
        "float", 6.4,
        "int", 2,
        "ptr*", &cablePenInner
    )

    DllCall(
        "gdiplus\GdipCreatePen1",
        "uint", 0xFF000000,
        "float", 12.0,
        "int", 2,
        "ptr*", &handlePenOuter
    )

    DllCall(
        "gdiplus\GdipCreatePen1",
        "uint", 0xFF171717,
        "float", 8.4,
        "int", 2,
        "ptr*", &handlePenInner
    )

    DllCall(
        "gdiplus\GdipCreatePen1",
        "uint", 0xFFFFFFFF,
        "float", 2.6,
        "int", 2,
        "ptr*", &stripePen
    )

    for pen in [
        cablePenOuter,
        cablePenInner,
        handlePenOuter,
        handlePenInner,
        stripePen
    ]
    {
        DllCall(
            "gdiplus\GdipSetPenLineJoin",
            "ptr", pen,
            "int", 2
        )

        DllCall(
            "gdiplus\GdipSetPenStartCap",
            "ptr", pen,
            "int", 2
        )

        DllCall(
            "gdiplus\GdipSetPenEndCap",
            "ptr", pen,
            "int", 2
        )
    }

    DllCall(
        "gdiplus\GdipGraphicsClear",
        "ptr", graphics,
        "uint", 0x00000000
    )

    PresentFrame()
    overlay.Hide()
}

PresentFrame()
{
    global overlayHwnd
    global screenW
    global screenH
    global memDC

    dst := Buffer(8, 0)
    size := Buffer(8, 0)
    src := Buffer(8, 0)
    blend := Buffer(4, 0)

    NumPut("Int", 0, dst, 0)
    NumPut("Int", 0, dst, 4)

    NumPut("Int", screenW, size, 0)
    NumPut("Int", screenH, size, 4)

    NumPut("Int", 0, src, 0)
    NumPut("Int", 0, src, 4)

    NumPut("UChar", 0, blend, 0)
    NumPut("UChar", 0, blend, 1)
    NumPut("UChar", 255, blend, 2)
    NumPut("UChar", 1, blend, 3)

    DllCall(
        "user32\UpdateLayeredWindow",
        "ptr", overlayHwnd,
        "ptr", 0,
        "ptr", dst.Ptr,
        "ptr", size.Ptr,
        "ptr", memDC,
        "ptr", src.Ptr,
        "uint", 0,
        "ptr", blend.Ptr,
        "uint", 2
    )
}

ShowWhip()
{
    global overlay
    global visible

    if visible
        return

    overlay.Show(
        "NA x0 y0 w" A_ScreenWidth " h" A_ScreenHeight
    )

    visible := true
}

HideWhip()
{
    global overlay
    global visible
    global graphics

    if !visible
        return

    DllCall(
        "gdiplus\GdipGraphicsClear",
        "ptr", graphics,
        "uint", 0x00000000
    )

    PresentFrame()

    overlay.Hide()
    visible := false
}

Cleanup(*)
{
    global gdipToken
    global memDC
    global dib
    global oldBmp
    global graphics

    global cablePenOuter
    global cablePenInner
    global handlePenOuter
    global handlePenInner
    global stripePen

    for pen in [
        cablePenOuter,
        cablePenInner,
        handlePenOuter,
        handlePenInner,
        stripePen
    ]
    {
        if pen
            DllCall(
                "gdiplus\GdipDeletePen",
                "ptr", pen
            )
    }

    if graphics
        DllCall(
            "gdiplus\GdipDeleteGraphics",
            "ptr", graphics
        )

    if memDC && oldBmp
        DllCall(
            "gdi32\SelectObject",
            "ptr", memDC,
            "ptr", oldBmp
        )

    if dib
        DllCall(
            "gdi32\DeleteObject",
            "ptr", dib
        )

    if memDC
        DllCall(
            "gdi32\DeleteDC",
            "ptr", memDC
        )

    if gdipToken
        DllCall(
            "gdiplus\GdiplusShutdown",
            "ptr", gdipToken
        )
}
