.pragma library

var STATE_PATH_SUFFIX = "/.local/state/omarchy/settings/theme-modes.json"

function statePath(home) {
  return String(home || "") + STATE_PATH_SUFFIX
}

function slugFromName(name) {
  return String(name || "")
    .replace(/<[^>]+>/g, "")
    .toLowerCase()
    .trim()
    .replace(/\s+/g, "-")
}

function defaultState(currentThemeSlug) {
  var slug = String(currentThemeSlug || "").trim()
  return {
    lightTheme: slug || "flexoki-light",
    darkTheme: slug || "catppuccin",
    lightBackground: "",
    darkBackground: "",
    mode: "dark",
    manualOverride: true,
    autoEnabled: false,
    autoSource: "time",
    lightStart: "07:00",
    darkStart: "19:00",
    batteryDarkOnBattery: true
  }
}

function parseStateFile(raw, currentThemeSlug) {
  var base = defaultState(currentThemeSlug)
  if (!raw || !String(raw).trim()) return base

  try {
    var parsed = JSON.parse(String(raw))
    if (!parsed || typeof parsed !== "object") return base
    if (parsed.lightTheme) base.lightTheme = slugFromName(parsed.lightTheme)
    if (parsed.darkTheme) base.darkTheme = slugFromName(parsed.darkTheme)
    if (parsed.lightBackground) base.lightBackground = String(parsed.lightBackground)
    if (parsed.darkBackground) base.darkBackground = String(parsed.darkBackground)
    if (parsed.mode === "light" || parsed.mode === "dark") base.mode = parsed.mode
    if (typeof parsed.manualOverride === "boolean") base.manualOverride = parsed.manualOverride
    if (typeof parsed.autoEnabled === "boolean") base.autoEnabled = parsed.autoEnabled
    if (parsed.autoSource === "time" || parsed.autoSource === "battery") base.autoSource = parsed.autoSource
    if (parsed.lightStart) base.lightStart = normalizeTime(parsed.lightStart, base.lightStart)
    if (parsed.darkStart) base.darkStart = normalizeTime(parsed.darkStart, base.darkStart)
    if (typeof parsed.batteryDarkOnBattery === "boolean") base.batteryDarkOnBattery = parsed.batteryDarkOnBattery
  } catch (e) {
    return base
  }

  return base
}

function serializeState(state) {
  return JSON.stringify({
    lightTheme: slugFromName(state.lightTheme),
    darkTheme: slugFromName(state.darkTheme),
    lightBackground: String(state.lightBackground || ""),
    darkBackground: String(state.darkBackground || ""),
    mode: state.mode === "light" ? "light" : "dark",
    manualOverride: !!state.manualOverride,
    autoEnabled: !!state.autoEnabled,
    autoSource: state.autoSource === "battery" ? "battery" : "time",
    lightStart: normalizeTime(state.lightStart, "07:00"),
    darkStart: normalizeTime(state.darkStart, "19:00"),
    batteryDarkOnBattery: state.batteryDarkOnBattery !== false
  }, null, 2) + "\n"
}

function normalizeTime(value, fallback) {
  var text = String(value || fallback || "00:00").trim()
  var match = text.match(/^(\d{1,2}):(\d{2})$/)
  if (!match) return fallback
  var hour = Math.max(0, Math.min(23, parseInt(match[1], 10)))
  var minute = Math.max(0, Math.min(59, parseInt(match[2], 10)))
  return (hour < 10 ? "0" : "") + hour + ":" + (minute < 10 ? "0" : "") + minute
}

function parseTimeMinutes(value, fallbackMinutes) {
  var normalized = normalizeTime(value, minutesToTime(fallbackMinutes))
  var parts = normalized.split(":")
  return parseInt(parts[0], 10) * 60 + parseInt(parts[1], 10)
}

