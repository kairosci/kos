import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Commons
import qs.Ui

PanelWindow {
  id: root
  required property Item anchorItem
  required property QtObject bar
  property var owner: null
  property int margin: Style.gapsOut
  property int padding: Style.spacing.popupPadding
  property int contentWidth: Style.space(280)
  property int contentHeight: Style.space(200)
  property color borderColor: Color.popups.border
  property var borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border, Math.max(1, Style.space(2)))
  property bool open: false
  property bool centerOnBar: false
  property string triggerMode: "click"
  property Item focusTarget: null
  property bool popoutSwitching: false
  property bool popoutSwitchClosing: false
  property int gap: Style.gapsOut
  readonly property bool containsMouse: hover.hovered
  readonly property real availableCardWidth: screen ? screen.width - margin * 2 : 1
  readonly property real availableCardHeight: screen ? screen.height - margin * 2 : 1
  readonly property real verticalContentInset: padding * 2 + Border.top(borderSpec) + Border.bottom(borderSpec)
  default property alias contentItem: content.children
  function fittedContentWidth(width, cap) { return Math.min(width, cap || availableCardWidth, availableCardWidth) }
  function fittedContentHeight(height, cap) { return Math.min(height + verticalContentInset, cap || availableCardHeight, availableCardHeight) }
  function cappedContentHeight(height) { return Math.min(height, availableCardHeight) }
  function close() { if (owner && typeof owner.close === "function") owner.close(); else open = false }
  visible: open
  screen: {
    var focused = Hyprland.focusedMonitor
    for (var i = 0; i < Quickshell.screens.length; i++) {
      if (focused && Quickshell.screens[i].name === focused.name) return Quickshell.screens[i]
    }
    return Quickshell.screens[0] || null
  }
  color: "transparent"
  implicitWidth: Math.min(contentWidth, availableCardWidth)
  implicitHeight: Math.min(contentHeight, availableCardHeight)
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.namespace: "os-control"
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
  onOpenChanged: if (open) Qt.callLater(function() { if (root.focusTarget) root.focusTarget.forceActiveFocus() })
  HyprlandFocusGrab {
    active: root.open && root.triggerMode === "click"
    windows: [root]
    onCleared: root.close()
  }
  BorderSurface {
    anchors.fill: parent
    color: Color.popups.background
    borderSpec: root.borderSpec
    padding: root.padding
    radius: Style.cornerRadius
    Item { id: content; anchors.fill: parent }
    HoverHandler { id: hover }
    Keys.onEscapePressed: root.close()
    focus: true
  }
}
