# Quickshell control center

A KDE-Plasma-7-style quick settings panel for QuickShell 0.3.1 on Hyprland.
It replaces the old **swaync** panel that used to open from the waybar bell.

It is additive: it lives entirely in this directory and reuses the Material 3
design system in `../modules/common/` without modifying it.

## Launch

```sh
qs -c controlcenter
```

It is normally started at login by Hyprland (`exec-once`, see below) and it
**starts hidden**. The whole QML tree is built once at startup, so toggling it
is instant — it only maps/unmaps the layer surface, nothing is rebuilt.

Geometry, per output: 420 px wide, anchored only to the top and therefore
centred horizontally **on that output**, 18 px corner radius, `exclusiveZone: 0`
(never reserves screen space).

## Multi-monitor

The panel is drawn by **one window per output**, all driven by one shared state,
so it behaves as a single logical panel:

* `shell.qml` creates a `Variants` over `CcPanelState.panelScreens` and each
  delegate is a `ControlCenterPanel` bound to its own `modelData` (its screen).
  The model is live: plugging in a monitor adds an instance, unplugging one
  destroys it.
* Visibility, the inline power menu and the IPC live in the
  `modules/controlcenter/CcPanelState.qml` singleton, so `open` / `close` /
  `toggle` — from the waybar bell, the `$mainMod SHIFT, N` keybind or Escape —
  always act on **every** instance at once. A `PanelWindow` property could not
  do that: it would be per instance, and each monitor would toggle on its own.
* Each instance is centred on its own screen: with two 1920x1080 outputs at
  x=0 and x=1920, `hyprctl layers` shows one `quickshell-controlcenter` surface
  at x=750 and one at x=2670 (750 + 1920). `exclusiveZone: 0` and `anchors { top:
  true }` are unchanged, and `hyprctl monitors` still reports `reserved: 0 42 0 0`
  on both (waybar only).

### `Theme.panelOutputs` — all monitors or one

```qml
// modules/controlcenter/Theme.qml
readonly property string panelOutputs: "all"   // default: every connected monitor
// readonly property string panelOutputs: "eDP-1"   // single-output mode
```

* `"all"` → one instance per connected monitor.
* `"<name>"` → the panel exists only on that output (`hyprctl monitors` prints
  the names, e.g. `eDP-1`, `HDMI-A-1`).
* A name that matches no connected output logs
  `Theme.panelOutputs="..." matches no connected output` and falls back to
  `"all"`, so a typo cannot leave the user with no panel at all.

The switch is read in `CcPanelState.panelScreens`, which is the model of the
`Variants`; editing it reloads the running config (QuickShell watches its own
QML files) with no restart.

## Toggle from the command line

```sh
qs -c controlcenter ipc call panel toggle     # exact command the waybar bell runs
qs -c controlcenter ipc call panel open
qs -c controlcenter ipc call panel close
```

The single `IpcHandler { target: "panel" }` lives at the bottom of `shell.qml`,
next to the `Variants`, and forwards to `CcPanelState`:

```qml
IpcHandler {
    target: "panel"

    function toggle() { CcPanelState.toggle() }
    function close() { CcPanelState.dismiss() }
    function open() { CcPanelState.reveal() }
}
```

Exactly one handler exists. Registering it inside the per-screen panel would
register the target once per monitor, and the handlers would then fight over the
same name. `qs -c controlcenter ipc show` lists one `target panel` with
`open` / `close` / `toggle`.

## Escape closes the panel

Escape and `ipc call panel close` run **the same code path**: the shared
`CcPanelState.dismiss()` (`modules/controlcenter/CcPanelState.qml`), which also
resets `powerMenuOpen` and clears it on **every** instance, so Escape closes all
panels at once. `toggle()` and `close()` in the `IpcHandler` call it too, so
there is only one way for the panel to disappear.

### The mechanism

The panel used to be `WlrLayershell.keyboardFocus: WlrKeyboardFocus.None`, so it
never received key events and Escape went to the focused window. It takes the
keyboard **only while it is visible**:

```qml
WlrLayershell.keyboardFocus: panel.ownsKeyboardFocus ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
```

plus a bare, non-mouse-accepting `Item` that holds active focus while the panel
owns the keyboard and calls `CcPanelState.dismiss()` on `Qt.Key_Escape`:

```qml
Item {
    id: keyHandler
    anchors.fill: parent
    focus: panel.ownsKeyboardFocus
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            CcPanelState.dismiss()
            event.accepted = true
        }
    }
}
```

### Only one instance takes the keyboard (deliberate)

Only one Wayland surface can hold the keyboard at a time, so
`WlrKeyboardFocus.Exclusive` on every instance would be a race the compositor
resolves for whichever surface committed last — possibly the panel on a monitor
the user is not even looking at, taking the keyboard away from the focused
window. Instead:

