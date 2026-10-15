import QtQuick
import QtQuick.Layouts
import "root:/modules/common"
import "root:/modules/common/widgets"
import "root:/modules/controlcenter"
import "root:/services"

/**
 * One audio device row inside the audio drawer (an output or input device).
 *
 * Left: device icon and name, with an "Activo" marker on the current default
 * device. Right: whatever the parent passes in `trailing` (the volume of the
 * active output). Clicking a non-active row makes that device the default.
 */
Rectangle {
    id: root

    /** The PipeWire node this row shows (from CcSystem.audioSinks / audioSources). */
    required property var node

    /** Whether this node is the current default device. */
    property bool active: false

    /** Trailing text (e.g. the volume of the active output). */
    property string trailing: ""

    /** Emitted when the row is clicked and should become the default device. */
    signal activated()

    implicitHeight: 46
    radius: 10
    color: (rowHover.hovered && !root.active) ? Theme.tileHoverBg : Theme.tileIconBg
    border.width: 1
    border.color: root.active ? Theme.accent : Theme.tileBorder

    HoverHandler {
        id: rowHover
    }

    MouseArea {
        anchors.fill: parent
        enabled: !root.active
        cursorShape: root.active ? Qt.ArrowCursor : Qt.PointingHandCursor
        onClicked: root.activated()
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        spacing: 10

        MaterialSymbol {
            text: CcSystem.audioNodeIcon(root.node)
            iconSize: 20
            color: root.active ? Theme.accent : Theme.textPrimary
            font.family: Theme.iconFontFamily
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                text: CcSystem.audioNodeName(root.node)
                color: Theme.textPrimary
                font.pixelSize: Appearance.font.pixelSize.textMedium
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            RowLayout {
                spacing: 4
                visible: root.active

                Rectangle {
                    width: 6
                    height: 6
                    radius: 3
                    color: "#4ade80"
                }

                StyledText {
                    text: "Activo"
                    color: "#4ade80"
                    font.pixelSize: Appearance.font.pixelSize.textSmall - 1
                }
            }
        }

        StyledText {
            visible: root.trailing !== ""
            text: root.trailing
            color: Theme.textDim
            font.pixelSize: Appearance.font.pixelSize.textSmall
        }
    }
}
