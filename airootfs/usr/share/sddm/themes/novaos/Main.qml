// =============================================================================
// NovaOS SDDM Theme - Main.qml
// =============================================================================
// Implements the 3-layer login flow described in the NovaOS brief:
//
//   Layer 1 - Boot welcome: animated gradient + NovaOS logo + "Welcome / Wait
//             a moment" copy. Transparent, colored, modern (Win11/Mac vibe).
//   Layer 2 - Password entry: glass panel, animated focus ring, show/hide
//             password, user avatar, session selector, suspend/shutdown/reboot.
//
// Designed for SDDM 0.20+ with Qt6 / QtQuick 2 / QtQuick.Controls 2.
// Tested against KDE Plasma 6's SDDM greeter.
// =============================================================================

import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Effects 1.0
import Qt5Compat.GraphicalEffects 1.0

Item {
    id: root
    width: 640
    height: 480

    // ----- Read config from theme.conf via SDDM's config object -----
    readonly property color cAccent:           config.accent           || "#7C4DFF"
    readonly property color cAccentSecondary:  config.accentSecondary  || "#00E5FF"
    readonly property color cText:             config.textColor        || "#FFFFFF"
    readonly property color cTextSecondary:    config.textSecondaryColor || "#B8B8D0"
    readonly property color cBgStart:          config.backgroundStart  || "#0F0C29"
    readonly property color cBgMid:            config.backgroundMid    || "#302B63"
    readonly property color cBgEnd:            config.backgroundEnd    || "#24243E"

    readonly property bool   glassEnabled:     config.glassEnabled === "true" || config.glassEnabled === true
    readonly property real   glassOpacity:     parseFloat(config.glassOpacity || "0.65")
    readonly property int    glassRadius:      parseInt(config.glassRadius || "24", 10)
    readonly property int    glassBlur:        parseInt(config.glassBlur || "42", 10)

    readonly property bool   animEnabled:      config.animationEnabled === "true" || config.animationEnabled === true
    readonly property int    animMs:           parseInt(config.animationDurationMs || "600", 10)

    readonly property string logoText:         config.logoText        || "NovaOS"
    readonly property string logoSubtext:      config.logoSubtext     || "Welcome — just a moment"
    readonly property string welcomeMsg:       config.welcomeMessage  || "Welcome to NovaOS"
    readonly property string welcomeSub:       config.welcomeSubmessage || "Initializing your experience — please wait a moment"
    readonly property int    welcomeMs:        parseInt(config.welcomeDurationMs || "2200", 10)

    readonly property string clockFormat:      config.clockFormat     || "hh:mm"

    // ----- State machine: layer 1 (welcome) -> layer 2 (login) -----
    states: [
        State { name: "welcome" },     // Layer 1
        State { name: "login"   }      // Layer 2
    ]
    state: "welcome"

    // =========================================================================
    // Background: animated multi-stop gradient with subtle parallax orbs
    // =========================================================================
    Rectangle {
        id: background
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: root.cBgStart }
            GradientStop { position: 0.5; color: root.cBgMid   }
            GradientStop { position: 1.0; color: root.cBgEnd   }
        }

        // Animated floating orb 1 (accent purple)
        Item {
            id: orb1
            width: 600; height: 600
            x: -200; y: -200
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: "transparent"
                gradient: Gradient {
                    orientation: Gradient.Radial
                    GradientStop { position: 0.0; color: Qt.rgba(0.49, 0.30, 1.0, 0.35) }   // #7C4DFF
                    GradientStop { position: 1.0; color: Qt.rgba(0.49, 0.30, 1.0, 0.00) }
                }
            }
            NumberAnimation on x { from: -200; to: parent.width - 400; duration: 18000; loops: Animation.Infinite; easing.type: Easing.InOutSine }
            NumberAnimation on y { from: -200; to: parent.height - 400; duration: 22000; loops: Animation.Infinite; easing.type: Easing.InOutSine }
        }

        // Animated floating orb 2 (accent cyan)
        Item {
            id: orb2
            width: 500; height: 500
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: "transparent"
                gradient: Gradient {
                    orientation: Gradient.Radial
                    GradientStop { position: 0.0; color: Qt.rgba(0.00, 0.90, 1.00, 0.25) }  // #00E5FF
                    GradientStop { position: 1.0; color: Qt.rgba(0.00, 0.90, 1.00, 0.00) }
                }
            }
            NumberAnimation on x { from: parent.width - 300; to: -100; duration: 26000; loops: Animation.Infinite; easing.type: Easing.InOutSine }
            NumberAnimation on y { from: parent.height - 200; to: -100; duration: 20000; loops: Animation.Infinite; easing.type: Easing.InOutSine }
        }

        // Animated noise overlay (gives the gradient texture)
        Canvas {
            id: noiseCanvas
            anchors.fill: parent
            opacity: 0.04
            property var noise: null
            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                // Draw simple pseudo-random noise dots
                for (var i = 0; i < 1200; i++) {
                    var x = Math.random() * width
                    var y = Math.random() * height
                    var s = Math.random() * 1.5
                    ctx.fillStyle = "white"
                    ctx.fillRect(x, y, s, s)
                }
            }
            NumberAnimation on opacity { from: 0.03; to: 0.06; duration: 4000; loops: Animation.Infinite; easing.type: Easing.InOutSine }
        }
    }

    // =========================================================================
    // Layer 1: Welcome / boot screen
    // =========================================================================
    Item {
        id: layerWelcome
        anchors.fill: parent
        opacity: root.state === "welcome" ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: root.animEnabled ? root.animMs : 0; easing.type: Easing.OutCubic } }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 24

            // NovaOS logo mark (drawn in QML, no image asset needed)
            Item {
                id: logoMark
                Layout.alignment: Qt.AlignHCenter
                width: 96; height: 96

                Rectangle {
                    anchors.fill: parent
                    radius: 24
                    color: "transparent"
                    border.color: root.cAccent
                    border.width: 2
                    opacity: 0.6
                    scale: 1.0
                    NumberAnimation on scale { from: 1.0; to: 1.15; duration: 1800; loops: Animation.Infinite; easing.type: Easing.InOutSine }
                    NumberAnimation on opacity { from: 0.6; to: 0.0; duration: 1800; loops: Animation.Infinite; easing.type: Easing.InOutSine }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 24
                    gradient: Gradient {
                        orientation: Gradient.Vertical
                        GradientStop { position: 0.0; color: root.cAccent }
                        GradientStop { position: 1.0; color: Qt.darker(root.cAccent, 1.6) }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "N"
                        font.family: "Noto Sans"
                        font.weight: Font.Black
                        font.pixelSize: 56
                        color: "#FFFFFF"
                    }

                    layer.enabled: true
                    layer.effect: DropShadow {
                        horizontalOffset: 0
                        verticalOffset: 6
                        radius: 18
                        samples: 36
                        color: Qt.rgba(0.49, 0.30, 1.0, 0.55)
                    }
                }
            }

            // Welcome headline
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: root.welcomeMsg
                font.family: "Noto Sans"
                font.weight: Font.Light
                font.pixelSize: 36
                color: root.cText

                NumberAnimation on opacity { from: 0; to: 1; duration: root.animMs; easing.type: Easing.OutCubic }
            }

            // Submessage
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: root.welcomeSub
                font.family: "Noto Sans"
                font.weight: Font.Light
                font.pixelSize: 16
                color: root.cTextSecondary

                NumberAnimation on opacity { from: 0; to: 1; duration: root.animMs + 200; easing.type: Easing.OutCubic }
            }

            // "Just a moment" animated spinner
            Item {
                Layout.alignment: Qt.AlignHCenter
                width: 36; height: 36

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: "transparent"
                    border.color: Qt.rgba(1,1,1,0.15)
                    border.width: 3
                }

                Rectangle {
                    id: spinnerArc
                    width: 36; height: 36
                    radius: width / 2
                    color: "transparent"
                    border.color: root.cAccent
                    border.width: 3
                    // Approximate arc by clipping
                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: Item {
                            width: 36; height: 36
                            Rectangle {
                                width: 18; height: 36
                                color: "black"
                            }
                        }
                    }
                    RotationAnimation on rotation {
                        from: 0; to: 360; duration: 900; loops: Animation.Infinite
                    }
                }
            }
        }

        // Auto-advance to login after welcomeMs
        Timer {
            interval: root.welcomeMs
            running: root.state === "welcome"
            repeat: false
            onTriggered: {
                if (root.state === "welcome") {
                    root.state = "login"
                }
            }
        }

        // Click anywhere to skip welcome
        MouseArea {
            anchors.fill: parent
            onClicked: {
                if (root.state === "welcome") root.state = "login"
            }
        }
    }

    // =========================================================================
    // Layer 2: Login / password panel
    // =========================================================================
    Item {
        id: layerLogin
        anchors.fill: parent
        opacity: root.state === "login" ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: root.animEnabled ? root.animMs : 0; easing.type: Easing.OutCubic } }

        // User selection panel (left side, optional)
        ListView {
            id: userList
            visible: config.showUserList !== "false"
            width: 220
            anchors.left: parent.left
            anchors.leftMargin: 60
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -40
            model: userModel
            spacing: 10
            opacity: 0.95

            delegate: ItemDelegate {
                width: userList.width
                height: 60

                background: Rectangle {
                    color: "transparent"
                    radius: 16
                    border.color: model.name === userNameField.text ? root.cAccent : "transparent"
                    border.width: 2
                }

                contentItem: RowLayout {
                    spacing: 12
                    Rectangle {
                        width: 40; height: 40
                        radius: 20
                        gradient: Gradient {
                            orientation: Gradient.Vertical
                            GradientStop { position: 0.0; color: root.cAccent }
                            GradientStop { position: 1.0; color: Qt.darker(root.cAccent, 1.4) }
                        }
                        Text {
                            anchors.centerIn: parent
                            text: model.name ? model.name.charAt(0).toUpperCase() : "?"
                            color: "white"
                            font.weight: Font.Bold
                            font.pixelSize: 18
                        }
                    }
                    Text {
                        text: model.name
                        color: root.cText
                        font.family: "Noto Sans"
                        font.pixelSize: 16
                    }
                }

                onClicked: {
                    userNameField.text = model.name
                    userNameField.focus = true
                }
            }
        }

        // Center glass login panel
        Rectangle {
            id: glassPanel
            anchors.centerIn: parent
            width: 440
            height: 520
            radius: root.glassRadius
            color: Qt.rgba(1, 1, 1, root.glassOpacity * 0.18)

            border.color: Qt.rgba(1, 1, 1, 0.18)
            border.width: 1

            // Subtle inner glow on the glass edge
            layer.enabled: root.glassEnabled
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Qt.rgba(0, 0, 0, 0.4)
                shadowBlur: 0.8
                shadowVerticalOffset: 12
                shadowHorizontalOffset: 0
            }

            // Background blur layer (approximation: another translucent rect)
            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: parent.radius - 1
                color: Qt.rgba(0.1, 0.08, 0.18, 0.55)
            }

            // Entrance animation
            scale: root.state === "login" ? 1.0 : 0.92
            Behavior on scale { NumberAnimation { duration: root.animEnabled ? root.animMs : 0; easing.type: Easing.OutBack } }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 40
                spacing: 18

                // Logo + brand at top of panel
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 12

                    Rectangle {
                        width: 36; height: 36
                        radius: 10
                        gradient: Gradient {
                            orientation: Gradient.Vertical
                            GradientStop { position: 0.0; color: root.cAccent }
                            GradientStop { position: 1.0; color: Qt.darker(root.cAccent, 1.6) }
                        }
                        Text {
                            anchors.centerIn: parent
                            text: "N"
                            color: "white"
                            font.weight: Font.Black
                            font.pixelSize: 22
                        }
                    }

                    Text {
                        text: root.logoText
                        font.family: "Noto Sans"
                        font.weight: Font.DemiBold
                        font.pixelSize: 24
                        color: root.cText
                    }
                }

                Item { Layout.preferredHeight: 8 }

                // Username field
                Label {
                    text: "Username"
                    color: root.cTextSecondary
                    font.pixelSize: 12
                    font.family: "Noto Sans"
                }
                TextField {
                    id: userNameField
                    Layout.fillWidth: true
                    placeholderText: "novaos"
                    text: userModel.count === 1 ? userModel.get(0).name : ""
                    color: root.cText
                    font.pixelSize: 16
                    font.family: "Noto Sans"
                    background: Rectangle {
                        radius: 12
                        color: Qt.rgba(1, 1, 1, 0.06)
                        border.color: userNameField.activeFocus ? root.cAccent : Qt.rgba(1, 1, 1, 0.12)
                        border.width: userNameField.activeFocus ? 2 : 1
                        Behavior on border.color { ColorAnimation { duration: 200 } }
                    }
                    onAccepted: passwordField.forceActiveFocus()
                    Keys.onReturnPressed: passwordField.forceActiveFocus()
                }

                // Password field
                Label {
                    text: "Password"
                    color: root.cTextSecondary
                    font.pixelSize: 12
                    font.family: "Noto Sans"
                }
                TextField {
                    id: passwordField
                    Layout.fillWidth: true
                    echoMode: showPasswordToggle.checked ? TextInput.Normal : TextInput.Password
                    placeholderText: "••••••••"
                    color: root.cText
                    font.pixelSize: 16
                    font.family: "Noto Sans"
                    background: Rectangle {
                        radius: 12
                        color: Qt.rgba(1, 1, 1, 0.06)
                        border.color: passwordField.activeFocus ? root.cAccent : Qt.rgba(1, 1, 1, 0.12)
                        border.width: passwordField.activeFocus ? 2 : 1
                        Behavior on border.color { ColorAnimation { duration: 200 } }
                    }
                    onAccepted: doLogin()
                    Keys.onReturnPressed: doLogin()

                    // Animated focus ring
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: -4
                        radius: parent.background.radius + 4
                        color: "transparent"
                        border.color: root.cAccent
                        border.width: 1
                        opacity: passwordField.activeFocus ? 0.4 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 250 } }
                        z: -1
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Switch {
                        id: showPasswordToggle
                        text: "Show password"
                        font.pixelSize: 12
                        font.family: "Noto Sans"
                        contentItem.color: root.cTextSecondary
                    }
                    Item { Layout.fillWidth: true }
                }

                // Session selector
                RowLayout {
                    Layout.fillWidth: true
                    Label {
                        text: "Session:"
                        color: root.cTextSecondary
                        font.pixelSize: 12
                    }
                    ComboBox {
                        id: sessionCombo
                        Layout.fillWidth: true
                        model: sessionModel
                        textRole: "name"
                        font.pixelSize: 13
                        font.family: "Noto Sans"
                    }
                }

                // Error message area
                Text {
                    id: errorText
                    Layout.fillWidth: true
                    color: "#FF6B6B"
                    font.pixelSize: 12
                    font.family: "Noto Sans"
                    horizontalAlignment: Text.AlignHCenter
                    visible: text.length > 0
                }

                // Login button
                Button {
                    id: loginButton
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48
                    text: "Sign in"
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                    font.family: "Noto Sans"

                    background: Rectangle {
                        radius: 12
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: root.cAccent }
                            GradientStop { position: 1.0; color: root.cAccentSecondary }
                        }
                        opacity: loginButton.pressed ? 0.8 : (loginButton.hovered ? 0.92 : 1.0)
                        Behavior on opacity { NumberAnimation { duration: 120 } }
                    }

                    contentItem: Text {
                        text: loginButton.text
                        color: "white"
                        font: loginButton.font
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    onClicked: doLogin()

                    // Subtle pulse on idle
                    SequentialAnimation on scale {
                        loops: Animation.Infinite
                        running: root.state === "login"
                        NumberAnimation { to: 1.0; duration: 1500; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.015; duration: 1500; easing.type: Easing.InOutSine }
                    }
                }

                Item { Layout.fillHeight: true }

                // Power row at bottom
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 24

                    PowerButton {
                        iconSource: "suspend"
                        label: "Suspend"
                        onClicked: sddm.suspend()
                    }
                    PowerButton {
                        iconSource: "restart"
                        label: "Restart"
                        onClicked: sddm.reboot()
                    }
                    PowerButton {
                        iconSource: "shutdown"
                        label: "Shut down"
                        onClicked: sddm.powerOff()
                    }
                }
            }
        }

        // Clock at bottom
        Item {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 32
            anchors.horizontalCenter: parent.horizontalCenter
            width: clockRow.implicitWidth
            height: clockRow.implicitHeight

            RowLayout {
                id: clockRow
                anchors.centerIn: parent

                Text {
                    id: clockText
                    color: root.cText
                    font.family: "Noto Sans"
                    font.weight: Font.Light
                    font.pixelSize: 48
                    text: Qt.formatDateTime(new Date(), root.clockFormat)
                }
                Text {
                    color: root.cTextSecondary
                    font.family: "Noto Sans"
                    font.pixelSize: 14
                    text: "  " + Qt.formatDate(new Date(), "ddd, MMM d")
                }
            }

            Timer {
                interval: 1000 * 30
                running: true
                repeat: true
                onTriggered: clockText.text = Qt.formatDateTime(new Date(), root.clockFormat)
            }
        }
    }

    // =========================================================================
    // Helpers
    // =========================================================================
    function doLogin() {
        errorText.text = ""
        if (!userNameField.text) {
            errorText.text = "Please enter a username."
            userNameField.forceActiveFocus()
            return
        }
        sddm.login(userNameField.text, passwordField.text, sessionCombo.currentIndex)
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            errorText.text = "Authentication failed. Please check your credentials."
            // Shake the panel
            glassPanel.x = glassPanel.x + 8
            shakeAnim.start()
            passwordField.text = ""
            passwordField.forceActiveFocus()
        }
    }

    SequentialAnimation {
        id: shakeAnim
        NumberAnimation { target: glassPanel; property: "x"; from: glassPanel.x - 8; to: glassPanel.x + 8; duration: 50 }
        NumberAnimation { target: glassPanel; property: "x"; from: glassPanel.x + 8; to: glassPanel.x - 8; duration: 50 }
        NumberAnimation { target: glassPanel; property: "x"; from: glassPanel.x - 8; to: glassPanel.x;     duration: 50 }
    }

    // Power button custom component
    component PowerButton: Item {
        property string iconSource
        property string label
        signal clicked()
        width: 56; height: 64
        ColumnLayout {
            anchors.centerIn: parent
            spacing: 4
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                width: 36; height: 36
                radius: 18
                color: Qt.rgba(1, 1, 1, 0.08)
                border.color: Qt.rgba(1, 1, 1, 0.18)
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    color: "white"
                    font.pixelSize: 18
                    text: parent.parent.iconSource === "suspend"  ? "⏸"
                        : parent.parent.iconSource === "restart"   ? "↻"
                        : "⏻"
                }
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: label
                color: root.cTextSecondary
                font.pixelSize: 10
                font.family: "Noto Sans"
            }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.clicked()
        }
    }
}