```qml
// CcPanelState.qml
readonly property var keyboardScreen: {
    const focused = Hyprland.focusedMonitor        // Quickshell.Hyprland
    if (focused) {
        const match = screens.find(screen => screen.name === focused.name)
        if (match) return match                    // the monitor you are on
    }
    return screens[0]                              // no panel there / no Hyprland service
}
```

* The instance on Hyprland's **focused** monitor gets `Exclusive`; every other
  instance stays at `None` (pointer events are not gated by keyboard
  interactivity, so the sliders and tiles on the other monitors still work with
  the mouse).
* The ownership follows the focused monitor, so Escape works on whichever screen
  the user is actually on. It is recomputed automatically when focus moves.
* **Trade-offs, honestly:** the keyboard owner is decided by the compositor's
  focused monitor rather than by the pointer (they coincide in practice, since
  Hyprland focuses the monitor the pointer is on). And if Hyprland's IPC is
  unavailable — or the focused monitor is the one output *without* a panel in
  single-output mode — the first panel instance in `Theme.panelOutputs` order
  takes the keyboard instead, so exactly one surface can always receive Escape.
  In that fallback case Escape closes the panel only from that screen's
  perspective (it still closes all of them, but only that surface can hear the
  key).

### What this costs

* While the panel is **open** the owning instance holds the keyboard, so
  keystrokes do not reach the window that was focused before (Wayland has no key
  pass-through for a client without a virtual keyboard). Escape is the only key
  the panel acts on; every other key is ignored.
* While the panel is **hidden** the surfaces are unmapped *and* `keyboardFocus`
  is `None`, so nothing can be swallowed and normal window keybinds are
  untouched.
* `WlrKeyboardFocus.OnDemand` was rejected for the owning instance: the panel
  would only take the keyboard after a click, so Escape would do nothing when
  the panel was opened from the waybar bell.

### Click outside to close: NOT implemented

A full-screen input-catcher layer would swallow the click that is supposed to
close the panel (the click would not reach the window underneath), which is a
regression. `HyprlandFocusGrab` (`hyprland_focus_grab_v1`) is not a drop-in
either: in Hyprland 0.56.2 it installs a **seat grab with `m_keyboard = true`
and `m_pointer = true`** (`src/protocols/FocusGrab.cpp`), i.e. it intercepts
keyboard *and* pointer input and changes how Escape is routed — and the
`overview/` config needs a `Timer` delay before activating it, which points at a
race. Skipped deliberately; the waybar bell / `panel close` / Escape remain the
ways to close.

### Verifying Escape without a physical key

`hyprctl dispatch sendshortcut` **cannot** be used: its third argument (a window
regex) is mandatory — an empty one is dropped by `CVarList2` and the dispatcher
answers `sendshortcut: invalid args` — and when it is given, `Actions::pass()`
calls `setKeyboardFocus()` on that window before sending the key. It therefore
always delivers to a *window*, never to a layer surface:

```sh
hyprctl dispatch sendshortcut ", Escape,"          # -> sendshortcut: invalid args
hyprctl dispatch sendshortcut ", Escape, class:x"  # -> key goes to window x
```

Instead, inject a real key event through the compositor with a tiny
`zwp_virtual_keyboard_v1` client (built once, no installs, gcc + libwayland are
already on the system). The wire format wants the **raw evdev code**: Escape = 1,
`z` = 44.

```sh
# /tmp/dsh-vk/vkinject (source: /tmp/dsh-vk/vk.c, rebuilt with
#   wayland-scanner client-header vk.xml vk-client.h &&
#   wayland-scanner private-code  vk.xml vk-protocol.c &&
#   gcc -o vkinject vk.c vk-protocol.c $(pkg-config --cflags --libs wayland-client))
qs -c controlcenter ipc call panel open
hyprctl layers | grep quickshell-controlcenter   # one per monitor, 750 46 420 354 on eDP-1
# (y = waybar height + Theme.panelMargin; with a 38 px bar -> 46, with 33 px -> 41)
/tmp/dsh-vk/vkinject 1                           # Escape -> every instance closes
hyprctl layers | grep quickshell-controlcenter   # gone
```

### Reverting the Escape / keyboard-focus feature

Restore `modules/controlcenter/ControlCenterPanel.qml`:

1. The `keyboardFocus` binding back to a plain
   `WlrKeyboardFocus: WlrKeyboardFocus.None` (delete `ownsKeyboardFocus` and the
   comment above it).
2. Delete the `Item { id: keyHandler ... }` block.

There is nothing to undo outside `controlcenter/`: no Hyprland config, no
keybind, no submap, no waybar change.

### Reverting the multi-monitor refactor

