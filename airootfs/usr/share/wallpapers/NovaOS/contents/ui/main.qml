/*
 * NovaOS Aurora - animated wallpaper
 * Renders a slowly-drifting multi-stop gradient + floating orbs,
 * that subtly shifts color based on time of day.
 * No image asset required - the wallpaper is fully procedural.
 */

import QtQuick 2.15
import org.kde.plasma.wallpapers 2.0 as Wallpaper

Item {
    id: root
    anchors.fill: parent

    // Time-of-day palette
    readonly property var palettes: {
        "night":   { "top": "#0F0C29", "mid": "#302B63", "bot": "#24243E" },
        "morning": { "top": "#1E1B4B", "mid": "#5B21B6", "bot": "#7C3AED" },
        "noon":    { "top": "#312E81", "mid": "#6D28D9", "bot": "#A78BFA" },
        "evening": { "top": "#1E1A3E", "mid": "#4C1D95", "bot": "#7C4DFF" }
    }

    readonly property string tod: {
        var h = new Date().getHours();
        if (h < 6 || h >= 21) return "night";
        if (h < 11) return "morning";
        if (h < 17) return "noon";
        return "evening";
    }
    readonly property var pal: palettes[tod]

    Rectangle {
        id: bg
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: root.pal.top; Behavior on color { ColorAnimation { duration: 3000 } } }
            GradientStop { position: 0.5; color: root.pal.mid; Behavior on color { ColorAnimation { duration: 3000 } } }
            GradientStop { position: 1.0; color: root.pal.bot; Behavior on color { ColorAnimation { duration: 3000 } } }
        }
    }

    // Floating orb 1 - violet
    Item {
        width: Math.max(root.width, root.height) * 0.6
        height: width
        x: -width * 0.2
        y: -height * 0.2
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            gradient: Gradient {
                orientation: Gradient.Radial
                GradientStop { position: 0.0; color: Qt.rgba(0.49, 0.30, 1.0, 0.25) }
                GradientStop { position: 1.0; color: Qt.rgba(0.49, 0.30, 1.0, 0.00) }
            }
        }
        NumberAnimation on x { from: -width*0.2; to: root.width - width*0.8; duration: 60000; loops: Animation.Infinite; easing.type: Easing.InOutSine }
        NumberAnimation on y { from: -height*0.2; to: root.height - height*0.8; duration: 75000; loops: Animation.Infinite; easing.type: Easing.InOutSine }
    }

    // Floating orb 2 - cyan
    Item {
        width: Math.max(root.width, root.height) * 0.5
        height: width
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            gradient: Gradient {
                orientation: Gradient.Radial
                GradientStop { position: 0.0; color: Qt.rgba(0.00, 0.90, 1.00, 0.18) }
                GradientStop { position: 1.0; color: Qt.rgba(0.00, 0.90, 1.00, 0.00) }
            }
        }
        NumberAnimation on x { from: root.width - width*0.8; to: -width*0.2; duration: 90000; loops: Animation.Infinite; easing.type: Easing.InOutSine }
        NumberAnimation on y { from: root.height - height*0.8; to: -height*0.2; duration: 66000; loops: Animation.Infinite; easing.type: Easing.InOutSine }
    }

    // Slow rotation on a faint geometric pattern (decorative)
    Canvas {
        id: linesCanvas
        anchors.fill: parent
        opacity: 0.06
        rotation: 0
        NumberAnimation on rotation { from: 0; to: 360; duration: 600000; loops: Animation.Infinite }
        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            ctx.strokeStyle = "white"
            ctx.lineWidth = 1
            var cx = width / 2, cy = height / 2
            for (var i = 0; i < 24; i++) {
                var a = i * Math.PI / 12
                ctx.beginPath()
                ctx.moveTo(cx + Math.cos(a) * 100, cy + Math.sin(a) * 100)
                ctx.lineTo(cx + Math.cos(a) * Math.max(width, height), cy + Math.sin(a) * Math.max(width, height))
                ctx.stroke()
            }
        }
    }

    // Re-pick palette every 15 minutes (tod will recompute on next paint)
    Timer {
        interval: 15 * 60 * 1000
        running: true
        repeat: true
        onTriggered: bg.update()
    }
}
