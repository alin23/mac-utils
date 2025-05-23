# mac-utils

Small utilities for macOS

## runfg

Run any command ensuring that the process won't be sent to the Apple Silicon efficiency cores.

- [runfg.swift](/runfg.swift)
- [runfg (compiled binary)](/bin/runfg)

---

## runbg

Run any command pinned to the Apple Silicon efficiency cores.

- [runbg.swift](/runbg.swift)
- [runbg (compiled binary)](/bin/runbg)

---

## VerticalMonitorLayout

Arrange the external monitor above the MacBook display.

- [VerticalMonitorLayout.swift](/VerticalMonitorLayout.swift)
- [VerticalMonitorLayout (compiled binary)](/bin/VerticalMonitorLayout)

[![add to shortcuts button](img/add-to-shortcuts.svg)](https://www.icloud.com/shortcuts/05d718d1f6c24c1493a73f539ddd12a9)

![vertical monitor layout in Display preferences](https://files.alinpanaitiu.com/vertical-monitor-layout.png)

---

## HorizontalMonitorLayout

Arrange the external monitor to the left or right of the MacBook display.

- [HorizontalMonitorLayout.swift](/HorizontalMonitorLayout.swift)
- [HorizontalMonitorLayout (compiled binary)](/bin/HorizontalMonitorLayout)

---

## SwapMonitors

- [SwapMonitors.swift](/SwapMonitors.swift)
- [SwapMonitors (compiled binary)](/bin/SwapMonitors)

In a MacBook with 2 monitors setup, swap the external monitors around.

[![add to shortcuts button](img/add-to-shortcuts.svg)](https://www.icloud.com/shortcuts/3c9f6a71589a4813904973b3ef493c1f)

![swap monitor layout in Display preferences](https://files.alinpanaitiu.com/swap-monitor-layout.png)

---

## MirrorMacBookToMonitor

In a MacBook with 1 monitor setup, mirror the MacBook display contents to the external monitor.

- [MirrorMacBookToMonitor.swift](/MirrorMacBookToMonitor.swift)
- [MirrorMacBookToMonitor (compiled binary)](/bin/MirrorMacBookToMonitor)

[![add to shortcuts button](img/add-to-shortcuts.svg)](https://www.icloud.com/shortcuts/93b2496bd03b4c21886e2322409240cb)

![mirrored MacBook in Display preferences](https://files.alinpanaitiu.com/mirror-macbook-to-monitor.png)

---

## ToggleHDR

Enable/disable HDR for a monitor where the **High Dynamic Range** checkbox is available in Display Preferences.

- [ToggleHDR.swift](/ToggleHDR.swift)
- [ToggleHDR (compiled binary)](/bin/ToggleHDR)

[![add to shortcuts button](img/add-to-shortcuts.svg)](https://www.icloud.com/shortcuts/2f412b6ad9644aaf83e86bd53cb4294e)

![hdr checkbox in Display preferences](https://files.lunar.fyi/hdr-toggle-ventura.webp)

---

## RotateDisplay

Change rotation of a display from the command line.

- [RotateDisplay.swift](/RotateDisplay.swift)
- [RotateDisplay (compiled binary)](/bin/RotateDisplay)

---

## SetNativeBrightness

Set brightness for Apple native displays from the command line.

- [SetNativeBrightness.swift](/SetNativeBrightness.swift)
- [SetNativeBrightness (compiled binary)](/bin/SetNativeBrightness)

Works for the built-in MacBook and iMac screen, and Apple vendored displays like:

- Studio Display
- Pro Display XDR
- LG Ultrafine for Mac
- LED Cinema
- Thunderbolt Display

---

## SetKeyboardBacklight

Set keyboard backlight brightness from the command line.

- [SetKeyboardBacklight.swift](/SetKeyboardBacklight.swift)
- [SetKeyboardBacklight (compiled binary)](/bin/SetKeyboardBacklight)

---

## IsNowPlaying

Prints `true` (or exits with code `0` on `-q`) if the Mac is currently playing any media.

Prints now playing media information with `-v` if the Mac is currently playing any media.

- [IsNowPlaying.swift](/IsNowPlaying.swift)
- compiled binary
    - [com.apple.controlcenter.mac-utils.IsNowPlaying (for macOS 15.4+)](/bin/com.apple.controlcenter.mac-utils.IsNowPlaying)
    - [IsNowPlaying (for macOS 15.3 and older)](/bin/IsNowPlaying)

> On macOS 15.4 and newer, the compiled binary has the Control Center bundle ID as a prefix to work around a restriction added in that macOS version.
>
> To keep using the `IsNowPlaying` command on macOS 15.4 and newer, you can symlink the binary to `IsNowPlaying`:
>
> ```sh
> ln -s com.apple.controlcenter.mac-utils.IsNowPlaying IsNowPlaying
> ```

---

## IsCameraOn

Prints true (or exits with code 0 on `-q`) if the Mac camera is in use by any application.

- [IsCameraOn.swift](/IsCameraOn.swift)
- [IsCameraOn (compiled binary)](/bin/IsCameraOn)

---

## ReferencePreset

Activate presets for reference monitors like the Pro Display XDR or the MacBook Pro 2021 screen.

- [ReferencePreset.swift](/ReferencePreset.swift)
- [ReferencePreset (compiled binary)](/bin/ReferencePreset)

![reference presets in Display preferences](https://files.alinpanaitiu.com/reference-display-presets.png)

## ApplyColorProfile

Apply `.icc` color profiles to any display. It works even if the display does not have a color profile setting in System Settings.

- [ApplyColorProfile.swift](/ApplyColorProfile.swift)
- [ApplyColorProfile (compiled binary)](/bin/ApplyColorProfile)

---

## SendMediaKey

Send media key events such as play/pause, next, previous, volume up, volume down, mute, etc.

- [SendMediaKey.swift](/SendMediaKey.swift)
- [SendMediaKey (compiled binary)](/bin/SendMediaKey)
