; =============================================================================
;  Toolbar XPerience.ahk  —  XP-style Auto-Hide Side Toolbar
;  AutoHotkey v1.1
;
;  Folder-driven toolbar:
;    - Set TOOLBAR_ROOT below or use Settings.
;    - Add shortcuts, files, and subfolders to that root folder.
;    - Subfolders open as flyout levels.
;    - Each level has an "Open this folder" item at the top.
;    - Gear button in the top-right opens Settings.
;
;  Notes:
;    - Save this file as UTF-8 with BOM if using emoji glyphs.
;    - Uses Windows light/dark app preference by default.
; =============================================================================

#NoEnv
#SingleInstance Force
#Persistent
SetWorkingDir %A_ScriptDir%
SendMode Input
SetTitleMatchMode, 2
CoordMode, Mouse, Screen

; ── Configuration ─────────────────────────────────────────────────────────────
TOOLBAR_ROOT  := A_MyDocuments Chr(92) "Toolbar XP Shortcuts" ; default shortcut folder
TOOLBAR_TITLE := "Toolbar XPerience" ; shown in the title bar.
TOOLBAR_ICON  := A_ScriptDir Chr(92) "Toolbar_XPerience.ico" ; optional .ico/.png/.exe/.dll icon shown at top-left
DOCK_SIDE     := "Left"             ; "Left" or "Right"
DOCK_MONITOR  := "Auto"             ; "Auto" or monitor number, e.g. "1", "2", "3"
TOOLBAR_WIDTH := 250                ; px, expanded width
HIDE_DELAY_MS := 600                ; ms before auto-hide triggers after mouse leaves
TAB_WIDTH     := 6                  ; px, visible tab when hidden
EDGE_TRIGGER_PX := 0                ; 0 means mouse must touch the actual screen edge
GLASS_ENABLED := true               ; true adds pane transparency / glass-like feel
PANE_ALPHA := 95                    ; volcanic glass clarity: 255 darkest, 180 clearer
GLASS_DARKNESS := 80                ; glass tint darkness: 0 light gray, 100 near black
RIGHT_CLICK_ADD_URL := true         ; right-click toolbar/flyout to add URL from clipboard
THEME_MODE := "Light"               ; System, Light, or Dark
SHOW_ADVANCED_SETTINGS := false     ; settings window starts simplified
START_WITH_WINDOWS := false         ; managed by Startup folder shortcut

; Animation speed. Lower numbers are faster.
; Set ANIMATION_STEPS := 1 and ANIMATION_SLEEP_MS := 0 for near-instant open/close.
ANIMATION_STEPS    := 2
ANIMATION_SLEEP_MS := 5

FONT_NAME := "Segoe UI"
FONT_SIZE := 9
TITLE_HEIGHT := 26
ROW_HEIGHT := 20

; Colors are set by ApplyTheme() during startup.
global TOOLBAR_COLOR := "F0F0F0"
global TITLE_COLOR   := "404040"
global SUBTITLE_COLOR := "606060"
global TEXT_COLOR    := "000000"
global TITLE_TEXT_COLOR := "FFFFFF"
global LIST_BG_COLOR := "FFFFFF"
global INPUT_BG_COLOR := "FFFFFF"
global INPUT_TEXT_COLOR := "000000"

; ── Globals ───────────────────────────────────────────────────────────────────
global hToolbar := 0
global hGear := 0
global hTitleIcon := 0

global IsExpanded := false
global HideTimer := false
global DockW, DockH, DockLeft, DockTop, DockRight, DockBottom

global MainImageList := 0
global LevelImageLists := {}
global LevelRowPaths := {}
global LevelHwnds := {}
global LevelFolders := {}
global OpenLevels := 0

global GLASS_ENABLED, PANE_ALPHA, GLASS_DARKNESS
global RIGHT_CLICK_ADD_URL, TOOLBAR_ICON
global DOCK_MONITOR, THEME_MODE, SHOW_ADVANCED_SETTINGS
global START_WITH_WINDOWS

InitDockArea()

; ── Tray menu ─────────────────────────────────────────────────────────────────
Menu, Tray, NoStandard
Menu, Tray, Add, Open Toolbar Root, OpenRoot
Menu, Tray, Add, Settings, ShowSettings
Menu, Tray, Add, Reload Script, ReloadScript
Menu, Tray, Add
Menu, Tray, Add, Exit, ExitApp
Menu, Tray, Add, Toggle Right-Click URL Add, ToggleRightClickUrl
Menu, Tray, Tip, Toolbar XPerience

; ── Startup ───────────────────────────────────────────────────────────────────
LoadIni()
InitDockArea()
ApplyTrayIcon()
ApplyTheme()
START_WITH_WINDOWS := IsStartupShortcutEnabled()

if !FileExist(TOOLBAR_ROOT) {
    FileCreateDir, %TOOLBAR_ROOT%
}

UpdateTrayMenuChecks()
BuildToolbar()
SetTimer, EdgeDetect, 50
OnMessage(0x205, "HandleRightButtonUp") ; WM_RBUTTONUP
return

; Ctrl+Shift+V while the mouse is over the toolbar/flyout creates a URL shortcut
; from the clipboard in that level's backing folder.
#If ToolbarIsActiveForPaste()
^+v::
    AddUrlFromClipboardAtMouse()
return
#If

; =============================================================================
;  BUILD MAIN TOOLBAR
; =============================================================================
BuildToolbar() {
    global hToolbar, hGear, hTitleIcon
    global TOOLBAR_WIDTH, DockH, DOCK_SIDE, TAB_WIDTH, TOOLBAR_ROOT, TOOLBAR_TITLE, TOOLBAR_ICON
    global DockW, DockLeft, DockTop, DockRight, FONT_NAME, FONT_SIZE, TITLE_HEIGHT
    global TOOLBAR_COLOR, TITLE_COLOR, TEXT_COLOR, TITLE_TEXT_COLOR, LIST_BG_COLOR

    Gui, Toolbar:Destroy

    if (DOCK_SIDE = "Left")
        xPos := DockLeft - (TOOLBAR_WIDTH - TAB_WIDTH)
    else
        xPos := DockRight - TAB_WIDTH

    displayTitle := "Toolbar XPerience"

    Gui, Toolbar:New, +AlwaysOnTop +ToolWindow -Caption +Border +E0x10 +LastFound +HwndhToolbar
    Gui, Toolbar:Color, %TOOLBAR_COLOR%
    Gui, Toolbar:Font, % "s" FONT_SIZE " c" TEXT_COLOR, %FONT_NAME%

    ; Title strip
    gearX := TOOLBAR_WIDTH - 28
    titleX := 0
    titleW := TOOLBAR_WIDTH - 30

    if (TOOLBAR_ICON != "" && FileExist(TOOLBAR_ICON)) {
        titleX := 28
        titleW := TOOLBAR_WIDTH - 58
        Gui, Toolbar:Add, Picture, % "x4 y3 w20 h20 Background" TITLE_COLOR " +HwndhTitleIcon", %TOOLBAR_ICON%
    }

    Gui, Toolbar:Add, Text, % "x" titleX " y0 w" titleW " h" TITLE_HEIGHT " +0x200 Background" TITLE_COLOR " c" TITLE_TEXT_COLOR " Center", %displayTitle%
    Gui, Toolbar:Add, Text, % "x" gearX " y0 w28 h" TITLE_HEIGHT " +0x200 Background" TITLE_COLOR " c" TITLE_TEXT_COLOR " Center gTopSettings +HwndhGear", ⚙

    ; Main ListView
    listY := TITLE_HEIGHT
    listH := DockH - TITLE_HEIGHT
    Gui, Toolbar:Add, ListView, % "x0 y" listY " w" TOOLBAR_WIDTH " h" listH " -Hdr -Multi AltSubmit NoSort Background" LIST_BG_COLOR " c" TEXT_COLOR " gMainListAction", Name

    Gui, Toolbar:Show, % "x" xPos " y" DockTop " w" TOOLBAR_WIDTH " h" DockH " NoActivate", Toolbar XPerience
    ApplyPaneEffects(hToolbar)

    PopulateLevel(0, TOOLBAR_ROOT)
}