function minutesToTime(totalMinutes) {
  var mins = Math.max(0, Math.min(23 * 60 + 59, totalMinutes | 0))
  var hour = Math.floor(mins / 60)
  var minute = mins % 60
  return (hour < 10 ? "0" : "") + hour + ":" + (minute < 10 ? "0" : "") + minute
}

function parseThemeList(raw) {
  var lines = String(raw || "").split("\n")
  var themes = []
  var seen = {}
  for (var i = 0; i < lines.length; i++) {
    var name = String(lines[i] || "").trim()
    if (!name) continue
    var slug = slugFromName(name)
    if (!slug || seen[slug]) continue
    seen[slug] = true
    themes.push({ name: name, slug: slug, previewPath: "" })
  }
  return themes
}

function parseThemeCatalog(raw) {
  if (!raw || !String(raw).trim()) return []
  try {
    var parsed = JSON.parse(String(raw))
    if (!Array.isArray(parsed)) return []
    var themes = []
    var seen = {}
    for (var i = 0; i < parsed.length; i++) {
      var entry = parsed[i]
      if (!entry || typeof entry !== "object") continue
      var name = String(entry.name || "").trim()
      var slug = slugFromName(entry.slug || name)
      if (!name || !slug || seen[slug]) continue
      seen[slug] = true
      themes.push({
        name: name,
        slug: slug,
        previewPath: String(entry.previewPath || "")
      })
    }
    return themes
  } catch (e) {
    return []
  }
}

function displayNameForSlug(slug, themes) {
  var key = slugFromName(slug)
  for (var i = 0; i < themes.length; i++) {
    if (themes[i].slug === key) return themes[i].name
  }
  return key.replace(/-/g, " ").replace(/\b\w/g, function(c) { return c.toUpperCase() })
}

function themeForMode(state) {
  return state.mode === "light" ? slugFromName(state.lightTheme) : slugFromName(state.darkTheme)
}

function backgroundForMode(state) {
  return state.mode === "light" ? String(state.lightBackground || "") : String(state.darkBackground || "")
}

function backgroundInList(path, backgrounds) {
  var target = String(path || "")
  if (!target) return false
  for (var i = 0; i < backgrounds.length; i++) {
    if (backgrounds[i] && backgrounds[i].path === target) return true
  }
  return false
}

function parseBackgroundCatalog(raw) {
  if (!raw || !String(raw).trim()) return []
  try {
    var parsed = JSON.parse(String(raw))
    if (!Array.isArray(parsed)) return []
    var items = []
    for (var i = 0; i < parsed.length; i++) {
      var entry = parsed[i]
      if (!entry || typeof entry !== "object") continue
      var path = String(entry.path || "").trim()
      if (!path) continue
      items.push({
        path: path,
        name: String(entry.name || ""),
        thumbnailPath: String(entry.thumbnailPath || path)
      })
    }
    return items
  } catch (e) {
    return []
  }
}

function computeAutoMode(state, onBattery, date) {
  if (!state.autoEnabled) return state.mode
  if (state.autoSource === "battery") {
    return onBattery ? "dark" : "light"
  }

  var now = date instanceof Date ? date : new Date()
  var current = now.getHours() * 60 + now.getMinutes()
  var lightStart = parseTimeMinutes(state.lightStart, 7 * 60)
  var darkStart = parseTimeMinutes(state.darkStart, 19 * 60)
  if (lightStart === darkStart) return state.mode

  if (lightStart < darkStart) {
    return (current >= lightStart && current < darkStart) ? "light" : "dark"
  }
  return (current >= lightStart || current < darkStart) ? "light" : "dark"
}

function statusLabel(state, onBattery) {
  if (state.manualOverride) return "Manual"
  if (!state.autoEnabled) return "Manual"
  if (state.autoSource === "battery") return onBattery ? "Auto · battery" : "Auto · AC"
  return "Auto · schedule"
}

function modeIcon(mode) {
  return mode === "light" ? "󰖙" : "󰖔"
}
