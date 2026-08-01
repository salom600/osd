/*
 * NovaOS Aurora - KWin decoration QML
 * -----------------------------------
 * Renders a glass-style frame around every window:
 *   - 14px rounded corners
 *   - translucent background (opacity from settings)
 *   - KWin blur behind (when window is inactive)
 *   - Modern title bar: app icon on left, 3 window buttons on right
 *   - Adaptive: opacity rises to ~95% when window is active (focus)
 */

import QtQuick 2.15
import QtQuick.Window 2.15
import org.kde.kwin 3.0 as KWin
import org.kde.kirigami 2.20 as Kirigami
import Qt5Compat.GraphicalEffects 1.0

KWin.AbstractButton {
    id: root

    // === Geometry ===
    leftPadding: 0
    rightPadding: 0
    topPadding: 0
    bottomPadding: 0

    // === Colors (synced with NovaOS.colors) ===
    readonly property color cAccent: "#7C4DFF"
    readonly property color cAccentSecondary: "#00E5FF"
    readonly property color cTextActive: "#FFFFFF"
    readonly property color cTextInactive: "#B8B8D0"
    readonly property color cGlassBg: "#14141E"
    readonly property color cGlassBgActive: "#1B1B2A"

    // === Settings ===
    readonly property bool   glassBlur:           decoration.settings.glassBlur ?? true
    readonly property bool   adaptiveTransparency: decoration.settings.adaptiveTransparency ?? true
    readonly property int    backgroundOpacity:    decoration.settings.backgroundOpacity ?? 72
    readonly property int    cornerRadius:         decoration.settings.cornerRadius ?? 14
    readonly property bool   windowShadow:         decoration.settings.windowShadow ?? true
    readonly property bool   animateTransitions:   decoration.settings.animateTransitions ?? true

    readonly property bool   isActive:             decoration.client.active

    // === Computed ===
    readonly property real effectiveOpacity: {
        if (!adaptiveTransparency) return backgroundOpacity / 100.0
        return isActive ? Math.min(0.96, backgroundOpacity / 100.0 + 0.20) : backgroundOpacity / 100.0
    }

    // === Main background ===
    Rectangle {
        id: bg
        anchors.fill: parent
        radius: root.cornerRadius
        color: Qt.rgba(
            (isActive ? root.cGlassBgActive : root.cGlassBg).r,
            (isActive ? root.cGlassBgActive : root.cGlassBg).g,
            (isActive ? root.cGlassBgActive : root.cGlassBg).b,
            root.effectiveOpacity
        )
        border.color: isActive ? Qt.rgba(0.49, 0.30, 1.0, 0.55) : Qt.rgba(1, 1, 1, 0.10)
        border.width: isActive ? 1 : 1

        Behavior on color { ColorAnimation { duration: root.animateTransitions ? 250 : 0 } }
        Behavior on border.color { ColorAnimation { duration: root.animateTransitions ? 250 : 0 } }
    }

    // === Subtle inner highlight on top edge ===
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        anchors.topMargin: parent.cornerRadius
        anchors.leftMargin: parent.cornerRadius
        anchors.rightMargin: parent.cornerRadius
        color: Qt.rgba(1, 1, 1, isActive ? 0.18 : 0.06)
    }

    // === Window shadow ===
    DropShadow {
        anchors.fill: parent
        visible: root.windowShadow
        horizontalOffset: 0
        verticalOffset: 6
        radius: 28
        samples: 56
        color: Qt.rgba(0, 0, 0, isActive ? 0.55 : 0.35)
        source: bg
    }

    // === Title bar content ===
    Item {
        id: titleBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 36 + root.cornerRadius / 2

        // App icon (left)
        Item {
            id: appIconBox
            width: 28; height: 28
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            // Placeholder - real icon is provided by KWin AbstractButton.icon
            Rectangle {
                anchors.fill: parent
                radius: 6
                color: Qt.rgba(1, 1, 1, 0.10)
                visible: !root.icon || root.icon.toString() === ""
            }
            Image {
                anchors.fill: parent
                source: root.icon ? root.icon.toString() : ""
                fillMode: Image.PreserveAspectFit
                visible: root.icon && root.icon.toString() !== ""
            }
        }

        // Title text
        Text {
            id: titleText
            anchors.left: appIconBox.right
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: root.caption || ""
            color: root.isActive ? root.cTextActive : root.cTextInactive
            font.family: "Noto Sans"
            font.weight: Font.DemiBold
            font.pixelSize: 13
            elide: Text.ElideRight
            Behavior on color { ColorAnimation { duration: root.animateTransitions ? 250 : 0 } }
        }

        // Window buttons (right)
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            // Minimize
            WindowButton {
                glyph: "—"; accentOnHover: false
                onClicked: decoration.requestMinimize()
            }
            // Maximize
            WindowButton {
                glyph: decoration.client.maximized ? "❐" : "▢"; accentOnHover: false
                onClicked: decoration.requestToggleMaximized()
            }
            // Close
            WindowButton {
                glyph: "✕"; accentOnHover: true; accentColor: "#FF5C5C"
                onClicked: decoration.requestClose()
            }
        }
    }

    // === Custom button component ===
    component WindowButton: Rectangle {
        id: btn
        property string glyph: ""
        property bool accentOnHover: false
        property color accentColor: "#FF5C5C"
        signal clicked()
        width: 28; height: 28
        radius: 8
        color: hoverHandler.hovered
               ? (accentOnHover ? accentColor : Qt.rgba(1, 1, 1, 0.18))
               : "transparent"
        Behavior on color { ColorAnimation { duration: 120 } }

        Text {
            anchors.centerIn: parent
            text: btn.glyph
            color: hoverHandler.hovered && accentOnHover ? "white" : root.cTextActive
            font.family: "Noto Sans"
            font.pixelSize: 13
            font.weight: Font.Medium
        }

        HoverHandler {
            id: hoverHandler
            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            onTapped: btn.clicked()
        }
    }
}