; =============================================================================
;  POPULATE A LEVEL
;    level 0 = main toolbar
;    level 1+ = flyout windows
; =============================================================================
PopulateLevel(level, folder) {
    global TOOLBAR_WIDTH, MainImageList, LevelImageLists, LevelRowPaths, LevelFolders

    if (level = 0) {
        Gui, Toolbar:Default
        if (MainImageList)
            IL_Destroy(MainImageList)
        MainImageList := IL_Create(80, 80, false)
        LV_SetImageList(MainImageList, 1)
        imageList := MainImageList
    } else {
        guiName := "Sub" level
        Gui, %guiName%:Default
        if (LevelImageLists[level])
            IL_Destroy(LevelImageLists[level])
        LevelImageLists[level] := IL_Create(80, 80, false)
        LV_SetImageList(LevelImageLists[level], 1)
        imageList := LevelImageLists[level]
    }

    LV_Delete()
    LevelRowPaths[level] := {}
    LevelFolders[level] := folder

    ; Top option: open this level's target folder in Explorer.
    iconIndex := AddIconForPath(imageList, A_WinDir "\explorer.exe", false)
    row := LV_Add("Icon" iconIndex, "Open this folder")
    LevelRowPaths[level][row] := "::OPEN_FOLDER::" folder

    ; Visual spacer under "Open this folder".
    ; This row is intentionally non-launchable.
    row := LV_Add("Icon0", "────────────────────────")
    LevelRowPaths[level][row] := "::SEPARATOR::"

    ; Add folders first. Skip hidden/system-looking blank names defensively.
    Loop, %folder%\*, 1, 0
    {
        if InStr(A_LoopFileAttrib, "D") {
            if (A_LoopFileName = "")
                continue
            itemPath := A_LoopFileLongPath
            iconIndex := AddIconForPath(imageList, itemPath, true)
            row := LV_Add("Icon" iconIndex, A_LoopFileName)
            LevelRowPaths[level][row] := itemPath
        }
    }

    ; Add shortcuts second.
    Loop, %folder%\*.lnk, 0, 0
    {
        if (A_LoopFileName = "")
            continue
        itemPath := A_LoopFileLongPath
        iconIndex := AddIconForPath(imageList, itemPath, false)
        row := LV_Add("Icon" iconIndex, A_LoopFileName)
        LevelRowPaths[level][row] := itemPath
    }

    ; Add other files third.
    Loop, %folder%\*.*, 0, 0
    {
        if (A_LoopFileExt = "lnk")
            continue
        if (A_LoopFileName = "")
            continue
        itemPath := A_LoopFileLongPath
        iconIndex := AddIconForPath(imageList, itemPath, false)
        row := LV_Add("Icon" iconIndex, A_LoopFileName)
        LevelRowPaths[level][row] := itemPath
    }

    LV_ModifyCol(1, TOOLBAR_WIDTH - 4)
}

; =============================================================================
;  MAIN LEVEL ACTION
; =============================================================================
MainListAction:
    if (A_GuiEvent != "DoubleClick" && A_GuiEvent != "Normal")
        return

    Gui, Toolbar:Default
    row := LV_GetNext(0, "F")
    if (!row)
        return

    HandleLevelSelection(0, row, hToolbar)
return

; =============================================================================
;  SUB LEVEL ACTION
; =============================================================================
SubListAction:
    global LevelHwnds

    if (A_GuiEvent != "DoubleClick" && A_GuiEvent != "Normal")
        return

    level := GetLevelFromGuiName(A_Gui)
    if (level < 1)
        return

    guiName := "Sub" level
    Gui, %guiName%:Default

    row := LV_GetNext(0, "F")
    if (!row)
        return

    parentHwnd := LevelHwnds[level]
    HandleLevelSelection(level, row, parentHwnd)
return

HandleLevelSelection(level, row, parentHwnd) {
    global LevelRowPaths

    target := LevelRowPaths[level][row]
    if (target = "")
        return

    if (target = "::SEPARATOR::")
        return


    if (SubStr(target, 1, 15) = "::OPEN_FOLDER::") {
        folder := SubStr(target, 16)
        RunExplorerFolder(folder)
        return
    }

    targetFolder := GetFolderTarget(target)
    if (targetFolder != "") {
        ShowSubmenu(level + 1, targetFolder, parentHwnd)
        return
    }

    if FileExist(target) {
        RunTarget(target)
        CloseSubmenusFrom(1)
    }
}

; =============================================================================
;  SUBMENU / FLYOUT WINDOW
; =============================================================================
ShowSubmenu(level, folder, parentHwnd) {
    global TOOLBAR_WIDTH, DockH, DOCK_SIDE, FONT_NAME, FONT_SIZE, TITLE_HEIGHT
    global DockLeft, DockRight
    global SUBTITLE_COLOR, TOOLBAR_COLOR, TEXT_COLOR, TITLE_TEXT_COLOR, LIST_BG_COLOR
    global LevelHwnds, OpenLevels

    ; Close only deeper levels, not the parent levels.
    CloseSubmenusFrom(level)

    WinGetPos, px, py, pw, ph, ahk_id %parentHwnd%
    if (px = "")
        return

    if (DOCK_SIDE = "Left")
        sx := px + pw
    else
        sx := px - TOOLBAR_WIDTH

    ; Keep the flyout on-screen horizontally.
    if (sx < DockLeft)
        sx := DockLeft
    if (sx + TOOLBAR_WIDTH > DockRight)
        sx := DockRight - TOOLBAR_WIDTH

    guiName := "Sub" level
    titleText := GetFolderName(folder)

    Gui, %guiName%:New, +AlwaysOnTop +ToolWindow -Caption +Border +E0x10 +HwndSubHwnd
    Gui, %guiName%:Color, %TOOLBAR_COLOR%
    Gui, %guiName%:Font, % "s" FONT_SIZE " c" TEXT_COLOR, %FONT_NAME%

    Gui, %guiName%:Add, Text, % "x0 y0 w" TOOLBAR_WIDTH " h" TITLE_HEIGHT " +0x200 Background" SUBTITLE_COLOR " c" TITLE_TEXT_COLOR " Center", %titleText%

    listY := TITLE_HEIGHT
    listH := DockH - TITLE_HEIGHT
    Gui, %guiName%:Add, ListView, % "x0 y" listY " w" TOOLBAR_WIDTH " h" listH " -Hdr -Multi AltSubmit NoSort Background" LIST_BG_COLOR " c" TEXT_COLOR " gSubListAction", Name

    Gui, %guiName%:Show, % "x" sx " y" py " w" TOOLBAR_WIDTH " h" DockH " NoActivate", % "SideToolbarSub" level
    ApplyPaneEffects(SubHwnd)

    LevelHwnds[level] := SubHwnd
    if (level > OpenLevels)
        OpenLevels := level

    PopulateLevel(level, folder)
}

CloseSubmenusFrom(startLevel) {
    global OpenLevels, LevelHwnds, LevelImageLists, LevelRowPaths, LevelFolders

    if (OpenLevels < startLevel)
        return

    Loop, % OpenLevels - startLevel + 1
    {
        level := OpenLevels - A_Index + 1
        guiName := "Sub" level
        Gui, %guiName%:Destroy

        if (LevelImageLists[level]) {
            IL_Destroy(LevelImageLists[level])
            LevelImageLists[level] := 0
        }

        LevelHwnds.Delete(level)
        LevelRowPaths.Delete(level)
        LevelFolders.Delete(level)
    }

    OpenLevels := startLevel - 1
    if (OpenLevels < 0)
        OpenLevels := 0
}

