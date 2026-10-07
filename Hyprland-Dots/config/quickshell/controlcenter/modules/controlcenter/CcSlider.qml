import QtQuick
import QtQuick.Layouts
import "root:/modules/controlcenter"
import "root:/modules/common"
import "root:/modules/common/widgets"

/**
 * Samsung One UI style thick pill slider:
 * Chunky glass capsule with smooth fill, icon embedded on the left,
 * live draggable feedback, and mouse wheel step control.
 */
Item {
    id: root

    /** Shown when not dragged (usually a binding to a system service). */
    property real value: 0
    property string icon: ""
    property color fillColor: Theme.trackFill

    /** Emitted when dragged or scrolled, with the updated 0..1 value. */
    signal moved(real value)

    implicitHeight: Theme.sliderRowHeight

    readonly property real shownValue: dragging ? dragValue : value
    property real dragValue: 0
    property bool dragging: false

    function valueFromX(x) {
        if (root.width <= 0)
            return 0
        return Math.max(0, Math.min(1, x / root.width))
    }

    // ── One UI Outer Pill Capsule ─────────────────────────────────────
    Rectangle {
        id: trackBg
        anchors.fill: parent
        radius: height / 2
        color: Theme.tileBg
        border.width: 1
        border.color: Theme.tileBorder
        clip: true

        // Filled active progress bar (smooth pill)
        Rectangle {
            id: fillBar
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: Math.max(0, parent.width * Math.max(0, Math.min(1, root.shownValue)))
            radius: height / 2
            color: root.fillColor
            visible: width > 0

            Behavior on color {
                ColorAnimation { duration: Theme.colorDuration }
            }
        }

        // Icon embedded inside the pill on the left (One UI)
        MaterialSymbol {
            id: iconItem
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            z: 2
            text: root.icon
            iconSize: Theme.sliderIconSize
            font.family: Theme.iconFontFamily
            color: {
                if (root.shownValue > 0.18) {
                    return (root.fillColor === Theme.accent) ? Theme.onAccent : Theme.tileBg
                }
                return Theme.textSecondary
            }

            Behavior on color {
                ColorAnimation { duration: Theme.colorDuration }
            }
        }

        // Percentage text shown on hover or drag
        StyledText {
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            z: 2
            text: Math.round(root.shownValue * 100) + "%"
            font.pixelSize: Appearance.font.pixelSize.textSmall
            font.weight: Font.DemiBold
            color: {
                if (root.shownValue > 0.88) {
                    return (root.fillColor === Theme.accent) ? Theme.onAccent : Theme.tileBg
                }
                return Theme.textDim
            }
            visible: mouse.containsMouse || root.dragging
        }

        // Full pill mouse area
        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            preventStealing: true

            onPressed: (event) => {
                root.dragValue = root.valueFromX(event.x)
                root.dragging = true
                root.moved(root.dragValue)
            }
            onPositionChanged: (event) => {
                if (root.dragging) {
                    root.dragValue = root.valueFromX(event.x)
                    root.moved(root.dragValue)
                }
            }
            onReleased: {
                root.dragging = false
                root.moved(root.dragValue)
            }
            onCanceled: root.dragging = false

            onWheel: (wheel) => {
                const step = 0.05
                const delta = wheel.angleDelta.y > 0 ? step : -step
                const newVal = Math.max(0, Math.min(1, root.value + delta))
                root.moved(newVal)
            }
        }
    }
}
