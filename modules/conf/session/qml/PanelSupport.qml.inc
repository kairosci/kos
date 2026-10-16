  property var shell: null
  property var manifest: null
  ControlContext { id: sessionContext; shell: root.shell; owner: root }
  bar: sessionContext
  function status() { return JSON.stringify({ready: true, opened: root.opened, id: root.manifest ? root.manifest.id : ""}) }
  function reloadSessionSettings() {
    if (!root.manifest) return
    var text = sessionConfig.text()
    if (!text.trim()) return
    var config = JSON.parse(text)
    var entries = config.plugins || []
    root.settings = entries.filter(function(entry) { return entry.id === root.manifest.id })[0] || ({})
  }
  onManifestChanged: reloadSessionSettings()
  FileView {
    id: sessionConfig
    path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/omarchy/shell.json"
    watchChanges: true
    onLoaded: root.reloadSessionSettings()
    onFileChanged: reload()
  }