; =============================================================================
;  ICON HELPERS
; =============================================================================
AddIconForPath(imageList, path, isFolder := false, forcedIconNumber := "") {
    ; First try to ask Windows Shell for the same icon Explorer would show.
    ; This is especially important for .url files, Start Menu links, Steam/game links,
    ; and other shell-managed shortcuts whose icons are not easy to extract manually.
    shellIdx := AddShellIconToImageList(imageList, path)
    if (shellIdx)
        return shellIdx

    ; Fallback manual extraction.
    iconPath := path
    iconNumber := 1
    shell32 := A_WinDir Chr(92) "System32" Chr(92) "shell32.dll"

    if (forcedIconNumber != "") {
        iconNumber := forcedIconNumber
    } else if (isFolder) {
        iconPath := shell32
        iconNumber := 4
    } else if (GetFileExt(path) = "lnk") {
        FileGetShortcut, %path%, linkTarget, linkDir, linkArgs, linkDesc, linkIcon, linkIconNum, linkRunState

        if (linkIcon != "") {
            iconPath := linkIcon
            iconNumber := linkIconNum
        } else if (linkTarget != "") {
            iconPath := linkTarget
            iconNumber := 1
        }
    } else if (GetFileExt(path) = "url") {
        IniRead, urlIconFile, %path%, InternetShortcut, IconFile,
        IniRead, urlIconIndex, %path%, InternetShortcut, IconIndex, 0

        if (urlIconFile != "") {
            iconPath := urlIconFile
            iconNumber := urlIconIndex + 1
            if (iconNumber < 1)
                iconNumber := 1
        }
    }

    idx := IL_Add(imageList, iconPath, iconNumber)
    if (!idx)
        idx := IL_Add(imageList, shell32, 1)
    if (!idx)
        idx := 1

    return idx
}

AddShellIconToImageList(imageList, path) {
    ; Uses SHGetFileInfo so the toolbar icon matches Explorer as closely as possible.
    ; Works well for .url files that have IconFile/IconIndex metadata.
    VarSetCapacity(sfi, A_PtrSize + 688, 0)

    flags := 0x100 | 0x1   ; SHGFI_ICON | SHGFI_SMALLICON
    cb := A_PtrSize + 688
    shellFn := "Shell32.dll" Chr(92) "SHGetFileInfo"

    result := DllCall(shellFn
        , "Str", path
        , "UInt", 0
        , "Ptr", &sfi
        , "UInt", cb
        , "UInt", flags
        , "Ptr")

    if (!result)
        return 0

    hIcon := NumGet(sfi, 0, "Ptr")
    if (!hIcon)
        return 0

    replaceFn := "Comctl32.dll" Chr(92) "ImageList_ReplaceIcon"
    idxZeroBased := DllCall(replaceFn
        , "Ptr", imageList
        , "Int", -1
        , "Ptr", hIcon
        , "Int")

    destroyFn := "User32.dll" Chr(92) "DestroyIcon"
    DllCall(destroyFn, "Ptr", hIcon)

    if (idxZeroBased < 0)
        return 0

    ; ListView icon indexes are 1-based.
    return idxZeroBased + 1
}

GetFileExt(path) {
    SplitPath, path,,, ext
    return ext
}

; =============================================================================
;  EDGE DETECTION — auto show / hide
; =============================================================================
EdgeDetect:
    global IsExpanded, HideTimer, DOCK_SIDE, DockW, DockLeft, DockRight, EDGE_TRIGGER_PX, HIDE_DELAY_MS

    MouseGetPos, mx, my

    if (DOCK_SIDE = "Left")
        edgeZone := (mx <= DockLeft + EDGE_TRIGGER_PX)
    else
        edgeZone := (mx >= DockRight - 1 - EDGE_TRIGGER_PX)

    if (edgeZone) {
        if (!IsExpanded)
            SlideIn()

        if HideTimer {
            SetTimer, HideToolbar, Off
            HideTimer := false
        }
    } else if (IsExpanded) {
        if MouseIsOverToolbarOrSubmenu() {
            if HideTimer {
                SetTimer, HideToolbar, Off
                HideTimer := false
            }
        } else if (!HideTimer) {
            SetTimer, HideToolbar, % -HIDE_DELAY_MS
            HideTimer := true
        }
    }
return

HideToolbar:
    global HideTimer

    if MouseIsOverToolbarOrSubmenu() {
        HideTimer := false
        return
    }

    CloseSubmenusFrom(1)
    SlideOut()
    HideTimer := false
return

MouseIsOverToolbarOrSubmenu() {
    global hToolbar, LevelHwnds, OpenLevels

    MouseGetPos, mx, my

    if IsMouseOverHwnd(hToolbar, mx, my)
        return true

    Loop, %OpenLevels%
    {
        level := A_Index
        if IsMouseOverHwnd(LevelHwnds[level], mx, my)
            return true
    }

    return false
}

IsMouseOverHwnd(hwnd, mx, my) {
    if (!hwnd)
        return false

    WinGetPos, x, y, w, h, ahk_id %hwnd%
    if (x = "")
        return false

    return (mx >= x && mx <= x + w && my >= y && my <= y + h)
}

; =============================================================================
;  SLIDE ANIMATIONS
; =============================================================================
SlideIn() {
    global IsExpanded, TOOLBAR_WIDTH, DOCK_SIDE, DockW, DockLeft, DockRight, DockTop, hToolbar
    global ANIMATION_STEPS, ANIMATION_SLEEP_MS

    IsExpanded := true

    if (DOCK_SIDE = "Left")
        targetX := DockLeft
    else
        targetX := DockRight - TOOLBAR_WIDTH

    WinGetPos, cx, cy,,, ahk_id %hToolbar%
    if (cx = "")
        return

    steps := ANIMATION_STEPS + 0
    if (steps < 1)
        steps := 1

    dx := (targetX - cx) / steps

    Loop, %steps% {
        cx += dx
        WinMove, ahk_id %hToolbar%,, % Round(cx), %DockTop%
        if (ANIMATION_SLEEP_MS > 0)
            Sleep, %ANIMATION_SLEEP_MS%
    }

    WinMove, ahk_id %hToolbar%,, %targetX%, %DockTop%
}

SlideOut() {
    global IsExpanded, TOOLBAR_WIDTH, TAB_WIDTH, DOCK_SIDE, DockW, DockLeft, DockRight, DockTop, hToolbar
    global ANIMATION_STEPS, ANIMATION_SLEEP_MS

    IsExpanded := false

    if (DOCK_SIDE = "Left")
        targetX := DockLeft - (TOOLBAR_WIDTH - TAB_WIDTH)
    else
        targetX := DockRight - TAB_WIDTH

    WinGetPos, cx, cy,,, ahk_id %hToolbar%
    if (cx = "")
        return

    steps := ANIMATION_STEPS + 0
    if (steps < 1)
        steps := 1

    dx := (targetX - cx) / steps

    Loop, %steps% {
        cx += dx
        WinMove, ahk_id %hToolbar%,, % Round(cx), %DockTop%
        if (ANIMATION_SLEEP_MS > 0)
            Sleep, %ANIMATION_SLEEP_MS%
    }

    WinMove, ahk_id %hToolbar%,, %targetX%, %DockTop%
}

