// Config created by Keyitdev https://github.com/Keyitdev/sddm-astronaut-theme
// Copyright (C) 2022-2025 Keyitdev
// Based on https://github.com/MarianArlt/sddm-sugar-dark
// Distributed under the GPLv3+ License https://www.gnu.org/licenses/gpl-3.0.html

import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
import SddmComponents 2.0 as SDDM

ColumnLayout {
    id: formContainer
    spacing: 20
    SDDM.TextConstants { id: textConstants }

    property int p: config.ScreenPadding == "" ? 0 : config.ScreenPadding
    property string a: config.FormPosition

    Clock {
        id: clock
        Layout.alignment: Qt.AlignHCenter
        Layout.preferredWidth: parent.width / 2
        Layout.bottomMargin: 15
    }

    // Centered Glassmorphic Login Box
    Rectangle {
        id: loginBox
        Layout.alignment: Qt.AlignHCenter
        width: 420
        height: input.implicitHeight + 40
        color: Qt.rgba(15/255, 20/255, 30/255, 0.45)
        border.color: Qt.rgba(1, 1, 1, 0.15)
        border.width: 1
        radius: 15

        Input {
            id: input
            width: parent.width - 40
            anchors.centerIn: parent
        }
    }

    // Centered Glassmorphic System Buttons Box
    Rectangle {
        id: systemButtonsBox
        Layout.alignment: Qt.AlignHCenter
        width: systemButtons.implicitWidth + 30
        height: systemButtons.implicitHeight + 25
        color: Qt.rgba(15/255, 20/255, 30/255, 0.45)
        border.color: Qt.rgba(1, 1, 1, 0.15)
        border.width: 1
        radius: 15
        visible: config.HideSystemButtons != "true"

        SystemButtons {
            id: systemButtons
            width: implicitWidth
            height: implicitHeight
            anchors.centerIn: parent
            exposedSession: input.exposeSession
        }
    }

}
