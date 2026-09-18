import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Services.Mpris
import "root:/modules/controlcenter"
import "root:/modules/common"
import "root:/modules/common/widgets"
import "root:/services"

/**
 * Mini Media Player section for the Control Center.
 * Supports Spotify, YouTube, Chromium, Firefox, MPD, VLC via MPRIS / playerctl.
 */
Rectangle {
    id: root

    implicitHeight: 74
    radius: Theme.tileRadius
    color: Theme.tileBg
    border.width: 1
    border.color: Theme.tileBorder

    readonly property var activePlayer: {
        const players = Mpris.players.values ?? []
        if (players.length === 0) return null
        for (let i = 0; i < players.length; i++) {
            if (players[i].playbackState === MprisPlaybackState.Playing)
                return players[i]
        }
        return players[0]
    }

    readonly property bool hasMedia: activePlayer !== null && (activePlayer.trackTitle ?? "").length > 0
    readonly property bool isPlaying: activePlayer !== null && activePlayer.playbackState === MprisPlaybackState.Playing

    readonly property string titleText: hasMedia ? activePlayer.trackTitle : "No media playing"
    readonly property string artistText: {
        if (!hasMedia) return "Spotify • YouTube • MPRIS"
        const artists = activePlayer.trackArtists
        if (typeof artists === "string" && artists.length > 0) return artists
        if (Array.isArray(artists) && artists.length > 0) return artists.join(", ")
        if (activePlayer.trackAlbumArtist && activePlayer.trackAlbumArtist.length > 0)
            return activePlayer.trackAlbumArtist
        return "Unknown Artist"
    }

    readonly property string artSource: hasMedia ? (activePlayer.trackArtUrl ?? activePlayer.artUrl ?? "") : ""

    function togglePlayPause() {
        if (!activePlayer) {
            CcSystem.runDetached(["playerctl", "play-pause"])
            return
        }
        if (isPlaying) {
            if (activePlayer.canPause) activePlayer.pause()
            else CcSystem.runDetached(["playerctl", "pause"])
        } else {
            if (activePlayer.canPlay) activePlayer.play()
            else CcSystem.runDetached(["playerctl", "play"])
        }
    }

    function previousTrack() {
        if (activePlayer && activePlayer.canGoPrevious) {
            activePlayer.previous()
        } else {
            CcSystem.runDetached(["playerctl", "previous"])
        }
    }

    function nextTrack() {
        if (activePlayer && activePlayer.canGoNext) {
            activePlayer.next()
        } else {
            CcSystem.runDetached(["playerctl", "next"])
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 12

        // ── Album Cover Thumbnail ─────────────────────────────────────────
        Rectangle {
            id: artBox
            Layout.preferredWidth: 54
            Layout.preferredHeight: 54
            radius: 10
            color: Theme.tileIconBg
            clip: true

            Image {
                id: coverImg
                anchors.fill: parent
                source: root.artSource
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: status === Image.Ready && root.hasMedia
            }

            MaterialSymbol {
                anchors.centerIn: parent
                visible: coverImg.status !== Image.Ready || !root.hasMedia
                text: "music_note"
                iconSize: 26
                color: root.hasMedia ? Theme.accent : Theme.textDim
                font.family: Theme.iconFontFamily
            }
        }

        // ── Track Title & Artist ──────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 2

            StyledText {
                Layout.fillWidth: true
                text: root.titleText
                color: root.hasMedia ? Theme.textPrimary : Theme.textDim
                font.pixelSize: Appearance.font.pixelSize.textMedium
                font.weight: Font.Bold
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            StyledText {
                Layout.fillWidth: true
                text: root.artistText
                color: Theme.textDim
                font.pixelSize: Appearance.font.pixelSize.textSmall
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }

        // ── Media Controls Row ────────────────────────────────────────────
        Row {
            Layout.alignment: Qt.AlignVCenter
            spacing: 6

            // Previous Button
            Rectangle {
                width: 32
                height: 32
                radius: 16
                color: prevHover.hovered ? Theme.tileHoverBg : "transparent"

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "skip_previous"
                    iconSize: 20
                    color: root.hasMedia ? Theme.textPrimary : Theme.textDim
                    font.family: Theme.iconFontFamily
                }

                HoverHandler { id: prevHover }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.previousTrack()
                }
            }

            // Play / Pause Accent Button
            Rectangle {
                width: 38
                height: 38
                radius: 19
                color: root.isPlaying ? Theme.accent : (playHover.hovered ? Theme.tileHoverBg : Theme.tileIconBg)
                border.width: root.isPlaying ? 0 : 1
                border.color: Theme.tileBorder

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: root.isPlaying ? "pause" : "play_arrow"
                    iconSize: 22
                    color: root.isPlaying ? Theme.onAccent : Theme.textPrimary
                    font.family: Theme.iconFontFamily
                }

                HoverHandler { id: playHover }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.togglePlayPause()
                }
            }

            // Next Button
            Rectangle {
                width: 32
                height: 32
                radius: 16
                color: nextHover.hovered ? Theme.tileHoverBg : "transparent"

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "skip_next"
                    iconSize: 20
                    color: root.hasMedia ? Theme.textPrimary : Theme.textDim
                    font.family: Theme.iconFontFamily
                }

                HoverHandler { id: nextHover }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.nextTrack()
                }
            }
        }
    }
}
