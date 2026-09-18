//@ pragma UseQApplication
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic

import QtQuick
import Quickshell
import Quickshell.Io
import "root:/modules/common"
import "root:/modules/common/widgets"
import "root:/modules/controlcenter"
import "root:/services"

ShellRoot {
    Scope {
        id: shell

        // One panel window per output (`Theme.panelOutputs`, "all" by default),
        // each bound to its own screen. The model is live: plugging a monitor in
        // adds an instance and unplugging one destroys it.
        Variants {
            id: panels
            model: CcPanelState.panelScreens
            ControlCenterPanel {}
        }

        // ── Command line control ──────────────────────────────────────────
        // The waybar bell runs: qs -c controlcenter ipc call panel toggle
        // Exactly one handler, here: per-screen instances would each register
        // the same target.
        IpcHandler {
            target: "panel"

            function toggle() {
                CcPanelState.toggle()
            }

            function close() {
                CcPanelState.dismiss()
            }

            function open() {
                CcPanelState.reveal()
            }
        }
    }
}
