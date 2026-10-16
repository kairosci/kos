import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Bluetooth

Pane {
    id: root
    property var app
    property var scanAdapters: []
    padding: app ? app.snapshot.policy.window.margin : 0
    Component.onDestruction: { for (const adapter of scanAdapters) adapter.discovering = false }
    ColumnLayout {
        width: parent.width
        Label { text: root.app ? root.app.text("bluetooth") : ""; font.bold: true; font.pointSize: root.app ? root.app.snapshot.policy.window.titleSize : font.pointSize }
        Label { visible: Bluetooth.adapters.values.length === 0; text: root.app ? root.app.text("empty") : "" }
        Repeater {
            model: Bluetooth.adapters
            ColumnLayout {
                id: adapterRow
                required property var modelData
                Layout.fillWidth: true
                Switch { text: adapterRow.modelData.name; checked: adapterRow.modelData.enabled; onClicked: adapterRow.modelData.enabled = checked }
                Switch {
                    text: root.app ? root.app.text("scan") : ""
                    enabled: adapterRow.modelData.enabled
                    checked: adapterRow.modelData.discovering
                    onClicked: { adapterRow.modelData.discovering = checked; if (checked && !root.scanAdapters.includes(adapterRow.modelData)) root.scanAdapters = root.scanAdapters.concat([adapterRow.modelData]) }
                }
                Repeater {
                    model: adapterRow.modelData.devices
                    ColumnLayout {
                        id: deviceRow
                        required property var modelData
                        Layout.fillWidth: true
                        RowLayout {
                            Layout.fillWidth: true
                            Label { Layout.fillWidth: true; text: deviceRow.modelData.name || deviceRow.modelData.address; elide: Text.ElideRight }
                            BusyIndicator { visible: deviceRow.modelData.pairing; running: visible }
                            Button {
                                text: root.app ? root.app.text(deviceRow.modelData.paired ? (deviceRow.modelData.connected ? "disconnect" : "connect") : "pair") : ""
                                enabled: !deviceRow.modelData.pairing
                                onClicked: {
                                    if (!deviceRow.modelData.paired) deviceRow.modelData.pair()
                                    else if (deviceRow.modelData.connected) deviceRow.modelData.disconnect()
                                    else deviceRow.modelData.connect()
                                }
                            }
                        }
                        Switch { visible: deviceRow.modelData.paired; text: root.app ? root.app.text("trust") : ""; checked: deviceRow.modelData.trusted; onClicked: deviceRow.modelData.trusted = checked }
                    }
                }
            }
        }
    }
}
