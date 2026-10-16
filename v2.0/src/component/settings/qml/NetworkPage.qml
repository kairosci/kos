import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Networking

Pane {
    id: root
    property var app
    padding: app ? app.snapshot.policy.window.margin : 0
    ColumnLayout {
        width: parent.width
        Label { text: root.app ? root.app.text("network") : ""; font.bold: true; font.pointSize: root.app ? root.app.snapshot.policy.window.titleSize : font.pointSize }
        Switch { text: root.app ? root.app.text("wifi") : ""; checked: Networking.wifiEnabled; enabled: Networking.wifiHardwareEnabled; onClicked: Networking.wifiEnabled = checked }
        Label { visible: Networking.devices.values.length === 0; text: root.app ? root.app.text("empty") : "" }
        Repeater {
            model: Networking.devices
            ColumnLayout {
                id: deviceRow
                required property var modelData
                Layout.fillWidth: true
                Binding {
                    target: deviceRow.modelData
                    property: "scannerEnabled"
                    value: true
                    when: deviceRow.modelData.type === DeviceType.Wifi
                    restoreMode: Binding.RestoreBindingOrValue
                }
                Label { text: deviceRow.modelData.name; font.bold: true }
                Repeater {
                    model: deviceRow.modelData.networks
                    RowLayout {
                        id: networkRow
                        required property var modelData
                        Layout.fillWidth: true
                        Label { Layout.fillWidth: true; text: networkRow.modelData.name; elide: Text.ElideRight }
                        Label { text: networkRow.modelData.connected && root.app ? root.app.text("connected") : "" }
                        BusyIndicator { running: networkRow.modelData.stateChanging; visible: running }
                        Button {
                            text: root.app ? root.app.text(networkRow.modelData.connected ? "disconnect" : "connect") : ""
                            enabled: !networkRow.modelData.stateChanging
                            onClicked: networkRow.modelData.connected ? networkRow.modelData.disconnect() : networkRow.modelData.connect()
                        }
                        Button { visible: networkRow.modelData.known; text: root.app ? root.app.text("forget") : ""; onClicked: { forgetDialog.network = networkRow.modelData; forgetDialog.open() } }
                        Connections {
                            target: networkRow.modelData
                            function onConnectionFailed(reason) {
                                if (reason === ConnectionFailReason.NoSecrets && [WifiSecurityType.WpaPsk, WifiSecurityType.Wpa2Psk, WifiSecurityType.Sae].includes(networkRow.modelData.security)) {
                                    if (passwordDialog.visible || forgetDialog.visible) {
                                        root.app.failure = root.app.text("connectionFailed") + ": " + networkRow.modelData.name
                                        return
                                    }
                                    passwordDialog.network = networkRow.modelData
                                    passwordDialog.open()
                                } else if (root.app) root.app.failure = root.app.text("connectionFailed") + ": " + ConnectionFailReason.toString(reason)
                            }
                        }
                    }
                }
            }
        }
    }
    Dialog {
        id: passwordDialog
        property var network: null
        parent: Overlay.overlay
        anchors.centerIn: parent
        modal: true
        title: root.app ? root.app.text("password") + ": " + (network ? network.name : "") : ""
        footer: DialogButtonBox {
            Button { text: root.app ? root.app.text("connect") : ""; DialogButtonBox.buttonRole: DialogButtonBox.AcceptRole }
            Button { text: root.app ? root.app.text("cancel") : ""; DialogButtonBox.buttonRole: DialogButtonBox.RejectRole }
        }
        TextField { id: password; echoMode: TextInput.Password; selectByMouse: true; onAccepted: passwordDialog.accept() }
        onOpened: password.forceActiveFocus()
        onAccepted: { if (network) network.connectWithPsk(password.text); password.clear() }
        onRejected: password.clear()
        onClosed: password.clear()
    }
    Dialog {
        id: forgetDialog
        property var network: null
        parent: Overlay.overlay
        anchors.centerIn: parent
        modal: true
        title: root.app ? root.app.text("forget") : ""
        footer: DialogButtonBox {
            Button { text: root.app ? root.app.text("forget") : ""; DialogButtonBox.buttonRole: DialogButtonBox.AcceptRole }
            Button { text: root.app ? root.app.text("cancel") : ""; DialogButtonBox.buttonRole: DialogButtonBox.RejectRole }
        }
        Label { text: forgetDialog.network ? forgetDialog.network.name : "" }
        onAccepted: { if (network) network.forget() }
    }
}
