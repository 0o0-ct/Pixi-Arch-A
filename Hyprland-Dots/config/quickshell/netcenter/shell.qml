//@ pragma UseQApplication
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic

import QtQuick
import Quickshell
import Quickshell.Io
import "root:/modules/controlcenter"
import "root:/services"

/**
 * netcenter — standalone Wi-Fi panel.
 *
 * A dedicated panel with the Wi-Fi drawer (`CcWifiDrawer`, shared with the
 * control center) as its body: the waybar network module opens it with
 *
 *     qs -c netcenter ipc call panel toggle
 *
 * The window and its state are shared components of the control center
 * module (`CcCenterPanelState` / `CcCenterPanelWindow`, same code as
 * btcenter and audiocenter). The design system is reused through symlinked
 * module directories: `modules/common` and `modules/controlcenter` point at
 * the control center's copies, and `services` at its services.
 */
ShellRoot {
    Scope {
        id: shell

        // Shared state: one value every screen instance obeys. Closing the
        // panel also cancels a pending Wi-Fi password prompt.
        CcCenterPanelState {
            id: panel
            onDismissed: WifiService.cancelPrompt()
        }

        // One panel window per output (`Theme.panelOutputs`, "all" by
        // default), each bound to its own screen. The model is live: plugging
        // a monitor in adds an instance and unplugging one destroys it.
        Variants {
            id: panels
            model: panel.panelScreens
            CcCenterPanelWindow {
                panelState: panel
                panelName: "netcenter"

                CcWifiDrawer {
                    width: parent.width
                }
            }
        }

        // ── Command line control ──────────────────────────────────────────
        // Exactly one handler: per-screen instances would each register the
        // same target.
        IpcHandler {
            target: "panel"

            function toggle() {
                panel.toggle()
            }

            function close() {
                panel.dismiss()
            }

            function open() {
                panel.reveal()
            }
        }
    }
}
