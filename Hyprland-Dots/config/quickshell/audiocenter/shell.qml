//@ pragma UseQApplication
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic

import QtQuick
import Quickshell
import Quickshell.Io
import "root:/modules/controlcenter"

/**
 * audiocenter — standalone audio devices panel.
 */
ShellRoot {
    Scope {
        id: shell

        CcCenterPanelState {
            id: panel
        }

        Variants {
            id: panels
            model: panel.panelScreens
            CcCenterPanelWindow {
                panelState: panel
                panelName: "audiocenter"

                CcAudioDrawer {
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
