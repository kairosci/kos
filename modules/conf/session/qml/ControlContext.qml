import QtQuick
import Quickshell
import qs.Commons

QtObject {
  property var shell: null
  property var owner: null
  readonly property color foreground: Color.foreground
  readonly property color barForeground: Color.foreground
  readonly property color background: Color.background
  readonly property color urgent: Color.urgent
  readonly property int iconSlot: Style.bar.iconSlot
  readonly property string fontFamily: Style.font.family
  readonly property string position: "top"
  readonly property bool vertical: false
  readonly property int barSize: 0
  readonly property bool foregroundAnimationEnabled: true
  readonly property bool transparent: false
  readonly property bool barHidden: true
  property var activePopout: null
  property bool centerHoverRevealSuppressed: false
  function requestPopout(owner) {
    if (activePopout && activePopout !== owner && typeof activePopout.close === "function") activePopout.close()
    activePopout = owner
  }
  function releasePopout(owner) { if (activePopout === owner) activePopout = null }
  function showTooltip(target, text) {}
  function hideTooltip(target) {}
  function registerClickTarget(target) {}
  function unregisterClickTarget(target) {}
  function moduleWidgets(id) { return owner ? [owner] : [] }
  function run(command) { Quickshell.execDetached(["bash", "-lc", command]) }
  function switchPanelFrom(owner, direction) { return false }
  function setCenterHoverRevealSuppressed(value) { centerHoverRevealSuppressed = value }
}