1. In `shell.qml`, delete the `Variants` block and put a single
   `ControlCenterPanel {}` back inside the `Scope` — the panel then needs its
   `screen:` set explicitly again (the old
   `screens.find(s => s.name === Theme.outputName) ?? screens[0]` lookup).
2. Give `ControlCenterPanel.qml` its own `property bool panelVisible: false` and
   `property bool powerMenuOpen: false` again, point `visible` / the header /
   the power menu back at those properties, and restore `dismiss()` / `reveal()`
   in the panel together with the `IpcHandler { target: "panel" }` block that
   used to be at the bottom of the file.
3. `rm modules/controlcenter/CcPanelState.qml` and drop its line from
   `modules/controlcenter/qmldir`.
4. In `Theme.qml`, `panelOutputs` can stay (it is simply unused once step 1 is
   undone) or go back to a `readonly property string outputName: "eDP-1"`.

`git` is not used here, so keep a copy before starting if you want this to be
mechanical.

## Notifications

The panel's `NotificationServer` (in `services/CcNotifications.qml`) owns
`org.freedesktop.Notifications`. Only one process can own that name, so **swaync
must not run**. swaync used to be autostarted by Hyprland; that autostart is now
commented out and swaync was stopped, so the control center gets the bus.

### Revert notifications back to swaync — one command

```sh
qs -c controlcenter ipc call panel close >/dev/null 2>&1; systemctl --user stop dsh-cc 2>/dev/null; systemctl --user start swaync
```

(If you started the panel some other way, replace the `stop dsh-cc` part with
whatever kills that instance — e.g. `pkill -f 'qs -c controlcenter'`. swaync
cannot take the bus while a quickshell instance still holds it.)

To make the revert permanent across logins you must also un-comment the
`exec-once = swaync` line — see the file-by-file list below.

**Caveat:** `/usr/share/dbus-1/services/org.erikreider.swaync.service` declares
`Name=org.freedesktop.Notifications` with `SystemdService=swaync.service`. That
means if a notification is sent while *nothing* owns the name, dbus will
**start swaync again by itself**. That is why the control center is started at
login by `exec-once`: it must claim the bus before anything sends a
notification.

## Testing the end-to-end path

```sh
qs -c controlcenter ipc call panel open
notify-send -a Test "Hello" "Rendered by the QuickShell control center"
hyprctl layers | grep quickshell          # xywh 750 50 420 <height> on eDP-1
                                          # xywh 2670 50 420 <height> on HDMI-A-1
grim -o eDP-1 /tmp/cc-check.png
grim -o HDMI-A-1 /tmp/cc-check-hdmi.png
```

## Files changed outside this directory (and how to undo each)

Everything else lives inside `~/.config/quickshell/controlcenter/`.

### 1. `~/.config/waybar/ModulesCustom`

| Line | Before | After |
| --- | --- | --- |
| 166 | `"tooltip-format": "Left Click: Launch Quick Settings &amp; Notification Center\nRight Click: Launch Logout Menu",` | `"tooltip-format": "Left Click: Toggle Control Center\nRight Click: Launch Logout Menu",` |
| 168 | `"on-click": "command -v ags && ags request -i matshell 'system-menu' \|\| swaync-client -t -sw",` | `"on-click": "qs -c controlcenter ipc call panel toggle",` |

`on-click-right` (line 169, `Wlogout.sh`) was deliberately **not** changed.

Undo: restore those two lines to the "Before" text above.

### 2. `~/JaKooLit/Hyprland-Dots/config/waybar/ModulesCustom`

Same two lines (166 and 168), same before/after. Note that before this change
the repo copy's line 166 used a bare `&` instead of `&amp;`; both copies are now
byte-identical for this module.

Undo: same as above, in the repo copy.

> Waybar rereads its **config** only on a full restart: `pkill -x waybar; waybar`
> (`pkill -SIGUSR2 waybar` only reloads the CSS).

### 3. `~/.config/hypr/configs/Startup_Apps.conf`

Line 22, `exec-once = swaync`, was replaced by two lines, so every line below 22
shifted down by one:

```
22  #exec-once = swaync  # replaced by the QuickShell control center (owns org.freedesktop.Notifications)
23  exec-once = command -v qs && qs -c controlcenter
```

Undo: delete line 23 and restore line 22 to `exec-once = swaync`.

### 4. `~/JaKooLit/Hyprland-Dots/config/hypr/configs/Startup_Apps.conf`

Identical change at the same lines.

Undo: identical.

> Only the `.conf` files are live: `~/.config/hypr/hyprland.conf` sources
> `Startup_Apps.conf`. The parallel `Startup_Apps.hl` tree is **not** loaded by
> the running session (confirmed via `hyprctl getoption misc:vrr` → `0`, which
> only the `.conf` tree sets). It still contains `exec-once = swaync` at line 22
> and was intentionally left untouched; apply the same edit there if you ever
> switch to `hyprland.hl`.

