  property var observedPowered: null
  readonly property bool adapterPowered: observedPowered === null
    ? !!adapter && adapter.enabled : observedPowered

  onAdapterChanged: observedPowered = null

  Process {
    id: powerProbe
    property string queriedPath: ""
    command: ["busctl", "--system", "--timeout=2", "get-property",
      "org.bluez", queriedPath, "org.bluez.Adapter1", "Powered"]
    stdout: StdioCollector {
      onStreamFinished: {
        if (root.adapter && powerProbe.queriedPath === root.adapter.dbusPath) {
          const value = text.trim()
          root.observedPowered = value === "b true" ? true
            : value === "b false" ? false : null
        }
      }
    }
    onExited: (exitCode, exitStatus) => {
      if (exitCode !== 0 || exitStatus !== 0) root.observedPowered = null
    }
  }

  Timer {
    interval: 2000
    running: root.adapter !== null
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      if (!powerProbe.running && root.adapter) {
        powerProbe.queriedPath = root.adapter.dbusPath
        powerProbe.running = true
      }
    }
  }
