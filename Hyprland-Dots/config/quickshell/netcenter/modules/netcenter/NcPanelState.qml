pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import "root:/modules/controlcenter"
import "root:/services"

/**
 * Shared state of the standalone Wi-Fi panel (`qs -c netcenter`).
 *
 * Mirror of CcPanelState: the panel is drawn by one window per output (see
 * `shell.qml`), but it is a single logical panel — every instance asks this
 * singleton whether it should be mapped, so open/close/toggle from the waybar
 * module or Escape always act on every instance at once.
 */
Singleton {
    id: state

    // ══════════════════════════════════════════════════════════════════════
    //  VISIBILITY — one value shared by every screen instance
    // ══════════════════════════════════════════════════════════════════════

    /** Whether the panel is mapped. Every instance binds its `visible` here. */
    property bool visible: false

    /**
     * Monitor the panel was opened on, captured at open time.
     *
     * Used by the "focused" output mode so an already-open panel does NOT jump
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

    /** Closes the panel on every instance. */
    function dismiss() {
        state.visible = false
        state.openScreenName = ""
        WifiService.cancelPrompt()
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

    // ══════════════════════════════════════════════════════════════════════
    //  OUTPUTS — which screens get a panel instance
    // ══════════════════════════════════════════════════════════════════════

    /**
     * Screens the panel is drawn on, read from `Theme.panelOutputs`.
     *
     * "all" (the default) means every connected output; anything else is
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

        console.warn("[netcenter] Theme.panelOutputs=\"" + wanted
            + "\" matches no connected output; showing the panel on every monitor")
        return connected
    }

    // ══════════════════════════════════════════════════════════════════════
    //  KEYBOARD — which single instance may take the keyboard
    // ══════════════════════════════════════════════════════════════════════

    /**
     * The instance allowed to take `WlrKeyboardFocus.OnDemand` (so the
     * password field can receive typing and Escape closes the panel on the
     * monitor the user is actually on).
     */
    readonly property var keyboardScreen: {
        const screens = state.panelScreens
        if (screens.length === 0 || state.openScreenName.length === 0)
            return null
        return screens.find(screen => screen.name === state.openScreenName) ?? screens[0]
    }

    readonly property string keyboardScreenName: state.openScreenName
}
