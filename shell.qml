import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

ShellRoot {
    id: root

    property color colBg: "#1a1b26"
    property color colBgAlt: "#24283b"
    property color colFg: "#a9b1d6"
    property color colMuted: "#444b6a"
    property color colCyan: "#7aa2f7"
    property color colPurple: "#bb9af7"
    property color colRed: "#f7768e"
    property color colYellow: "#e0af68"
    property color colBlue: "#7dcfff"
    property color colGreen: "#9ece6a"

    property string fontFamily: "JetBrainsMono Nerd Font"
    property int fontSize: 13

    property int cpuUsage: 0
    property int memUsage: 0
    property int volumeLevel: 0

    property var lastCpuIdle: 0
    property var lastCpuTotal: 0

    property bool volumeMenuVisible: false

    Process {
        id: cpuProc
        command: ["sh", "-c", "head -1 /proc/stat"]
        stdout: SplitParser {
            onRead: data => {
                if (!data) return
                var parts = data.trim().split(/\s+/)
                var user = parseInt(parts[1]) || 0
                var nice = parseInt(parts[2]) || 0
                var system = parseInt(parts[3]) || 0
                var idle = parseInt(parts[4]) || 0
                var iowait = parseInt(parts[5]) || 0
                var irq = parseInt(parts[6]) || 0
                var softirq = parseInt(parts[7]) || 0

                var total = user + nice + system + idle + iowait + irq + softirq
                var idleTime = idle + iowait

                if (lastCpuTotal > 0) {
                    var totalDiff = total - lastCpuTotal
                    var idleDiff = idleTime - lastCpuIdle
                    if (totalDiff > 0) {
                        cpuUsage = Math.round(100 * (totalDiff - idleDiff) / totalDiff)
                    }
                }
                lastCpuTotal = total
                lastCpuIdle = idleTime
            }
        }
        Component.onCompleted: running = true
    }

    Process {
        id: memProc
        command: ["sh", "-c", "free | grep Mem"]
        stdout: SplitParser {
            onRead: data => {
                if (!data) return
                var parts = data.trim().split(/\s+/)
                var total = parseInt(parts[1]) || 1
                var used = parseInt(parts[2]) || 0
                memUsage = Math.round(100 * used / total)
            }
        }
        Component.onCompleted: running = true
    }

    Process {
        id: volProc
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        stdout: SplitParser {
            onRead: data => {
                if (!data) return
                var match = data.match(/Volume:\s*([\d.]+)/)
                if (match && match[1]) {
                    volumeLevel = Math.round(parseFloat(match[1]) * 100)
                }
            }
        }
        Component.onCompleted: running = true
    }

    Process {
        id: setVolProc
        command: []
        running: false
        onRunningChanged: {
            if (!running) volProc.running = true
        }
    }

    function setVolume(value) {
        var volumeFloat = (value / 100).toFixed(2)
        setVolProc.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", volumeFloat]
        setVolProc.running = true
        volumeLevel = value
    }

    function toggleMute() {
        setVolProc.command = ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]
        setVolProc.running = true
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            cpuProc.running = true
            memProc.running = true
            volProc.running = true
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: barWindow
            property var modelData
            screen: modelData

            anchors {
                top: true
                left: true
                right: true
            }

            implicitHeight: 32
            color: root.colBg
            exclusionMode: Quickshell.ExclusionMode.Exclusive

            Rectangle {
                anchors.fill: parent
                color: root.colBg

                RowLayout {
                    anchors.fill: parent
                    spacing: 0

                    Item { width: 8 }

                    Rectangle {
                        Layout.preferredWidth: 22
                        Layout.preferredHeight: 22
                        color: "transparent"
                        Layout.alignment: Qt.AlignVCenter

                        Image {
                            anchors.fill: parent
                            source: "file:///home/tony/.config/quickshell/icons/tonybtw.png"
                            fillMode: Image.PreserveAspectFit
                        }
                    }

                    Item { width: 12 }

                    Repeater {
                        model: 9

                        Rectangle {
                            Layout.preferredWidth: 26
                            Layout.preferredHeight: parent.height
                            color: "transparent"

                            property var workspace: Hyprland.workspaces.values.find(ws => ws.id === index + 1) ?? null
                            property bool isActive: Hyprland.focusedWorkspace?.id === (index + 1)
                            property bool hasWindows: workspace !== null

                            Text {
                                text: index + 1
                                color: parent.isActive ? root.colPurple : (parent.hasWindows ? root.colFg : root.colMuted)
                                font.pixelSize: root.fontSize
                                font.family: root.fontFamily
                                font.bold: parent.isActive
                                anchors.centerIn: parent
                            }

                            Rectangle {
                                width: 16
                                height: 3
                                color: parent.isActive ? root.colPurple : "transparent"
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: Hyprland.dispatch("workspace " + (index + 1))
                            }
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 1
                        Layout.preferredHeight: 14
                        Layout.alignment: Qt.AlignVCenter
                        Layout.leftMargin: 6
                        Layout.rightMargin: 12
                        color: root.colMuted
                    }

                    Text {
                        text: "Excalibur"
                        color: root.colBlue
                        font.pixelSize: root.fontSize
                        font.family: root.fontFamily
                        font.bold: true
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    Text {
                        text: "  " + cpuUsage + "%"
                        color: root.colYellow
                        font.pixelSize: root.fontSize
                        font.family: root.fontFamily
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Rectangle {
                        Layout.preferredWidth: 1
                        Layout.preferredHeight: 14
                        Layout.alignment: Qt.AlignVCenter
                        Layout.leftMargin: 10
                        Layout.rightMargin: 10
                        color: root.colMuted
                    }

                    Text {
                        text: "  " + memUsage + "%"
                        color: root.colGreen
                        font.pixelSize: root.fontSize
                        font.family: root.fontFamily
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Rectangle {
                        Layout.preferredWidth: 1
                        Layout.preferredHeight: 14
                        Layout.alignment: Qt.AlignVCenter
                        Layout.leftMargin: 10
                        Layout.rightMargin: 10
                        color: root.colMuted
                    }

                    Item {
                        id: volumeButton
                        Layout.preferredWidth: volText.implicitWidth + 10
                        Layout.preferredHeight: parent.height
                        Layout.alignment: Qt.AlignVCenter

                        Text {
                            id: volText
                            text: "󰕾 " + volumeLevel + "%"
                            color: root.colRed
                            font.pixelSize: root.fontSize
                            font.family: root.fontFamily
                            anchors.centerIn: parent
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.volumeMenuVisible = !root.volumeMenuVisible
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 1
                        Layout.preferredHeight: 14
                        Layout.alignment: Qt.AlignVCenter
                        Layout.leftMargin: 10
                        Layout.rightMargin: 10
                        color: root.colMuted
                    }

                    Text {
                        id: clockText
                        text: "  " + Qt.formatDateTime(new Date(), "ddd, MMM dd - HH:mm")
                        color: root.colCyan
                        font.pixelSize: root.fontSize
                        font.family: root.fontFamily
                        font.bold: true
                        Layout.alignment: Qt.AlignVCenter
                        Layout.rightMargin: 12

                        Timer {
                            interval: 1000
                            running: true
                            repeat: true
                            onTriggered: clockText.text = "  " + Qt.formatDateTime(new Date(), "ddd, MMM dd - HH:mm")
                        }
                    }
                }
            }

            PopupWindow {
                id: volumeMenu
                visible: root.volumeMenuVisible
                parentWindow: barWindow
                
                anchor.edges: Quickshell.RectangleAnchor.Top | Quickshell.RectangleAnchor.Left

                width: barWindow.width
                height: 140
                color: "transparent"

                Rectangle {
                    width: 220
                    height: 100
                    
                    x: parent.width - 235
                    y: 24 

                    color: root.colBg
                    radius: 0 

                    // DEĞİŞİKLİK: Tüm kenarlık çizgileri (border Rectangle bileşenleri) tamamen kaldırıldı.

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 10

                        RowLayout {
                            Layout.fillWidth: true
                            
                            Text {
                                text: "Ses Kontrolü"
                                color: root.colFg
                                font.family: root.fontFamily
                                font.pixelSize: root.fontSize
                                font.bold: true
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: "󰝟"
                                color: root.colRed
                                font.family: root.fontFamily
                                font.pixelSize: root.fontSize + 2
                                
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.toggleMute()
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 20
                            color: root.colBgAlt
                            radius: 0 

                            Rectangle {
                                width: (parent.width * root.volumeLevel) / 100
                                height: parent.height
                                color: root.colPurple
                                radius: 0 
                            }

                            Text {
                                text: root.volumeLevel + "%"
                                color: root.colFg
                                font.family: root.fontFamily
                                font.pixelSize: root.fontSize - 2
                                anchors.centerIn: parent
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                
                                function updateVolume(mouse) {
                                    var percentage = Math.max(0, Math.min(100, Math.round((mouse.x / width) * 100)))
                                    root.setVolume(percentage)
                                }

                                onClicked: mouse => updateVolume(mouse)
                                onPositionChanged: mouse => updateVolume(mouse)
                            }
                        }
                    }
                }
            }
        }
    }
}