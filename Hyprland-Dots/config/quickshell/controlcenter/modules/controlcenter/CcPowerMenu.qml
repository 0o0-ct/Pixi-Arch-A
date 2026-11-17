import QtQuick
import "root:/modules/controlcenter"
import "root:/services"

/**
 * Inline power menu, revealed by the header's power button. Nothing runs on
 * the first click: the destructive commands need a deliberate second click on
 * the named entry.
 */
Item {
    id: root

    signal actionInvoked()

    readonly property var actions: [
        {
            icon: "bedtime",
            title: "Suspend",
            subtitle: "systemctl suspend",
            command: ["systemctl", "suspend"]
        },
        {
            icon: "restart_alt",
            title: "Restart",
            subtitle: "systemctl reboot",
            command: ["systemctl", "reboot"]
        },
        {
            icon: "power_settings_new",
            title: "Shut down",
            subtitle: "systemctl poweroff",
            command: ["systemctl", "poweroff"]
        }
    ]

    implicitHeight: column.implicitHeight

    Column {
        id: column
        width: root.width
        spacing: Theme.tileGap

        Repeater {
            model: root.actions

            CcTile {
                width: column.width
                icon: root.actions[index].icon
                title: root.actions[index].title
                subtitle: root.actions[index].subtitle
                onClicked: {
                    CcSystem.runDetached(root.actions[index].command)
                    root.actionInvoked()
                }
            }
        }
    }
}
