import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"

Item {
    id: lumiTabRoot
    anchors.fill: parent

    property bool apiKeyVisible: false

    function focusApiKey() { lumiApiKeyInput.forceActiveFocus(); }
    function scrollTo(y) {
        let maxY = Math.max(0, lumiFlickable.contentHeight - lumiFlickable.height);
        lumiFlickable.contentY = Math.max(0, Math.min(y - root.s(40), maxY > 0 ? maxY : y));
    }
    function scrollToBox(approxItemY) {
        let viewH = lumiFlickable.height;
        let itemTop = approxItemY;
        let itemBottom = approxItemY + root.s(80);
        let curY = lumiFlickable.contentY;
        let maxY = Math.max(0, lumiFlickable.contentHeight - viewH);
        if (itemTop < curY + root.s(10)) {
            lumiFlickable.contentY = Math.max(0, itemTop - root.s(20));
        } else if (itemBottom > curY + viewH - root.s(10)) {
            lumiFlickable.contentY = Math.min(maxY, itemBottom - viewH + root.s(20));
        }
    }


    Flickable {
        id: lumiFlickable
        anchors.fill: parent
        contentWidth: width
        contentHeight: lumiCol.implicitHeight + root.s(100)
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        MouseArea { anchors.fill: parent; onClicked: root.clearHighlight(); z: -1 }

        ColumnLayout {
            id: lumiCol
            width: parent.width
            spacing: root.s(10)

            // ── Box 0: Setup Instructions ────────────────────────────
            Rectangle {
                id: lBox0
                Layout.fillWidth: true
                Layout.preferredHeight: lumiInstructionLayout.implicitHeight + root.s(28)
                radius: root.s(12)

                property bool isActive: root.highlightedBox === 0
                color: isActive ? root.mauve : root.surface0
                border.color: isActive ? root.mauve : root.surface1
                border.width: 1
                Behavior on color { ColorAnimation { duration: 220; easing.type: Easing.OutExpo } }
                clip: true

                MouseArea { anchors.fill: parent; onClicked: root.highlightedBox = 0; z: -1 }

                ColumnLayout {
                    id: lumiInstructionLayout
                    anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                    anchors.margins: root.s(14)
                    spacing: root.s(10)

                    RowLayout {
                        spacing: root.s(12)
                        Text {
                            text: "󰧑"
                            font.family: "Iosevka Nerd Font"
                            font.pixelSize: root.s(20)
                            color: lBox0.isActive ? root.base : root.mauve
                            Layout.alignment: Qt.AlignVCenter
                            Behavior on color { ColorAnimation { duration: 220; easing.type: Easing.OutExpo } }
                        }
                        Text {
                            text: "Lumi AI Setup"
                            font.family: "Inter"; font.weight: Font.Bold; font.pixelSize: root.s(15)
                            color: lBox0.isActive ? root.base : root.text
                            Layout.fillWidth: true
                            Behavior on color { ColorAnimation { duration: 220; easing.type: Easing.OutExpo } }
                        }
                    }

                    RowLayout {
                        spacing: root.s(10); Layout.fillWidth: true
                        Item {
                            Layout.preferredWidth: root.s(22); Layout.fillHeight: true
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter; width: 2; height: parent.height
                                color: lBox0.isActive ? Qt.alpha(root.base, 0.3) : root.surface2
                                Behavior on color { ColorAnimation { duration: 220 } }
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: root.s(6)
                            Layout.topMargin: root.s(2); Layout.bottomMargin: root.s(2)
                            Repeater {
                                model: [
                                    "Go to aistudio.google.com and sign in with Google.",
                                    "Click 'Get API Key' from the left menu.",
                                    "Click 'Create API Key' and copy your key.",
                                    "Paste it in the API Key field below."
                                ]
                                Rectangle {
                                    Layout.fillWidth: true; Layout.preferredHeight: root.s(30)
                                    radius: root.s(6)
                                    color: lBox0.isActive ? Qt.alpha(root.base, 0.12) : root.surface0
                                    border.color: lBox0.isActive ? Qt.alpha(root.base, 0.2) : root.surface1
                                    border.width: 1
                                    Behavior on color { ColorAnimation { duration: 220 } }
                                    Behavior on border.color { ColorAnimation { duration: 220 } }
                                    RowLayout {
                                        anchors.fill: parent; anchors.margins: root.s(7); spacing: root.s(7)
                                        Text {
                                            text: "󰄾"; font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(12)
                                            color: lBox0.isActive ? Qt.alpha(root.base, 0.6) : root.overlay0
                                            Behavior on color { ColorAnimation { duration: 220 } }
                                        }
                                        Text {
                                            text: modelData; font.family: "Inter"; font.pixelSize: root.s(11)
                                            color: lBox0.isActive ? Qt.alpha(root.base, 0.85) : root.subtext1
                                            Layout.fillWidth: true
                                            Behavior on color { ColorAnimation { duration: 220 } }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        text: "* Google Gemini offers a generous free tier — no credit card required."
                        font.family: "Inter"; font.pixelSize: root.s(10); font.italic: true
                        color: lBox0.isActive ? Qt.alpha(root.base, 0.7) : root.yellow
                        Layout.topMargin: root.s(2)
                        Behavior on color { ColorAnimation { duration: 220 } }
                    }
                }
            }

            // ── Box 1: Gemini API Key ────────────────────────────────
            Rectangle {
                id: lBox1
                Layout.fillWidth: true
                Layout.preferredHeight: apiKeyColLayout.implicitHeight + root.s(28)
                radius: root.s(12)

                property bool isActive: root.highlightedBox === 1
                color: isActive ? root.mauve : root.surface0
                border.color: isActive ? root.mauve : root.surface1
                border.width: 1
                Behavior on color { ColorAnimation { duration: 220; easing.type: Easing.OutExpo } }

                MouseArea { anchors.fill: parent; onClicked: root.highlightedBox = 1; z: -1 }

                ColumnLayout {
                    id: apiKeyColLayout
                    anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                    anchors.margins: root.s(16)
                    spacing: root.s(10)

                    RowLayout {
                        Layout.fillWidth: true; spacing: root.s(14)
                        Item {
                            Layout.preferredWidth: root.s(22); Layout.alignment: Qt.AlignVCenter
                            Text {
                                anchors.centerIn: parent; text: "󰌆"
                                font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(18)
                                color: lBox1.isActive ? root.base : root.mauve
                                Behavior on color { ColorAnimation { duration: 220; easing.type: Easing.OutExpo } }
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: root.s(3)
                            Text {
                                text: "Gemini API Key"
                                font.family: "Inter"; font.weight: Font.Medium; font.pixelSize: root.s(14)
                                color: lBox1.isActive ? root.base : root.text; Layout.fillWidth: true
                                Behavior on color { ColorAnimation { duration: 220; easing.type: Easing.OutExpo } }
                            }
                            Text {
                                text: "Google Gemini API Key (Starts with AIzaSy...)"
                                font.family: "Inter"; font.pixelSize: root.s(11)
                                color: lBox1.isActive ? Qt.alpha(root.base, 0.75) : Qt.alpha(root.subtext0, 0.7)
                                Layout.fillWidth: true
                                Behavior on color { ColorAnimation { duration: 220; easing.type: Easing.OutExpo } }
                            }
                        }

                        // Status indicator
                        Rectangle {
                            Layout.preferredWidth: root.s(8); Layout.preferredHeight: root.s(8)
                            radius: root.s(4)
                            Layout.alignment: Qt.AlignVCenter
                            color: Config.lumiApiKey.length > 10
                                ? root.green
                                : (Config.lumiApiKey.length > 0 ? root.yellow : root.red)
                            Behavior on color { ColorAnimation { duration: 300 } }
                        }
                    }

                    // Single API Key input field
                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: root.s(42)
                        radius: root.s(7)
                        color: lBox1.isActive ? Qt.alpha(root.base, 0.15) : root.surface0
                        border.color: lumiApiKeyInput.activeFocus
                            ? (lBox1.isActive ? root.base : root.mauve)
                            : (lBox1.isActive ? Qt.alpha(root.base, 0.3) : root.surface2)
                        border.width: 1
                        Behavior on border.color { ColorAnimation { duration: 150 } }
                        Behavior on color { ColorAnimation { duration: 220; easing.type: Easing.OutExpo } }

                        RowLayout {
                            anchors.fill: parent; anchors.margins: root.s(10); spacing: root.s(10)
                            Text {
                                text: "󰌆"; font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(16)
                                color: lBox1.isActive ? Qt.alpha(root.base, 0.6) : root.subtext0
                                Behavior on color { ColorAnimation { duration: 220 } }
                            }
                            TextInput {
                                id: lumiApiKeyInput
                                Layout.fillWidth: true; Layout.fillHeight: true
                                verticalAlignment: TextInput.AlignVCenter
                                font.family: "JetBrains Mono"; font.pixelSize: root.s(12)
                                color: lBox1.isActive ? root.base : root.text
                                clip: true; selectByMouse: true
                                echoMode: lumiTabRoot.apiKeyVisible ? TextInput.Normal : TextInput.Password
                                passwordCharacter: "•"
                                text: Config.lumiApiKey
                                onTextChanged: {
                                    if (Config.lumiApiKey !== text) {
                                        Config.lumiApiKey = text
                                        Config.saveLumiConfig()
                                    }
                                }
                                Behavior on color { ColorAnimation { duration: 220 } }
                                Text {
                                    text: "AIzaSy..."
                                    color: lBox1.isActive ? Qt.alpha(root.base, 0.5) : root.subtext0
                                    visible: !parent.text && !parent.activeFocus
                                    font: parent.font; anchors.verticalCenter: parent.verticalCenter
                                    Behavior on color { ColorAnimation { duration: 220 } }
                                }
                            }
                            // Toggle visibility
                            Rectangle {
                                width: root.s(26); height: root.s(26); radius: root.s(5)
                                color: eyeLumiMa.containsMouse
                                    ? Qt.alpha(lBox1.isActive ? root.base : root.mauve, 0.2)
                                    : "transparent"
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Text {
                                    anchors.centerIn: parent
                                    text: lumiTabRoot.apiKeyVisible ? "󰈈" : "󰈉"
                                    font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(16)
                                    color: eyeLumiMa.containsMouse
                                        ? (lBox1.isActive ? root.base : root.mauve)
                                        : (lBox1.isActive ? Qt.alpha(root.base, 0.6) : root.subtext0)
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }
                                MouseArea {
                                    id: eyeLumiMa; anchors.fill: parent; hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: lumiTabRoot.apiKeyVisible = !lumiTabRoot.apiKeyVisible
                                }
                            }
                        }
                    }
                }
            }

            // ── Box 2: AI Model ──────────────────────────────────────
            Rectangle {
                id: lBox2
                Layout.fillWidth: true
                Layout.preferredHeight: modelColLayout.implicitHeight + root.s(28)
                radius: root.s(12)

                property bool isActive: root.highlightedBox === 2
                color: isActive ? root.teal : root.surface0
                border.color: isActive ? root.teal : root.surface1
                border.width: 1
                Behavior on color { ColorAnimation { duration: 220; easing.type: Easing.OutExpo } }

                MouseArea { anchors.fill: parent; onClicked: root.highlightedBox = 2; z: -1 }

                ColumnLayout {
                    id: modelColLayout
                    anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                    anchors.margins: root.s(16)
                    spacing: root.s(10)

                    RowLayout {
                        Layout.fillWidth: true; spacing: root.s(14)
                        Item {
                            Layout.preferredWidth: root.s(22); Layout.alignment: Qt.AlignVCenter
                            Text {
                                anchors.centerIn: parent; text: "󰍊"
                                font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(18)
                                color: lBox2.isActive ? root.base : root.teal
                                Behavior on color { ColorAnimation { duration: 220; easing.type: Easing.OutExpo } }
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: root.s(3)
                            Text {
                                text: "AI Model"
                                font.family: "Inter"; font.weight: Font.Medium; font.pixelSize: root.s(14)
                                color: lBox2.isActive ? root.base : root.text; Layout.fillWidth: true
                                Behavior on color { ColorAnimation { duration: 220; easing.type: Easing.OutExpo } }
                            }
                            Text {
                                text: "Google Gemini model to use for inference"
                                font.family: "Inter"; font.pixelSize: root.s(11)
                                color: lBox2.isActive ? Qt.alpha(root.base, 0.75) : Qt.alpha(root.subtext0, 0.7)
                                Layout.fillWidth: true
                                Behavior on color { ColorAnimation { duration: 220; easing.type: Easing.OutExpo } }
                            }
                        }
                    }

                    // Quick-select chips
                    Flow {
                        Layout.fillWidth: true; spacing: root.s(6)
                        Repeater {
                            model: [
                                { id: "gemini-3.5-flash",       label: "Gemini 3.5 Flash" },
                                { id: "gemini-3.1-flash-lite", label: "Gemini 3.1 Flash Lite" },
                                { id: "gemini-2.0-flash",       label: "Gemini 2.0 Flash" },
                                { id: "gemini-3.1-pro-preview", label: "Gemini 3.1 Pro" }
                            ]
                            Rectangle {
                                width: modelChipRow.implicitWidth + root.s(20)
                                height: root.s(26); radius: root.s(13)
                                property bool isSelected: Config.lumiModel === modelData.id
                                color: isSelected
                                    ? (lBox2.isActive ? Qt.alpha(root.base, 0.3) : root.teal)
                                    : (lBox2.isActive ? Qt.alpha(root.base, 0.1) : "transparent")
                                border.color: isSelected
                                    ? (lBox2.isActive ? Qt.alpha(root.base, 0.7) : root.teal)
                                    : (lBox2.isActive ? Qt.alpha(root.base, 0.25) : root.surface2)
                                border.width: 1
                                scale: chipModelMa.containsMouse ? 1.04 : 1.0
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Behavior on border.color { ColorAnimation { duration: 150 } }
                                Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutBack } }
                                RowLayout {
                                    id: modelChipRow; anchors.centerIn: parent; spacing: root.s(5)
                                    Text {
                                        text: modelData.label
                                        font.family: "JetBrains Mono"; font.pixelSize: root.s(10)
                                        color: isSelected
                                            ? (lBox2.isActive ? root.base : root.base)
                                            : (lBox2.isActive ? Qt.alpha(root.base, 0.7) : root.subtext0)
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                    }
                                }
                                MouseArea {
                                    id: chipModelMa; anchors.fill: parent; hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        Config.lumiModel = modelData.id
                                        Config.saveLumiConfig()
                                    }
                                }
                            }
                        }
                    }

                    // Custom model text input
                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: root.s(42)
                        radius: root.s(7)
                        color: lBox2.isActive ? Qt.alpha(root.base, 0.15) : root.surface0
                        border.color: lumiModelInput.activeFocus
                            ? (lBox2.isActive ? root.base : root.teal)
                            : (lBox2.isActive ? Qt.alpha(root.base, 0.3) : root.surface2)
                        border.width: 1
                        Behavior on border.color { ColorAnimation { duration: 150 } }
                        Behavior on color { ColorAnimation { duration: 220; easing.type: Easing.OutExpo } }

                        RowLayout {
                            anchors.fill: parent; anchors.margins: root.s(10); spacing: root.s(10)
                            Text {
                                text: "󰈊"; font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(16)
                                color: lBox2.isActive ? Qt.alpha(root.base, 0.6) : root.subtext0
                                Behavior on color { ColorAnimation { duration: 220 } }
                            }
                            TextInput {
                                id: lumiModelInput
                                Layout.fillWidth: true; Layout.fillHeight: true
                                verticalAlignment: TextInput.AlignVCenter
                                font.family: "JetBrains Mono"; font.pixelSize: root.s(12)
                                color: lBox2.isActive ? root.base : root.text
                                clip: true; selectByMouse: true
                                text: Config.lumiModel
                                onTextChanged: {
                                    if (Config.lumiModel !== text) {
                                        Config.lumiModel = text
                                        Config.saveLumiConfig()
                                    }
                                }
                                Behavior on color { ColorAnimation { duration: 220 } }
                                Text {
                                    text: "e.g. gemini-2.5-flash"
                                    color: lBox2.isActive ? Qt.alpha(root.base, 0.5) : root.subtext0
                                    visible: !parent.text && !parent.activeFocus
                                    font: parent.font; anchors.verticalCenter: parent.verticalCenter
                                    Behavior on color { ColorAnimation { duration: 220 } }
                                }
                            }
                        }
                    }
                }
            }

            // ── Box 3: Auto-Speak (TTS) ──────────────────────────────
            Rectangle {
                id: lBox3
                Layout.fillWidth: true
                Layout.preferredHeight: ttsRow.implicitHeight + root.s(28)
                radius: root.s(12)

                property bool isActive: root.highlightedBox === 3
                color: isActive ? root.green : root.surface0
                border.color: isActive ? root.green : root.surface1
                border.width: 1
                Behavior on color { ColorAnimation { duration: 220; easing.type: Easing.OutExpo } }

                MouseArea { anchors.fill: parent; onClicked: root.highlightedBox = 3; z: -1 }

                RowLayout {
                    id: ttsRow
                    anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                    anchors.margins: root.s(16)
                    spacing: root.s(14)

                    Item {
                        Layout.preferredWidth: root.s(22); Layout.alignment: Qt.AlignVCenter
                        Text {
                            anchors.centerIn: parent; text: "󰓃"
                            font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(18)
                            color: lBox3.isActive ? root.base : root.green
                            Behavior on color { ColorAnimation { duration: 220; easing.type: Easing.OutExpo } }
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter; spacing: root.s(3)
                        Text {
                            text: "Auto-Speak (TTS)"
                            font.family: "Inter"; font.weight: Font.Medium; font.pixelSize: root.s(14)
                            color: lBox3.isActive ? root.base : root.text; Layout.fillWidth: true
                            Behavior on color { ColorAnimation { duration: 220; easing.type: Easing.OutExpo } }
                        }
                        Text {
                            text: "Automatically read AI responses out loud"
                            font.family: "Inter"; font.pixelSize: root.s(11)
                            color: lBox3.isActive ? Qt.alpha(root.base, 0.75) : Qt.alpha(root.subtext0, 0.7)
                            Layout.fillWidth: true
                            Behavior on color { ColorAnimation { duration: 220; easing.type: Easing.OutExpo } }
                        }
                    }

                    // Toggle switch
                    Rectangle {
                        Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                        Layout.preferredWidth: root.s(40); Layout.preferredHeight: root.s(22)
                        radius: root.s(11)
                        scale: ttsToggleMa.containsMouse ? 1.05 : 1.0
                        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                        color: Config.lumiAutoSpeak
                            ? (lBox3.isActive ? root.base : root.green)
                            : Qt.alpha(root.surface2, lBox3.isActive ? 0.4 : 1.0)
                        Behavior on color { ColorAnimation { duration: 220; easing.type: Easing.OutExpo } }
                        Rectangle {
                            width: root.s(16); height: root.s(16); radius: root.s(8)
                            color: Config.lumiAutoSpeak
                                ? (lBox3.isActive ? root.green : root.base)
                                : (lBox3.isActive ? root.green : root.surface0)
                            y: root.s(3); x: Config.lumiAutoSpeak ? root.s(21) : root.s(3)
                            Behavior on x { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }
                            Behavior on color { ColorAnimation { duration: 220; easing.type: Easing.OutExpo } }
                        }
                        MouseArea {
                            id: ttsToggleMa; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Config.lumiAutoSpeak = !Config.lumiAutoSpeak
                        }
                    }
                }
            }

            // ── Box 3.2: TTS Voice Selection ─────────────────────────
            Rectangle {
                id: lBoxVoice
                Layout.fillWidth: true
                Layout.preferredHeight: voiceColLayout.implicitHeight + root.s(28)
                radius: root.s(12)

                property bool isActive: root.highlightedBox === 32
                color: isActive ? root.sky : root.surface0
                border.color: isActive ? root.sky : root.surface1
                border.width: 1
                Behavior on color { ColorAnimation { duration: 220; easing.type: Easing.OutExpo } }

                MouseArea { anchors.fill: parent; onClicked: root.highlightedBox = 32; z: -1 }

                ColumnLayout {
                    id: voiceColLayout
                    anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                    anchors.margins: root.s(16)
                    spacing: root.s(10)

                    RowLayout {
                        Layout.fillWidth: true; spacing: root.s(14)
                        Item {
                            Layout.preferredWidth: root.s(22); Layout.alignment: Qt.AlignVCenter
                            Text {
                                anchors.centerIn: parent; text: "󰔊"
                                font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(18)
                                color: lBoxVoice.isActive ? root.base : root.sky
                                Behavior on color { ColorAnimation { duration: 220; easing.type: Easing.OutExpo } }
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: root.s(3)
                            Text {
                                text: "TTS Voice (Suara Lumi)"
                                font.family: "Inter"; font.weight: Font.Medium; font.pixelSize: root.s(14)
                                color: lBoxVoice.isActive ? root.base : root.text; Layout.fillWidth: true
                                Behavior on color { ColorAnimation { duration: 220; easing.type: Easing.OutExpo } }
                            }
                            Text {
                                text: "Pilih suara text-to-speech yang dibacakan Lumi (Microsoft edge-tts)"
                                font.family: "Inter"; font.pixelSize: root.s(11)
                                color: lBoxVoice.isActive ? Qt.alpha(root.base, 0.75) : Qt.alpha(root.subtext0, 0.7)
                                Layout.fillWidth: true
                                Behavior on color { ColorAnimation { duration: 220; easing.type: Easing.OutExpo } }
                            }
                        }
                    }

                    // Voice preset chips
                    Flow {
                        Layout.fillWidth: true; spacing: root.s(6)
                        Repeater {
                            model: [
                                { id: "id-ID-GadisNeural",  label: "Gadis (Wanita 🇮🇩)" },
                                { id: "id-ID-ArdiNeural",   label: "Ardi (Pria 🇮🇩)" },
                                { id: "en-US-JennyNeural",  label: "Jenny (EN 🇺🇸)" },
                                { id: "en-US-GuyNeural",    label: "Guy (EN 🇺🇸)" },
                                { id: "en-GB-SoniaNeural",  label: "Sonia (EN 🇬🇧)" }
                            ]
                            Rectangle {
                                width: voiceChipRow.implicitWidth + root.s(20)
                                height: root.s(26); radius: root.s(13)
                                property bool isSelected: Config.lumiTtsVoice === modelData.id
                                color: isSelected
                                    ? (lBoxVoice.isActive ? Qt.alpha(root.base, 0.3) : root.sky)
                                    : (lBoxVoice.isActive ? Qt.alpha(root.base, 0.1) : "transparent")
                                border.color: isSelected
                                    ? (lBoxVoice.isActive ? Qt.alpha(root.base, 0.7) : root.sky)
                                    : (lBoxVoice.isActive ? Qt.alpha(root.base, 0.25) : root.surface2)
                                border.width: 1
                                scale: voiceChipMa.containsMouse ? 1.04 : 1.0
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Behavior on border.color { ColorAnimation { duration: 150 } }
                                Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutBack } }
                                RowLayout {
                                    id: voiceChipRow; anchors.centerIn: parent; spacing: root.s(5)
                                    Text {
                                        text: modelData.label
                                        font.family: "JetBrains Mono"; font.pixelSize: root.s(10)
                                        color: isSelected
                                            ? root.base
                                            : (lBoxVoice.isActive ? Qt.alpha(root.base, 0.7) : root.subtext0)
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                    }
                                }
                                MouseArea {
                                    id: voiceChipMa; anchors.fill: parent; hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        Config.lumiTtsVoice = modelData.id
                                        Config.saveLumiConfig()
                                    }
                                }
                            }
                        }
                    }

                    // Custom voice input
                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: root.s(42)
                        radius: root.s(7)
                        color: lBoxVoice.isActive ? Qt.alpha(root.base, 0.15) : root.surface0
                        border.color: voiceInput.activeFocus
                            ? (lBoxVoice.isActive ? root.base : root.sky)
                            : (lBoxVoice.isActive ? Qt.alpha(root.base, 0.3) : root.surface2)
                        border.width: 1
                        Behavior on border.color { ColorAnimation { duration: 150 } }
                        Behavior on color { ColorAnimation { duration: 220; easing.type: Easing.OutExpo } }

                        RowLayout {
                            anchors.fill: parent; anchors.margins: root.s(10); spacing: root.s(10)
                            Text {
                                text: "󰔊"; font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(16)
                                color: lBoxVoice.isActive ? Qt.alpha(root.base, 0.6) : root.subtext0
                                Behavior on color { ColorAnimation { duration: 220 } }
                            }
                            TextInput {
                                id: voiceInput
                                Layout.fillWidth: true; Layout.fillHeight: true
                                verticalAlignment: TextInput.AlignVCenter
                                font.family: "JetBrains Mono"; font.pixelSize: root.s(12)
                                color: lBoxVoice.isActive ? root.base : root.text
                                clip: true; selectByMouse: true
                                text: Config.lumiTtsVoice
                                onTextChanged: {
                                    if (Config.lumiTtsVoice !== text) {
                                        Config.lumiTtsVoice = text
                                        Config.saveLumiConfig()
                                    }
                                }
                                Behavior on color { ColorAnimation { duration: 220 } }
                                Text {
                                    text: "e.g. id-ID-GadisNeural"
                                    color: lBoxVoice.isActive ? Qt.alpha(root.base, 0.5) : root.subtext0
                                    visible: !parent.text && !parent.activeFocus
                                    font: parent.font; anchors.verticalCenter: parent.verticalCenter
                                    Behavior on color { ColorAnimation { duration: 220 } }
                                }
                            }
                        }
                    }
                }
            }

            // ── Box 3.5: Voice Pause Duration (Auto-Answer Delay) ─────
            Rectangle {
                id: lBoxPause
                Layout.fillWidth: true
                Layout.preferredHeight: pauseColLayout.implicitHeight + root.s(28)
                radius: root.s(12)

                property bool isActive: root.highlightedBox === 35
                color: isActive ? root.peach : root.surface0
                border.color: isActive ? root.peach : root.surface1
                border.width: 1
                Behavior on color { ColorAnimation { duration: 220; easing.type: Easing.OutExpo } }

                MouseArea { anchors.fill: parent; onClicked: root.highlightedBox = 35; z: -1 }

                ColumnLayout {
                    id: pauseColLayout
                    anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                    anchors.margins: root.s(16)
                    spacing: root.s(10)

                    RowLayout {
                        Layout.fillWidth: true; spacing: root.s(14)
                        Item {
                            Layout.preferredWidth: root.s(22); Layout.alignment: Qt.AlignVCenter
                            Text {
                                anchors.centerIn: parent; text: "󱎫"
                                font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(18)
                                color: lBoxPause.isActive ? root.base : root.peach
                                Behavior on color { ColorAnimation { duration: 220; easing.type: Easing.OutExpo } }
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: root.s(3)
                            Text {
                                text: "Silence Pause Duration (Waktu Diam)"
                                font.family: "Inter"; font.weight: Font.Medium; font.pixelSize: root.s(14)
                                color: lBoxPause.isActive ? root.base : root.text; Layout.fillWidth: true
                                Behavior on color { ColorAnimation { duration: 220; easing.type: Easing.OutExpo } }
                            }
                            Text {
                                text: "Duration of silence (in seconds) after speaking before Lumi automatically answers"
                                font.family: "Inter"; font.pixelSize: root.s(11)
                                color: lBoxPause.isActive ? Qt.alpha(root.base, 0.75) : Qt.alpha(root.subtext0, 0.7)
                                Layout.fillWidth: true
                                Behavior on color { ColorAnimation { duration: 220; easing.type: Easing.OutExpo } }
                            }
                        }
                    }

                    // Quick-select chips
                    Flow {
                        Layout.fillWidth: true; spacing: root.s(6)
                        Repeater {
                            model: [
                                { val: 0.2, label: "0.2s (200ms AI)" },
                                { val: 0.5, label: "0.5s (Cepat)" },
                                { val: 1.0, label: "1.0s (Standar)" },
                                { val: 1.5, label: "1.5s (Santai)" },
                                { val: 2.0, label: "2.0s (Lama)" }
                            ]
                            Rectangle {
                                width: pauseChipRow.implicitWidth + root.s(20)
                                height: root.s(26); radius: root.s(13)
                                property bool isSelected: Math.abs(Config.lumiSilenceDuration - modelData.val) < 0.1
                                color: isSelected
                                    ? (lBoxPause.isActive ? Qt.alpha(root.base, 0.3) : root.peach)
                                    : (lBoxPause.isActive ? Qt.alpha(root.base, 0.1) : "transparent")
                                border.color: isSelected
                                    ? (lBoxPause.isActive ? Qt.alpha(root.base, 0.7) : root.peach)
                                    : (lBoxPause.isActive ? Qt.alpha(root.base, 0.25) : root.surface2)
                                border.width: 1
                                scale: chipPauseMa.containsMouse ? 1.04 : 1.0
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Behavior on border.color { ColorAnimation { duration: 150 } }
                                Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutBack } }
                                RowLayout {
                                    id: pauseChipRow; anchors.centerIn: parent; spacing: root.s(5)
                                    Text {
                                        text: modelData.label
                                        font.family: "JetBrains Mono"; font.pixelSize: root.s(10)
                                        color: isSelected
                                            ? root.base
                                            : (lBoxPause.isActive ? Qt.alpha(root.base, 0.7) : root.subtext0)
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                    }
                                }
                                MouseArea {
                                    id: chipPauseMa; anchors.fill: parent; hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        Config.lumiSilenceDuration = modelData.val
                                        Config.saveLumiConfig()
                                    }
                                }
                            }
                        }
                    }

                    // Custom numeric input field
                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: root.s(42)
                        radius: root.s(7)
                        color: lBoxPause.isActive ? Qt.alpha(root.base, 0.15) : root.surface0
                        border.color: pauseDurInput.activeFocus
                            ? (lBoxPause.isActive ? root.base : root.peach)
                            : (lBoxPause.isActive ? Qt.alpha(root.base, 0.3) : root.surface2)
                        border.width: 1
                        Behavior on border.color { ColorAnimation { duration: 150 } }
                        Behavior on color { ColorAnimation { duration: 220; easing.type: Easing.OutExpo } }

                        RowLayout {
                            anchors.fill: parent; anchors.margins: root.s(10); spacing: root.s(10)
                            Text {
                                text: "󱎫"; font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(16)
                                color: lBoxPause.isActive ? Qt.alpha(root.base, 0.6) : root.subtext0
                                Behavior on color { ColorAnimation { duration: 220 } }
                            }
                            TextInput {
                                id: pauseDurInput
                                Layout.fillWidth: true; Layout.fillHeight: true
                                verticalAlignment: TextInput.AlignVCenter
                                font.family: "JetBrains Mono"; font.pixelSize: root.s(12)
                                color: lBoxPause.isActive ? root.base : root.text
                                clip: true; selectByMouse: true
                                text: Config.lumiSilenceDuration.toString()
                                onTextChanged: {
                                    let v = parseFloat(text)
                                    if (!isNaN(v) && v >= 0.3 && v <= 5.0) {
                                        Config.lumiSilenceDuration = v
                                        Config.saveLumiConfig()
                                    }
                                }
                                Behavior on color { ColorAnimation { duration: 220 } }
                                Text {
                                    text: "e.g. 1.0"
                                    color: lBoxPause.isActive ? Qt.alpha(root.base, 0.5) : root.subtext0
                                    visible: !parent.text && !parent.activeFocus
                                    font: parent.font; anchors.verticalCenter: parent.verticalCenter
                                    Behavior on color { ColorAnimation { duration: 220 } }
                                }
                            }
                        }
                    }
                }
            }

            // ── Box 6: Microphone Calibration ────────────────────────
            Rectangle {
                id: lBox6
                Layout.fillWidth: true
                Layout.preferredHeight: micColLayout.implicitHeight + root.s(28)
                radius: root.s(12)

                property bool isActive: root.highlightedBox === 6
                property int calibPhase: 0 // 0 = idle, 1 = bg 5s, 2 = speech 4s
                property string statusMsg: ""
                property bool statusIsError: statusMsg.indexOf("Gagal") !== -1 || statusMsg.indexOf("rendah") !== -1 || statusMsg.indexOf("Error") !== -1
                color: isActive ? root.red : root.surface0
                border.color: isActive ? root.red : root.surface1
                border.width: 1
                Behavior on color { ColorAnimation { duration: 220; easing.type: Easing.OutExpo } }

                MouseArea { anchors.fill: parent; onClicked: root.highlightedBox = 6; z: -1 }

                ColumnLayout {
                    id: micColLayout
                    anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                    anchors.margins: root.s(16)
                    spacing: root.s(10)

                    RowLayout {
                        Layout.fillWidth: true; spacing: root.s(14)
                        Item {
                            Layout.preferredWidth: root.s(22); Layout.alignment: Qt.AlignVCenter
                            Text {
                                anchors.centerIn: parent; text: "󰍬"
                                font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(18)
                                color: lBox6.isActive ? root.base : root.red
                                Behavior on color { ColorAnimation { duration: 220; easing.type: Easing.OutExpo } }
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: root.s(3)
                            Text {
                                text: "Microphone Calibration (2-Stage)"
                                font.family: "Inter"; font.weight: Font.Medium; font.pixelSize: root.s(14)
                                color: lBox6.isActive ? root.base : root.text; Layout.fillWidth: true
                                Behavior on color { ColorAnimation { duration: 220; easing.type: Easing.OutExpo } }
                            }
                            Text {
                                text: "5s background noise (stay silent) + 4s user voice (speak normally)"
                                font.family: "Inter"; font.pixelSize: root.s(11)
                                color: lBox6.isActive ? Qt.alpha(root.base, 0.75) : Qt.alpha(root.subtext0, 0.7)
                                Layout.fillWidth: true
                                Behavior on color { ColorAnimation { duration: 220; easing.type: Easing.OutExpo } }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: root.s(36)
                        radius: root.s(7)
                        color: calibMa.containsMouse ? Qt.alpha(lBox6.isActive ? root.base : root.red, 0.15) : "transparent"
                        border.color: lBox6.isActive ? Qt.alpha(root.base, 0.3) : root.surface2
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 150 } }
                        
                        // Calibration Animation / Icon
                        RowLayout {
                            anchors.centerIn: parent; spacing: root.s(8)
                            Text {
                                text: lBox6.calibPhase > 0 ? "󰔚" : "󰐕"
                                font.family: "Iosevka Nerd Font"
                                color: lBox6.isActive ? root.base : root.red
                                font.pixelSize: root.s(15)
                                RotationAnimation on rotation {
                                    loops: Animation.Infinite
                                    from: 0; to: 360
                                    duration: 1000
                                    running: lBox6.calibPhase > 0
                                }
                            }
                            Text { 
                                text: lBox6.calibPhase === 1 ? "Phase 1: Stay Silent (5s noise)..." :
                                      lBox6.calibPhase === 2 ? "Phase 2: Speak Normally (4s voice)..." :
                                      "Run 2-Stage Calibration"
                                font.family: "Inter"
                                font.pixelSize: root.s(12)
                                color: lBox6.isActive ? root.base : root.red
                                font.weight: Font.Medium 
                            }
                        }
                        
                        MouseArea {
                            id: calibMa; anchors.fill: parent; hoverEnabled: true
                            cursorShape: lBox6.calibPhase > 0 ? Qt.ForbiddenCursor : Qt.PointingHandCursor
                            onClicked: {
                                if (lBox6.calibPhase === 0) {
                                    lBox6.statusMsg = "";
                                    lBox6.calibPhase = 1;
                                    calibBgProcess.running = true;
                                }
                            }
                        }
                    }

                    // Native 2-Phase Calibration Processes
                    Process {
                        id: calibBgProcess
                        command: ["python3", Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/lumi2/backend/calibrate_mic.py", "bg"]
                        running: false
                        stdout: StdioCollector {
                            onStreamFinished: {
                                let txt = this.text ? this.text.trim() : "";
                                try {
                                    let obj = JSON.parse(txt);
                                    if (obj.status === "error") {
                                        lBox6.statusMsg = obj.message || "Phase 1 Gagal";
                                        lBox6.calibPhase = 0;
                                    }
                                } catch(e) {}
                            }
                        }
                        onExited: function(exitCode) {
                            if (exitCode !== 0) {
                                if (lBox6.statusMsg === "") lBox6.statusMsg = "Phase 1 Error (exit " + exitCode + ")";
                                lBox6.calibPhase = 0;
                            } else if (lBox6.calibPhase === 1) {
                                lBox6.calibPhase = 2;
                                calibSpeechProcess.running = true;
                            }
                        }
                    }

                    Process {
                        id: calibSpeechProcess
                        command: ["python3", Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/lumi2/backend/calibrate_mic.py", "speech"]
                        running: false
                        stdout: StdioCollector {
                            onStreamFinished: {
                                let txt = this.text ? this.text.trim() : "";
                                try {
                                    let obj = JSON.parse(txt);
                                    if (obj.status === "error") {
                                        lBox6.statusMsg = obj.message || "Gagal: SNR terlalu rendah";
                                    } else if (obj.optimal_threshold) {
                                        Config.lumiSilenceThreshold = obj.optimal_threshold;
                                        Config.saveLumiConfig();
                                        lBox6.statusMsg = "Hasil: " + obj.optimal_threshold + " (SNR " + obj.snr_db + "dB)";
                                    }
                                } catch(e) {
                                    lBox6.statusMsg = "Kalibrasi Selesai";
                                }
                                lBox6.calibPhase = 0;
                            }
                        }
                    }

                    // Manual Threshold Input
                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: root.s(42)
                        radius: root.s(7)
                        color: lBox6.isActive ? Qt.alpha(root.base, 0.15) : root.surface0
                        border.color: lumiSilenceInput.activeFocus
                            ? (lBox6.isActive ? root.base : root.red)
                            : (lBox6.isActive ? Qt.alpha(root.base, 0.3) : root.surface2)
                        border.width: 1
                        Behavior on border.color { ColorAnimation { duration: 150 } }
                        Behavior on color { ColorAnimation { duration: 220; easing.type: Easing.OutExpo } }

                        RowLayout {
                            anchors.fill: parent; anchors.margins: root.s(10); spacing: root.s(10)
                            Text {
                                text: "󰎆"; font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(16)
                                color: lBox6.isActive ? Qt.alpha(root.base, 0.6) : root.subtext0
                                Behavior on color { ColorAnimation { duration: 220 } }
                            }
                            TextInput {
                                id: lumiSilenceInput
                                Layout.fillWidth: true; Layout.fillHeight: true
                                verticalAlignment: TextInput.AlignVCenter
                                font.family: "JetBrains Mono"; font.pixelSize: root.s(12)
                                color: lBox6.isActive ? root.base : root.text
                                clip: true; selectByMouse: true
                                text: Config.lumiSilenceThreshold
                                onTextChanged: {
                                    Config.lumiSilenceThreshold = text
                                    Config.saveLumiConfig()
                                }
                                Behavior on color { ColorAnimation { duration: 220 } }
                                Text {
                                    text: "e.g. -35dB"
                                    color: lBox6.isActive ? Qt.alpha(root.base, 0.5) : root.subtext0
                                    visible: !parent.text && !parent.activeFocus
                                    font: parent.font; anchors.verticalCenter: parent.verticalCenter
                                    Behavior on color { ColorAnimation { duration: 220 } }
                                }
                            }
                        }
                    }

                    // Status / Error Info Card at the Bottom
                    Rectangle {
                        id: calibStatusBox
                        Layout.fillWidth: true
                        Layout.preferredHeight: lBox6.statusMsg !== "" ? calibStatusLayout.implicitHeight + root.s(16) : 0
                        visible: lBox6.statusMsg !== ""
                        radius: root.s(8)
                        clip: true
                        
                        color: lBox6.statusIsError
                            ? Qt.alpha(root.red, lBox6.isActive ? 0.25 : 0.12)
                            : Qt.alpha(root.green, lBox6.isActive ? 0.25 : 0.12)
                        border.color: lBox6.statusIsError
                            ? (lBox6.isActive ? root.base : root.red)
                            : (lBox6.isActive ? root.base : root.green)
                        border.width: 1

                        Behavior on Layout.preferredHeight { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: 200 } }

                        RowLayout {
                            id: calibStatusLayout
                            anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                            anchors.margins: root.s(10)
                            spacing: root.s(10)

                            Text {
                                text: lBox6.statusIsError ? "󰀦" : "󰄬"
                                font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(16)
                                color: lBox6.statusIsError
                                    ? (lBox6.isActive ? root.base : root.red)
                                    : (lBox6.isActive ? root.base : root.green)
                                Layout.alignment: Qt.AlignTop
                            }
                            Text {
                                text: lBox6.statusMsg
                                font.family: "Inter"
                                font.pixelSize: root.s(11)
                                font.weight: Font.Medium
                                color: lBox6.statusIsError
                                    ? (lBox6.isActive ? root.base : root.red)
                                    : (lBox6.isActive ? root.base : root.text)
                                Layout.fillWidth: true
                                wrapMode: Text.Wrap
                            }
                        }
                    }
                }
            }


            // ── Box 7: Microphone Device ────────────────────────
            Rectangle {
                id: lBox7
                Layout.fillWidth: true
                Layout.preferredHeight: deviceColLayout.implicitHeight + root.s(28)
                radius: root.s(12)

                property bool isActive: root.highlightedBox === 7
                ListModel {
                    id: devicesModel
                    ListElement { text: "System Default"; value: "default" }
                    ListElement { text: "PulseAudio Server"; value: "pulse" }
                    ListElement { text: "PipeWire Server"; value: "pipewire" }
                }
                
                color: isActive ? root.blue : root.surface0
                border.color: isActive ? root.blue : root.surface1
                border.width: 1
                Behavior on color { ColorAnimation { duration: 220; easing.type: Easing.OutExpo } }

                MouseArea { anchors.fill: parent; onClicked: root.highlightedBox = 7; z: -1 }

                Process {
                    id: deviceProc
                    command: ["bash", "-c", "timeout 2 pactl list sources 2>/dev/null | awk -F': ' '/^[[:space:]]*Name:/ {name=$2} /^[[:space:]]*Description:/ {desc=$2; print name \"|\" desc}'"]
                    running: true
                    stdout: SplitParser {
                        onRead: function(line) {
                            var dev = line.trim()
                            if (dev.length > 0) {
                                var parts = dev.split("|")
                                if (parts.length === 2) {
                                    var val = parts[0]
                                    var txt = parts[1]
                                    
                                    var exists = false
                                    for (var i = 0; i < devicesModel.count; i++) {
                                        if (devicesModel.get(i).value === val) {
                                            exists = true; break;
                                        }
                                    }
                                    
                                    if (!exists) {
                                        devicesModel.append({ text: txt, value: val })
                                    }
                                }
                            }
                        }
                    }
                }

                ColumnLayout {
                    id: deviceColLayout
                    anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                    anchors.margins: root.s(16)
                    spacing: root.s(10)

                    RowLayout {
                        Layout.fillWidth: true; spacing: root.s(14)
                        Item {
                            Layout.preferredWidth: root.s(22); Layout.alignment: Qt.AlignVCenter
                            Text {
                                anchors.centerIn: parent; text: "󰍎"
                                font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(18)
                                color: lBox7.isActive ? root.base : root.blue
                                Behavior on color { ColorAnimation { duration: 220; easing.type: Easing.OutExpo } }
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: root.s(3)
                            Text {
                                text: "Microphone Device"
                                font.family: "JetBrains Mono"; font.pixelSize: root.s(13); font.weight: Font.Bold
                                color: lBox7.isActive ? root.base : root.text
                                Behavior on color { ColorAnimation { duration: 220; easing.type: Easing.OutExpo } }
                            }
                            Text {
                                text: "Select the physical microphone for voice capture."
                                font.family: "JetBrains Mono"; font.pixelSize: root.s(11)
                                color: lBox7.isActive ? Qt.alpha(root.base, 0.7) : root.subtext0
                                Behavior on color { ColorAnimation { duration: 220; easing.type: Easing.OutExpo } }
                                Layout.fillWidth: true; wrapMode: Text.Wrap
                            }
                        }
                    }

                    ComboBox {
                        Layout.fillWidth: true
                        Layout.preferredHeight: root.s(38)
                        model: devicesModel
                        textRole: "text"
                        valueRole: "value"
                        font.family: "JetBrains Mono"; font.pixelSize: root.s(12)
                        
                        function getIndex() {
                            for (var i = 0; i < devicesModel.count; i++) {
                                if (devicesModel.get(i).value === Config.lumiMicDevice) return i;
                            }
                            return 0;
                        }
                        currentIndex: getIndex()
                        
                        onActivated: function(index) {
                            Config.lumiMicDevice = devicesModel.get(index).value
                            Config.saveLumiConfig()
                        }
                        
                        background: Rectangle {
                            color: lBox7.isActive ? Qt.alpha(root.base, 0.15) : root.surface1
                            radius: root.s(8)
                        }
                        contentItem: Text {
                            text: parent.displayText
                            font: parent.font
                            color: lBox7.isActive ? root.base : root.text
                            verticalAlignment: Text.AlignVCenter
                            leftPadding: root.s(12)
                        }
                    }
                }
            }
            // ── Box 5: Dynamic Model Routing ─────────────────────────
            Rectangle {
                id: lBox5
                Layout.fillWidth: true
                Layout.preferredHeight: routingColLayout.implicitHeight + root.s(28)
                radius: root.s(12)

                property bool isActive: root.highlightedBox === 5
                color: isActive ? root.peach : root.surface0
                border.color: isActive ? root.peach : root.surface1
                border.width: 1
                Behavior on color { ColorAnimation { duration: 220; easing.type: Easing.OutExpo } }

                MouseArea { anchors.fill: parent; onClicked: root.highlightedBox = 5; z: -1 }

                ColumnLayout {
                    id: routingColLayout
                    anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                    anchors.margins: root.s(16)
                    spacing: root.s(12)

                    // Header
                    RowLayout {
                        Layout.fillWidth: true; spacing: root.s(14)
                        Item {
                            Layout.preferredWidth: root.s(22); Layout.alignment: Qt.AlignVCenter
                            Text {
                                anchors.centerIn: parent; text: "󰕭"
                                font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(18)
                                color: lBox5.isActive ? root.base : root.peach
                                Behavior on color { ColorAnimation { duration: 220; easing.type: Easing.OutExpo } }
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: root.s(3)
                            Text {
                                text: "Dynamic Model Routing"
                                font.family: "Inter"; font.weight: Font.Medium; font.pixelSize: root.s(14)
                                color: lBox5.isActive ? root.base : root.text; Layout.fillWidth: true
                                Behavior on color { ColorAnimation { duration: 220; easing.type: Easing.OutExpo } }
                            }
                            Text {
                                text: "Pakai model kecil untuk chat singkat, otomatis upgrade ke model besar"
                                font.family: "Inter"; font.pixelSize: root.s(11)
                                color: lBox5.isActive ? Qt.alpha(root.base, 0.75) : Qt.alpha(root.subtext0, 0.7)
                                Layout.fillWidth: true; wrapMode: Text.WordWrap
                                Behavior on color { ColorAnimation { duration: 220; easing.type: Easing.OutExpo } }
                            }
                        }
                    }

                    // Status badge — current routing decision indicator
                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: root.s(32); radius: root.s(8)
                        color: lBox5.isActive ? Qt.alpha(root.base, 0.15) : root.surface1
                        Behavior on color { ColorAnimation { duration: 220 } }
                        RowLayout {
                            anchors.fill: parent; anchors.margins: root.s(10); spacing: root.s(8)
                            Text { text: "󰁪"; font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(13); color: lBox5.isActive ? Qt.alpha(root.base, 0.7) : root.peach }
                            Text {
                                text: "Singkat (<" + Config.lumiRoutingThreshold + " char) → " + Config.lumiSmallModel + "  |  Panjang → " + Config.lumiModel
                                font.family: "JetBrains Mono"; font.pixelSize: root.s(10)
                                color: lBox5.isActive ? Qt.alpha(root.base, 0.85) : root.subtext1
                                Layout.fillWidth: true; elide: Text.ElideRight
                                Behavior on color { ColorAnimation { duration: 220 } }
                            }
                        }
                    }

                    // Small Model (Fast)
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: root.s(6)
                        RowLayout {
                            spacing: root.s(6)
                            Text { text: ""; font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(13); color: lBox5.isActive ? Qt.alpha(root.base, 0.8) : root.green }
                            Text { text: "Fast Model"; font.family: "Inter"; font.pixelSize: root.s(12); font.weight: Font.Medium; color: lBox5.isActive ? root.base : root.text }
                            Text { text: "— untuk chat singkat"; font.family: "Inter"; font.pixelSize: root.s(11); color: lBox5.isActive ? Qt.alpha(root.base, 0.6) : Qt.alpha(root.subtext0, 0.7) }
                        }
                        Flow {
                            Layout.fillWidth: true; spacing: root.s(6)
                            Repeater {
                                model: [
                                    { id: "llama-3.1-8b-instant",   label: "Llama 3.1 8B ⚡" },
                                    { id: "gemma2-9b-it",            label: "Gemma2 9B" },
                                    { id: "llama-3.2-3b-preview",   label: "Llama 3.2 3B" }
                                ]
                                Rectangle {
                                    width: smallChipRow.implicitWidth + root.s(20); height: root.s(26); radius: root.s(13)
                                    property bool isSelected: Config.lumiSmallModel === modelData.id
                                    color: isSelected ? (lBox5.isActive ? Qt.alpha(root.base, 0.3) : root.green) : (lBox5.isActive ? Qt.alpha(root.base, 0.1) : "transparent")
                                    border.color: isSelected ? (lBox5.isActive ? Qt.alpha(root.base, 0.7) : root.green) : (lBox5.isActive ? Qt.alpha(root.base, 0.25) : root.surface2)
                                    border.width: 1
                                    scale: smallChipMa.containsMouse ? 1.04 : 1.0
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutBack } }
                                    RowLayout { id: smallChipRow; anchors.centerIn: parent; spacing: root.s(5)
                                        Text { text: modelData.label; font.family: "JetBrains Mono"; font.pixelSize: root.s(10)
                                            color: isSelected ? root.base : (lBox5.isActive ? Qt.alpha(root.base, 0.7) : root.subtext0); Behavior on color { ColorAnimation { duration: 150 } } }
                                    }
                                    MouseArea { id: smallChipMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { Config.lumiSmallModel = modelData.id; Config.saveLumiConfig() } }
                                }
                            }
                        }
                    }

                    // Routing Threshold Slider
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: root.s(6)
                        RowLayout {
                            Layout.fillWidth: true
                            RowLayout {
                                spacing: root.s(6)
                                Text { text: "󰾺"; font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(13); color: lBox5.isActive ? Qt.alpha(root.base, 0.8) : root.subtext0 }
                                Text { text: "Routing Threshold"; font.family: "Inter"; font.pixelSize: root.s(12); font.weight: Font.Medium; color: lBox5.isActive ? root.base : root.text }
                                Text { text: "— batas upgrade model"; font.family: "Inter"; font.pixelSize: root.s(11); color: lBox5.isActive ? Qt.alpha(root.base, 0.6) : Qt.alpha(root.subtext0, 0.7) }
                            }
                            Item { Layout.fillWidth: true }
                            Rectangle {
                                Layout.preferredWidth: root.s(56); Layout.preferredHeight: root.s(22); radius: root.s(6)
                                color: lBox5.isActive ? Qt.alpha(root.base, 0.2) : root.surface1
                                Behavior on color { ColorAnimation { duration: 220 } }
                                Text {
                                    anchors.centerIn: parent
                                    text: Config.lumiRoutingThreshold + " ch"
                                    font.family: "JetBrains Mono"; font.pixelSize: root.s(10)
                                    color: lBox5.isActive ? root.base : root.text
                                    Behavior on color { ColorAnimation { duration: 220 } }
                                }
                            }
                        }
                        Slider {
                            Layout.fillWidth: true
                            from: 500; to: 5000; stepSize: 250
                            value: Config.lumiRoutingThreshold
                            onMoved: { Config.lumiRoutingThreshold = value; Config.saveLumiConfig() }
                            background: Rectangle {
                                x: parent.leftPadding; y: parent.topPadding + parent.availableHeight / 2 - height / 2
                                width: parent.availableWidth; height: root.s(4); radius: root.s(2)
                                color: lBox5.isActive ? Qt.alpha(root.base, 0.25) : root.surface2
                                Rectangle {
                                    width: parent.parent.visualPosition * parent.width; height: parent.height; radius: parent.radius
                                    color: lBox5.isActive ? Qt.alpha(root.base, 0.8) : root.peach
                                }
                            }
                            handle: Rectangle {
                                x: parent.leftPadding + parent.visualPosition * (parent.availableWidth - width)
                                y: parent.topPadding + parent.availableHeight / 2 - height / 2
                                width: root.s(16); height: root.s(16); radius: root.s(8)
                                color: lBox5.isActive ? root.base : root.peach
                                border.color: lBox5.isActive ? Qt.alpha(root.base, 0.5) : Qt.alpha(root.peach, 0.4)
                                border.width: 2
                                Behavior on color { ColorAnimation { duration: 220 } }
                            }
                        }
                        // Visual guide labels
                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: "500  (selalu kecil)"; font.family: "Inter"; font.pixelSize: root.s(9); color: lBox5.isActive ? Qt.alpha(root.base, 0.5) : root.overlay0 }
                            Item { Layout.fillWidth: true }
                            Text { text: "5000  (selalu besar)"; font.family: "Inter"; font.pixelSize: root.s(9); color: lBox5.isActive ? Qt.alpha(root.base, 0.5) : root.overlay0 }
                        }
                    }
                }
            }

            // ── Box 4: Advanced Parameters ───────────────────────────
            Rectangle {
                id: lBox4
                Layout.fillWidth: true
                Layout.preferredHeight: advancedColLayout.implicitHeight + root.s(28)
                radius: root.s(12)

                property bool isActive: root.highlightedBox === 4
                color: isActive ? root.blue : root.surface0
                border.color: isActive ? root.blue : root.surface1
                border.width: 1
                Behavior on color { ColorAnimation { duration: 220; easing.type: Easing.OutExpo } }

                MouseArea { anchors.fill: parent; onClicked: root.highlightedBox = 4; z: -1 }

                ColumnLayout {
                    id: advancedColLayout
                    anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                    anchors.margins: root.s(16)
                    spacing: root.s(14)

                    // Header
                    RowLayout {
                        Layout.fillWidth: true; spacing: root.s(14)
                        Item {
                            Layout.preferredWidth: root.s(22); Layout.alignment: Qt.AlignVCenter
                            Text {
                                anchors.centerIn: parent; text: "󰒓"
                                font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(18)
                                color: lBox4.isActive ? root.base : root.blue
                                Behavior on color { ColorAnimation { duration: 220; easing.type: Easing.OutExpo } }
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: root.s(3)
                            Text {
                                text: "Advanced Parameters"
                                font.family: "Inter"; font.weight: Font.Medium; font.pixelSize: root.s(14)
                                color: lBox4.isActive ? root.base : root.text; Layout.fillWidth: true
                                Behavior on color { ColorAnimation { duration: 220; easing.type: Easing.OutExpo } }
                            }
                            Text {
                                text: "Fine-tune inference behavior and memory"
                                font.family: "Inter"; font.pixelSize: root.s(11)
                                color: lBox4.isActive ? Qt.alpha(root.base, 0.75) : Qt.alpha(root.subtext0, 0.7)
                                Layout.fillWidth: true
                                Behavior on color { ColorAnimation { duration: 220; easing.type: Easing.OutExpo } }
                            }
                        }
                    }

                    // ── Reusable slider row component ─────────────────
                    // Temperature
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: root.s(6)
                        RowLayout {
                            Layout.fillWidth: true
                            RowLayout {
                                spacing: root.s(6)
                                Text { text: "󰔄"; font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(14); color: lBox4.isActive ? Qt.alpha(root.base, 0.8) : root.subtext0; Behavior on color { ColorAnimation { duration: 220 } } }
                                Text { text: "Temperature"; font.family: "Inter"; font.pixelSize: root.s(12); font.weight: Font.Medium; color: lBox4.isActive ? root.base : root.text; Behavior on color { ColorAnimation { duration: 220 } } }
                                Text { text: "— Kreativitas jawaban"; font.family: "Inter"; font.pixelSize: root.s(11); color: lBox4.isActive ? Qt.alpha(root.base, 0.6) : Qt.alpha(root.subtext0, 0.7); Behavior on color { ColorAnimation { duration: 220 } } }
                            }
                            Item { Layout.fillWidth: true }
                            Rectangle {
                                Layout.preferredWidth: root.s(38); Layout.preferredHeight: root.s(22); radius: root.s(6)
                                color: lBox4.isActive ? Qt.alpha(root.base, 0.2) : root.surface1
                                Behavior on color { ColorAnimation { duration: 220 } }
                                Text {
                                    anchors.centerIn: parent
                                    text: Config.lumiTemperature.toFixed(2)
                                    font.family: "JetBrains Mono"; font.pixelSize: root.s(11)
                                    color: lBox4.isActive ? root.base : root.text
                                    Behavior on color { ColorAnimation { duration: 220 } }
                                }
                            }
                        }
                        Slider {
                            Layout.fillWidth: true
                            from: 0.0; to: 1.0; stepSize: 0.01
                            value: Config.lumiTemperature
                            onMoved: { Config.lumiTemperature = value; Config.saveLumiConfig() }
                            background: Rectangle {
                                x: parent.leftPadding; y: parent.topPadding + parent.availableHeight / 2 - height / 2
                                width: parent.availableWidth; height: root.s(4); radius: root.s(2)
                                color: lBox4.isActive ? Qt.alpha(root.base, 0.25) : root.surface2
                                Rectangle {
                                    width: parent.parent.visualPosition * parent.width; height: parent.height; radius: parent.radius
                                    color: lBox4.isActive ? Qt.alpha(root.base, 0.8) : root.blue
                                    Behavior on color { ColorAnimation { duration: 220 } }
                                }
                            }
                            handle: Rectangle {
                                x: parent.leftPadding + parent.visualPosition * (parent.availableWidth - width)
                                y: parent.topPadding + parent.availableHeight / 2 - height / 2
                                width: root.s(16); height: root.s(16); radius: root.s(8)
                                color: lBox4.isActive ? root.base : root.blue
                                border.color: lBox4.isActive ? Qt.alpha(root.base, 0.5) : Qt.alpha(root.blue, 0.4)
                                border.width: 2
                                Behavior on color { ColorAnimation { duration: 220 } }
                            }
                        }
                    }

                    // Top-P
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: root.s(6)
                        RowLayout {
                            Layout.fillWidth: true
                            RowLayout {
                                spacing: root.s(6)
                                Text { text: "󰖟"; font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(14); color: lBox4.isActive ? Qt.alpha(root.base, 0.8) : root.subtext0; Behavior on color { ColorAnimation { duration: 220 } } }
                                Text { text: "Top-P"; font.family: "Inter"; font.pixelSize: root.s(12); font.weight: Font.Medium; color: lBox4.isActive ? root.base : root.text; Behavior on color { ColorAnimation { duration: 220 } } }
                                Text { text: "— Keragaman token"; font.family: "Inter"; font.pixelSize: root.s(11); color: lBox4.isActive ? Qt.alpha(root.base, 0.6) : Qt.alpha(root.subtext0, 0.7); Behavior on color { ColorAnimation { duration: 220 } } }
                            }
                            Item { Layout.fillWidth: true }
                            Rectangle {
                                Layout.preferredWidth: root.s(38); Layout.preferredHeight: root.s(22); radius: root.s(6)
                                color: lBox4.isActive ? Qt.alpha(root.base, 0.2) : root.surface1
                                Behavior on color { ColorAnimation { duration: 220 } }
                                Text {
                                    anchors.centerIn: parent
                                    text: Config.lumiTopP.toFixed(2)
                                    font.family: "JetBrains Mono"; font.pixelSize: root.s(11)
                                    color: lBox4.isActive ? root.base : root.text
                                    Behavior on color { ColorAnimation { duration: 220 } }
                                }
                            }
                        }
                        Slider {
                            Layout.fillWidth: true
                            from: 0.0; to: 1.0; stepSize: 0.01
                            value: Config.lumiTopP
                            onMoved: { Config.lumiTopP = value; Config.saveLumiConfig() }
                            background: Rectangle {
                                x: parent.leftPadding; y: parent.topPadding + parent.availableHeight / 2 - height / 2
                                width: parent.availableWidth; height: root.s(4); radius: root.s(2)
                                color: lBox4.isActive ? Qt.alpha(root.base, 0.25) : root.surface2
                                Rectangle {
                                    width: parent.parent.visualPosition * parent.width; height: parent.height; radius: parent.radius
                                    color: lBox4.isActive ? Qt.alpha(root.base, 0.8) : root.blue
                                    Behavior on color { ColorAnimation { duration: 220 } }
                                }
                            }
                            handle: Rectangle {
                                x: parent.leftPadding + parent.visualPosition * (parent.availableWidth - width)
                                y: parent.topPadding + parent.availableHeight / 2 - height / 2
                                width: root.s(16); height: root.s(16); radius: root.s(8)
                                color: lBox4.isActive ? root.base : root.blue
                                border.color: lBox4.isActive ? Qt.alpha(root.base, 0.5) : Qt.alpha(root.blue, 0.4)
                                border.width: 2
                                Behavior on color { ColorAnimation { duration: 220 } }
                            }
                        }
                    }

                    // Max Tokens
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: root.s(6)
                        RowLayout {
                            Layout.fillWidth: true
                            RowLayout {
                                spacing: root.s(6)
                                Text { text: "󰊹"; font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(14); color: lBox4.isActive ? Qt.alpha(root.base, 0.8) : root.subtext0; Behavior on color { ColorAnimation { duration: 220 } } }
                                Text { text: "Max Tokens"; font.family: "Inter"; font.pixelSize: root.s(12); font.weight: Font.Medium; color: lBox4.isActive ? root.base : root.text; Behavior on color { ColorAnimation { duration: 220 } } }
                                Text { text: "— Panjang respons maks"; font.family: "Inter"; font.pixelSize: root.s(11); color: lBox4.isActive ? Qt.alpha(root.base, 0.6) : Qt.alpha(root.subtext0, 0.7); Behavior on color { ColorAnimation { duration: 220 } } }
                            }
                            Item { Layout.fillWidth: true }
                            Rectangle {
                                Layout.preferredWidth: root.s(48); Layout.preferredHeight: root.s(22); radius: root.s(6)
                                color: lBox4.isActive ? Qt.alpha(root.base, 0.2) : root.surface1
                                Behavior on color { ColorAnimation { duration: 220 } }
                                Text {
                                    anchors.centerIn: parent
                                    text: Config.lumiMaxTokens
                                    font.family: "JetBrains Mono"; font.pixelSize: root.s(11)
                                    color: lBox4.isActive ? root.base : root.text
                                    Behavior on color { ColorAnimation { duration: 220 } }
                                }
                            }
                        }
                        Slider {
                            Layout.fillWidth: true
                            from: 256; to: 4096; stepSize: 64
                            value: Config.lumiMaxTokens
                            onMoved: { Config.lumiMaxTokens = value; Config.saveLumiConfig() }
                            background: Rectangle {
                                x: parent.leftPadding; y: parent.topPadding + parent.availableHeight / 2 - height / 2
                                width: parent.availableWidth; height: root.s(4); radius: root.s(2)
                                color: lBox4.isActive ? Qt.alpha(root.base, 0.25) : root.surface2
                                Rectangle {
                                    width: parent.parent.visualPosition * parent.width; height: parent.height; radius: parent.radius
                                    color: lBox4.isActive ? Qt.alpha(root.base, 0.8) : root.blue
                                    Behavior on color { ColorAnimation { duration: 220 } }
                                }
                            }
                            handle: Rectangle {
                                x: parent.leftPadding + parent.visualPosition * (parent.availableWidth - width)
                                y: parent.topPadding + parent.availableHeight / 2 - height / 2
                                width: root.s(16); height: root.s(16); radius: root.s(8)
                                color: lBox4.isActive ? root.base : root.blue
                                border.color: lBox4.isActive ? Qt.alpha(root.base, 0.5) : Qt.alpha(root.blue, 0.4)
                                border.width: 2
                                Behavior on color { ColorAnimation { duration: 220 } }
                            }
                        }
                    }

                    // Context Threshold
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: root.s(6)
                        RowLayout {
                            Layout.fillWidth: true
                            RowLayout {
                                spacing: root.s(6)
                                Text { text: "󰍉"; font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(14); color: lBox4.isActive ? Qt.alpha(root.base, 0.8) : root.subtext0; Behavior on color { ColorAnimation { duration: 220 } } }
                                Text { text: "Context Memory"; font.family: "Inter"; font.pixelSize: root.s(12); font.weight: Font.Medium; color: lBox4.isActive ? root.base : root.text; Behavior on color { ColorAnimation { duration: 220 } } }
                                Text { text: "— Batas memori sebelum diringkas"; font.family: "Inter"; font.pixelSize: root.s(11); color: lBox4.isActive ? Qt.alpha(root.base, 0.6) : Qt.alpha(root.subtext0, 0.7); Behavior on color { ColorAnimation { duration: 220 } } }
                            }

                            Item { Layout.fillWidth: true }
                            Rectangle {
                                Layout.preferredWidth: root.s(52); Layout.preferredHeight: root.s(22); radius: root.s(6)
                                color: lBox4.isActive ? Qt.alpha(root.base, 0.2) : root.surface1
                                Behavior on color { ColorAnimation { duration: 220 } }
                                Text {
                                    anchors.centerIn: parent
                                    text: Config.lumiContextThreshold + " tk"
                                    font.family: "JetBrains Mono"; font.pixelSize: root.s(10)
                                    color: lBox4.isActive ? root.base : root.text
                                    Behavior on color { ColorAnimation { duration: 220 } }
                                }
                            }
                        }
                        Slider {
                            Layout.fillWidth: true
                            from: 1000; to: 8000; stepSize: 500
                            value: Config.lumiContextThreshold
                            onMoved: { Config.lumiContextThreshold = value; Config.saveLumiConfig() }
                            background: Rectangle {
                                x: parent.leftPadding; y: parent.topPadding + parent.availableHeight / 2 - height / 2
                                width: parent.availableWidth; height: root.s(4); radius: root.s(2)
                                color: lBox4.isActive ? Qt.alpha(root.base, 0.25) : root.surface2
                                Rectangle {
                                    width: parent.parent.visualPosition * parent.width; height: parent.height; radius: parent.radius
                                    color: lBox4.isActive ? Qt.alpha(root.base, 0.8) : root.blue
                                    Behavior on color { ColorAnimation { duration: 220 } }
                                }
                            }
                            handle: Rectangle {
                                x: parent.leftPadding + parent.visualPosition * (parent.availableWidth - width)
                                y: parent.topPadding + parent.availableHeight / 2 - height / 2
                                width: root.s(16); height: root.s(16); radius: root.s(8)
                                color: lBox4.isActive ? root.base : root.blue
                                border.color: lBox4.isActive ? Qt.alpha(root.base, 0.5) : Qt.alpha(root.blue, 0.4)
                                border.width: 2
                                Behavior on color { ColorAnimation { duration: 220 } }
                            }
                        }
                    }
                }
            }
        }
    }
}
