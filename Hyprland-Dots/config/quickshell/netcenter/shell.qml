//@ pragma UseQApplication
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic

import QtQuick
import Quickshell
import Quickshell.Io
import "root:/modules/netcenter"

/**
 * netcenter — standalone Wi-Fi panel.
 *
 * A dedicated panel with the Wi-Fi drawer (`CcWifiDrawer`, shared with the
 * control center) as its body: the waybar network module opens it with
 *
 *     qs -c netcenter ipc call panel toggle
 *
 * It reuses the control center design system through symlinked module
 * directories: `modules/common` and `modules/controlcenter` point at the
 * control center's copies, and `services` at its services (WifiService).
 */
ShellRoot {
    Scope {
        id: shell

        // One panel window per output (`Theme.panelOutputs`, "all" by
        // default), each bound to its own screen — same model as CcPanelState.
        Variants {
            id: panels
            model: NcPanelState.panelScreens
            NcPanelWindow {}
        }

        // ── Command line control ──────────────────────────────────────────
        // Exactly one handler: per-screen instances would each register the
        // same target.
        IpcHandler {
            target: "panel"

            function toggle() {
                NcPanelState.toggle()
            }

            function close() {
                NcPanelState.dismiss()
            }

            function open() {
                NcPanelState.reveal()
            }
        }
    }
}
