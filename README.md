# Toolbar XPerience

**Toolbar XPerience** is an AutoHotkey v1.1 side toolbar inspired by the classic Windows XP folder toolbar experience. It creates an auto-hiding, folder-driven launcher that can dock to the left or right edge of your screen, show nested folders as flyout panes, launch shortcuts/files, and create new shortcuts by dragging items into the toolbar.

It is designed to feel lightweight, fast, and familiar: manage the toolbar by managing a normal folder.

---

## Features

* **XP-style auto-hide side toolbar**

  * Dock to the left or right edge of the screen.
  * Reveal the toolbar by moving the mouse to the screen edge.
  * Hide automatically after the mouse leaves.

* **Folder-driven launcher**

  * The toolbar reads from a normal folder.
  * Add files, shortcuts, folders, and URL shortcuts to that folder.
  * Subfolders open as flyout panes.
  * Shortcuts to folders are treated like folders and open as flyouts.

* **Multi-level flyouts**

  * Browse deeper folder structures without opening Explorer.
  * Every pane includes **Open this folder** for jumping into File Explorer.

* **Drag-and-drop shortcut creation**

  * Drop files, folders, `.lnk`, or `.url` files onto a pane.
  * The script creates or copies shortcuts into the matching backing folder.
  * Existing shortcuts are cloned while preserving target, arguments, icon, run state, and description where possible.

* **URL shortcut support**

  * Right-click a pane while a URL is in the clipboard to create a `.url` shortcut.
  * Press `Ctrl + Shift + V` while hovering a pane to create a URL shortcut from the clipboard.
  * Best-effort favicon download for URL shortcuts.

* **Native icons**

  * Uses Windows shell icons where possible.
  * Supports icons for files, folders, `.lnk`, `.url`, and special shell-managed shortcuts.

* **Glass / acrylic-style panes**

  * Optional Windows acrylic/blur effect.
  * Adjustable glass clarity and tint darkness.
  * Automatically uses dark pane colors when glass is enabled for better readability.

* **Multi-monitor support**

  * Auto-detects furthest-left or furthest-right monitor based on dock side.
  * Optional monitor override in Advanced Settings.

* **Settings GUI**

  * Simple mode for common settings.
  * Advanced mode for monitor, theme, glass, animation, and timing controls.

* **Startup support**

  * Optional checkbox to start Toolbar XPerience with Windows.
  * Creates/removes a Startup folder shortcut automatically.

---

## Requirements

* Windows 10 or Windows 11
* AutoHotkey v1.1
* `Toolbar XPerience.ahk`
* Optional: `Toolbar_XPerience.ico` in the same folder as the script

> This script is written for **AutoHotkey v1.1**, not AutoHotkey v2.

---

## Installation

1. Install **AutoHotkey v1.1**.
2. Download or clone this repository.
3. Place these files in the same folder:

```text
Toolbar XPerience.ahk
Toolbar_XPerience.ico
```

4. Run:

```text
Toolbar XPerience.ahk
```

On first run, the default toolbar folder is created here:

```text
Documents\Toolbar XP Shortcuts
```

You can change the folder in Settings.

---

## Basic Usage

### Open the toolbar

Move the mouse to the configured screen edge. By default, the toolbar docks to the **left edge**.

### Add shortcuts

Open the toolbar root folder from the tray menu or Settings, then add shortcuts/files/folders there.

Default root:

```text
Documents\Toolbar XP Shortcuts
```

Example structure:

```text
Toolbar XP Shortcuts
│
├── Apps
│   ├── Chrome.lnk
│   ├── Notepad++.lnk
│   └── VS Code.lnk
│
├── Games
│   ├── Steam.lnk
│   └── Emulators
│       ├── Dolphin.lnk
│       └── MAME.lnk
│
├── Scripts
│   ├── Backup.ps1.lnk
│   └── Plex Restart.lnk
│
└── Google.url
```

Folders appear as flyout panes. Files and shortcuts launch when clicked.

---

## Settings

Open Settings by clicking the gear icon in the top-right of the toolbar or from the tray menu.