; =============================================================================
;  DRAG AND DROP SUPPORT
; =============================================================================
ToolbarGuiDropFiles:
SubGuiDropFiles:
GuiDropFiles:
    global TOOLBAR_ROOT, LevelFolders

    ; Determine which toolbar/flyout level received the drop.
    if (A_Gui = "Toolbar") {
        dropLevel := 0
    } else {
        dropLevel := GetLevelFromGuiName(A_Gui)
    }

    if (dropLevel < 0)
        dropLevel := 0

    destFolder := LevelFolders[dropLevel]
    if (destFolder = "")
        destFolder := TOOLBAR_ROOT

    if !FileExist(destFolder)
        FileCreateDir, %destFolder%

    createdCount := 0
    failedCount := 0

    Loop, Parse, A_GuiEvent, `n
    {
        droppedPath := A_LoopField
        if (droppedPath = "")
            continue

        if IsUrlText(droppedPath)
            ok := CreateUrlShortcutInFolder(droppedPath, destFolder)
        else
            ok := CreateShortcutInFolder(droppedPath, destFolder)

        if ok
            createdCount++
        else
            failedCount++
    }

    RefreshVisibleLevels()

    if (failedCount > 0) {
        TrayTip, Toolbar XPerience, Created %createdCount% shortcut(s). Failed: %failedCount%., 3, 17
    } else if (createdCount > 0) {
        TrayTip, Toolbar XPerience, Created %createdCount% shortcut(s)., 2, 1
    }
return

CreateUrlShortcutInFolder(url, destFolder, title := "") {
    if (url = "")
        return false

    if (title = "")
        title := UrlToShortcutName(url)

    linkPath := GetUniqueFilePath(destFolder, title ".url")
    iconPath := GetOrDownloadFavicon(url)

    content := "[InternetShortcut]`r`nURL=" url "`r`n"
    if (iconPath != "") {
        content .= "IconFile=" iconPath "`r`n"
        content .= "IconIndex=0`r`n"
    }

    FileDelete, %linkPath%
    FileAppend, %content%, %linkPath%
    return !ErrorLevel
}

IsUrlText(text) {
    text := Trim(text)
    return RegExMatch(text, "i)^(https?|ftp)://")
}

UrlToShortcutName(url) {
    clean := RegExReplace(url, "i)^https?://", "")
    clean := RegExReplace(clean, "^www\.", "")
    clean := RegExReplace(clean, "[/\:?*" Chr(34) "<>|]+", "_")
    clean := RegExReplace(clean, "_+$", "")
    if (StrLen(clean) > 80)
        clean := SubStr(clean, 1, 80)
    if (clean = "")
        clean := "URL Shortcut"
    return clean
}

GetOrDownloadFavicon(url) {
    ; Best-effort favicon handling. Many sites expose /favicon.ico.
    ; If that download fails, the .url shortcut will still work but may show
    ; the browser/default internet shortcut icon.
    domain := GetUrlDomain(url)
    if (domain = "")
        return ""

    iconDir := A_ScriptDir Chr(92) "SideToolbar_Favicons"
    FileCreateDir, %iconDir%

    iconPath := iconDir Chr(92) SanitizeShortcutName(domain) ".ico"
    if FileExist(iconPath)
        return iconPath

    faviconUrl := "https://" domain "/favicon.ico"
    UrlDownloadToFile, %faviconUrl%, %iconPath%
    if (!ErrorLevel && FileExist(iconPath))
        return iconPath

    FileDelete, %iconPath%
    faviconUrl := "http://" domain "/favicon.ico"
    UrlDownloadToFile, %faviconUrl%, %iconPath%
    if (!ErrorLevel && FileExist(iconPath))
        return iconPath

    FileDelete, %iconPath%
    return ""
}

GetUrlDomain(url) {
    if RegExMatch(url, "i)^(?:https?|ftp)://([^/:?#]+)", m)
        return m1
    return ""
}

CreateShortcutInFolder(sourcePath, destFolder) {
    if !FileExist(sourcePath)
        return false

    SplitPath, sourcePath, sourceName, sourceDir, sourceExt, sourceNameNoExt

    if (sourceName = "")
        return false

    ; If the user drops an existing shortcut, clone it into this toolbar folder.
    ; This makes the new shortcut point to the same target and preserves arguments,
    ; working directory, description, run state, and custom icon where possible.
    if (sourceExt = "lnk") {
        return CloneShortcutToFolder(sourcePath, destFolder)
    }

    ; If the user drops an internet shortcut, copy it as-is too.
    ; .url files store icon info differently than .lnk files.
    if (sourceExt = "url") {
        linkPath := GetUniqueFilePath(destFolder, sourceName)
        FileCopy, %sourcePath%, %linkPath%, 0
        return !ErrorLevel
    }

    if InStr(FileExist(sourcePath), "D") {
        workingDir := sourcePath
        iconFile := A_WinDir "\System32\shell32.dll"
        iconNumber := 4
    } else {
        workingDir := sourceDir
        iconFile := sourcePath
        iconNumber := 1
    }

    linkPath := GetUniqueShortcutPath(destFolder, sourceNameNoExt)

    ; FileCreateShortcut parameters:
    ; Target, LinkFile, WorkingDir, Args, Description, IconFile, ShortcutKey, IconNumber
    FileCreateShortcut, %sourcePath%, %linkPath%, %workingDir%,,, %iconFile%,, %iconNumber%

    return !ErrorLevel
}

CloneShortcutToFolder(sourceShortcut, destFolder) {
    if !FileExist(sourceShortcut)
        return false

    SplitPath, sourceShortcut, sourceName, sourceDir, sourceExt, sourceNameNoExt
    linkPath := GetUniqueShortcutPath(destFolder, sourceNameNoExt)

    FileGetShortcut, %sourceShortcut%, linkTarget, linkDir, linkArgs, linkDesc, linkIcon, linkIconNum, linkRunState

    ; Some shell shortcuts, especially special app/start-menu shortcuts, do not expose
    ; normal shortcut properties through FileGetShortcut. In that case, copy the .lnk
    ; file byte-for-byte as a fallback.
    if (linkTarget = "") {
        FileCopy, %sourceShortcut%, %linkPath%, 0
        return !ErrorLevel
    }

    ; Preserve custom icon if the source shortcut has one. If it does not, allow the
    ; target to supply its own icon, which usually matches Explorer behavior.
    if (linkIcon != "") {
        iconFile := linkIcon
        iconNumber := linkIconNum
    } else {
        iconFile := ""
        iconNumber := ""
    }

    FileCreateShortcut, %linkTarget%, %linkPath%, %linkDir%, %linkArgs%, %linkDesc%, %iconFile%,, %iconNumber%, %linkRunState%

    ; If recreation failed for any reason, fall back to copying the original .lnk.
    if ErrorLevel {
        FileCopy, %sourceShortcut%, %linkPath%, 0
        return !ErrorLevel
    }

    return true
}

GetUniqueShortcutPath(destFolder, baseName) {
    baseName := SanitizeShortcutName(baseName)
    if (baseName = "")
        baseName := "Shortcut"

    candidate := destFolder "\" baseName ".lnk"
    if !FileExist(candidate)
        return candidate

    Loop, 999
    {
        candidate := destFolder "\" baseName " (" A_Index ").lnk"
        if !FileExist(candidate)
            return candidate
    }

    return destFolder "\" baseName " (" A_Now ").lnk"
}

GetUniqueFilePath(destFolder, fileName) {
    SplitPath, fileName,,, ext, nameNoExt
    nameNoExt := SanitizeShortcutName(nameNoExt)
    if (nameNoExt = "")
        nameNoExt := "Shortcut"

    candidate := destFolder "\" nameNoExt "." ext
    if !FileExist(candidate)
        return candidate

    Loop, 999
    {
        candidate := destFolder "\" nameNoExt " (" A_Index ")." ext
        if !FileExist(candidate)
            return candidate
    }

    return destFolder "\" nameNoExt " (" A_Now ")." ext
}

SanitizeShortcutName(name) {
    ; Remove characters that are invalid in Windows filenames.
    name := RegExReplace(name, "[\/:*?" Chr(34) "<>|]", "_")
    return Trim(name)
}

RefreshVisibleLevels() {
    global TOOLBAR_ROOT, OpenLevels, LevelFolders

    PopulateLevel(0, TOOLBAR_ROOT)

    Loop, %OpenLevels%
    {
        level := A_Index
        folder := LevelFolders[level]
        if (folder != "" && FileExist(folder))
            PopulateLevel(level, folder)
    }
}

ToolbarIsActiveForPaste() {
    global IsExpanded
    if (!IsExpanded)
        return false
    if !MouseIsOverToolbarOrSubmenu()
        return false
    return true
}

AddUrlFromClipboardAtMouse() {
    global TOOLBAR_ROOT, LevelFolders

    ClipWait, 0.2
    url := Trim(Clipboard)

    if !IsUrlText(url) {
        TrayTip, Toolbar XPerience, Clipboard does not contain a URL., 2, 17
        return false
    }

    level := GetMouseOverLevel()
    destFolder := LevelFolders[level]
    if (destFolder = "")
        destFolder := TOOLBAR_ROOT

    if !FileExist(destFolder)
        FileCreateDir, %destFolder%

    if CreateUrlShortcutInFolder(url, destFolder) {
        RefreshVisibleLevels()
        TrayTip, Toolbar XPerience, Created URL shortcut from clipboard., 2, 1
        return true
    }

    TrayTip, Toolbar XPerience, Failed to create URL shortcut., 2, 17
    return false
}

GetMouseOverLevel() {
    global hToolbar, LevelHwnds, OpenLevels

    MouseGetPos, mx, my

    ; Check deeper flyouts first so overlapping/adjacent panes choose the intended level.
    Loop, %OpenLevels%
    {
        level := OpenLevels - A_Index + 1
        if IsMouseOverHwnd(LevelHwnds[level], mx, my)
            return level
    }

    if IsMouseOverHwnd(hToolbar, mx, my)
        return 0

    return 0
}

HandleRightButtonUp(wParam, lParam, msg, hwnd) {
    global RIGHT_CLICK_ADD_URL

    if (!RIGHT_CLICK_ADD_URL)
        return

    if !MouseIsOverToolbarOrSubmenu()
        return

    url := Trim(Clipboard)
    if IsUrlText(url) {
        AddUrlFromClipboardAtMouse()
        return 0
    }
}

ToggleRightClickUrl:
    global RIGHT_CLICK_ADD_URL
    RIGHT_CLICK_ADD_URL := !RIGHT_CLICK_ADD_URL
    UpdateTrayMenuChecks()
    SaveQuickSettings()
return

UpdateTrayMenuChecks() {
    global RIGHT_CLICK_ADD_URL
    if (RIGHT_CLICK_ADD_URL)
        Menu, Tray, Check, Toggle Right-Click URL Add
    else
        Menu, Tray, Uncheck, Toggle Right-Click URL Add
}

SaveQuickSettings() {
    global RIGHT_CLICK_ADD_URL
    ini := A_ScriptDir Chr(92) "SideToolbar.ini"
    IniWrite, %RIGHT_CLICK_ADD_URL%, %ini%, Config, RightClickAddUrl
}

; =============================================================================
;  SETTINGS WINDOW
; =============================================================================
TopSettings:
ShowSettings:
    global TOOLBAR_ROOT, TOOLBAR_TITLE, TOOLBAR_ICON, DOCK_SIDE, DOCK_MONITOR, TOOLBAR_WIDTH, HIDE_DELAY_MS
    global ANIMATION_STEPS, ANIMATION_SLEEP_MS, EDGE_TRIGGER_PX
    global GLASS_ENABLED, PANE_ALPHA, GLASS_DARKNESS
    global THEME_MODE, SHOW_ADVANCED_SETTINGS, START_WITH_WINDOWS
    global TOOLBAR_COLOR, TITLE_COLOR, TEXT_COLOR, TITLE_TEXT_COLOR, LIST_BG_COLOR
    global INPUT_BG_COLOR, INPUT_TEXT_COLOR

    ApplyTheme()

    Gui, Settings:Destroy
    Gui, Settings:New, +AlwaysOnTop +ToolWindow +Border
    Gui, Settings:Color, %TOOLBAR_COLOR%, %INPUT_BG_COLOR%
    Gui, Settings:Font, s9 c%TEXT_COLOR%, Segoe UI

    Gui, Settings:Add, Text, x10 y10 w340 h22 +0x200 Background%TITLE_COLOR% c%TITLE_TEXT_COLOR% Center, Toolbar XPerience Settings

    y := 44
    Gui, Settings:Add, Checkbox, x10 y%y% vSettingsShowAdvanced gToggleAdvancedSettings c%TEXT_COLOR% Checked%SHOW_ADVANCED_SETTINGS%, Show advanced options

    y += 28
    currentStartup := IsStartupShortcutEnabled()
    Gui, Settings:Add, Checkbox, x10 y%y% vSettingsStartWithWindows c%TEXT_COLOR% Checked%currentStartup%, Start Toolbar XPerience with Windows

    y += 34
    Gui, Settings:Add, Text, x10 y%y% w320 c%TEXT_COLOR%, Toolbar title:
    y += 20
    Gui, Settings:Add, Edit, x10 y%y% w340 vSettingsTitle Background%INPUT_BG_COLOR% c%INPUT_TEXT_COLOR%, %TOOLBAR_TITLE%

    y += 34
    if (SHOW_ADVANCED_SETTINGS) {
        Gui, Settings:Add, Text, x10 y%y% w320 c%TEXT_COLOR%, Toolbar icon file .ico/.png/.exe/.dll:
        y += 20
        Gui, Settings:Add, Edit, x10 y%y% w260 vSettingsIcon Background%INPUT_BG_COLOR% c%INPUT_TEXT_COLOR%, %TOOLBAR_ICON%
        Gui, Settings:Add, Button, x280 y%y% w70 h23 gBrowseIcon, Browse...
        y += 34
    } else {
        Gui, Settings:Add, Edit, x10 y%y% w1 h1 vSettingsIcon Hidden, %TOOLBAR_ICON%
    }

    
    Gui, Settings:Add, Text, x10 y%y% w320 c%TEXT_COLOR%, Toolbar root folder:
    y += 20
    Gui, Settings:Add, Edit, x10 y%y% w260 vSettingsRoot Background%INPUT_BG_COLOR% c%INPUT_TEXT_COLOR%, %TOOLBAR_ROOT%
    Gui, Settings:Add, Button, x280 y%y% w70 h23 gBrowseRoot, Browse...

    y += 36
    Gui, Settings:Add, Text, x10 y%y% w320 c%TEXT_COLOR%, Dock side:
    y += 20
    sideChoice := (DOCK_SIDE = "Left") ? 1 : 2
    Gui, Settings:Add, DropDownList, x10 y%y% w120 vSettingsSide Choose%sideChoice%, Left|Right

    y += 36
    if (SHOW_ADVANCED_SETTINGS) {
        Gui, Settings:Add, Text, x10 y%y% w320 c%TEXT_COLOR%, Monitor override:
        y += 20
        monitorOptions := GetMonitorDropdownOptions()
        monitorChoice := GetMonitorChoiceIndex(DOCK_MONITOR)
        Gui, Settings:Add, DropDownList, x10 y%y% w180 vSettingsMonitor Choose%monitorChoice%, %monitorOptions%

        y += 36
        Gui, Settings:Add, Text, x10 y%y% w320 c%TEXT_COLOR%, Theme mode:
        y += 20
        themeChoice := GetThemeChoiceIndex(THEME_MODE)
        Gui, Settings:Add, DropDownList, x10 y%y% w120 vSettingsTheme Choose%themeChoice%, System|Light|Dark

        y += 36
    } else {
        Gui, Settings:Add, Edit, x10 y%y% w1 h1 vSettingsMonitor Hidden, %DOCK_MONITOR%
        Gui, Settings:Add, Edit, x10 y%y% w1 h1 vSettingsTheme Hidden, %THEME_MODE%
    }

    
    if (SHOW_ADVANCED_SETTINGS) {
        Gui, Settings:Add, Text, x10 y%y% w320 c%TEXT_COLOR%, Toolbar width px:
        y += 20
        Gui, Settings:Add, Edit, x10 y%y% w80 vSettingsWidth Background%INPUT_BG_COLOR% c%INPUT_TEXT_COLOR%, %TOOLBAR_WIDTH%

        y += 36
        Gui, Settings:Add, Text, x10 y%y% w320 c%TEXT_COLOR%, Hide delay ms:
        y += 20
        Gui, Settings:Add, Edit, x10 y%y% w80 vSettingsDelay Background%INPUT_BG_COLOR% c%INPUT_TEXT_COLOR%, %HIDE_DELAY_MS%

        y += 36
        Gui, Settings:Add, Text, x10 y%y% w320 c%TEXT_COLOR%, Edge trigger px. 0 means actual edge:
        y += 20
        Gui, Settings:Add, Edit, x10 y%y% w80 vSettingsEdgePx Background%INPUT_BG_COLOR% c%INPUT_TEXT_COLOR%, %EDGE_TRIGGER_PX%

        y += 36
    } else {
        Gui, Settings:Add, Edit, x10 y%y% w1 h1 vSettingsWidth Hidden, %TOOLBAR_WIDTH%
        Gui, Settings:Add, Edit, x10 y%y% w1 h1 vSettingsDelay Hidden, %HIDE_DELAY_MS%
        Gui, Settings:Add, Edit, x10 y%y% w1 h1 vSettingsEdgePx Hidden, %EDGE_TRIGGER_PX%
    }

    
    Gui, Settings:Add, Checkbox, x10 y%y% vSettingsGlassEnabled c%TEXT_COLOR% Checked%GLASS_ENABLED%, Enable glass/transparency effect

    y += 28
    if (SHOW_ADVANCED_SETTINGS) {
        Gui, Settings:Add, Text, x10 y%y% w340 c%TEXT_COLOR%, Volcanic glass clarity. 255 darkest, 180 clearer:
        y += 20
        Gui, Settings:Add, Edit, x10 y%y% w80 vSettingsPaneAlpha Background%INPUT_BG_COLOR% c%INPUT_TEXT_COLOR%, %PANE_ALPHA%

        y += 36
        Gui, Settings:Add, Text, x10 y%y% w340 c%TEXT_COLOR%, Glass tint darkness. 0 light, 100 black:
        y += 20
        Gui, Settings:Add, Edit, x10 y%y% w80 vSettingsGlassDarkness Background%INPUT_BG_COLOR% c%INPUT_TEXT_COLOR%, %GLASS_DARKNESS%

        y += 36
    } else {
        Gui, Settings:Add, Edit, x10 y%y% w1 h1 vSettingsPaneAlpha Hidden, %PANE_ALPHA%
        Gui, Settings:Add, Edit, x10 y%y% w1 h1 vSettingsGlassDarkness Hidden, %GLASS_DARKNESS%
    }

    
    Gui, Settings:Add, Checkbox, x10 y%y% vSettingsRightClickUrl c%TEXT_COLOR% Checked%RIGHT_CLICK_ADD_URL%, Right-click pane adds URL from clipboard

    y += 36
    if (SHOW_ADVANCED_SETTINGS) {
        Gui, Settings:Add, Text, x10 y%y% w320 c%TEXT_COLOR%, Animation steps. 1 is fastest:
        y += 20
        Gui, Settings:Add, Edit, x10 y%y% w80 vSettingsAnimSteps Background%INPUT_BG_COLOR% c%INPUT_TEXT_COLOR%, %ANIMATION_STEPS%

        y += 36
        Gui, Settings:Add, Text, x10 y%y% w320 c%TEXT_COLOR%, Animation sleep ms. 0 is fastest:
        y += 20
        Gui, Settings:Add, Edit, x10 y%y% w80 vSettingsAnimSleep Background%INPUT_BG_COLOR% c%INPUT_TEXT_COLOR%, %ANIMATION_SLEEP_MS%

        y += 42
    } else {
        Gui, Settings:Add, Edit, x10 y%y% w1 h1 vSettingsAnimSteps Hidden, %ANIMATION_STEPS%
        Gui, Settings:Add, Edit, x10 y%y% w1 h1 vSettingsAnimSleep Hidden, %ANIMATION_SLEEP_MS%
        y += 20
    }
    Gui, Settings:Add, Button, x10 y%y% w120 h28 gSaveSettings Default, Save && Reload
    Gui, Settings:Add, Button, x140 y%y% w90 h28 gSettingsCancel, Cancel

    y += 42
    Gui, Settings:Show, w370 h%y%, Toolbar XPerience Settings
return

ToggleAdvancedSettings:
    global SHOW_ADVANCED_SETTINGS
    Gui, Settings:Submit, NoHide
    SHOW_ADVANCED_SETTINGS := SettingsShowAdvanced + 0
    Gosub, ShowSettings
return

BrowseRoot:
    global TOOLBAR_ROOT
    FileSelectFolder, chosen, %TOOLBAR_ROOT%,, Select toolbar root folder
    if (chosen != "")
        GuiControl, Settings:, SettingsRoot, %chosen%
return

BrowseIcon:
    FileSelectFile, chosenIcon, 3,, Select toolbar icon, Icon/Image Files (*.ico; *.png; *.bmp; *.jpg; *.jpeg; *.exe; *.dll)
    if (chosenIcon != "")
        GuiControl, Settings:, SettingsIcon, %chosenIcon%
return

SaveSettings:
    global TOOLBAR_ROOT, TOOLBAR_TITLE, TOOLBAR_ICON, DOCK_SIDE, DOCK_MONITOR, TOOLBAR_WIDTH, HIDE_DELAY_MS
    global ANIMATION_STEPS, ANIMATION_SLEEP_MS, EDGE_TRIGGER_PX, IsExpanded
    global GLASS_ENABLED, PANE_ALPHA, GLASS_DARKNESS, RIGHT_CLICK_ADD_URL, THEME_MODE, SHOW_ADVANCED_SETTINGS, START_WITH_WINDOWS

    Gui, Settings:Submit

    TOOLBAR_TITLE       := SettingsTitle
    SHOW_ADVANCED_SETTINGS := SettingsShowAdvanced + 0
    START_WITH_WINDOWS := SettingsStartWithWindows + 0
    TOOLBAR_ICON        := SettingsIcon
    TOOLBAR_ROOT        := SettingsRoot
    DOCK_SIDE           := SettingsSide
    DOCK_MONITOR        := NormalizeMonitorSetting(SettingsMonitor)
    THEME_MODE          := SettingsTheme
    TOOLBAR_WIDTH       := SettingsWidth + 0
    HIDE_DELAY_MS       := SettingsDelay + 0
    EDGE_TRIGGER_PX     := SettingsEdgePx + 0
    GLASS_ENABLED      := SettingsGlassEnabled + 0
    PANE_ALPHA         := SettingsPaneAlpha + 0
    GLASS_DARKNESS     := SettingsGlassDarkness + 0
    RIGHT_CLICK_ADD_URL := SettingsRightClickUrl + 0
    ANIMATION_STEPS     := SettingsAnimSteps + 0
    ANIMATION_SLEEP_MS  := SettingsAnimSleep + 0

    ini := A_ScriptDir Chr(92) "SideToolbar.ini"
    IniWrite, %TOOLBAR_TITLE%,      %ini%, Config, Title
    IniWrite, %TOOLBAR_ICON%,       %ini%, Config, Icon
    IniWrite, %TOOLBAR_ROOT%,       %ini%, Config, Root
    IniWrite, %DOCK_SIDE%,          %ini%, Config, Side
    IniWrite, %DOCK_MONITOR%,      %ini%, Config, Monitor
    IniWrite, %THEME_MODE%,        %ini%, Config, ThemeMode
    IniWrite, %SHOW_ADVANCED_SETTINGS%, %ini%, Config, ShowAdvancedSettings
    IniWrite, %START_WITH_WINDOWS%, %ini%, Config, StartWithWindows
    IniWrite, %TOOLBAR_WIDTH%,      %ini%, Config, Width
    IniWrite, %HIDE_DELAY_MS%,      %ini%, Config, HideDelay
    IniWrite, %EDGE_TRIGGER_PX%,    %ini%, Config, EdgeTriggerPx
    IniWrite, %GLASS_ENABLED%,   %ini%, Config, GlassEnabled
    IniWrite, %PANE_ALPHA%,      %ini%, Config, PaneAlpha
    IniWrite, %GLASS_DARKNESS%, %ini%, Config, GlassDarkness
    IniWrite, %RIGHT_CLICK_ADD_URL%, %ini%, Config, RightClickAddUrl
    IniWrite, %ANIMATION_STEPS%,    %ini%, Config, AnimationSteps
    IniWrite, %ANIMATION_SLEEP_MS%, %ini%, Config, AnimationSleepMs

    if !FileExist(TOOLBAR_ROOT)
        FileCreateDir, %TOOLBAR_ROOT%

    SetStartupShortcut(START_WITH_WINDOWS)

    Gui, Settings:Destroy
    CloseSubmenusFrom(1)
    IsExpanded := false
    InitDockArea()
    ApplyTheme()
    UpdateTrayMenuChecks()
    ApplyTrayIcon()
    BuildToolbar()
return

SettingsCancel:
    Gui, Settings:Destroy
return

; =============================================================================
;  STARTUP SHORTCUT HELPERS
; =============================================================================
GetStartupShortcutPath() {
    return A_Startup Chr(92) "Toolbar XPerience.lnk"
}

IsStartupShortcutEnabled() {
    return FileExist(GetStartupShortcutPath()) ? true : false
}

SetStartupShortcut(enable) {
    shortcutPath := GetStartupShortcutPath()

    if (enable) {
        target := A_ScriptFullPath
        workDir := A_ScriptDir
        icon := A_ScriptDir Chr(92) "Toolbar_XPerience.ico"

        FileDelete, %shortcutPath%

        if FileExist(icon)
            FileCreateShortcut, %target%, %shortcutPath%, %workDir%,, Toolbar XPerience, %icon%
        else
            FileCreateShortcut, %target%, %shortcutPath%, %workDir%,, Toolbar XPerience

        return !ErrorLevel
    } else {
        if FileExist(shortcutPath)
            FileDelete, %shortcutPath%
        return !FileExist(shortcutPath)
    }
}

; =============================================================================
;  TRAY ACTIONS
; =============================================================================
OpenRoot:
    global TOOLBAR_ROOT
    RunExplorerFolder(TOOLBAR_ROOT)
return

ReloadScript:
    Reload
return

ExitApp:
    ExitApp
return

; =============================================================================
;  MONITOR / DOCK AREA HELPERS
; =============================================================================
InitDockArea() {
    global DockW, DockH, DockLeft, DockTop, DockRight, DockBottom, DOCK_SIDE, DOCK_MONITOR

    ; Pick the dock monitor based on the selected side unless a specific monitor
    ; override is selected in Settings.
    ;   Auto + Left  = furthest-left monitor
    ;   Auto + Right = furthest-right monitor
    ;   1/2/3/etc.   = that exact monitor number from Windows
    SysGet, monitorCount, MonitorCount

    monitorNumber := NormalizeMonitorSetting(DOCK_MONITOR)
    if (monitorNumber != "Auto" && monitorNumber >= 1 && monitorNumber <= monitorCount) {
        SysGet, mon, MonitorWorkArea, %monitorNumber%
        DockLeft := monLeft
        DockTop := monTop
        DockRight := monRight
        DockBottom := monBottom
        DockW := DockRight - DockLeft
        DockH := DockBottom - DockTop
        return
    }

    found := false
    Loop, %monitorCount%
    {
        SysGet, mon, MonitorWorkArea, %A_Index%

        if (!found) {
            useThis := true
        } else if (DOCK_SIDE = "Right") {
            useThis := (monRight > DockRight)
        } else {
            useThis := (monLeft < DockLeft)
        }

        if (useThis) {
            DockLeft := monLeft
            DockTop := monTop
            DockRight := monRight
            DockBottom := monBottom
            found := true
        }
    }

    if (!found) {
        SysGet, mon, MonitorWorkArea, 1
        DockLeft := monLeft
        DockTop := monTop
        DockRight := monRight
        DockBottom := monBottom
    }

    DockW := DockRight - DockLeft
    DockH := DockBottom - DockTop
}

; =============================================================================
;  MONITOR / THEME SETTINGS HELPERS
; =============================================================================
GetMonitorDropdownOptions() {
    SysGet, monitorCount, MonitorCount
    options := "Auto"

    Loop, %monitorCount%
    {
        SysGet, mon, MonitorWorkArea, %A_Index%
        label := A_Index " - " monLeft "," monTop " to " monRight "," monBottom
        options .= "|" label
    }

    return options
}

GetMonitorChoiceIndex(monitorSetting) {
    SysGet, monitorCount, MonitorCount
    monitorSetting := NormalizeMonitorSetting(monitorSetting)

    if (monitorSetting = "Auto")
        return 1

    if (monitorSetting >= 1 && monitorSetting <= monitorCount)
        return monitorSetting + 1

    return 1
}

NormalizeMonitorSetting(value) {
    value := Trim(value)

    if (value = "" || value = "Auto")
        return "Auto"

    if RegExMatch(value, "^[ 	]*([0-9]+)", m)
        return m1 + 0

    return "Auto"
}

GetThemeChoiceIndex(themeMode) {
    themeMode := NormalizeThemeMode(themeMode)
    if (themeMode = "System")
        return 1
    if (themeMode = "Light")
        return 2
    if (themeMode = "Dark")
        return 3
    return 1
}

GrayHex(v) {
    v := v + 0
    if (v < 0)
        v := 0
    if (v > 255)
        v := 255
    return Format("{:02X}{:02X}{:02X}", v, v, v)
}

NormalizeThemeMode(themeMode) {
    themeMode := Trim(themeMode)
    if (themeMode = "Light")
        return "Light"
    if (themeMode = "Dark")
        return "Dark"
    return "System"
}

; =============================================================================
;  HELPERS
; =============================================================================
RunTarget(target) {
    quotedTarget := Chr(34) target Chr(34)
    Run, %quotedTarget%
}

GetFolderTarget(path) {
    ; Returns a folder path when the selected item is either:
    ;   - a real folder, or
    ;   - a .lnk shortcut pointing to a folder.
    ; Otherwise returns blank.

    if InStr(FileExist(path), "D")
        return path

    SplitPath, path,,, ext
    if (ext != "lnk")
        return ""

    FileGetShortcut, %path%, linkTarget, linkDir, linkArgs, linkDesc, linkIcon, linkIconNum, linkRunState

    if (linkTarget != "" && InStr(FileExist(linkTarget), "D"))
        return linkTarget

    return ""
}

RunExplorerFolder(folder) {
    if !FileExist(folder)
        return
    Run, % "explorer.exe " Chr(34) folder Chr(34)
}

GetFolderName(path) {
    path := RTrim(path, "\/")
    SplitPath, path, outName
    return outName
}

GetLevelFromGuiName(guiName) {
    if (SubStr(guiName, 1, 3) != "Sub")
        return 0
    return SubStr(guiName, 4) + 0
}

ApplyPaneEffects(hwnd) {
    global GLASS_ENABLED

    if (!hwnd)
        return

    if (GLASS_ENABLED) {
        ; Do NOT use WinSet Transparent here. It fades the entire window,
        ; including the title bar and text. Acrylic blur/tint gives the glass
        ; effect while keeping the title strip readable.
        WinSet, Transparent, OFF, ahk_id %hwnd%
        TryEnableBlurBehind(hwnd)
    } else {
        WinSet, Transparent, OFF, ahk_id %hwnd%
    }
}

TryEnableBlurBehind(hwnd) {
    global PANE_ALPHA, GLASS_DARKNESS

    ; Stronger Windows 10/11 blur/acrylic-style background.
    ; This uses the undocumented SetWindowCompositionAttribute API.
    ; PANE_ALPHA controls the acrylic tint opacity instead of fading the whole pane.

    if (!hwnd)
        return false

    accentState := 4        ; ACCENT_ENABLE_ACRYLICBLURBEHIND

    alpha := PANE_ALPHA + 0
    if (alpha < 80)
        alpha := 80
    if (alpha > 255)
        alpha := 255

    ; GradientColor is AABBGGRR.
    ; PANE_ALPHA controls clarity/opacity. GLASS_DARKNESS controls tint darkness.
    darkness := GLASS_DARKNESS + 0
    if (darkness < 0)
        darkness := 0
    if (darkness > 100)
        darkness := 100

    ; Convert 0-100 darkness into a gray level. Higher darkness = lower RGB.
    ; Keep a slight warm volcanic tint by making red barely higher than blue/green.
    base := Round(70 * (100 - darkness) / 100)
    red := base + 4
    green := base + 1
    blue := base + 2

    if (red > 255)
        red := 255
    if (green > 255)
        green := 255
    if (blue > 255)
        blue := 255

    ; AABBGGRR byte order.
    tintColor := (blue << 16) | (green << 8) | red
    gradientColor := (alpha << 24) | tintColor

    VarSetCapacity(accentPolicy, 16, 0)
    NumPut(accentState, accentPolicy, 0, "Int")
    NumPut(0, accentPolicy, 4, "Int")
    NumPut(gradientColor, accentPolicy, 8, "UInt")
    NumPut(0, accentPolicy, 12, "Int")

    VarSetCapacity(wcad, A_PtrSize * 3, 0)
    NumPut(19, wcad, 0, "Int")
    NumPut(&accentPolicy, wcad, A_PtrSize, "Ptr")
    NumPut(16, wcad, A_PtrSize * 2, "UPtr")

    setCompFn := "user32.dll" Chr(92) "SetWindowCompositionAttribute"
    result := DllCall(setCompFn, "Ptr", hwnd, "Ptr", &wcad)

    if (!result) {
        VarSetCapacity(bb, 16, 0)
        NumPut(1, bb, 0, "UInt")
        NumPut(1, bb, 4, "Int")
        dwmFn := "dwmapi.dll" Chr(92) "DwmEnableBlurBehindWindow"
        DllCall(dwmFn, "Ptr", hwnd, "Ptr", &bb)
    }

    return result
}

ResolveToolbarIconPath(iconPath) {
    defaultIcon := A_ScriptDir Chr(92) "Toolbar_XPerience.ico"

    if (iconPath != "" && FileExist(iconPath))
        return iconPath

    ; If a relative icon filename was saved in the INI, resolve it relative to the script.
    if (iconPath != "" && !InStr(iconPath, ":") && SubStr(iconPath, 1, 1) != Chr(92)) {
        candidate := A_ScriptDir Chr(92) iconPath
        if FileExist(candidate)
            return candidate
    }

    if FileExist(defaultIcon)
        return defaultIcon

    return iconPath
}

ApplyTrayIcon() {
    global TOOLBAR_ICON
    TOOLBAR_ICON := ResolveToolbarIconPath(TOOLBAR_ICON)
    if (TOOLBAR_ICON != "" && FileExist(TOOLBAR_ICON))
        Menu, Tray, Icon, %TOOLBAR_ICON%
}

ApplyTheme() {
    global TOOLBAR_COLOR, TITLE_COLOR, SUBTITLE_COLOR, TEXT_COLOR, TITLE_TEXT_COLOR, LIST_BG_COLOR
    global INPUT_BG_COLOR, INPUT_TEXT_COLOR, THEME_MODE
    global GLASS_ENABLED, GLASS_DARKNESS

    ; Theme mode can be forced for testing, or follow Windows app preference.
    if (THEME_MODE = "Dark") {
        lightTheme := 0
    } else if (THEME_MODE = "Light") {
        lightTheme := 1
    } else {
        themeKey := "HKCU" Chr(92) "Software" Chr(92) "Microsoft" Chr(92) "Windows" Chr(92) "CurrentVersion" Chr(92) "Themes" Chr(92) "Personalize"
        RegRead, lightTheme, %themeKey%, AppsUseLightTheme
    }

    ; Glass/transparency looks best with dark child controls. If glass is enabled,
    ; force the toolbar panes to use the dark-mode color branch even when Windows
    ; or the testing dropdown is set to Light.
    if (GLASS_ENABLED)
        lightTheme := 0

    if (lightTheme = 0) {
        if (GLASS_ENABLED) {
            ; When glass is enabled, make the actual child controls darker too.
            ; Otherwise the ListView's solid background stays gray even when the
            ; acrylic tint itself is nearly black.
            d := GLASS_DARKNESS + 0
            if (d < 0)
                d := 0
            if (d > 100)
                d := 100

            base := Round(45 * (100 - d) / 100) + 5
            titleBase := base - 3
            subBase := base + 6
            inputBase := base + 45

            if (titleBase < 0)
                titleBase := 0
            if (subBase > 80)
                subBase := 80
            if (inputBase > 95)
                inputBase := 95

            TOOLBAR_COLOR := GrayHex(base)
            LIST_BG_COLOR := GrayHex(base)
            TITLE_COLOR := GrayHex(titleBase)
            SUBTITLE_COLOR := GrayHex(subBase)
            INPUT_BG_COLOR := GrayHex(inputBase)
        } else {
            TOOLBAR_COLOR := "242424"
            TITLE_COLOR := "151515"
            SUBTITLE_COLOR := "202020"
            LIST_BG_COLOR := "242424"
            INPUT_BG_COLOR := "555555"
        }

        TEXT_COLOR := "F2F2F2"
        TITLE_TEXT_COLOR := "FFFFFF"
        INPUT_TEXT_COLOR := "FFFFFF"
    } else {
        TOOLBAR_COLOR := "F0F0F0"
        TITLE_COLOR := "404040"
        SUBTITLE_COLOR := "606060"
        TEXT_COLOR := "000000"
        TITLE_TEXT_COLOR := "FFFFFF"
        LIST_BG_COLOR := "FFFFFF"
        INPUT_BG_COLOR := "FFFFFF"
        INPUT_TEXT_COLOR := "000000"
    }
}

LoadIni() {
    global TOOLBAR_ROOT, TOOLBAR_TITLE, TOOLBAR_ICON, DOCK_SIDE, DOCK_MONITOR, TOOLBAR_WIDTH, HIDE_DELAY_MS
    global ANIMATION_STEPS, ANIMATION_SLEEP_MS, EDGE_TRIGGER_PX
    global GLASS_ENABLED, PANE_ALPHA, GLASS_DARKNESS, RIGHT_CLICK_ADD_URL, THEME_MODE, SHOW_ADVANCED_SETTINGS, START_WITH_WINDOWS

    ini := A_ScriptDir "\SideToolbar.ini"

    if FileExist(ini) {
        IniRead, v, %ini%, Config, Title, %TOOLBAR_TITLE%
        TOOLBAR_TITLE := "Toolbar XPerience"

        IniRead, v, %ini%, Config, Icon, %TOOLBAR_ICON%
        TOOLBAR_ICON := ResolveToolbarIconPath(v)

        IniRead, v, %ini%, Config, Root, %TOOLBAR_ROOT%
        TOOLBAR_ROOT := v

        IniRead, v, %ini%, Config, Side, %DOCK_SIDE%
        DOCK_SIDE := v

        IniRead, v, %ini%, Config, Monitor, %DOCK_MONITOR%
        DOCK_MONITOR := NormalizeMonitorSetting(v)

        IniRead, v, %ini%, Config, ThemeMode, %THEME_MODE%
        THEME_MODE := NormalizeThemeMode(v)

        IniRead, v, %ini%, Config, ShowAdvancedSettings, %SHOW_ADVANCED_SETTINGS%
        SHOW_ADVANCED_SETTINGS := v + 0

        IniRead, v, %ini%, Config, StartWithWindows, %START_WITH_WINDOWS%
        START_WITH_WINDOWS := v + 0

        IniRead, v, %ini%, Config, Width, %TOOLBAR_WIDTH%
        TOOLBAR_WIDTH := v + 0

        IniRead, v, %ini%, Config, HideDelay, %HIDE_DELAY_MS%
        HIDE_DELAY_MS := v + 0

        IniRead, v, %ini%, Config, EdgeTriggerPx, %EDGE_TRIGGER_PX%
        EDGE_TRIGGER_PX := v + 0

        IniRead, v, %ini%, Config, GlassEnabled, %GLASS_ENABLED%
        GLASS_ENABLED := v + 0

        IniRead, v, %ini%, Config, PaneAlpha, %PANE_ALPHA%
        PANE_ALPHA := v + 0

        IniRead, v, %ini%, Config, GlassDarkness, %GLASS_DARKNESS%
        GLASS_DARKNESS := v + 0

        IniRead, v, %ini%, Config, RightClickAddUrl, %RIGHT_CLICK_ADD_URL%
        RIGHT_CLICK_ADD_URL := v + 0

        IniRead, v, %ini%, Config, AnimationSteps, %ANIMATION_STEPS%
        ANIMATION_STEPS := v + 0

        IniRead, v, %ini%, Config, AnimationSleepMs, %ANIMATION_SLEEP_MS%
        ANIMATION_SLEEP_MS := v + 0
    }

    TOOLBAR_ICON := ResolveToolbarIconPath(TOOLBAR_ICON)

    if (DOCK_SIDE != "Left" && DOCK_SIDE != "Right")
        DOCK_SIDE := "Left"

    DOCK_MONITOR := NormalizeMonitorSetting(DOCK_MONITOR)
    THEME_MODE := NormalizeThemeMode(THEME_MODE)
    SHOW_ADVANCED_SETTINGS := SHOW_ADVANCED_SETTINGS + 0
    START_WITH_WINDOWS := IsStartupShortcutEnabled()

    if (TOOLBAR_WIDTH < 100)
        TOOLBAR_WIDTH := 250

    if (HIDE_DELAY_MS < 50)
        HIDE_DELAY_MS := 1000

    if (EDGE_TRIGGER_PX < 0)
        EDGE_TRIGGER_PX := 0

    if (PANE_ALPHA < 80)
        PANE_ALPHA := 80

    if (PANE_ALPHA > 255)
        PANE_ALPHA := 255

    if (GLASS_DARKNESS < 0)
        GLASS_DARKNESS := 0

    if (GLASS_DARKNESS > 100)
        GLASS_DARKNESS := 100

    if (ANIMATION_STEPS < 1)
        ANIMATION_STEPS := 1

    if (ANIMATION_SLEEP_MS < 0)
        ANIMATION_SLEEP_MS := 0
}
