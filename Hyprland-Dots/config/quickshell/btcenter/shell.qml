//@ pragma UseQApplication
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic

import QtQuick
import Quickshell
import Quickshell.Io
import "root:/modules/controlcenter"

/**
 * btcenter — standalone Bluetooth panel.
 *
 * A dedicated panel with the Bluetooth drawer (`CcBluetoothDrawer`, shared
 * with the control center) as its body: the waybar bluetooth module opens it
 * with
 *
 *     qs -c btcenter ipc call panel toggle
 *
 * The window and its state are shared components of the control center
 * module (`CcCenterPanelState` / `CcCenterPanelWindow`, same code as
 * netcenter and audiocenter). The design system is reused through symlinked
 * module directories: `modules/common` and `modules/controlcenter` point at
 * the control center's copies, and `services` at its services.
 */
ShellRoot {
    Scope {
        id: shell

        // Shared state: one value every screen instance obeys.
        CcCenterPanelState {
            id: panel
        }

        // One panel window per output (`Theme.panelOutputs`, "all" by
        // default), each bound to its own screen. The model is live: plugging
        // a monitor in adds an instance and unplugging one destroys it.
        Variants {
            id: panels
            model: panel.panelScreens
            CcCenterPanelWindow {
                panelState: panel
                panelName: "btcenter"

                CcBluetoothDrawer {
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