### 5. Runtime state (no file changed)

```sh
systemctl --user stop swaync     # what was done; swaync.service is `disabled`, so it stays down
```

Undo: `systemctl --user start swaync` (see the one-liner above).

### 6. Transient unit left running for this session

The panel currently running was started by the agent that wired this up as a
systemd transient unit so it would survive the agent session:

```sh
systemctl --user stop dsh-cc     # stop the panel instance
```

At the next login Hyprland starts it from `exec-once` instead, and this
transient unit no longer exists (transient units do not survive logout/reboot).

## Known leftovers / follow-ups

* `~/.config/hypr/configs/Keybinds.conf` **line 83** still runs the old panel:
  `bindd = $mainMod SHIFT, N, panel de notificaciones, exec, swaync-client -t -sw`.
  It was left alone on purpose (out of scope) and now does nothing while swaync
  is stopped. Suggested replacement:
  `bindd = $mainMod SHIFT, N, panel de notificaciones, exec, qs -c controlcenter ipc call panel toggle`
  (the same line exists in `Keybinds.hl`, which is not loaded).
* `~/JaKooLit/Hyprland-Dots/config/hypr/configs/Startup_Apps.conf` line 46 is
  `exec-once = qs` in the repo but `exec-once = qs -c overview  # Quickshell Overview`
  live — a pre-existing repo difference, not touched here.
* `pkill -SIGUSR2 waybar` is not enough after editing `ModulesCustom`; restart
  waybar.

## Remove

```sh
rm -rf ~/.config/quickshell/controlcenter
```

(Then undo files 1–4 above to point the bell and the login autostart back at
swaync.)

## Layout

1. **Header** — avatar (`~/.face`, monogram fallback), user name, uptime
   (`/proc/uptime`), and four backgroundless icon buttons: lock (`hyprlock`),
   power (opens the inline power menu), settings (opens this directory),
   edit (opens `Theme.qml`).
2. **Sliders** — brightness (`brightnessctl`) and output volume (QuickShell
   `Pipewire`); thin 6 px rounded tracks, draggable, applied on release.
3. **Tiles** — 2 columns x 3 rows: network, bluetooth, audio output, battery,
   `/` and `/home`. Active tiles use the accent gradient.
4. **Notifications** — scrollable list from QuickShell's `NotificationServer`
   with app name, summary, body and a dismiss button. Each item is
   `Theme.notificationItemHeight` (68 px) tall with `Theme.notificationSpacing`
   (6 px) gaps, the list being capped at `Theme.notificationMaxHeight` (232 px).
5. **Power menu** — inline, revealed by the power button; suspend / restart /
   shut down via `systemctl`.

## Tuning

Everything hardcoded (geometry, opacities, panel width, motion durations) is in
`modules/controlcenter/Theme.qml`. Rounding comes from the shared `Appearance`
singleton. The one deliberate override is `Theme.iconFontFamily`, because
`Appearance.font.family.iconFont` points at "FiraConde Nerd Font", which is not
installed, so `MaterialSymbol` would render ligature names as plain text.

The colours are not hardcoded either: `Theme.qml` derives them from the wallust
palette that `~/.config/wallust/templates/qml_color.json` renders to
`~/.config/quickshell/qml_color.json`, and watches that file, so the panel
follows the wallpaper without a restart. The knobs are at the top of the file —
`palettePath`, `logPalette`, the surface tints (`tintPanel`, `tintTile`,
`tintTileHover`, `tintTileIcon`, `alphaTile`, `alphaTileIcon`) and
`minContrast`, the WCAG ratio every text role is held to. Every role is a plain
`property color` (a QML binding named `onAccent` would be silently dropped,
because `accent` is a property of the same object), assigned by `applyRoles()`
from one pure derivation.

`Theme.panelOutputs` decides *where* the panel is shown (`"all"` = every monitor,
or one output name — see *Multi-monitor*). Nothing else about the panel is
display-specific: each instance reads its own `screen`.

## Notes

* Only `opacity`, `scale` and `color` are animated, and nothing loops.
* The panel has no text input. It takes keyboard focus **only while it is
  visible** (to handle Escape) and drops back to `WlrKeyboardFocus.None` when it
  hides, so opening it cannot affect the focused window after it is closed.
* The shared services are singletons (`Theme`, `CcSystem`, `CcNotifications`,
  `CcPanelState`), so one panel per monitor does **not** duplicate processes,
  the `org.freedesktop.Notifications` server, or the wallust file watch: only
  the QML tree of the window is built once per screen.
* Turning the panel on or off logs one line per toggle —
  `[controlcenter] panel open on [eDP-1, HDMI-A-1] | keyboard focus: eDP-1` —
  which is the quickest way to see what a multi-monitor toggle did
  (`journalctl --user -u controlcenter -f`).
