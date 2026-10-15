import QtQuick
import QtQuick.Layouts
import "root:/modules/common"
import "root:/modules/common/widgets"
import "root:/modules/controlcenter"
import "root:/services"

/**
 * Inline Wi-Fi password prompt — the drawer body while a protected network
 * is waiting for its key.
 *
 * Enter submits, the eye toggles visibility, and errors come from
 * WifiService.errorText (e.g. a wrong password reported by NetworkManager).
 */
ColumnLayout {
    id: root

    property bool revealPassword: false

    spacing: 8

    function focusInput() {
        passwordInput.forceActiveFocus()
        passwordInput.selectAll()
    }

    function submit() {
        const password = passwordInput.text ?? ""
        if (password.length === 0)
            return
        root.revealPassword = false
        WifiService.submitPassword(password)
        passwordInput.text = ""
    }

    onVisibleChanged: {
        if (visible)
            focusTimer.restart()
    }

    StyledText {
        Layout.fillWidth: true
        text: "Contraseña de «" + WifiService.pendingSsid + "»"
        color: Theme.textPrimary
        font.pixelSize: Appearance.font.pixelSize.textMedium
        font.weight: Font.DemiBold
        elide: Text.ElideRight
    }

    // ── Input field ───────────────────────────────────────────────────────
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 40
        radius: 10
        color: Theme.tileIconBg
        border.width: 1
        border.color: passwordInput.activeFocus ? Theme.accent : Theme.tileBorder

        TextInput {
            id: passwordInput

            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.right: eyeButton.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter

            echoMode: root.revealPassword ? TextInput.Normal : TextInput.Password
            passwordCharacter: "•"
            color: Theme.textPrimary
            selectionColor: Appearance.m3colors.m3selectionBackground
            selectedTextColor: Appearance.m3colors.m3selectionText
            font.family: Appearance?.font.family.uiFont ?? "sans-serif"
            font.pixelSize: Appearance.font.pixelSize.textBase
            clip: true
            verticalAlignment: TextInput.AlignVCenter

            onAccepted: root.submit()
        }

        MaterialSymbol {
            id: eyeButton

            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter

            text: root.revealPassword ? "visibility_off" : "visibility"
            iconSize: 18
            color: eyeHover.hovered ? Theme.textPrimary : Theme.textDim
            font.family: Theme.iconFontFamily

            HoverHandler { id: eyeHover }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.revealPassword = !root.revealPassword
            }
        }
    }

    // ── Error feedback ────────────────────────────────────────────────────
    StyledText {
        visible: WifiService.errorText !== ""
        Layout.fillWidth: true
        text: WifiService.errorText
        color: "#ef4444"
        font.pixelSize: Appearance.font.pixelSize.textSmall
        wrapMode: Text.Wrap
    }

    // ── Actions ───────────────────────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Item { Layout.fillWidth: true }

        Rectangle {
            implicitWidth: 96
            implicitHeight: 30
            radius: 15
            color: cancelHover.hovered ? Theme.tileHoverBg : Theme.tileIconBg
            border.width: 1
            border.color: Theme.tileBorder

            StyledText {
                anchors.centerIn: parent
                text: "Cancelar"
                color: Theme.textPrimary
                font.pixelSize: Appearance.font.pixelSize.textSmall
                font.weight: Font.Bold
            }

            HoverHandler { id: cancelHover }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: WifiService.cancelPrompt()
            }
        }

        Rectangle {
            implicitWidth: 100
            implicitHeight: 30
            radius: 15
            color: Theme.accent

            StyledText {
                anchors.centerIn: parent
                text: "Conectar"
                color: Theme.onAccent
                font.pixelSize: Appearance.font.pixelSize.textSmall
                font.weight: Font.Bold
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.submit()
            }
        }
    }

    Timer {
        id: focusTimer
        interval: 150
        onTriggered: root.focusInput()
    }

    Component.onCompleted: {
        if (root.visible)
            focusTimer.start()
    }
}
