import QtQuick
import qs.Ui

BarWidget {
  id: root
  moduleName: "kos.menu"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "\ue900"
    fontFamily: "kos"
    horizontalMargin: 7.5
    onPressed: function(button) {
      if (!root.bar) return
      if (button === Qt.RightButton) root.bar.run("xdg-terminal-exec")
      else root.bar.run("kos-shell shell toggle kos.menu '{\"menu\":\"root\"}'")
    }
  }
}
