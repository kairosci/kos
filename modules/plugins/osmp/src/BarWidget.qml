import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.Ui as Ui
import qs.Commons
import "MediaModel.js" as MediaLibrary

Ui.BarWidget {
  id: root
  moduleName: "os.osmp"

  readonly property var players: Mpris.players ? Mpris.players.values : []

  property var lastActiveAt: ({})
  property int serial: 0
  property string preferredPlayerKey: ""

  function selectPlayer(key) {
    preferredPlayerKey = key
    var p = activePlayer
    if (p) touch(p)
  }

  function touch(p) {
    var key = MediaLibrary.MediaModel.keyFor(p)
    if (!key) return
    serial += 1
    var next = {}
    for (var k in lastActiveAt) next[k] = lastActiveAt[k]
    next[key] = serial
    lastActiveAt = next
  }

  readonly property var activePlayer: MediaLibrary.MediaModel.selectActivePlayer(players, lastActiveAt, preferredPlayerKey)
  readonly property var sourcePlayers: MediaLibrary.MediaModel.filterSourcePlayers(players)
  readonly property bool hasMedia: MediaLibrary.MediaModel.hasMetadata(activePlayer)
  readonly property bool isPlaying: !!(activePlayer && activePlayer.isPlaying)
  readonly property string artUrl: activePlayer && activePlayer.trackArtUrl ? activePlayer.trackArtUrl : ""
  readonly property string title: activePlayer ? MediaLibrary.MediaModel.cleanTitle(activePlayer.trackTitle || "") : ""
  readonly property string artist: activePlayer ? MediaLibrary.MediaModel.normalizeArtist(activePlayer.trackArtist) : ""
  readonly property string album: activePlayer && activePlayer.trackAlbum ? String(activePlayer.trackAlbum).replace(/\s+/g, " ").trim() : ""
  readonly property string trackId: activePlayer && activePlayer.trackId ? String(activePlayer.trackId) : ""
  readonly property string identity: activePlayer ? (activePlayer.identity || activePlayer.desktopEntry || "") : ""
  readonly property string desktopEntry: activePlayer ? (activePlayer.desktopEntry || "") : ""

  property real trackPosition: activePlayer ? (activePlayer.position || 0) : 0
  property real trackLength: activePlayer && activePlayer.length > 0 ? activePlayer.length : 0
  property bool isSeeking: false
  readonly property bool canSeek: !!(activePlayer && activePlayer.canSeek && trackLength > 0)

  property var nativeQueue: []
  property var upcomingQueue: []
  readonly property bool hasNativeQueue: nativeQueue.length > 0
  readonly property bool hasUpcomingQueue: upcomingQueue.length > 0
  property string queueBusName: ""

  function updateUpcomingQueue() {
    upcomingQueue = MediaLibrary.MediaModel.extractUpcomingTracks(root.nativeQueue, root.trackId, root.title)
  }

  Timer {
    id: trackListDebounce
    interval: 300
    repeat: false
    onTriggered: root.queryTrackList()
  }

  function scheduleTrackListQuery() {
    trackListDebounce.restart()
  }

  function queryTrackList() {
    if (!root.activePlayer || !root.activePlayer.dbusName) {
      nativeQueue = []
      upcomingQueue = []
      return
    }
    trackListProc.command = [
      "busctl", "--user", "--json=short", "get-property",
      root.activePlayer.dbusName,
      "/org/mpris/MediaPlayer2",
      "org.mpris.MediaPlayer2",
      "HasTrackList"
    ]
    trackListProc.running = false
    trackListProc.running = true
  }

  function goToTrack(trackId) {
    if (root.activePlayer && root.activePlayer.dbusName && trackId && String(trackId).startsWith("/")) {
      goToProc.command = [
        "busctl", "--user", "call",
        root.activePlayer.dbusName,
        "/org/mpris/MediaPlayer2",
        "org.mpris.MediaPlayer2.TrackList",
        "GoTo", "o", String(trackId)
      ]
      goToProc.running = false
      goToProc.running = true
    }
  }

  property var trackHistory: []

  function updateHistory() {
    if (!root.hasMedia || !root.title) return
    var item = {
      title: root.title,
      artist: root.artist,
      album: root.album,
      artUrl: root.artUrl,
      length: root.trackLength,
      playerKey: MediaLibrary.MediaModel.keyFor(root.activePlayer),
      isPlaying: root.isPlaying
    }
    trackHistory = MediaLibrary.MediaModel.updateTrackHistory(root.trackHistory, item, 25)
  }

  onNativeQueueChanged: updateUpcomingQueue()
  onTitleChanged: {
    updateHistory()
    scheduleTrackListQuery()
    updateUpcomingQueue()
  }
  onTrackIdChanged: {
    scheduleTrackListQuery()
    updateUpcomingQueue()
  }
  onArtistChanged: updateHistory()
  onIsPlayingChanged: updateHistory()
  onActivePlayerChanged: {
    trackListProc.running = false
    fetchTracksProc.running = false
    getMetadataProc.running = false
    nativeQueue = []
    queueBusName = ""
    trackPosition = activePlayer ? (activePlayer.position || 0) : 0
    trackLength = activePlayer && activePlayer.length > 0 ? activePlayer.length : 0
    updateHistory()
    scheduleTrackListQuery()
    updateUpcomingQueue()
  }

  function clearHistory() {
    trackHistory = []
  }

  Process {
    id: goToProc
  }

  Process {
    id: trackListProc
    stdout: SplitParser {
      onRead: function(line) {
        var str = String(line).trim()
        if (!str) return
        try {
          var parsed = JSON.parse(str)
          if (parsed && parsed.data === true && root.activePlayer && root.activePlayer.dbusName) {
            fetchTracksProc.command = [
              "busctl", "--user", "--json=short", "get-property",
              root.activePlayer.dbusName,
              "/org/mpris/MediaPlayer2",
              "org.mpris.MediaPlayer2.TrackList",
              "Tracks"
            ]
            root.queueBusName = root.activePlayer.dbusName
            fetchTracksProc.running = false
            fetchTracksProc.running = true
            return
          }
        } catch (e) {
          console.warn("OSMP: invalid HasTrackList response", e)
        }
        root.nativeQueue = []

      }
    }
  }

  Process {
    id: fetchTracksProc
    stdout: SplitParser {
      onRead: function(line) {
        var str = String(line).trim()
        if (!str || !root.activePlayer || !root.activePlayer.dbusName) return
        var paths = []
        try {
          var parsed = JSON.parse(str)
          if (parsed && Array.isArray(parsed.data)) {
            paths = parsed.data
          }
        } catch (e) {
          console.warn("OSMP: invalid Tracks response", e)
          root.nativeQueue = []
          return
        }
        if (paths.length > 0) {
          var cmd = [
            "busctl", "--user", "--json=short", "call",
            root.activePlayer.dbusName,
            "/org/mpris/MediaPlayer2",
            "org.mpris.MediaPlayer2.TrackList",
            "GetTracksMetadata",
            "ao",
            String(paths.length)
          ]
          for (var k = 0; k < paths.length; k++) cmd.push(paths[k])
          getMetadataProc.command = cmd
          root.queueBusName = root.activePlayer.dbusName
          getMetadataProc.running = false
          getMetadataProc.running = true
        } else {
          root.nativeQueue = []
        }
      }
    }
  }

  Process {
    id: getMetadataProc
    stdout: SplitParser {
      onRead: function(line) {
        var str = String(line).trim()
        if (!str || !root.activePlayer) return
        if (!root.queueBusName || root.activePlayer.dbusName !== root.queueBusName) return
        var currentId = root.activePlayer.trackId || ""
        var pKey = MediaLibrary.MediaModel.keyFor(root.activePlayer)
        var parsedList = MediaLibrary.MediaModel.parseBusctlTracksMetadata(str, currentId, pKey, root.title)
        root.nativeQueue = parsedList
      }
    }
  }

  property bool panelOpen: false
  onHasMediaChanged: if (!hasMedia) panelOpen = false
  function close() { panelOpen = false }

  onPlayersChanged: {
    for (var i = 0; i < players.length; i++) touch(players[i])
  }

  Instantiator {
    model: root.players
    delegate: Connections {
      required property var modelData
      target: modelData
      function onIsPlayingChanged() { root.touch(modelData) }
      function onTrackTitleChanged() { root.touch(modelData) }
      function onTrackArtistChanged() { root.touch(modelData) }
      function onPlaybackStateChanged() { root.touch(modelData) }
    }
  }

  Connections {
    target: root.activePlayer
    function onPositionChanged() {
      if (!root.isSeeking && root.activePlayer) {
        root.trackPosition = root.activePlayer.position || 0
      }
    }
    function onLengthChanged() {
      if (root.activePlayer) {
        root.trackLength = root.activePlayer.length > 0 ? root.activePlayer.length : 0
      }
    }
  }

  Timer {
    id: positionTimer
    interval: 500
    running: root.panelOpen && root.isPlaying && !root.isSeeking
    repeat: true
    onTriggered: {
      if (root.activePlayer) {
        root.trackPosition = root.activePlayer.position || 0
      }
    }
  }

  function seekTo(val) {
    if (root.canSeek && isFinite(val)) {
      var position = Math.max(0, Math.min(root.trackLength, val))
      root.activePlayer.position = position
      root.trackPosition = position
    }
  }

  function runAction(action) {
    var p = root.activePlayer
    if (!p) return
    if (action === "previous") { if (p.canGoPrevious) p.previous() }
    else if (action === "next") { if (p.canGoNext) p.next() }
    else if (action === "playPause") {
      if (p.isPlaying && p.canPause) p.pause()
      else if (!p.isPlaying && p.canPlay) p.play()
      else if (p.canTogglePlaying) p.togglePlaying()
    }
  }

  visible: root.hasMedia
  implicitWidth: visible ? button.implicitWidth : 0
  implicitHeight: visible ? button.implicitHeight : 0

  Ui.BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.isPlaying ? "󰏤" : "󰐊"
    foreground: root.bar ? root.bar.barForeground : Color.foreground
    tooltipText: root.hasMedia ? (root.title + (root.artist ? " — " + root.artist : "")) : "OSMP"
    onPressed: function(b) {
      if (b === Qt.RightButton) {
        root.runAction("playPause")
      } else if (b === Qt.MiddleButton) {
        root.runAction("next")
      } else {
        root.panelOpen = !root.panelOpen
      }
    }
    onWheelMoved: function(delta) {
      if (!root.hasMedia) return
      if (delta > 0) root.runAction("previous")
      else if (delta < 0) root.runAction("next")
    }
  }

  MediaPopup {
    id: popup
    anchorItem: button
    bar: root.bar
    owner: root
    playerWidget: root
    open: root.panelOpen
  }
}
