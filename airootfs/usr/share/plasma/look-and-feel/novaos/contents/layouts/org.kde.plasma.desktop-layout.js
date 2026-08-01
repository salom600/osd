// =============================================================================
// NovaOS - Plasma panel layout preset (Layer 3: bottom bar)
// =============================================================================
// This file defines the default Plasma panel layout for NovaOS:
//   - Bottom-positioned, full-width, height 56px
//   - Glass blur background (controlled by panel-background.svg + theme.json)
//   - Left:   Application Launcher (start menu, "ApplicationName" style)
//   - Center: Task manager (icons only, modern Win11 look)
//   - Right:  System tray (Pin, Sound, Network, Bluetooth, Battery),
//             Digital clock (modern typeface), Notifications, User menu
//
// This is loaded when the user applies the NovaOS Look and Feel package.
// =============================================================================

import QtQuick 2.15
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.extras 2.0 as PlasmaExtras
import org.kde.plasma.components 3.0 as PC3
import org.kde.kirigami 2.20 as Kirigami

Item {
    id: root

    // === Panel configuration ===
    // The panel itself is created by Plasma when applying the LNF;
    // this layout file specifies what applets live on it.

    property var panelLayout: ({
        "panel": {
            "location": "bottom",
            "height": 56,
            "alignment": "center",
            "lengthMode": "fill",
            "length": 0,
            "hidingMode": "dodgewindows",
            "opacity": 0.72,
            "floating": true,
            "floatingMargin": 8
        },
        "applets": [
            // ---- Left: Start menu (Application Launcher) ----
            {
                "plugin": "org.kde.plasma.kickoff",
                "position": "left",
                "config": {
                    "iconName": "novaos-start-here",
                    "favoriteSystemActions": true,
                    "appIdList": "preferred",
                    "primaryActions": "3"
                }
            },
            // ---- Left: Pager / Activities (optional) ----
            {
                "plugin": "org.kde.plasma.pager",
                "position": "left",
                "config": {}
            },
            // ---- Center: Task manager (icons only, modern) ----
            {
                "plugin": "org.kde.plasma.taskmanager",
                "position": "center",
                "config": {
                    "groupingStrategy": 1,
                    "iconOnly": true,
                    "showToolTips": true,
                    "maxTextLines": 1,
                    "launchers": [
                        "applications:firefox.desktop",
                        "applications:org.kde.dolphin.desktop",
                        "applications:org.kde.konsole.desktop",
                        "applications:org.kde.kate.desktop",
                        "applications:novaos-store.desktop",
                        "applications:bottles.desktop"
                    ]
                }
            },
            // ---- Right: System tray (sound, network, bluetooth, battery) ----
            {
                "plugin": "org.kde.plasma.systemtray",
                "position": "right",
                "config": {
                    "extraItems": [
                        "org.kde.plasma.mediacontroller",
                        "org.kde.plasma.volume",
                        "org.kde.plasma.networkmanagement",
                        "org.kde.plasma.bluetooth",
                        "org.kde.plasma.battery",
                        "org.kde.plasma.keyboardlayout",
                        "org.kde.plasma.clipboard",
                        "org.kde.plasma.notifications",
                        "org.kde.plasma.devicenotifier",
                        "org.kde.plasma.keyboardindicator",
                        "org.kde.plasma.nightcolor"
                    ]
                }
            },
            // ---- Right: Digital clock (Win11-style, modern font) ----
            {
                "plugin": "org.kde.plasma.digitalclock",
                "position": "right",
                "config": {
                    "showSeconds": false,
                    "dateFormat": "custom",
                    "customDateFormat": "ddd, MMM d",
                    "timeFormat": "h:mm AP",
                    "fontFamily": "Inter",
                    "boldText": true
                }
            },
            // ---- Right: Notifications ----
            {
                "plugin": "org.kde.plasma.notifications",
                "position": "right",
                "config": {}
            }
        ]
    })
}
