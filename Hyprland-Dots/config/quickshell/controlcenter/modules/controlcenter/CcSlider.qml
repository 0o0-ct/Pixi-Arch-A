import QtQuick
import QtQuick.Layouts
import "root:/modules/controlcenter"
import "root:/modules/common"
import "root:/modules/common/widgets"

/**
 * Thin rounded slider: dim track with a brighter filled portion, draggable
 * with either mouse button held.
 *
 * The filled width is bound directly (never animated) so dragging stays
 * cheap; only colors animate.
 */
Item {
    id: root

    /** Shown when not dragged (usually a binding to a system service). */
    property real value: 0
    property string icon: ""
    property color fillColor: Theme.trackFill

    /** Emitted once the user lets go, with the final 0..1 value. */
    signal moved(real value)

    implicitHeight: Theme.sliderRowHeight

    readonly property real shownValue: dragging ? dragValue : value
    property real dragValue: 0
    property bool dragging: false

    function valueFromX(x) {
        if (track.width <= 0)
            return 0
        return Math.max(0, Math.min(1, x / track.width))
    }

    RowLayout {
        anchors.fill: parent
        spacing: Theme.sliderGap

        MaterialSymbol {
            Layout.alignment: Qt.AlignVCenter
            text: root.icon
            iconSize: Theme.sliderIconSize
            font.family: Theme.iconFontFamily
            color: Theme.textSecondary

            Behavior on color {
                ColorAnimation { duration: Theme.colorDuration }
            }
        }

        Item {
            id: track
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            implicitHeight: root.implicitHeight

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: Theme.sliderTrackHeight
                radius: height / 2
                color: Theme.trackDim
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(Theme.sliderTrackHeight, track.width * root.shownValue)
                height: Theme.sliderTrackHeight
                radius: height / 2
                color: root.fillColor

                Behavior on color {
                    ColorAnimation { duration: Theme.colorDuration }
                }
            }

            MouseArea {
                id: mouse
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                preventStealing: true

                onPressed: (event) => {
                    root.dragValue = root.valueFromX(event.x)
                    root.dragging = true
                }
                onPositionChanged: (event) => {
                    if (root.dragging)
                        root.dragValue = root.valueFromX(event.x)
                }
                onReleased: {
                    root.dragging = false
                    root.moved(root.dragValue)
                }
                onCanceled: root.dragging = false
            }
        }
    }
}