### Simple settings

* **Start Toolbar XPerience with Windows**
* **Toolbar title**
* **Toolbar root folder**
* **Dock side**
* **Enable glass/transparency effect**
* **Right-click pane adds URL from clipboard**

### Advanced settings

Enable **Show advanced options** to configure:

* Toolbar icon file
* Monitor override
* Theme mode
* Toolbar width
* Hide delay
* Edge trigger distance
* Glass clarity
* Glass tint darkness
* Animation steps
* Animation sleep

---

## URL Shortcuts

Directly dragging a browser address-bar URL into a custom AutoHotkey GUI is not reliable because browsers use a different drag/drop format than regular files. Toolbar XPerience provides two practical alternatives.

### Method 1: right-click URL add

1. Copy a URL from your browser.
2. Open the toolbar pane where you want the shortcut.
3. Right-click the pane.
4. If the clipboard contains a URL, a `.url` shortcut is created.

### Method 2: keyboard shortcut

1. Copy a URL.
2. Hover the toolbar/flyout pane where you want it saved.
3. Press:

```text
Ctrl + Shift + V
```

The script creates a `.url` shortcut in that pane's backing folder.

---

## Drag and Drop

You can drop these onto the toolbar or any flyout pane:

* Files
* Folders
* `.lnk` shortcuts
* `.url` shortcuts

Behavior:

* Dropped files/folders get new `.lnk` shortcuts.
* Dropped `.lnk` shortcuts are cloned when possible.
* Dropped `.url` files are copied as-is.
* Duplicate names are automatically numbered.

Example:

```text
Notepad.lnk
Notepad (1).lnk
Notepad (2).lnk
```

---

## Glass Effect

The optional glass effect uses Windows composition APIs for an acrylic-style blur/tint.

Recommended values:

```text
Glass enabled: checked
Volcanic glass clarity: 95
Glass tint darkness: 80
```

Higher tint darkness values make the panes feel more like smoked or volcanic glass. Lower values make them lighter and more frosted.

> Windows may render acrylic/blur differently depending on build, GPU settings, transparency settings, and system theme.

---

## Multi-Monitor Behavior

With monitor override set to **Auto**:

```text
Dock side: Left  -> furthest-left monitor
Dock side: Right -> furthest-right monitor
```

Advanced Settings allow selecting a specific monitor if Auto does not match your layout.

---

## Startup Behavior

Enable this in Settings:

```text
Start Toolbar XPerience with Windows
```

The script creates a shortcut here:

```text
%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\Toolbar XPerience.lnk
```

Unchecking the option removes the Startup shortcut.

---

## Files Created by the Script

Depending on usage, Toolbar XPerience may create:

```text
SideToolbar.ini
SideToolbar_Favicons\
Documents\Toolbar XP Shortcuts\
Toolbar XPerience.lnk in the Windows Startup folder
```

`SideToolbar.ini` stores user settings.

---

## Recommended Repository Layout

```text
Toolbar-XPerience
│
├── Toolbar XPerience.ahk
├── Toolbar_XPerience.ico
├── README.md
└── LICENSE
```

---

## Notes and Limitations

* Written for **AutoHotkey v1.1**.
* Browser URL drag/drop directly from the address bar is not handled as a normal file drop by AutoHotkey's built-in GUI drop support.
* Acrylic blur uses Windows composition APIs and may vary by system.
* Some special Windows shortcuts may not expose all metadata to AutoHotkey; the script falls back to copying the original shortcut when needed.
* Save the script as **UTF-8 with BOM** if using special characters such as the gear icon.

---

## Planned / Possible Enhancements

* Native OLE URL drag/drop support.
* Per-pane width settings.
* More theme presets.
* Optional pin mode.
* Search/filter inside toolbar panes.
* Import/export settings.

---

## License

Choose a license before publishing. MIT is a common choice for small AutoHotkey utilities.

---

## Credits

Toolbar XPerience is inspired by the classic Windows XP folder toolbar and the convenience of managing launchers through normal filesystem folders.
