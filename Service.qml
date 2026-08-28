import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import "Model.js" as Model

Item {
  id: root

  property var settings: ({})
  property var state: Model.defaultState("")
  property var themes: []
  property string appliedTheme: ""
  property var backgrounds: []
  property string backgroundsSlug: ""
  property bool loadingBackgrounds: false
  property int backgroundsRequestId: 0
  property bool loadingThemes: false
  property bool applyingTheme: false
  property bool applyQueued: false
  property string lastError: ""
  property bool stateLoaded: false
  property bool _writingState: false

  readonly property string stateFilePath: Model.statePath(Quickshell.env("HOME"))
  readonly property string pluginDir: {
    var scriptUrl = Qt.resolvedUrl("catalog.sh")
    if (!scriptUrl)
      return Quickshell.env("HOME") + "/.config/omarchy/plugins/esemczak.theme-modes"
    var path = String(scriptUrl)
    if (path.indexOf("file://") === 0)
      path = path.substring(7)
    var slash = path.lastIndexOf("/")
    return slash >= 0 ? path.substring(0, slash) : path
  }
  readonly property bool onBattery: UPower.onBattery === true
  readonly property string activeThemeSlug: Model.themeForMode(state)
  readonly property string statusText: Model.statusLabel(state, onBattery)

  function saveState(nextState) {
    state = nextState
    scheduleStateSave()
  }

  function patchState(patch) {
    saveState(Object.assign({}, state, patch || {}))
  }

  function setLightTheme(slug) {
    var key = Model.slugFromName(slug)
    var next = Object.assign({}, state, { lightTheme: key })
    if (Model.slugFromName(state.lightTheme) !== key)
      next.lightBackground = ""
    saveState(next)
    loadBackgroundsForSlug(key)
    if (next.mode === "light") applyCurrentMode(false)
  }

  function setDarkTheme(slug) {
    var key = Model.slugFromName(slug)
    var next = Object.assign({}, state, { darkTheme: key })
    if (Model.slugFromName(state.darkTheme) !== key)
      next.darkBackground = ""
    saveState(next)
    loadBackgroundsForSlug(key)
    if (next.mode === "dark") applyCurrentMode(false)
  }

  function setLightBackground(path) {
    var nextPath = String(path || "")
    patchState({ lightBackground: nextPath })
    if (state.mode === "light") applyBackground(nextPath)
  }

  function setDarkBackground(path) {
    var nextPath = String(path || "")
    patchState({ darkBackground: nextPath })
    if (state.mode === "dark") applyBackground(nextPath)
  }

  function loadBackgroundsForSlug(slug) {
    var key = Model.slugFromName(slug)
    if (!key) {
      backgrounds = []
      backgroundsSlug = ""
      loadingBackgrounds = false
      return
    }
    if (backgroundsProcess.running) {
      backgroundsProcess.running = false
    }
    backgroundsRequestId++
    var requestId = backgroundsRequestId
    backgroundsSlug = key
    loadingBackgrounds = true
    backgroundsProcess.command = ["bash", root.pluginDir + "/backgrounds.sh", key]
    backgroundsProcess.running = true
    backgroundsProcess.requestId = requestId
  }

  function validateSavedBackground(mode, items) {
    var key = mode === "light" ? "lightBackground" : "darkBackground"
    var current = String(state[key] || "")
    if (!current || Model.backgroundInList(current, items)) return
    var patch = {}
    patch[key] = ""
    patchState(patch)
  }

  function setModeManual(mode) {
    var nextMode = mode === "light" ? "light" : "dark"
    patchState({ mode: nextMode, manualOverride: true })
    applyCurrentMode(true)
  }

  function toggleModeManual() {
    setModeManual(state.mode === "light" ? "dark" : "light")
  }

  function followAutomatic() {
    enableAutomaticSwitching()
  }

  function enableAutomaticSwitching() {
    patchState({ manualOverride: false, autoEnabled: true })
    evaluateAutomatic(true)
  }

  function enableManualSwitching() {
    patchState({ manualOverride: true })
  }

  function setAutoEnabled(enabled) {
    patchState({ autoEnabled: !!enabled })
    if (!state.manualOverride) evaluateAutomatic(true)
  }

  function setAutoSource(source) {
    patchState({ autoSource: source === "battery" ? "battery" : "time" })
    if (!state.manualOverride && state.autoEnabled) evaluateAutomatic(true)
  }

  function setLightStart(value) {
    patchState({ lightStart: Model.normalizeTime(value, state.lightStart) })
    if (!state.manualOverride && state.autoEnabled && state.autoSource === "time") evaluateAutomatic(true)
  }

  function setDarkStart(value) {
    patchState({ darkStart: Model.normalizeTime(value, state.darkStart) })
    if (!state.manualOverride && state.autoEnabled && state.autoSource === "time") evaluateAutomatic(true)
  }

  function refreshThemes() {
    if (catalogProcess.running) return
    loadingThemes = true
    catalogProcess.running = true
  }

  function evaluateAutomatic(forceApply) {
    if (state.manualOverride || !state.autoEnabled) return
    var desired = Model.computeAutoMode(state, onBattery, new Date())
    if (desired === state.mode && !forceApply) return
    patchState({ mode: desired })
    applyCurrentMode(true)
  }

  function applyCurrentMode(fromAuto) {
    var slug = Model.themeForMode(state)
    if (!slug) return
    if (applyProcess.running) {
      applyQueued = true
      return
    }
    applyingTheme = true
    lastError = ""
    var background = Model.backgroundForMode(state)
    var cmd = "omarchy theme set " + shellQuote(slug)
    if (background) cmd += " && omarchy theme bg set " + shellQuote(background)
    applyProcess.command = ["bash", "-lc", cmd]
    applyProcess.running = true
  }

  function applyBackground(path) {
    var target = String(path || "")
    if (!target || backgroundProcess.running) return
    lastError = ""
    backgroundProcess.command = ["bash", "-lc", "omarchy theme bg set " + shellQuote(target)]
    backgroundProcess.running = true
  }

  function shellQuote(value) {
    return "'" + String(value || "").replace(/'/g, "'\\''") + "'"
  }

  function loadState(raw, currentThemeSlug) {
    state = Model.parseStateFile(raw, currentThemeSlug)
    stateLoaded = true
    evaluateAutomatic(false)
  }

  function flushState() {
    if (!stateLoaded) return
    _writingState = true
    stateFile.setText(Model.serializeState(state))
    Qt.callLater(function() { root._writingState = false })
  }

  function scheduleStateSave() {
    if (!stateLoaded) return
    stateSaveTimer.restart()
  }

  FileView {
    id: stateFile
    path: root.stateFilePath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: if (!root._writingState) currentThemeReader.running = true
    onLoadFailed: if (!root._writingState) currentThemeReader.running = true
  }

  Timer {
    id: stateSaveTimer
    interval: 200
    repeat: false
    onTriggered: root.flushState()
  }

  Process {
    id: ensureDirsProc
    command: ["bash", "-lc", "mkdir -p \"$(dirname '" + root.stateFilePath.replace(/'/g, "'\\''") + "')\""]
    onExited: if (!stateFile.loaded) stateFile.reload()
  }

  Process {
    id: currentThemeReader
    command: ["bash", "-lc", "cat \"$HOME/.local/state/omarchy/current/theme.name\" 2>/dev/null || true"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.loadState(stateFile.text(), text)
    }
  }

  Process {
    id: catalogProcess
    command: ["bash", root.pluginDir + "/catalog.sh"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var parsed = Model.parseThemeCatalog(text)
        if (parsed.length > 0) {
          root.themes = parsed
        } else {
          themeListFallbackProcess.running = true
        }
        root.loadingThemes = false
      }
    }
    onExited: function(code) {
      if (code !== 0) {
        themeListFallbackProcess.running = true
        root.loadingThemes = false
      }
    }
  }

  Process {
    id: themeListFallbackProcess
    command: ["bash", "-lc", "omarchy theme list"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var parsed = Model.parseThemeCatalog(text)
        root.themes = parsed.length > 0 ? parsed : Model.parseThemeList(text)
      }
    }
  }

  Process {
    id: backgroundsProcess
    property int requestId: 0
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (backgroundsProcess.requestId !== root.backgroundsRequestId) return
        var slug = root.backgroundsSlug
        var items = Model.parseBackgroundCatalog(text)
        root.backgrounds = items
        root.loadingBackgrounds = false
        if (slug === Model.slugFromName(root.state.lightTheme))
          root.validateSavedBackground("light", items)
        if (slug === Model.slugFromName(root.state.darkTheme))
          root.validateSavedBackground("dark", items)
      }
    }
    onExited: function(code) {
      if (code !== 0) {
        root.backgrounds = []
        root.loadingBackgrounds = false
      }
    }
  }

  Process {
    id: backgroundProcess
    onExited: function(code) {
      if (code !== 0) root.lastError = "Failed to apply background"
    }
  }

  Process {
    id: applyProcess
    onExited: function(code) {
      root.applyingTheme = false
      if (code !== 0) {
        root.lastError = "Failed to apply theme"
        root.applyQueued = false
        return
      }
      root.appliedTheme = Model.themeForMode(root.state)
      root.lastError = ""
      if (root.applyQueued) {
        root.applyQueued = false
        root.applyCurrentMode(false)
      }
    }
  }

  Timer {
    interval: 30000
    running: root.stateLoaded && root.state.autoEnabled && !root.state.manualOverride
    repeat: true
    triggeredOnStart: true
    onTriggered: root.evaluateAutomatic(false)
  }

  Connections {
    target: UPower
    function onOnBatteryChanged() {
      if (!root.stateLoaded) return
      if (!root.state.manualOverride && root.state.autoEnabled && root.state.autoSource === "battery")
        root.evaluateAutomatic(false)
    }
  }

  Component.onCompleted: {
    ensureDirsProc.running = true
    refreshThemes()
  }
}
