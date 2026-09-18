pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import "root:/modules/controlcenter"

/**
 * Shared state of the control center panel.
 *
 * The panel is drawn by *one window per output* (see `shell.qml`), but it is a
 * single logical panel: every instance asks this singleton whether it should be
 * mapped, so `open` / `close` / `toggle` — from the waybar bell, the Hyprland
 * keybind or Escape — always act on every instance at once.
 *
 * Keeping the state here rather than inside `ControlCenterPanel.qml` is what
 * makes that possible: a `PanelWindow` property would be per instance, and each
 * monitor would toggle on its own.
 *
 * The same applies to the IPC: exactly one `IpcHandler { target: "panel" }`
 * exists, in `shell.qml`. Registering it per instance would give several
 * handlers fighting over one target name.
 */
Singleton {
    id: state

    // ══════════════════════════════════════════════════════════════════════
    //  VISIBILITY — one value shared by every screen instance
    // ══════════════════════════════════════════════════════════════════════

    /** Whether the panel is mapped. Every instance binds its `visible` here. */
    property bool visible: false

    /** Inline power menu of the panel; also shared, so all instances agree. */
    property bool powerMenuOpen: false

    /**
     * Monitor the panel was opened on, captured at open time.
     *
     * Used by the `"focused"` output mode so an already-open panel does NOT jump
     * to the other screen when focus moves. Empty when unknown.
     */
    property string openScreenName: ""

    /** Opens the panel, on the monitor the user is working on or requested. */
    function reveal(targetScreen) {
        if (typeof targetScreen === "string" && targetScreen.length > 0) {
            state.openScreenName = targetScreen
        } else {
            const focused = Hyprland.focusedMonitor
            state.openScreenName = focused ? focused.name : (Quickshell.screens[0]?.name ?? "")
        }
        state.visible = true
    }

    /**
     * Closes the panel on every instance.
     */
    function dismiss() {
        state.visible = false
        state.powerMenuOpen = false
        state.openScreenName = ""
    }

    /** Flips `visible` targeting the specific monitor. */
    function toggle(targetScreen) {
        if (state.visible) {
            const requested = (typeof targetScreen === "string" && targetScreen.length > 0)
                ? targetScreen
                : (Hyprland.focusedMonitor?.name ?? "")
            if (requested.length > 0 && requested !== state.openScreenName) {
                state.openScreenName = requested
                return
            }
            state.dismiss()
        } else {
            state.reveal(targetScreen)
        }
    }

    /**
     * Logs one line per toggle: which outputs have a panel and which instance
     * currently owns the keyboard. Cheap, and it is the easiest way to see what
     * a multi-monitor toggle actually did.
     */
    onVisibleChanged: console.log("[controlcenter] panel " + (visible ? "open" : "closed")
        + " on [" + state.outputNames() + "]"
        + " | keyboard focus: " + (state.visible ? state.keyboardScreenName : "none"))

    // ══════════════════════════════════════════════════════════════════════
    //  OUTPUTS — which screens get a panel instance
    // ══════════════════════════════════════════════════════════════════════

    /**
     * Screens the panel is drawn on, read from `Theme.panelOutputs`.
     *
     * `"all"` (the default) means every connected output; anything else is
     * matched against the output name. This is the model of the `Variants` in
     * `shell.qml`, so it stays live: plugging a monitor in adds an instance,
     * unplugging one destroys it.
     */
    readonly property var panelScreens: {
        const connected = Quickshell.screens ?? []
        if (connected.length === 0)
            return []

        const wanted = (Theme.panelOutputs ?? "").trim()

        // "focused": solo el monitor en el que estas trabajando. El nombre se
        // captura al ABRIR (ver reveal()), asi que mover el foco mientras el
        // panel esta abierto no lo hace saltar de pantalla.
        //
        // OJO: se lee Hyprland.focusedMonitor directamente y NO
        // state.keyboardScreen, porque keyboardScreen ya depende de
        // panelScreens y referenciarlo aqui seria un ciclo de bindings.
        if (wanted === "focused") {
            const live = Hyprland.focusedMonitor
            const name = state.visible ? state.openScreenName : (live ? live.name : "")
            const match = name ? connected.find(screen => screen.name === name) : null
            return match ? [match] : connected.slice(0, 1)
        }

        if (wanted.length === 0 || wanted === "all")
            return connected

        const named = connected.filter(screen => screen.name === wanted)
        if (named.length > 0)
            return named

        // A typo must not leave the user with no panel at all.
        console.warn("[controlcenter] Theme.panelOutputs=\"" + wanted
            + "\" matches no connected output; showing the panel on every monitor")
        return connected
    }

    /** "eDP-1, HDMI-A-1" — for the log line above. */
    function outputNames() {
        const names = []
        for (let i = 0; i < state.panelScreens.length; i++)
            names.push(state.panelScreens[i].name)
        return names.join(", ")
    }

    // ══════════════════════════════════════════════════════════════════════
    //  KEYBOARD — which single instance may take the keyboard
    // ══════════════════════════════════════════════════════════════════════

    /**
     * The instance allowed to take `WlrKeyboardFocus.Exclusive`.
     *
     * Only one Wayland surface can hold the keyboard at a time, so `Exclusive`
     * on all instances at once is a race the compositor wins for whichever
     * surface committed last — which can be the panel on a monitor the user is
     * not even looking at, stealing the keyboard from the focused window.
     *
     * Instead the keyboard follows the monitor Hyprland has focused, so Escape
     * closes the panel on the screen the user is actually on. If the focused
     * monitor has no panel (single-output mode on the other screen) or the
     * Hyprland service is unavailable, the first panel instance takes it, so
     * Escape always has exactly one surface able to receive it.
     */
    readonly property var keyboardScreen: {
        const screens = state.panelScreens
        if (screens.length === 0 || state.openScreenName.length === 0)
            return null
        return screens.find(screen => screen.name === state.openScreenName) ?? screens[0]
    }

    readonly property string keyboardScreenName: state.openScreenName
}
