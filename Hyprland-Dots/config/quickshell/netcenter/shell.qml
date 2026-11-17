//@ pragma UseQApplication
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic

import QtQuick
import Quickshell
import Quickshell.Io
import "root:/modules/controlcenter"
import "root:/services"

/**
 * netcenter — standalone Wi-Fi panel.
 */
ShellRoot {
    Scope {
        id: shell

        CcCenterPanelState {
            id: panel
            onDismissed: WifiService.cancelPrompt()
        }

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

        IpcHandler {
            target: "panel"

            function toggle() {
                panel.toggle()
            }

            function toggleOn(targetScreen: string) {
                panel.toggle(targetScreen)
            }

            function close() {
                panel.dismiss()
            }

            function open() {
                panel.reveal()
            }

            function openOn(targetScreen: string) {
                panel.reveal(targetScreen)
            }
        }
    }
}
